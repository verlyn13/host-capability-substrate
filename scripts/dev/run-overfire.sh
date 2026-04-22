#!/usr/bin/env bash
# run-overfire.sh — verify classifier does NOT hard-block safe-but-suspicious
# commands listed in tests/fixtures/soak/overfire.txt.
#
# Pass criterion: 0 lines classify as forbidden or write-destructive.
# <2% hard-block rate is the Phase 0b exit gate; 0 is the desired outcome.
#
# Snapshot semantics: truncates overfire-results.jsonl at start of run.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "run-overfire"

OUT="overfire-results.jsonl"
snapshot_begin "$OUT"

LIST="$HCS_ROOT/tests/fixtures/soak/overfire.txt"
if [ ! -f "$LIST" ]; then
  echo "  ✗ $LIST missing" >&2
  exit 1
fi

# Build an input JSONL from the list.
tmp_in="$(mktemp)"
trap 'rm -f "$tmp_in"' EXIT
while IFS= read -r line; do
  case "$line" in
    '' | \#*) continue ;;
  esac
  # Python json to quote safely.
  python3 -c "import json,sys; print(json.dumps({'command': sys.argv[1]}))" "$line" >> "$tmp_in"
done < "$LIST"

# Pipe through classify.py batch mode.
results=$(python3 "$HCS_ROOT/scripts/dev/classify.py" --batch < "$tmp_in")

total=0
hard_blocks=0
while IFS= read -r rec; do
  [ -z "$rec" ] && continue
  total=$((total + 1))
  cls=$(printf '%s' "$rec" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('classified_class',''))")
  if [ "$cls" = "forbidden" ] || [ "$cls" = "write-destructive" ]; then
    hard_blocks=$((hard_blocks + 1))
    printf '  ✗ HARD-BLOCK: %s\n' "$(printf '%s' "$rec" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d.get("command","")[:90])')"
  fi
  jsonl_append "$OUT" "$rec"
done <<< "$results"

rate=0
if [ "$total" -gt 0 ]; then
  rate=$(python3 -c "print(round(100 * $hard_blocks / $total, 3))")
fi

echo "  — total tested: $total, hard-blocks: $hard_blocks (${rate}%, target ≤2%)"
echo "  → $(log_dir)/$OUT"

# Fail if overblock rate >2%.
python3 -c "import sys; sys.exit(0 if $hard_blocks * 100 <= 2 * $total else 1)"
