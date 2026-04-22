#!/usr/bin/env bash
# run-underfire.sh — verify classifier CORRECTLY classifies every command in
# tests/fixtures/soak/underfire.txt at write-host severity or higher. No
# commands are executed — the file is read as data and piped to classify.py.
#
# Pass criterion: 0 lines classify as read-safe or unknown.
#
# Snapshot semantics: truncates underfire-results.jsonl at start of run.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "run-underfire"

OUT="underfire-results.jsonl"
snapshot_begin "$OUT"

LIST="$HCS_ROOT/tests/fixtures/soak/underfire.txt"
if [ ! -f "$LIST" ]; then
  echo "  ✗ $LIST missing" >&2
  exit 1
fi

tmp_in="$(mktemp)"
trap 'rm -f "$tmp_in"' EXIT
while IFS= read -r line; do
  case "$line" in
    '' | \#*) continue ;;
  esac
  python3 -c "import json,sys; print(json.dumps({'command': sys.argv[1]}))" "$line" >> "$tmp_in"
done < "$LIST"

results=$(python3 "$HCS_ROOT/scripts/dev/classify.py" --batch < "$tmp_in")

total=0
slips=0
while IFS= read -r rec; do
  [ -z "$rec" ] && continue
  total=$((total + 1))
  cls=$(printf '%s' "$rec" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('classified_class',''))")
  if [ "$cls" = "read-safe" ] || [ "$cls" = "unknown" ]; then
    slips=$((slips + 1))
    cmd=$(printf '%s' "$rec" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d.get("command","")[:90])')
    printf '  ✗ UNDER-FIRE: %s (classified %s)\n' "$cmd" "$cls"
  fi
  jsonl_append "$OUT" "$rec"
done <<< "$results"

echo "  — total tested: $total, under-classifications: $slips (target 0)"
echo "  → $(log_dir)/$OUT"

[ "$slips" -eq 0 ]
