#!/usr/bin/env bash
# measure-codex.sh — Phase 0b: shape counts from Codex SQLite + session index.
#
# Reads (read-only):
#   ~/.codex/session_index.jsonl
#   ~/.codex/logs_2.sqlite          structured log table
#   ~/.codex/state_5.sqlite         threads, agent_jobs, thread_dynamic_tools
#
# Writes:
#   $OUT_DIR/activity.jsonl          appended

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
assert_read_only_host_paths
script_banner "measure-codex"

CODEX_HOME="$HOME/.codex"

# 1. Session index — thread count + date range.
if [ -f "$CODEX_HOME/session_index.jsonl" ]; then
  thread_count=$(wc -l < "$CODEX_HOME/session_index.jsonl" | tr -d ' ')
  first_ts=$(head -1 "$CODEX_HOME/session_index.jsonl" 2>/dev/null | grep -oE '"updated_at":"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  last_ts=$(tail -1 "$CODEX_HOME/session_index.jsonl" 2>/dev/null | grep -oE '"updated_at":"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"codex-session-index\",\"category\":\"thread-count\",\"thread_count\":$thread_count,\"first\":\"$first_ts\",\"last\":\"$last_ts\"}"
  echo "  ✓ codex sessions: $thread_count threads from $first_ts to $last_ts"
else
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"codex-session-index\",\"status\":\"source-unavailable\"}"
fi

# 2. Codex structured logs — count by target module + level (last 7 days only).
if [ -f "$CODEX_HOME/logs_2.sqlite" ]; then
  # SQLite query — read-only mode. Use file: URI with mode=ro to enforce.
  # Counts log entries by level + target for past week.
  seven_days_ago=$(( $(date +%s) - 7 * 86400 ))
  sqlite3 -readonly "file:$CODEX_HOME/logs_2.sqlite?mode=ro" \
    "SELECT level, target, COUNT(*) FROM logs WHERE ts >= $seven_days_ago GROUP BY level, target ORDER BY COUNT(*) DESC LIMIT 20;" 2>/dev/null |
    while IFS='|' read -r level target count; do
      jsonl_append "activity.jsonl" \
        "{\"ts\":\"$(iso_now)\",\"source\":\"codex-logs\",\"category\":\"log-shape\",\"level\":\"$level\",\"target\":\"$(printf '%s' "$target" | sed 's/"/\\"/g')\",\"count\":$count}"
    done
  echo "  ✓ codex logs: top 20 (level, target) shapes"
else
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"codex-logs\",\"status\":\"source-unavailable\"}"
fi

# 3. Codex state — threads + tools.
if [ -f "$CODEX_HOME/state_5.sqlite" ]; then
  threads_count=$(sqlite3 -readonly "file:$CODEX_HOME/state_5.sqlite?mode=ro" "SELECT COUNT(*) FROM threads;" 2>/dev/null || echo 0)
  tools_count=$(sqlite3 -readonly "file:$CODEX_HOME/state_5.sqlite?mode=ro" "SELECT COUNT(*) FROM thread_dynamic_tools;" 2>/dev/null || echo 0)
  jobs_count=$(sqlite3 -readonly "file:$CODEX_HOME/state_5.sqlite?mode=ro" "SELECT COUNT(*) FROM agent_jobs;" 2>/dev/null || echo 0)
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"codex-state\",\"category\":\"state-counts\",\"threads\":$threads_count,\"dynamic_tools\":$tools_count,\"agent_jobs\":$jobs_count}"
  echo "  ✓ codex state: $threads_count threads, $tools_count tools, $jobs_count jobs"

  # Top 20 dynamic-tool names (shape only).
  sqlite3 -readonly "file:$CODEX_HOME/state_5.sqlite?mode=ro" \
    "SELECT name, COUNT(*) FROM thread_dynamic_tools GROUP BY name ORDER BY COUNT(*) DESC LIMIT 20;" 2>/dev/null |
    while IFS='|' read -r name count; do
      name_safe="$(printf '%s' "$name" | sed 's/"/\\"/g')"
      jsonl_append "activity.jsonl" \
        "{\"ts\":\"$(iso_now)\",\"source\":\"codex-state\",\"category\":\"dynamic-tool-shape\",\"name\":\"$name_safe\",\"count\":$count}"
    done
else
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"codex-state\",\"status\":\"source-unavailable\"}"
fi

echo "  → $(log_dir)/activity.jsonl"
