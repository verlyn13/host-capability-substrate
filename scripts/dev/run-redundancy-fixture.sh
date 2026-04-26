#!/usr/bin/env bash
# run-redundancy-fixture.sh — regression check for semantic tool mapping.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/redundancy"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-redundancy-fixture.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

cp "$fixture_dir"/activity-*.jsonl "$tmp_dir"/

HCS_MEASURE_OUT_DIR="$tmp_dir" bash "$repo_root/scripts/dev/measure-redundancy.sh"

python3 - "$tmp_dir/redundancy.jsonl" <<'PYEOF'
import json
import sys

path = sys.argv[1]
records = []
with open(path) as f:
    for line in f:
        line = line.strip()
        if line:
            records.append(json.loads(line))

summary = next((r for r in records if r.get("category") == "__summary__"), None)
if summary is None:
    raise SystemExit("missing redundancy summary")

expected = {
    "semantic_mapping_version": "semantic-tool-map-v1",
    "unique_tools_observed": 8,
    "unique_semantic_tools_observed": 5,
    "cross_source_redundant_tools": 3,
    "total_redundant_calls": 16,
}
for key, value in expected.items():
    actual = summary.get(key)
    if actual != value:
        raise SystemExit(f"{key}: expected {value!r}, got {actual!r}")

semantic = {r.get("semantic_tool"): r for r in records if r.get("category") != "__summary__"}
for key, raw_tools in {
    "shell.command": ["Bash", "exec_command"],
    "work-plan.update": ["TaskUpdate", "update_plan"],
    "human-input.request": ["AskUserQuestion", "request_user_input"],
}.items():
    rec = semantic.get(key)
    if rec is None:
        raise SystemExit(f"missing semantic record {key}")
    if rec.get("raw_tools") != raw_tools:
        raise SystemExit(f"{key}: expected raw_tools {raw_tools!r}, got {rec.get('raw_tools')!r}")
    if rec.get("cross_source") is not True:
        raise SystemExit(f"{key}: expected cross_source true")

print("  ✓ semantic redundancy fixture passed")
PYEOF
