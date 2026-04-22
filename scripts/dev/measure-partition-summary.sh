#!/usr/bin/env bash
# measure-partition-summary.sh — print the current-day partition summary.
# Separated from the justfile so `$(date ...)` isn't caught by just's own interpolation.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"

d="$OUT_DIR"
mode="${1:-}"

if [ ! -d "$d" ]; then
  echo "no partition yet for today; run: just measure"
  exit 0
fi

echo
echo "→ partition: $d/"

if [ "$mode" = "--detail" ]; then
  echo "=== $d ==="
  for f in "$d"/*.jsonl; do
    [ -f "$f" ] && printf "  %-40s  %6s records\n" "$(basename "$f")" "$(wc -l < "$f" | tr -d ' ')"
  done
  [ -f "$d/protocol-features.json" ] && printf "  %-40s  %s\n" "$(basename "$d/protocol-features.json")" "present"
else
  ls -l "$d"/ 2>/dev/null || true
fi
