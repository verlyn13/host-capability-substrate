#!/usr/bin/env bash
# measure-ide-hosts.sh — Phase 0b: shape counts from Cursor, Windsurf, Claude Desktop, Copilot CLI.
#
# Reads (read-only):
#   ~/Library/Application Support/Cursor/logs/            VS Code-style log dirs
#   ~/Library/Application Support/Windsurf/               similar
#   ~/Library/Application Support/Claude/claude-code-sessions/  (if granted)
#   ~/.copilot/logs/, command-history-state.json, session-state/
#
# Writes:
#   $OUT_DIR/activity.jsonl          appended
#
# Most IDE logs are VS Code-style — window-scoped and rotated. We capture
# directory count and size-shape rather than parsing internals.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
assert_read_only_host_paths
script_banner "measure-ide-hosts"

report_log_dir() {
  local host="$1"
  local dir="$2"
  if [ ! -d "$dir" ]; then
    jsonl_append "activity.jsonl" \
      "{\"ts\":\"$(iso_now)\",\"source\":\"$host\",\"status\":\"source-unavailable\"}"
    echo "  ⏸  $host: $dir not present"
    return
  fi
  local log_dir_count total_bytes
  log_dir_count=$(ls -1 "$dir" 2>/dev/null | wc -l | tr -d ' ')
  # Safe size calc; fallback to 0 on error
  total_bytes=$(du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}' || echo 0)
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"$host\",\"category\":\"log-volume\",\"entry_count\":$log_dir_count,\"total_bytes\":$total_bytes}"
  echo "  ✓ $host: $log_dir_count entries, $total_bytes bytes at $dir"
}

# Cursor
report_log_dir "cursor" "$HOME/Library/Application Support/Cursor/logs"

# Windsurf — check both common log dir locations
if [ -d "$HOME/Library/Application Support/Windsurf/logs" ]; then
  report_log_dir "windsurf" "$HOME/Library/Application Support/Windsurf/logs"
else
  report_log_dir "windsurf" "$HOME/Library/Application Support/Windsurf"
fi

# Claude Desktop — session directory access may require FDA (TCC).
claude_desktop="$HOME/Library/Application Support/Claude/claude-code-sessions"
if [ -r "$claude_desktop" ]; then
  report_log_dir "claude-desktop" "$claude_desktop"
else
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-desktop\",\"status\":\"tcc_unknown\",\"hint\":\"session directory not readable; may need Full Disk Access\"}"
  echo "  ⏸  claude-desktop: tcc_unknown — FDA may be required"
fi

# Copilot CLI
report_log_dir "copilot-cli-logs" "$HOME/.copilot/logs"
if [ -f "$HOME/.copilot/command-history-state.json" ]; then
  # Shape-only count — file size as proxy for history volume
  copilot_hist_bytes=$(wc -c < "$HOME/.copilot/command-history-state.json" | tr -d ' ')
  jsonl_append "activity.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"copilot-cli-history\",\"category\":\"history-size\",\"bytes\":$copilot_hist_bytes}"
  echo "  ✓ copilot-cli-history: $copilot_hist_bytes bytes"
fi

echo "  → $(log_dir)/activity.jsonl"
