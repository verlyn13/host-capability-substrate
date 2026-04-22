#!/usr/bin/env bash
# measure-brief.sh — Phase 0b: consolidate N partitions into a single brief.
#
# Reads every partition under .logs/phase-0/YYYY-MM-DD/ and produces:
#   .logs/phase-0/brief.md        consolidated markdown brief
#   .logs/phase-0/brief.json      structured summary for downstream Phase 1 threads
#
# Snapshot semantics: always overwrites brief.md / brief.json.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-brief"

BRIEF_MD="$HCS_ROOT/.logs/phase-0/brief.md"
BRIEF_JSON="$HCS_ROOT/.logs/phase-0/brief.json"

python3 - "$HCS_ROOT/.logs/phase-0" "$BRIEF_MD" "$BRIEF_JSON" <<'PYEOF'
import json, os, sys, glob, re
from collections import defaultdict, Counter
from datetime import datetime, timezone

base = sys.argv[1]
md_path = sys.argv[2]
json_path = sys.argv[3]
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Discover partitions: dirs matching YYYY-MM-DD
partitions = sorted([d for d in os.listdir(base)
                     if re.match(r'^\d{4}-\d{2}-\d{2}$', d)
                     and os.path.isdir(os.path.join(base, d))])

def load_jsonl(path):
    if not os.path.exists(path): return []
    out = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try: out.append(json.loads(line))
            except Exception: pass
    return out

def load_json(path):
    if not os.path.exists(path): return None
    try:
        with open(path) as f: return json.load(f)
    except Exception:
        return None

partition_data = {}
for p in partitions:
    pd = os.path.join(base, p)
    partition_data[p] = {
        'activity_claude_code': load_jsonl(os.path.join(pd, 'activity-claude-code.jsonl')),
        'activity_codex': load_jsonl(os.path.join(pd, 'activity-codex.jsonl')),
        'activity_ide_hosts': load_jsonl(os.path.join(pd, 'activity-ide-hosts.jsonl')),
        'traps': load_jsonl(os.path.join(pd, 'traps.jsonl')),
        'governance_inventory': load_jsonl(os.path.join(pd, 'governance-inventory.jsonl')),
        'redundancy': load_jsonl(os.path.join(pd, 'redundancy.jsonl')),
        'protocol_features': load_json(os.path.join(pd, 'protocol-features.json')),
        'tokens_estimate': load_json(os.path.join(pd, 'tokens-estimate.json')),
    }

# Build aggregates
summary = {
    'generated_ts': ts,
    'partitions': partitions,
    'partition_count': len(partitions),
    'per_partition': {},
    'aggregate': {},
}

# Per-partition record counts
for p, d in partition_data.items():
    pc = {
        'activity_records_claude_code': len(d['activity_claude_code']),
        'activity_records_codex': len(d['activity_codex']),
        'activity_records_ide_hosts': len(d['activity_ide_hosts']),
        'trap_hits': sum(1 for t in d['traps'] if t.get('trap_name') != '__summary__'),
        'governance_records': len(d['governance_inventory']),
        'redundancy_records': len(d['redundancy']),
        'has_protocol_features': d['protocol_features'] is not None,
        'has_tokens_estimate': d['tokens_estimate'] is not None,
    }
    summary['per_partition'][p] = pc

# Aggregate trap hits across partitions
all_traps = Counter()
trap_source_counts = defaultdict(lambda: Counter())
for p, d in partition_data.items():
    for t in d['traps']:
        name = t.get('trap_name')
        if name and name != '__summary__':
            all_traps[name] += 1
            trap_source_counts[name][t.get('source', '?')] += 1
summary['aggregate']['traps_total_hits'] = sum(all_traps.values())
summary['aggregate']['traps_by_class'] = dict(all_traps.most_common())

# Aggregate tool-use / function-call counts across partitions
tool_totals = Counter()
for p, d in partition_data.items():
    for rec in d['activity_claude_code'] + d['activity_codex']:
        if rec.get('category') in ('tool-use-shape', 'function-call-shape'):
            tool_totals[rec.get('tool', '?')] += int(rec.get('count', 0))
summary['aggregate']['top_tools'] = dict(tool_totals.most_common(20))
summary['aggregate']['unique_tools'] = len(tool_totals)

# Tokens aggregate
total_chars = 0
total_tokens = 0
for p, d in partition_data.items():
    te = d['tokens_estimate']
    if te and 'totals' in te:
        total_chars += int(te['totals'].get('chars', 0))
        total_tokens += int(te['totals'].get('estimated_tokens', 0))
summary['aggregate']['tokens_chars_total'] = total_chars
summary['aggregate']['tokens_estimated_total'] = total_tokens

