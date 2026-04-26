#!/usr/bin/env bash
# measure-redundancy.sh — Phase 0b: cross-source redundant-tool-call detection.
#
# Reads all activity-*.jsonl files in the CURRENT partition. Identifies the
# same semantic tool capability appearing across different sources / agent-ids
# within a 24h window (the partition is daily, so same-day counts as within
# window by definition). Raw tool names are preserved in each record.
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
MAPPING_VERSION = "semantic-tool-map-v1"

# Measurement-only equivalence map. This does not define runtime policy and is
# intentionally small: only established cross-client capability aliases live
# here. Unmapped tools retain their raw name as their semantic key.
SEMANTIC_TOOL_MAP = {
    "Agent": ("agent.task.create", "Agent task delegation"),
    "AskUserQuestion": ("human-input.request", "Human input request"),
    "Bash": ("shell.command", "Host shell command execution"),
    "Edit": ("file.write", "File write/edit"),
    "TaskCreate": ("agent.task.create", "Agent task delegation"),
    "TaskUpdate": ("work-plan.update", "Work-plan status update"),
    "TodoWrite": ("work-plan.update", "Work-plan status update"),
    "ToolSearch": ("tool-discovery.search", "Tool discovery search"),
    "Write": ("file.write", "File write/edit"),
    "apply_patch": ("file.write", "File write/edit"),
    "close_agent": ("agent.task.create", "Agent task delegation"),
    "exec_command": ("shell.command", "Host shell command execution"),
    "get_pod": ("runpod.get_pod", "Runpod pod inspection"),
    "list_pods": ("runpod.list_pods", "Runpod pod listing"),
    "mcp__runpod__get-pod": ("runpod.get_pod", "Runpod pod inspection"),
    "mcp__runpod__list-pods": ("runpod.list_pods", "Runpod pod listing"),
    "mcp__runpod__stop-pod": ("runpod.stop_pod", "Runpod pod stop request"),
    "request_user_input": ("human-input.request", "Human input request"),
    "resume_agent": ("agent.task.create", "Agent task delegation"),
    "send_input": ("agent.task.create", "Agent task delegation"),
    "spawn_agent": ("agent.task.create", "Agent task delegation"),
    "stop_pod": ("runpod.stop_pod", "Runpod pod stop request"),
    "tool_search_tool": ("tool-discovery.search", "Tool discovery search"),
    "update_plan": ("work-plan.update", "Work-plan status update"),
    "wait_agent": ("agent.task.create", "Agent task delegation"),
}

def semantic_tool(raw_tool):
    key, label = SEMANTIC_TOOL_MAP.get(raw_tool, (raw_tool, raw_tool))
    return key, label, raw_tool in SEMANTIC_TOOL_MAP

# Collect tool-use / function-call shape records across sources.
# Aggregate key = semantic capability; track raw tools and sources surfaced.
by_tool = defaultdict(lambda: {
    "label": "",
    "sources": set(),
    "count_by_source": defaultdict(int),
    "raw_tools": set(),
    "count_by_raw_tool": defaultdict(int),
    "mapped": False,
})
raw_tools_observed = set()

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
                semantic_key, label, mapped = semantic_tool(name)
                raw_tools_observed.add(name)
                by_tool[semantic_key]["label"] = label
                by_tool[semantic_key]["mapped"] = by_tool[semantic_key]["mapped"] or mapped
                by_tool[semantic_key]["sources"].add(src)
                by_tool[semantic_key]["count_by_source"][src] += count
                by_tool[semantic_key]["raw_tools"].add(name)
                by_tool[semantic_key]["count_by_raw_tool"][name] += count
    except (OSError, PermissionError):
        continue

# Emit per-semantic-tool records.
lines_out = []
redundant_tools = 0
total_redundant_calls = 0
for tool, info in sorted(by_tool.items(), key=lambda kv: -sum(kv[1]["count_by_source"].values())):
    sources = sorted(info["sources"])
    counts = {s: info["count_by_source"][s] for s in sources}
    raw_tools = sorted(info["raw_tools"])
    raw_counts = {t: info["count_by_raw_tool"][t] for t in raw_tools}
    total = sum(counts.values())
    cross_source = len(sources) >= 2
    if cross_source:
        redundant_tools += 1
        total_redundant_calls += total
    lines_out.append(json.dumps({
        "ts": ts,
        "tool": tool,
        "semantic_tool": tool,
        "semantic_label": info["label"],
        "semantic_mapping_version": MAPPING_VERSION,
        "semantic_mapped": info["mapped"],
        "raw_tools": raw_tools,
        "count_by_raw_tool": raw_counts,
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
    "unique_tools_observed": len(raw_tools_observed),
    "unique_semantic_tools_observed": len(by_tool),
    "cross_source_redundant_tools": redundant_tools,
    "total_redundant_calls": total_redundant_calls,
    "semantic_mapping_version": MAPPING_VERSION,
    "note": "Cross-source redundancy: same semantic tool capability surfaced by ≥2 distinct sources in this partition. Same-day window by definition of per-day partition. Raw tool names are preserved per record.",
}))

out_path = os.path.join(out_dir, out_name)
with open(out_path, 'w') as f:
    f.write("\n".join(lines_out) + "\n")

print(f"  ✓ redundancy analysis: {len(raw_tools_observed)} raw tools, {len(by_tool)} semantic tools, {redundant_tools} cross-source redundant")
PYEOF

echo "  → $(log_dir)/$OUT"
