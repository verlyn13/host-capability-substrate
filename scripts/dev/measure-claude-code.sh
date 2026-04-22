#!/usr/bin/env bash
# measure-claude-code.sh — Phase 0b: Claude Code command-shape counts.
#
# CORRECTED for actual log layout (2026-04-22):
#   ~/.claude/sessions/*.json     pid + sessionId metadata only (NOT tool-use)
#   ~/.claude/history.jsonl       user prompts (display, pastedContents, timestamp, project)
#   ~/.claude/projects/<slug>/<uuid>.jsonl   <-- RICH: transcript with assistant/user/attachment
#                                            events. tool_use records live in
#                                            assistant.message.content[] items.
#
# This script extracts:
#   - prompt volume from history.jsonl (count, chars)
#   - tool-use counts by tool name from project transcripts (last 7 days)
#   - probe proxy counts (--help, --version, which/command -v mentions)
#
# Snapshot semantics: truncates activity.jsonl section for this source on run.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-claude-code"

# Per-source output file (namespaced so each source snapshots independently
# and cross-source aggregation is straightforward).
OUT="activity-claude-code.jsonl"
snapshot_begin "$OUT"

CC_HOME="$HOME/.claude"

# 1. history.jsonl — prompt volume.
if [ -f "$CC_HOME/history.jsonl" ]; then
  prompt_count=$(wc -l < "$CC_HOME/history.jsonl" | tr -d ' ')
  total_chars=$(wc -c < "$CC_HOME/history.jsonl" | tr -d ' ')
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-history\",\"category\":\"prompt-volume\",\"prompt_count\":$prompt_count,\"total_chars\":$total_chars}"
  echo "  ✓ history.jsonl: $prompt_count prompts, $total_chars chars"
else
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-history\",\"status\":\"source-unavailable\"}"
fi

# 2. Project transcripts — tool-use counts by tool name.
# Claude Code stores tool_use records nested in assistant messages at
# message.content[].type == "tool_use" with a `name` field.
if [ -d "$CC_HOME/projects" ]; then
  # Bound by last 7 days of activity to keep scans tractable.
  # BSD find (macOS default) doesn't honour `-newermt "@UNIX_TS"`; use `-mtime -7`.
  total_transcripts=0

  tmp_list="$(mktemp)"
  find "$CC_HOME/projects" -type f -name '*.jsonl' -mtime -7 -print > "$tmp_list" 2>/dev/null || true
  total_transcripts=$(wc -l < "$tmp_list" | tr -d ' ')

  if [ "$total_transcripts" -gt 0 ]; then
    # One Python pass: read each transcript, sum tool_use counts per tool name.
    python3 - "$tmp_list" "$OUT_DIR/$OUT" <<'PYEOF'
import json, sys, os
from collections import Counter
from datetime import datetime, timezone

list_path = sys.argv[1]
out_path = sys.argv[2]
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

tool_counts = Counter()
content_type_counts = Counter()
event_type_counts = Counter()
total_tool_uses = 0
transcripts_scanned = 0

with open(list_path) as f:
    paths = [p.strip() for p in f if p.strip()]

for p in paths:
    transcripts_scanned += 1
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
                event_type = d.get('type', '?')
                event_type_counts[event_type] += 1
                if event_type == 'assistant':
                    msg = d.get('message') or {}
                    content = msg.get('content') if isinstance(msg, dict) else None
                    if isinstance(content, list):
                        for item in content:
                            if not isinstance(item, dict):
                                continue
                            it = item.get('type')
                            content_type_counts[it or '?'] += 1
                            if it == 'tool_use':
                                name = item.get('name') or '?'
                                tool_counts[name] += 1
                                total_tool_uses += 1
    except (OSError, PermissionError):
        continue

with open(out_path, 'a') as out:
    out.write(json.dumps({
        'ts': ts,
        'source': 'claude-code-transcripts',
        'category': 'transcript-volume',
        'transcripts_scanned': transcripts_scanned,
        'window_days': 7,
        'total_tool_uses': total_tool_uses,
    }) + '\n')
    for event_type, count in event_type_counts.most_common():
        out.write(json.dumps({
            'ts': ts,
            'source': 'claude-code-transcripts',
            'category': 'event-type-shape',
            'event_type': event_type,
            'count': count,
        }) + '\n')
    for tool, count in tool_counts.most_common():
        out.write(json.dumps({
            'ts': ts,
            'source': 'claude-code-transcripts',
            'category': 'tool-use-shape',
            'tool': tool,
            'count': count,
        }) + '\n')
    for ct, count in content_type_counts.most_common():
        out.write(json.dumps({
            'ts': ts,
            'source': 'claude-code-transcripts',
            'category': 'assistant-content-shape',
            'content_type': ct,
            'count': count,
        }) + '\n')
PYEOF
    scanned_display=$total_transcripts
    echo "  ✓ transcripts (7d window): $scanned_display files scanned"
  else
    jsonl_append "$OUT" \
      "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-transcripts\",\"status\":\"no-recent-transcripts\",\"window_days\":7}"
    echo "  ⏸  no transcripts in last 7 days"
  fi
  rm -f "$tmp_list"
else
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-transcripts\",\"status\":\"source-unavailable\"}"
  echo "  ⏸  ~/.claude/projects/ not present"
fi

# 3. Probe proxies from history (user-typed patterns that trigger probes).
if [ -f "$CC_HOME/history.jsonl" ]; then
  help_mentions=$(count_matches '"display":"[^"]*(--help|[[:space:]]-h([[:space:]]|\\"))' "$CC_HOME/history.jsonl")
  version_mentions=$(count_matches '"display":"[^"]*(--version|[[:space:]]-V([[:space:]]|\\"))' "$CC_HOME/history.jsonl")
  which_mentions=$(count_matches '"display":"[^"]*(which|command -v|type )[ \\]' "$CC_HOME/history.jsonl")
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-history\",\"category\":\"probe-proxy-mentions\",\"help\":${help_mentions:-0},\"version\":${version_mentions:-0},\"which\":${which_mentions:-0}}"
  echo "  ✓ probe proxies: help=${help_mentions:-0} version=${version_mentions:-0} which=${which_mentions:-0}"
fi

# 4. sessions/*.json — record file count only (format is pid metadata, not tool-use).
if [ -d "$CC_HOME/sessions" ]; then
  session_count=$(find "$CC_HOME/sessions" -maxdepth 1 -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-code-sessions\",\"category\":\"metadata-file-count\",\"count\":$session_count,\"note\":\"pid+sessionId metadata only; tool_use lives in projects/\"}"
  echo "  ✓ sessions/ metadata files: $session_count (pid/sessionId only)"
fi

echo "  → $(log_dir)/$OUT"
