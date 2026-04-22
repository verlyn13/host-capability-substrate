#!/usr/bin/env bash
# install-claude-hook.sh — opt-in installer for the HCS log-only PreToolUse
# hook into the user's global Claude Code settings (~/.claude/settings.json).
#
# This is an **opt-in**, **reversible** change. The user must explicitly run
# `install`. The hook is log-only — it emits decision records to
# .logs/phase-0/<date>/hook-decisions.jsonl and always returns `allow`. It
# never blocks or denies in Phase 0b.
#
# Install:   scripts/install/install-claude-hook.sh install
# Uninstall: scripts/install/install-claude-hook.sh uninstall
# Status:    scripts/install/install-claude-hook.sh status
#
# Always backs up the existing settings.json to settings.json.bak-<ts> before
# modifying. Uses jq to merge — never clobbers unrelated keys.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HCS_ROOT="$(cd "$HERE/../.." && pwd)"
HOOK_CMD="$HCS_ROOT/scripts/dev/hcs-hook-cli.sh"
SETTINGS="$HOME/.claude/settings.json"
MATCHER="Bash"

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "✗ jq is required but not installed" >&2
    exit 1
  fi
}

backup_settings() {
  if [ -f "$SETTINGS" ]; then
    local stamp
    stamp="$(date +%Y%m%dT%H%M%S)"
    cp "$SETTINGS" "${SETTINGS}.bak-${stamp}"
    echo "  ✓ backup: ${SETTINGS}.bak-${stamp}"
  fi
}

ensure_settings() {
  mkdir -p "$(dirname "$SETTINGS")"
  if [ ! -f "$SETTINGS" ]; then
    printf '%s\n' '{}' > "$SETTINGS"
  fi
}

do_install() {
  require_jq
  if [ ! -x "$HOOK_CMD" ]; then
    echo "✗ hook script not executable: $HOOK_CMD" >&2
    echo "  run: chmod +x $HOOK_CMD" >&2
    exit 1
  fi
  ensure_settings
  backup_settings

  # Merge. Structure per Claude Code hooks-guide:
  # hooks.PreToolUse is an array of { matcher, hooks:[{type,command}] }.
  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  jq --arg matcher "$MATCHER" --arg cmd "$HOOK_CMD" '
    . as $orig
    | ($orig.hooks // {}) as $h
    | ($h.PreToolUse // []) as $pre
    | ($pre | map(select(.matcher != $matcher))) as $others
    | ($others + [{matcher: $matcher, hooks: [{type: "command", command: $cmd}]}]) as $merged
    | . * {hooks: ($h + {PreToolUse: $merged})}
  ' "$SETTINGS" > "$tmp"

  mv "$tmp" "$SETTINGS"
  trap - EXIT

  echo "  ✓ installed hook into $SETTINGS"
  echo "  ✓ matcher: $MATCHER"
  echo "  ✓ command: $HOOK_CMD"
  echo ""
  echo "Hook is LOG-ONLY in Phase 0b — it never blocks, asks, or denies."
  echo "Decisions accumulate in \$HCS_ROOT/.logs/phase-0/<date>/hook-decisions.jsonl"
  echo ""
  echo "Verify with: $0 status"
}

do_uninstall() {
  require_jq
  if [ ! -f "$SETTINGS" ]; then
    echo "  ⏸  no settings.json — nothing to do"
    return 0
  fi
  backup_settings

  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  jq --arg matcher "$MATCHER" --arg cmd "$HOOK_CMD" '
    if (.hooks // {}) | has("PreToolUse") then
      .hooks.PreToolUse |= map(select(.matcher != $matcher or (.hooks // []) | map(.command) | index($cmd) | not))
    else . end
    | if (.hooks // {}).PreToolUse == [] then
        .hooks |= del(.PreToolUse)
      else . end
    | if .hooks == {} then del(.hooks) else . end
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  trap - EXIT

  echo "  ✓ removed HCS hook from $SETTINGS"
}

do_status() {
  if [ ! -f "$SETTINGS" ]; then
    echo "settings.json: not present"
    return 0
  fi
  echo "settings.json: $SETTINGS"
  if command -v jq >/dev/null 2>&1; then
    local installed
    installed=$(jq --arg cmd "$HOOK_CMD" '(.hooks.PreToolUse // []) | map(select((.hooks // []) | map(.command) | index($cmd))) | length' "$SETTINGS")
    echo "HCS hook installed: $([ "$installed" -gt 0 ] && printf yes || printf no)"
    echo "All PreToolUse hooks:"
    jq '.hooks.PreToolUse // []' "$SETTINGS"
  else
    grep -q "$HOOK_CMD" "$SETTINGS" && echo "HCS hook detected (grep fallback)" || echo "HCS hook not detected"
  fi
  # Show today's decision count.
  local today
  today="$(date -u +%Y-%m-%d)"
  local f="$HCS_ROOT/.logs/phase-0/$today/hook-decisions.jsonl"
  if [ -f "$f" ]; then
    local n
    n=$(wc -l < "$f" | tr -d ' ')
    echo "today's hook-decisions.jsonl: $n records"
  else
    echo "today's hook-decisions.jsonl: not yet written"
  fi
}

cmd="${1:-status}"
case "$cmd" in
  install) do_install ;;
  uninstall) do_uninstall ;;
  status) do_status ;;
  *)
    echo "usage: $0 {install|uninstall|status}"
    exit 2
    ;;
esac
