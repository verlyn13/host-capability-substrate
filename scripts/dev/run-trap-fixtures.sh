#!/usr/bin/env bash
# run-trap-fixtures.sh — regression check for measurement-side trap heuristics.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/traps"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-trap-fixture.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

file_list="$tmp_dir/file-list.txt"
printf '%s\n' "$fixture_dir/trap-source.jsonl" > "$file_list"

HCS_MEASURE_OUT_DIR="$tmp_dir" HCS_TRAP_FILE_LIST="$file_list" bash "$repo_root/scripts/dev/measure-traps.sh"

python3 - "$tmp_dir/traps.jsonl" <<'PYEOF'
import json
import sys
from collections import Counter

path = sys.argv[1]
records = []
with open(path) as f:
    for line in f:
        line = line.strip()
        if line:
            records.append(json.loads(line))

summary = next((r for r in records if r.get("trap_name") == "__summary__"), None)
if summary is None:
    raise SystemExit("missing trap summary")

counts = Counter(r.get("trap_name") for r in records if r.get("trap_name") != "__summary__")
for trap in (
    "process-argv-secret-exposure",
    "cloudflare-mcp-mutation-without-fanout-check",
):
    if counts[trap] < 1:
        raise SystemExit(f"expected at least one hit for {trap}, got {counts[trap]}")

if int(summary.get("traps_scanned", 0)) < 17:
    raise SystemExit(f"expected at least 17 scanned traps, got {summary.get('traps_scanned')!r}")

print("  ✓ trap fixture passed")
PYEOF
