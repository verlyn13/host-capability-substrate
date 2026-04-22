#!/usr/bin/env bash
# measure-ide-hosts.sh — Phase 0b: shape counts from IDE/terminal hosts.
#
# Cursor, Windsurf, Claude Desktop, Copilot CLI log into VS Code-style
# rotating directories or binary blobs; per-tool-call signal requires live MCP
# instrumentation (Phase 1 Thread B — echo server). Until then, we record
# log volume shape (entry count + total bytes) as a coarse activity proxy.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-ide-hosts"

OUT="activity-ide-hosts.jsonl"
snapshot_begin "$OUT"

report_log_dir() {
  local host="$1"
  local dir="$2"
  if [ ! -d "$dir" ]; then
    jsonl_append "$OUT" \
      "{\"ts\":\"$(iso_now)\",\"source\":\"$host\",\"status\":\"source-unavailable\",\"path\":\"$(redact "$dir")\"}"
    echo "  ⏸  $host: $dir not present"
    return
  fi
  local entry_count total_bytes
  entry_count=$(find "$dir" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
  total_bytes=$(du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}' || echo 0)
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"$host\",\"category\":\"log-volume-shape\",\"entry_count\":$entry_count,\"total_bytes\":$total_bytes}"
  echo "  ✓ $host: $entry_count entries, $total_bytes bytes"
}

report_log_dir "cursor" "$HOME/Library/Application Support/Cursor/logs"

if [ -d "$HOME/Library/Application Support/Windsurf/logs" ]; then
  report_log_dir "windsurf" "$HOME/Library/Application Support/Windsurf/logs"
else
  report_log_dir "windsurf" "$HOME/Library/Application Support/Windsurf"
fi

claude_desktop="$HOME/Library/Application Support/Claude/claude-code-sessions"
if [ -r "$claude_desktop" ]; then
  report_log_dir "claude-desktop" "$claude_desktop"
else
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"claude-desktop\",\"status\":\"tcc_unknown\",\"hint\":\"session directory not readable; may need Full Disk Access\"}"
  echo "  ⏸  claude-desktop: tcc_unknown"
fi

report_log_dir "copilot-cli-logs" "$HOME/.copilot/logs"
if [ -f "$HOME/.copilot/command-history-state.json" ]; then
  b=$(wc -c < "$HOME/.copilot/command-history-state.json" | tr -d ' ')
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"source\":\"copilot-cli-history\",\"category\":\"history-size\",\"bytes\":$b}"
  echo "  ✓ copilot-cli-history: $b bytes"
fi

echo "  → $(log_dir)/$OUT"
