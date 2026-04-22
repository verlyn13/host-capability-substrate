#!/usr/bin/env bash
# measure-claude-code.sh — Phase 0b: shape counts from Claude Code session artifacts.
#
# Reads (never writes):
#   ~/.claude/history.jsonl          user prompts
#   ~/.claude/sessions/*.json        session tool-call records (if present)
#   ~/.claude/shell-snapshots/*.sh   per-session shell env (shape only)
#
# Writes:
#   $OUT_DIR/activity.jsonl          appended tool-call shape buckets

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
assert_read_only_host_paths
script_banner "measure-claude-code"

CC_HOME="$HOME/.claude"

# 1. History file — count prompts per day, estimate chars/day.
if [ -f "$CC_HOME/history.jsonl" ]; then
  prompt_count=$(wc -l < "$CC_HOME/history.jsonl" | tr -d ' ')
  total_chars=$(wc -c < "$CC_HOME/history.jsonl" | tr -d ' ')
  ts="$(iso_now)"
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$ts\",\"source\":\"claude-code-history\",\"category\":\"prompt-volume\",\"prompt_count\":$prompt_count,\"total_chars\":$total_chars}"
  echo "  ✓ claude-code history: $prompt_count prompts, $total_chars chars"
else
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-history\",\"status\":\"source-unavailable\"}"
  echo "  ⏸  claude-code history unavailable"
fi

# 2. Sessions — count per-session tool-call shapes if the sessions exist.
if [ -d "$CC_HOME/sessions" ]; then
  session_count=$(ls -1 "$CC_HOME/sessions" 2>/dev/null | grep -c '\.json$' || echo 0)
  ts="$(iso_now)"
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$ts\",\"source\":\"claude-code-sessions\",\"category\":\"session-count\",\"session_count\":$session_count}"
  echo "  ✓ claude-code sessions: $session_count files"

  # Extract tool-call category counts from each session (shape only).
  # Sessions use a JSON format with a `messages` array or similar.
  # Grep for common command patterns that appear in tool_use events.
  tmp="$(mktemp)"
  for f in "$CC_HOME"/sessions/*.json; do
    [ -f "$f" ] || continue
    # Shape-only: count occurrences of common patterns
    grep -oE '"Bash"|"Read"|"Edit"|"Write"|"Grep"|"Glob"|"WebFetch"|"WebSearch"|"Task"' "$f" 2>/dev/null >> "$tmp" || true
  done
  if [ -s "$tmp" ]; then
    sort "$tmp" | uniq -c | while read -r count tool_q; do
      tool="$(printf '%s' "$tool_q" | tr -d '"')"
      jsonl_append "activity.jsonl" \
        "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-sessions\",\"category\":\"tool-use-shape\",\"tool\":\"$tool\",\"count\":$count}"
    done
  fi
  rm -f "$tmp"
else
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-sessions\",\"status\":\"source-unavailable\"}"
fi

# 3. Shell snapshots — count unique PATH entries per session (shape detection).
if [ -d "$CC_HOME/shell-snapshots" ]; then
  snap_count=$(ls -1 "$CC_HOME/shell-snapshots" 2>/dev/null | grep -c '\.sh$' || echo 0)
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-shell-snapshots\",\"category\":\"snapshot-count\",\"snapshot_count\":$snap_count}"
  echo "  ✓ claude-code shell snapshots: $snap_count"
fi

# 4. Scan history for likely --help / version-probe command shapes.
# We look at user prompts (display field) for patterns indicating the USER asked
# about a tool, which often triggers the agent to probe. This is a proxy signal.
if [ -f "$CC_HOME/history.jsonl" ]; then
  help_mentions=$(grep -cE '"display":"[^"]*--help|"display":"[^"]*-h(\\s|")' "$CC_HOME/history.jsonl" 2>/dev/null || echo 0)
  version_mentions=$(grep -cE '"display":"[^"]*(version|--version|-V(\\s|"))' "$CC_HOME/history.jsonl" 2>/dev/null || echo 0)
  which_mentions=$(grep -cE '"display":"[^"]*(which|command -v|type )[ \\]' "$CC_HOME/history.jsonl" 2>/dev/null || echo 0)
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-history\",\"category\":\"probe-mentions\",\"help\":$help_mentions,\"version\":$version_mentions,\"which\":$which_mentions}"
  echo "  ✓ claude-code probe proxies: help=$help_mentions version=$version_mentions which=$which_mentions"
fi

echo "  → $(log_dir)/activity.jsonl"
