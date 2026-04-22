#!/usr/bin/env bash
# hcs-hook-cli.sh — Phase 0b log-only Claude Code / Codex hook.
#
# Reads a JSON hook event on stdin, classifies any embedded shell command via
# classify.py, appends a decision record to `.logs/phase-0/<today>/hook-decisions.jsonl`,
# and writes a structured decision JSON on stdout. Always exits 0.
#
# PHASE 0b SCOPE: log-only. Never blocks, never denies, never asks. Phase 1+
# will replace this with a kernel-backed hook that consumes canonical policy
# (see AGENTS.md §Hard boundaries and implementation-charter.md invariants).
#
# Hook event schema (Claude Code PreToolUse, per docs/hooks-guide):
#   {"session_id": "...", "cwd": "...", "hook_event_name": "PreToolUse",
#    "tool_name": "Bash", "tool_input": {"command": "...", "description": "..."}}
#
# On stdout: JSON decision with `continue` always true in Phase 0b.
#   {"continue": true, "suppressOutput": true,
#    "hookSpecificOutput": {"hookEventName": "PreToolUse",
#                           "permissionDecision": "allow",
#                           "permissionDecisionReason": "phase-0b log-only"}}

set -euo pipefail

# Locate the HCS root and load common helpers.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HCS_ROOT="${HCS_ROOT:-$(cd "$HOOK_DIR/../.." && pwd)}"
export HCS_ROOT
# shellcheck disable=SC1091
. "$HCS_ROOT/scripts/dev/measure-common.sh"

OUT="hook-decisions.jsonl"
# Append semantics during live soak (unlike other measure-* scripts which
# snapshot). Hook decisions accumulate across the day as the user works;
# truncating them would lose data. snapshot_begin() is NOT called.
mkdir -p "$OUT_DIR"
touch "$OUT_DIR/$OUT"

# Read stdin with a bounded timeout so a stalled hook doesn't hang agent.
input_json=""
if ! input_json="$(cat)"; then
  input_json=""
fi

# Parse with jq if available, else fall back to a best-effort grep. jq is
# required for correct JSON handling — if missing, emit an error record and
# still return allow (log-only contract).
if ! command -v jq >/dev/null 2>&1; then
  jsonl_append "$OUT" "{\"ts\":\"$(iso_now)\",\"hook_error\":\"jq-missing\"}"
  printf '%s\n' '{"continue":true,"suppressOutput":true}'
  exit 0
fi

# Pre-parse guard: if input isn't valid JSON, emit an error record and a
# minimally valid decision. Never crash.
if ! printf '%s' "$input_json" | jq -e '.' >/dev/null 2>&1; then
  jsonl_append "$OUT" "{\"ts\":\"$(iso_now)\",\"hook_error\":\"malformed-input\",\"input_len\":${#input_json}}"
  printf '%s\n' '{"continue":true,"suppressOutput":true,"hookSpecificOutput":{"hookEventName":"unknown","permissionDecision":"allow","permissionDecisionReason":"phase-0b malformed-input"}}'
  exit 0
fi

# Extract fields. Tolerate missing fields.
hook_event=$(printf '%s' "$input_json" | jq -r '.hook_event_name // "unknown"' 2>/dev/null || printf 'unknown')
tool_name=$(printf '%s' "$input_json" | jq -r '.tool_name // "unknown"' 2>/dev/null || printf 'unknown')
session_id=$(printf '%s' "$input_json" | jq -r '.session_id // ""' 2>/dev/null || printf '')
cwd=$(printf '%s' "$input_json" | jq -r '.cwd // ""' 2>/dev/null || printf '')
command=$(printf '%s' "$input_json" | jq -r '.tool_input.command // ""' 2>/dev/null || printf '')

verdict_class="n/a"
verdict_reason="non-shell-tool"
verdict_first=""

# Only classify shell commands. Other tools (Read/Edit/Write) are logged with
# tool-name only.
if [ "$tool_name" = "Bash" ] && [ -n "$command" ]; then
  verdict_json=$(printf '%s' "$command" | python3 "$HCS_ROOT/scripts/dev/classify.py" --batch <<EOF
{"command": $(printf '%s' "$command" | jq -Rs .)}
EOF
)
  verdict_class=$(printf '%s' "$verdict_json" | jq -r '.classified_class // "parser-error"')
  verdict_reason=$(printf '%s' "$verdict_json" | jq -r '.classified_reason // ""')
  verdict_first=$(printf '%s' "$verdict_json" | jq -r '.classified_first_token // ""')
fi

# Record. Redact command text before writing to disk.
command_redacted=""
if [ -n "$command" ]; then
  command_redacted="$(redact "$command")"
fi

# Emit JSONL record. Truncate command to keep records bounded.
truncated=$(printf '%s' "$command_redacted" | head -c 400)
record=$(jq -cn \
  --arg ts "$(iso_now)" \
  --arg hook "$hook_event" \
  --arg tool "$tool_name" \
  --arg session "$session_id" \
  --arg cwd "$cwd" \
  --arg cmd "$truncated" \
  --arg cls "$verdict_class" \
  --arg reason "$verdict_reason" \
  --arg first "$verdict_first" \
  '{ts: $ts, hook_event: $hook, tool: $tool, session_id: $session, cwd: $cwd,
    command_redacted: $cmd, classified_class: $cls,
    classified_reason: $reason, classified_first_token: $first}')
printf '%s\n' "$record" >> "$OUT_DIR/$OUT"

# Phase 0b contract: always allow. Future phases add deny/ask based on class.
printf '%s\n' '{"continue":true,"suppressOutput":true,"hookSpecificOutput":{"hookEventName":"'"$hook_event"'","permissionDecision":"allow","permissionDecisionReason":"phase-0b log-only"}}'
exit 0
