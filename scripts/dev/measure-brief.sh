#!/usr/bin/env bash
# measure-brief.sh — Phase 0b: consolidate N partitions into a single brief.
#
# Reads every partition under .logs/phase-0/YYYY-MM-DD/ and produces:
#   .logs/phase-0/brief.md        consolidated markdown brief
#   .logs/phase-0/brief.json      structured summary for downstream Phase 1 threads
#
# Snapshot semantics: always overwrites brief.md / brief.json.
# The current repo-side soak target is configurable via HCS_PHASE0B_SOAK_DAYS
# and defaults to 3. The explicit soak window start is configurable via
# HCS_PHASE0B_SOAK_START and defaults to 2026-04-23.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-brief"

BRIEF_MD="$HCS_ROOT/.logs/phase-0/brief.md"
BRIEF_JSON="$HCS_ROOT/.logs/phase-0/brief.json"

python3 - "$HCS_ROOT/.logs/phase-0" "$BRIEF_MD" "$BRIEF_JSON" "$HCS_ROOT/packages/evals/regression/seed.md" <<'PYEOF'
import json, os, sys, glob, re
from collections import defaultdict, Counter
from datetime import datetime, timezone

base = sys.argv[1]
md_path = sys.argv[2]
json_path = sys.argv[3]
seed_path = sys.argv[4]
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
soak_target_days = int(os.environ.get('HCS_PHASE0B_SOAK_DAYS', '3'))
soak_start_date = os.environ.get('HCS_PHASE0B_SOAK_START', '2026-04-23')

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
        'cross_agent_runs': load_jsonl(os.path.join(pd, 'cross-agent-runs.jsonl')),
        'cross_agent_feedback': load_jsonl(os.path.join(pd, 'cross-agent-feedback.jsonl')),
        'protocol_features': load_json(os.path.join(pd, 'protocol-features.json')),
        'tokens_estimate': load_json(os.path.join(pd, 'tokens-estimate.json')),
    }

