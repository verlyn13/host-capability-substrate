#!/usr/bin/env bash
# render-dashboard.sh — Phase 0b: dashboard contract rehearsal.
#
# Renders fake rows from current `.logs/phase-0/<today>/` partitions as if
# they were feeding a read-only HCS dashboard. The point is NOT to build a
# real dashboard; it is to verify that current telemetry contains enough
# detail to populate the dashboard rows Phase 1 will define:
#
#   LiveSessionRow        (session_id, cwd, last_tool, last_ts)
#   PolicyDecisionCard    (class, reason, source, command_redacted, count)
#   AuditTimelineEvent    (ts, source, tool, command_redacted, classified_class)
#   TrapRecordCard        (trap_name, source, severity, count)
#   HealthStatus          (partition_present, overblock_ok, parse_error_ok)
#
# If any row cannot be populated from current logs, the corresponding gap is
# printed. Those gaps are the real deliverable.
#
# Output: Markdown to `dashboard-rehearsal.md` and a summary JSON.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "render-dashboard"

OUT_MD="dashboard-rehearsal.md"
OUT_JSON="dashboard-rehearsal.json"
file_replace "$OUT_MD" "# Phase 0b dashboard rehearsal — rendering skipped (python3 missing)"
file_replace "$OUT_JSON" '{"status":"rendering-skipped"}'

python3 - "$OUT_DIR" "$OUT_MD" "$OUT_JSON" <<'PYEOF'
import json
import os
import sys
from collections import Counter
from pathlib import Path

part_dir = Path(sys.argv[1])
md_path = part_dir / sys.argv[2]
json_path = part_dir / sys.argv[3]


def read_jsonl(p):
    rows = []
    if not p.exists():
        return rows
    with p.open() as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except Exception:
                continue
    return rows


def read_json(p, default=None):
    if not p.exists():
        return default
    try:
        with p.open() as fh:
            return json.load(fh)
    except Exception:
        return default


gaps = []


def gap(kind, detail):
    gaps.append({"kind": kind, "detail": detail})


# -------- LiveSessionRow --------
# Phase 0b proxy for sessions: unique session_id from hook-decisions.jsonl.
hook = read_jsonl(part_dir / 'hook-decisions.jsonl')
sessions = {}
for rec in hook:
    sid = rec.get('session_id') or ''
    if not sid:
        continue
    prev = sessions.get(sid)
    if prev is None or rec.get('ts', '') > prev.get('ts', ''):
        sessions[sid] = rec

live_rows = []
for sid, rec in sessions.items():
    live_rows.append({
        'session_id': sid[:24],
        'cwd': (rec.get('cwd') or '')[:60],
        'last_tool': rec.get('tool') or '',
        'last_ts': rec.get('ts') or '',
        'last_class': rec.get('classified_class') or '',
    })
live_rows.sort(key=lambda r: r['last_ts'], reverse=True)

if not live_rows:
    gap('LiveSessionRow',
        'no hook-decisions.jsonl yet — requires live hook installed AND at least '
        'one agent session after install. Opt-in via `just soak-install-hook`.')


# -------- PolicyDecisionCard --------
classify = read_jsonl(part_dir / 'classify.jsonl')
decisions = Counter()
for rec in classify:
    key = (rec.get('classified_class', ''), rec.get('classified_reason', ''))
    decisions[key] += 1
decision_rows = [
    {'class': c, 'reason': r[:60], 'count': n}
    for (c, r), n in decisions.most_common(12)
]

if not decision_rows:
    gap('PolicyDecisionCard', 'classify.jsonl empty — run measure-commands + measure-classify')


# -------- AuditTimelineEvent --------
# Proxy: last 10 from classify.jsonl sorted by ts.
classify_sorted = sorted(classify, key=lambda r: r.get('ts', ''), reverse=True)[:10]
timeline_rows = [
    {
        'ts': r.get('ts', ''),
        'source': r.get('source', ''),
        'tool': r.get('tool_name', ''),
        'class': r.get('classified_class', ''),
        'command': (r.get('command') or '')[:60],
    }
    for r in classify_sorted
]
if not timeline_rows:
    gap('AuditTimelineEvent', 'no classify.jsonl data')


