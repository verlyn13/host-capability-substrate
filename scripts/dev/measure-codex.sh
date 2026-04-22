#!/usr/bin/env bash
# measure-codex.sh — Phase 0b: Codex command-shape counts.
#
# CORRECTED for actual log layout (2026-04-22):
#   ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl   <-- RICH: per-turn rollouts.
#       Lines are {timestamp, type, payload}. type is one of
#       session_meta | event_msg | response_item | turn_context.
#       Tool calls live at:  response_item.payload.type == "function_call"
#       Outputs:              response_item.payload.type == "function_call_output"
#   ~/.codex/state_5.sqlite   threads(id, rollout_path, created_at, updated_at,
#                                     cwd, title, tokens_used, has_user_event, ...)
#       thread_dynamic_tools — tools registered per thread (infra, not activity)
#   ~/.codex/logs_2.sqlite    structured internal logs; NO command text column.
#
# The previous version measured only infra signals (logger targets, dynamic-tool
# registry counts). This version parses rollout JSONL files to get real
# function-call (tool-invocation) counts by tool name.
#
# Scope: recent threads (last 7 days by updated_at).

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-codex"

OUT="activity-codex.jsonl"
snapshot_begin "$OUT"

CODEX_HOME="$HOME/.codex"

# 1. Thread-level aggregates (rich signal).
if [ -f "$CODEX_HOME/state_5.sqlite" ]; then
  cutoff_ms=$(( ( $(date +%s) - 7 * 86400 ) * 1000 ))
  # Overall counts
  total_threads=$(sqlite3 -readonly "file:$CODEX_HOME/state_5.sqlite?mode=ro" "SELECT COUNT(*) FROM threads;" 2>/dev/null || echo 0)
  recent_threads=$(sqlite3 -readonly "file:$CODEX_HOME/state_5.sqlite?mode=ro" "SELECT COUNT(*) FROM threads WHERE updated_at_ms >= $cutoff_ms;" 2>/dev/null || echo 0)
  total_tokens=$(sqlite3 -readonly "file:$CODEX_HOME/state_5.sqlite?mode=ro" "SELECT COALESCE(SUM(tokens_used),0) FROM threads WHERE updated_at_ms >= $cutoff_ms;" 2>/dev/null || echo 0)
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"codex-threads\",\"category\":\"thread-counts\",\"total\":$total_threads,\"recent_7d\":$recent_threads,\"recent_7d_tokens\":$total_tokens}"
  echo "  ✓ threads: total=$total_threads recent_7d=$recent_threads tokens_7d=$total_tokens"

  # 2. Parse recent rollouts (bounded by 7d window).
  tmp_paths="$(mktemp)"
  sqlite3 -readonly "file:$CODEX_HOME/state_5.sqlite?mode=ro" \
    "SELECT rollout_path FROM threads WHERE updated_at_ms >= $cutoff_ms ORDER BY updated_at_ms DESC;" \
    > "$tmp_paths" 2>/dev/null || true

  rollout_file_count=$(wc -l < "$tmp_paths" | tr -d ' ')
  if [ "$rollout_file_count" -gt 0 ]; then
    python3 - "$tmp_paths" "$OUT_DIR/$OUT" <<'PYEOF'
import json, sys, os
from collections import Counter
from datetime import datetime, timezone

paths_file = sys.argv[1]
out_path = sys.argv[2]
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

function_calls = Counter()
event_types = Counter()
response_item_types = Counter()
total_function_calls = 0
rollouts_parsed = 0
rollouts_missing = 0

with open(paths_file) as f:
    paths = [p.strip() for p in f if p.strip()]

for p in paths:
    if not p or not os.path.exists(p):
        rollouts_missing += 1
        continue
    rollouts_parsed += 1
    try:
        with open(p, 'r', errors='replace') as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                t = d.get('type', '?')
                event_types[t] += 1
                if t == 'response_item':
                    payload = d.get('payload') or {}
                    if isinstance(payload, dict):
                        ptype = payload.get('type', '?')
                        response_item_types[ptype] += 1
                        if ptype == 'function_call':
                            name = payload.get('name') or '?'
                            function_calls[name] += 1
                            total_function_calls += 1
    except (OSError, PermissionError):
        continue

with open(out_path, 'a') as out:
    out.write(json.dumps({
        'ts': ts,
        'source': 'codex-rollouts',
        'category': 'rollout-volume',
        'rollouts_parsed': rollouts_parsed,
        'rollouts_missing': rollouts_missing,
        'window_days': 7,
        'total_function_calls': total_function_calls,
    }) + '\n')
    for t, c in event_types.most_common():
        out.write(json.dumps({
            'ts': ts,
            'source': 'codex-rollouts',
            'category': 'event-type-shape',
            'event_type': t,
            'count': c,
        }) + '\n')
    for rt, c in response_item_types.most_common():
        out.write(json.dumps({
            'ts': ts,
            'source': 'codex-rollouts',
            'category': 'response-item-shape',
            'response_item_type': rt,
            'count': c,
        }) + '\n')
    for name, c in function_calls.most_common():
        out.write(json.dumps({
            'ts': ts,
            'source': 'codex-rollouts',
            'category': 'function-call-shape',
            'tool': name,
            'count': c,
        }) + '\n')
PYEOF
    echo "  ✓ rollouts (7d): $rollout_file_count files scanned"
  else
    jsonl_append "$OUT" \
      "{\"ts\":\"$(iso_now)\",\"source\":\"codex-rollouts\",\"status\":\"no-recent-rollouts\",\"window_days\":7}"
  fi
  rm -f "$tmp_paths"
else
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"codex-state\",\"status\":\"source-unavailable\"}"
fi

# 3. Dynamic-tool registry snapshot (context, not activity).
if [ -f "$CODEX_HOME/state_5.sqlite" ]; then
  sqlite3 -readonly "file:$CODEX_HOME/state_5.sqlite?mode=ro" \
    "SELECT name, COUNT(*) FROM thread_dynamic_tools GROUP BY name ORDER BY COUNT(*) DESC LIMIT 20;" 2>/dev/null |
    while IFS='|' read -r name count; do
      name_safe="$(printf '%s' "$name" | sed 's/"/\\"/g')"
      jsonl_append "$OUT" \
        "{\"ts\":\"$(iso_now)\",\"source\":\"codex-state\",\"category\":\"dynamic-tool-registration\",\"name\":\"$name_safe\",\"count\":$count}"
    done
fi

echo "  → $(log_dir)/$OUT"