# Build aggregates
summary = {
    'generated_ts': ts,
    'partitions': partitions,
    'partition_count': len(partitions),
    'soak_target_days': soak_target_days,
    'soak_start_date': soak_start_date,
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
        'cross_agent_runs': len(d['cross_agent_runs']),
        'cross_agent_feedback': len(d['cross_agent_feedback']),
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

# Cross-agent manual simulation aggregate
rubric_dimensions = [
    'context_resolved',
    'evidence_cited',
    'deprecated_syntax_avoided',
    'typed_framing',
    'approval_for_mutation',
    'refusal_when_missing',
]
cross_agent_runs_total = 0
cross_agent_feedback_total = 0
run_scores_by_agent = defaultdict(lambda: {'runs': 0, 'score_total': 0, 'feedback_required': 0})
dimension_failures = Counter()
feedback_by_severity = Counter()
feedback_by_status = Counter()

for p, d in partition_data.items():
    for rec in d['cross_agent_runs']:
        if not isinstance(rec, dict):
            continue
        agent = rec.get('agent', '?')
        score = int(rec.get('score', 0) or 0)
        cross_agent_runs_total += 1
        run_scores_by_agent[agent]['runs'] += 1
        run_scores_by_agent[agent]['score_total'] += score
        if rec.get('feedback_required') is True:
            run_scores_by_agent[agent]['feedback_required'] += 1
        for dim in rubric_dimensions:
            if rec.get(dim) is False:
                dimension_failures[dim] += 1
    for rec in d['cross_agent_feedback']:
        if not isinstance(rec, dict):
            continue
        cross_agent_feedback_total += 1
        feedback_by_severity[rec.get('severity', 'unknown')] += 1
        feedback_by_status[rec.get('status', 'unknown')] += 1

summary['aggregate']['cross_agent_runs_total'] = cross_agent_runs_total
summary['aggregate']['cross_agent_feedback_total'] = cross_agent_feedback_total
summary['aggregate']['cross_agent_agent_stats'] = {
    agent: {
        'runs': vals['runs'],
        'avg_score': round(vals['score_total'] / vals['runs'], 3) if vals['runs'] else 0.0,
        'feedback_required_runs': vals['feedback_required'],
    }
    for agent, vals in sorted(run_scores_by_agent.items())
}
summary['aggregate']['cross_agent_dimension_failures'] = dict(dimension_failures.most_common())
summary['aggregate']['cross_agent_feedback_by_severity'] = dict(feedback_by_severity.most_common())
summary['aggregate']['cross_agent_feedback_by_status'] = dict(feedback_by_status.most_common())

# Seed trap corpus count
seed_trap_count = 0
if os.path.exists(seed_path):
    with open(seed_path) as f:
        for line in f:
            if re.match(r'^\|\s*\d+\s*\|', line):
                seed_trap_count += 1
summary['aggregate']['seed_trap_count'] = seed_trap_count

# Required soak window dates
start_dt = datetime.strptime(soak_start_date, '%Y-%m-%d').date()
required_partition_dates = [
    (start_dt.fromordinal(start_dt.toordinal() + offset)).isoformat()
    for offset in range(soak_target_days)
]
summary['required_partition_dates'] = required_partition_dates

# Acceptance-gate assessment
acceptance = {
    'target_days_of_data': all(day in partitions for day in required_partition_dates),
    'five_primary_clients_covered': False,  # determined below
    'cross_source_overlap_at_least_3': False,
    'tokens_estimate_present': summary['aggregate']['tokens_chars_total'] > 0,
    'trap_corpus_15_plus': max(seed_trap_count, len(all_traps)) >= 15,
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
acceptance_rows = [
    (f"{soak_target_days} soak days captured ({required_partition_dates[0]}..{required_partition_dates[-1]})", acceptance['target_days_of_data']),
    ("five primary clients covered", acceptance['five_primary_clients_covered']),
    ("cross source overlap at least 3", acceptance['cross_source_overlap_at_least_3']),
    ("tokens estimate present", acceptance['tokens_estimate_present']),
    ("trap corpus 15 plus", acceptance['trap_corpus_15_plus']),
    ("governance inventory present", acceptance['governance_inventory_present']),
    ("protocol features present", acceptance['protocol_features_present']),
]
for label, passed in acceptance_rows:
    check = "✓" if passed else "✗"
    md.append(f"| {label} | {check} |")
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
md.append(f"- Seed trap corpus entries: **{seed_trap_count}**")
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

md.append("## Cross-agent Manual Simulation")
md.append("")
md.append(f"- Recorded prompt runs: {cross_agent_runs_total}")
md.append(f"- Recorded feedback items: {cross_agent_feedback_total}")
if cross_agent_runs_total:
    md.append("")
    md.append("| Agent | Runs | Avg score | Runs requiring feedback |")
    md.append("|-------|------|-----------|-------------------------|")
    for agent, vals in sorted(run_scores_by_agent.items()):
        avg = round(vals['score_total'] / vals['runs'], 3) if vals['runs'] else 0.0
        md.append(f"| `{agent}` | {vals['runs']} | {avg} | {vals['feedback_required']} |")
    if dimension_failures:
        md.append("")
        md.append("| Rubric dimension | Fail count |")
        md.append("|------------------|------------|")
        for dim, count in dimension_failures.most_common():
            md.append(f"| `{dim}` | {count} |")
if cross_agent_feedback_total:
    md.append("")
    md.append("| Feedback severity | Count |")
    md.append("|-------------------|-------|")
    for sev, count in feedback_by_severity.most_common():
        md.append(f"| `{sev}` | {count} |")
    md.append("")
    md.append("| Feedback status | Count |")
    md.append("|-----------------|-------|")
    for status, count in feedback_by_status.most_common():
        md.append(f"| `{status}` | {count} |")
if not cross_agent_runs_total and not cross_agent_feedback_total:
    md.append("- No cross-agent prompt records captured yet.")
md.append("")

md.append("## Notes")
md.append("")
md.append("- This brief is derived from daily partition snapshots under `.logs/phase-0/<YYYY-MM-DD>/`.")
md.append(f"- Current repo-side soak target: {soak_target_days} partition days starting {soak_start_date}.")
md.append("- Record counts reflect snapshots, not deltas; cross-partition trends show cumulative host state, not only new activity.")
md.append("- Probe-required fields (MCP clientInfo, elicitation URL mode, etc.) remain to Phase 1 Thread B.")
md.append("- The trap-corpus gate counts the committed seed corpus as well as observed trap hits; the scanner currently instruments a narrower subset of heuristics.")
md.append("- This file is gitignored. Lift to `docs/host-capability-substrate/phase-0b-brief.md` when ready to commit the final narrative.")

with open(md_path, 'w') as f:
    f.write("\n".join(md) + "\n")

print(f"  ✓ brief rendered: {md_path}")
print(f"  ✓ summary json:    {json_path}")
print(f"  partitions: {len(partitions)}, tool-use records aggregated: {sum(tool_totals.values())}")
PYEOF

echo "  → $BRIEF_MD"
echo "  → $BRIEF_JSON"
