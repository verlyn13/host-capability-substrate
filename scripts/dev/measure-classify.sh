#!/usr/bin/env bash
# measure-classify.sh — Phase 0b: run classifier over commands.jsonl.
#
# Depends on measure-commands.sh having run first in the same day partition.
# Emits `classify.jsonl` with one record per command: original fields plus
# classified_class, classified_reason, classified_first_token, classified_segments.
#
# Snapshot semantics: truncates classify.jsonl at start of run.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-classify"

IN="commands.jsonl"
OUT="classify.jsonl"

if [ ! -s "$OUT_DIR/$IN" ]; then
  echo "  ⏸  no commands.jsonl in $OUT_DIR — run measure-commands first"
  snapshot_begin "$OUT"
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"classify\",\"status\":\"no-input\"}"
  exit 0
fi

snapshot_begin "$OUT"

classifier="$HCS_ROOT/scripts/dev/classify.py"
if [ ! -f "$classifier" ]; then
  echo "  ✗ classifier not found: $classifier" >&2
  exit 1
fi

python3 "$classifier" --batch < "$OUT_DIR/$IN" > "$OUT_DIR/$OUT"

total=$(wc -l < "$OUT_DIR/$OUT" | tr -d ' ')
echo "  ✓ classified $total records"
echo "  → $(log_dir)/$OUT"