# Acceptance-gate assessment
acceptance = {
    'seven_days_of_data': len(partitions) >= 7,
    'five_primary_clients_covered': False,  # determined below
    'cross_source_overlap_at_least_3': False,
    'tokens_estimate_present': summary['aggregate']['tokens_chars_total'] > 0,
    'trap_corpus_15_plus': len(all_traps) + 0 >= 15,  # rough; seed alone = 15
    'governance_inventory_present': any(s['governance_records'] > 0 for s in summary['per_partition'].values()),
    'protocol_features_present': any(s['has_protocol_features'] for s in summary['per_partition'].values()),
}
# 5 primary clients: CC, Codex, Cursor, Windsurf, Copilot CLI
sources_seen = set()
for p, d in partition_data.items():
    for rec in d['activity_claude_code']: sources_seen.add(rec.get('source', ''))
    for rec in d['activity_codex']: sources_seen.add(rec.get('source', ''))
    for rec in d['activity_ide_hosts']: sources_seen.add(rec.get('source', ''))
primary_markers = {
    'claude-code': any('claude-code' in s for s in sources_seen),
    'codex': any('codex' in s for s in sources_seen),
    'cursor': 'cursor' in sources_seen,
    'windsurf': 'windsurf' in sources_seen,
    'copilot': any('copilot' in s for s in sources_seen),
}
acceptance['five_primary_clients_covered'] = all(primary_markers.values())
# cross-source overlap
redundancy_summary = None
for p, d in partition_data.items():
    for rec in d['redundancy']:
        if rec.get('category') == '__summary__':
            redundancy_summary = rec
            break
    if redundancy_summary: break
if redundancy_summary:
    acceptance['cross_source_overlap_at_least_3'] = int(redundancy_summary.get('cross_source_redundant_tools', 0)) >= 3

summary['acceptance'] = acceptance
summary['primary_client_markers'] = primary_markers

with open(json_path, 'w') as f:
    json.dump(summary, f, indent=2)

# Render markdown brief
md = []
md.append(f"# Phase 0b — Measurement Brief")
md.append("")
md.append(f"*Generated: {ts}*")
md.append(f"*Partitions: {len(partitions)}* — {', '.join(partitions) if partitions else '(none)'}")
md.append("")
md.append("## Acceptance gate")
md.append("")
md.append("| Criterion | Met |")
md.append("|-----------|-----|")
for k, v in acceptance.items():
    check = "✓" if v else "✗"
    md.append(f"| {k.replace('_', ' ')} | {check} |")
md.append("")
md.append(f"Primary clients covered: {', '.join(k for k,v in primary_markers.items() if v) or '(none)'}")
if any(not v for v in primary_markers.values()):
    md.append(f"Missing: {', '.join(k for k,v in primary_markers.items() if not v)}")
md.append("")

md.append("## Tool-use totals across partitions")
md.append("")
md.append(f"- Unique tools observed: **{summary['aggregate']['unique_tools']}**")
md.append("")
md.append("| Tool | Total invocations |")
md.append("|------|------------------|")
for tool, count in list(tool_totals.most_common(10)):
    md.append(f"| `{tool}` | {count} |")
md.append("")

md.append("## Trap observations (by class)")
md.append("")
if all_traps:
    md.append("| Trap | Hits | Sources |")
    md.append("|------|------|---------|")
    for name, count in all_traps.most_common():
        sources = ', '.join(f"{s} ({c})" for s, c in trap_source_counts[name].most_common())
        md.append(f"| `{name}` | {count} | {sources} |")
else:
    md.append("No trap hits observed across partitions.")
md.append("")

md.append("## Tokens estimate (aggregate)")
md.append("")
md.append(f"- Total chars counted: {total_chars:,}")
md.append(f"- Estimated tokens (char/4 heuristic): {total_tokens:,}")
md.append("")

md.append("## Cross-source redundancy")
md.append("")
if redundancy_summary:
    md.append(f"- Unique tools observed: {redundancy_summary.get('unique_tools_observed', '?')}")
    md.append(f"- Cross-source redundant tools: **{redundancy_summary.get('cross_source_redundant_tools', 0)}**")
    md.append(f"- Total redundant calls: {redundancy_summary.get('total_redundant_calls', 0)}")
else:
    md.append("_No redundancy analysis in any partition._")
md.append("")

md.append("## Governance inventory")
md.append("")
gov_total = sum(s['governance_records'] for s in summary['per_partition'].values())
md.append(f"- Aggregate records across partitions: {gov_total}")
md.append("- Latest partition has per-artifact records in `governance-inventory.jsonl`")
md.append("")

md.append("## Notes")
md.append("")
md.append("- This brief is derived from daily partition snapshots under `.logs/phase-0/<YYYY-MM-DD>/`.")
md.append("- Record counts reflect snapshots, not deltas; cross-partition trends show cumulative host state, not only new activity.")
md.append("- Probe-required fields (MCP clientInfo, elicitation URL mode, etc.) remain to Phase 1 Thread B.")
md.append("- This file is gitignored. Lift to `docs/host-capability-substrate/phase-0b-brief.md` when ready to commit the final narrative.")

with open(md_path, 'w') as f:
    f.write("\n".join(md) + "\n")

print(f"  ✓ brief rendered: {md_path}")
print(f"  ✓ summary json:    {json_path}")
print(f"  partitions: {len(partitions)}, tool-use records aggregated: {sum(tool_totals.values())}")
PYEOF

echo "  → $BRIEF_MD"
echo "  → $BRIEF_JSON"
