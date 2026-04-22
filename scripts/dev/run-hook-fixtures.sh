#!/usr/bin/env bash
# run-hook-fixtures.sh — pipe each hook fixture through the log-only hook and
# compare its classification to the fixture's `_expected_class`.
#
# Output: `hook-fixtures.jsonl` in the day partition, one record per fixture
#   {fixture_id, expected, actual, pass, hook_exit, hook_stdout}
# Plus a summary printed to stdout.
#
# Snapshot semantics: truncates hook-fixtures.jsonl at start of run.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "run-hook-fixtures"

OUT="hook-fixtures.jsonl"
snapshot_begin "$OUT"

HOOK="$HCS_ROOT/scripts/dev/hcs-hook-cli.sh"
FIX_DIR="$HCS_ROOT/tests/fixtures/hooks"

if [ ! -d "$FIX_DIR" ]; then
  echo "  ✗ fixtures dir missing: $FIX_DIR" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "  ✗ jq not installed" >&2
  exit 1
fi

pass=0
fail=0
total=0

# Fixtures have _expected_class; when hook classifies a non-Bash tool it
# returns class "n/a" — fixture author marks this with expected "n/a".
for fx in "$FIX_DIR"/*.json; do
  [ -e "$fx" ] || continue
  total=$((total + 1))
  expected=$(jq -r '._expected_class // "n/a"' "$fx")
  fid=$(jq -r '._fixture_id // "?"' "$fx")

  hook_stdout=""
  hook_exit=0
  if ! hook_stdout=$("$HOOK" < "$fx" 2>/dev/null); then
    hook_exit=$?
  fi

  # Hook does not include the classification in stdout (always "allow" in
  # Phase 0b). Read it from the hook-decisions.jsonl tail instead.
  actual=$(tail -1 "$OUT_DIR/hook-decisions.jsonl" 2>/dev/null | jq -r '.classified_class // "parser-error"' 2>/dev/null || printf 'parser-error')

  if [ "$actual" = "$expected" ]; then
    ok=true
    pass=$((pass + 1))
    printf '  ✓ %-40s expected=%-20s actual=%-20s\n' "$fid" "$expected" "$actual"
  else
    ok=false
    fail=$((fail + 1))
    printf '  ✗ %-40s expected=%-20s actual=%-20s\n' "$fid" "$expected" "$actual"
  fi

  rec=$(jq -cn \
    --arg ts "$(iso_now)" \
    --arg fid "$fid" \
    --arg exp "$expected" \
    --arg act "$actual" \
    --argjson ok "$ok" \
    --arg stdout "$hook_stdout" \
    --argjson exit "$hook_exit" \
    '{ts:$ts, fixture_id:$fid, expected:$exp, actual:$act, pass:$ok, hook_exit:$exit, hook_stdout:$stdout}')
  jsonl_append "$OUT" "$rec"
done

echo "  — $pass/$total passed, $fail failed"
echo "  → $(log_dir)/$OUT"

# Exit non-zero if any failed.
[ "$fail" -eq 0 ]
