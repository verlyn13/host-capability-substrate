#!/usr/bin/env bash
# measure-redundancy.sh — Phase 0b: cross-source redundant-tool-call detection.
#
# Reads all activity-*.jsonl files in the CURRENT partition. Identifies the
# same logical command pattern appearing across different sources / agent-ids
# within a 24h window (the partition is daily, so same-day counts as within
# window by definition).
#
# Output: $OUT_DIR/redundancy.jsonl with per-pattern cross-source records +
# an aggregate __summary__ row.
#
# Snapshot semantics: overwrites redundancy.jsonl fresh each run.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-redundancy"

OUT="redundancy.jsonl"
snapshot_begin "$OUT"

python3 - "$OUT_DIR" "$OUT" <<'PYEOF'
import json, os, sys
from collections import defaultdict
from datetime import datetime, timezone

out_dir = sys.argv[1]
out_name = sys.argv[2]
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Collect tool-use / function-call shape records across sources.
# Aggregate key = normalized tool name; track which sources surfaced it.
by_tool = defaultdict(lambda: {"sources": set(), "count_by_source": defaultdict(int)})

activity_files = []
for fn in sorted(os.listdir(out_dir)):
    if fn.startswith("activity-") and fn.endswith(".jsonl"):
        activity_files.append(os.path.join(out_dir, fn))

for path in activity_files:
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                cat = d.get('category', '')
                src = d.get('source', '?')
                if cat == 'tool-use-shape':
                    name = d.get('tool') or '?'
                elif cat == 'function-call-shape':
                    name = d.get('tool') or '?'
                elif cat == 'dynamic-tool-registration':
                    continue
                else:
                    continue
                count = int(d.get('count', 0))
                by_tool[name]["sources"].add(src)
                by_tool[name]["count_by_source"][src] += count
    except (OSError, PermissionError):
        continue

# Emit per-tool records.
lines_out = []
redundant_tools = 0
total_redundant_calls = 0
for tool, info in sorted(by_tool.items(), key=lambda kv: -sum(kv[1]["count_by_source"].values())):
    sources = sorted(info["sources"])
    counts = {s: info["count_by_source"][s] for s in sources}
    total = sum(counts.values())
    cross_source = len(sources) >= 2
    if cross_source:
        redundant_tools += 1
        total_redundant_calls += total
    lines_out.append(json.dumps({
        "ts": ts,
        "tool": tool,
        "sources": sources,
        "count_by_source": counts,
        "total": total,
        "cross_source": cross_source,
    }))

# Aggregate summary
lines_out.append(json.dumps({
    "ts": ts,
    "category": "__summary__",
    "activity_files_scanned": len(activity_files),
    "unique_tools_observed": len(by_tool),
    "cross_source_redundant_tools": redundant_tools,
    "total_redundant_calls": total_redundant_calls,
    "note": "Cross-source redundancy: same tool name surfaced by ≥2 distinct sources in this partition. Same-day window by definition of per-day partition.",
}))

out_path = os.path.join(out_dir, out_name)
with open(out_path, 'w') as f:
    f.write("\n".join(lines_out) + "\n")

print(f"  ✓ redundancy analysis: {len(by_tool)} tools observed, {redundant_tools} cross-source redundant")
PYEOF

echo "  → $(log_dir)/$OUT"