# -------- TrapRecordCard --------
traps = read_jsonl(part_dir / 'traps.jsonl')
trap_counts = Counter()
severity_by_trap = {}
for rec in traps:
    name = rec.get('trap_name')
    if not name:
        continue
    trap_counts[name] += 1
    severity_by_trap[name] = rec.get('severity', 'unknown')
trap_rows = [
    {'trap_name': n, 'severity': severity_by_trap.get(n, '?'), 'count': c}
    for n, c in trap_counts.most_common()
]
if not trap_rows:
    gap('TrapRecordCard', 'no traps.jsonl data')


# -------- HealthStatus --------
confusion = read_json(part_dir / 'confusion-matrix.json', {}) or {}
gates = confusion.get('gates') or {}
health = {
    'partition_present': (part_dir / 'classify.jsonl').exists(),
    'parse_error_ok': gates.get('parse_error_ok'),
    'overblock_ok': gates.get('overblock_ok'),
    'parse_error_rate_pct': gates.get('parse_error_rate_pct'),
    'overblock_rate_pct_on_stringy_first_tokens': gates.get('overblock_rate_pct_on_stringy_first_tokens'),
}

# -------- Render markdown --------
lines = []
lines.append(f'# HCS Phase 0b dashboard rehearsal — {part_dir.name}')
lines.append('')
lines.append('Fake dashboard rendered from current partition. Gaps flagged at the bottom.')
lines.append('')

lines.append('## LiveSessionRow')
lines.append('')
if live_rows:
    lines.append('| session_id | cwd | last_tool | last_class | last_ts |')
    lines.append('|---|---|---|---|---|')
    for r in live_rows[:8]:
        lines.append(f"| `{r['session_id']}` | `{r['cwd']}` | {r['last_tool']} | {r['last_class']} | {r['last_ts']} |")
else:
    lines.append('_(no data — see gaps)_')
lines.append('')

lines.append('## PolicyDecisionCard')
lines.append('')
if decision_rows:
    lines.append('| class | reason | count |')
    lines.append('|---|---|---|')
    for r in decision_rows:
        lines.append(f"| {r['class']} | {r['reason']} | {r['count']} |")
else:
    lines.append('_(no data — see gaps)_')
lines.append('')

lines.append('## AuditTimelineEvent (last 10)')
lines.append('')
if timeline_rows:
    lines.append('| ts | source | tool | class | command |')
    lines.append('|---|---|---|---|---|')
    for r in timeline_rows:
        cmd = r['command'].replace('|', '\\|').replace('`', '')
        lines.append(f"| {r['ts']} | {r['source']} | {r['tool']} | {r['class']} | `{cmd}` |")
else:
    lines.append('_(no data — see gaps)_')
lines.append('')

lines.append('## TrapRecordCard')
lines.append('')
if trap_rows:
    lines.append('| trap_name | severity | count |')
    lines.append('|---|---|---|')
    for r in trap_rows:
        lines.append(f"| {r['trap_name']} | {r['severity']} | {r['count']} |")
else:
    lines.append('_(no data — see gaps)_')
lines.append('')

lines.append('## HealthStatus')
lines.append('')
for k, v in health.items():
    lines.append(f'- **{k}**: `{v}`')
lines.append('')

lines.append('## Dashboard gaps')
lines.append('')
if gaps:
    for g in gaps:
        lines.append(f"- **{g['kind']}** — {g['detail']}")
else:
    lines.append('_(none — all rows populated from current logs)_')
lines.append('')

md_path.write_text('\n'.join(lines))

report = {
    'partition': part_dir.name,
    'live_rows': live_rows[:20],
    'decision_rows': decision_rows,
    'timeline_rows': timeline_rows,
    'trap_rows': trap_rows[:20],
    'health': health,
    'gaps': gaps,
}
json_path.write_text(json.dumps(report, indent=2))

print(f"  ✓ rendered {len(live_rows)} sessions, {len(decision_rows)} decision cards, "
      f"{len(timeline_rows)} timeline events, {len(trap_rows)} traps")
print(f"  ⓘ gaps identified: {len(gaps)}")
for g in gaps:
    print(f"    - {g['kind']}: {g['detail']}")
PYEOF

echo "  → $(log_dir)/$OUT_MD"
echo "  → $(log_dir)/$OUT_JSON"
