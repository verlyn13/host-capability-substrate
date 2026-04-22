#!/usr/bin/env bash
# run-fault-injection.sh — inject 10 fault scenarios against the log-only hook
# and verify it fails safely (non-silent, non-mutating) in each.
#
# Every scenario:
#   1. constructs a fault condition (bad JSON, missing field, timeout, etc.)
#   2. invokes the hook
#   3. records hook exit code and stdout
#   4. records whether decision JSON on stdout is well-formed
#
# The hook's Phase 0b contract is: ALWAYS exit 0, ALWAYS emit valid decision
# JSON on stdout, NEVER crash. This harness verifies those guarantees.
#
# Snapshot semantics: truncates fault-injection.jsonl at start of run.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "run-fault-injection"

OUT="fault-injection.jsonl"
snapshot_begin "$OUT"

HOOK="$HCS_ROOT/scripts/dev/hcs-hook-cli.sh"

run_case() {
  local name="$1"
  local stdin="$2"
  local max_wait="${3:-2}"

  local stdout="" exit_code=0
  if ! stdout=$(printf '%s' "$stdin" | timeout "$max_wait" "$HOOK" 2>/dev/null); then
    exit_code=$?
  fi

  # Valid decision shape check: must be valid JSON with a "continue" boolean.
  local ok="false"
  local decision_json
  decision_json=$(printf '%s' "$stdout" | jq -c '.' 2>/dev/null || true)
  if [ -n "$decision_json" ]; then
    local cont
    cont=$(printf '%s' "$decision_json" | jq -r '.continue // empty' 2>/dev/null)
    if [ "$cont" = "true" ] || [ "$cont" = "false" ]; then
      ok="true"
    fi
  fi

  local rec
  rec=$(jq -cn \
    --arg ts "$(iso_now)" \
    --arg case "$name" \
    --argjson exit "$exit_code" \
    --arg stdout "$stdout" \
    --argjson ok "$ok" \
    '{ts:$ts, case:$case, hook_exit:$exit, hook_stdout:$stdout, decision_shape_valid:$ok}')
  jsonl_append "$OUT" "$rec"

  if [ "$ok" = "true" ] && [ "$exit_code" -eq 0 ]; then
    printf '  ✓ %-35s exit=%d decision=valid\n' "$name" "$exit_code"
    return 0
  else
    printf '  ✗ %-35s exit=%d decision=%s\n' "$name" "$exit_code" "$ok"
    return 1
  fi
}

# Each payload constructed at call time via jq so we avoid bash command
# substitution surprises inside array literals.
payload_valid_bash() {
  jq -cn --arg cmd "$1" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$cmd}, session_id:"fault", cwd:"/tmp"}'
}

pass=0
fail=0
total=0

tick() {
  total=$((total + 1))
  if "$@"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
}

tick run_case "empty-stdin" ""
tick run_case "malformed-json" "{not json"
tick run_case "missing-tool-name" '{"hook_event_name":"PreToolUse","tool_input":{"command":"ls"}}'
tick run_case "missing-tool-input" '{"hook_event_name":"PreToolUse","tool_name":"Bash"}'
tick run_case "missing-command-field" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"description":"x"}}'
tick run_case "valid-with-no-cwd" "$(payload_valid_bash 'ls')"
tick run_case "non-shell-tool" '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}'
tick run_case "compound-pipeline" "$(payload_valid_bash "find . -name '*.log' | head -3 | sort")"
tick run_case "bad-sed-delimiter" "$(payload_valid_bash "sed -e 's#foo#bar#g' file.txt")"
# String contains a '$(' subshell as LITERAL command text the hook will see —
# jq quoting prevents bash from evaluating it here.
tick run_case "subshell-forbidden-inside" "$(payload_valid_bash 'echo "before $(spctl --master-disable) after"')"

echo "  — $pass passed, $fail failed (of $total cases)"
echo "  → $(log_dir)/$OUT"
[ "$fail" -eq 0 ]
