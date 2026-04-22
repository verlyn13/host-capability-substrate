#!/usr/bin/env bash
# measure-governance-inventory.sh — Phase 0b: catalog existing governance surface.
#
# Enumerates:
#   - PreToolUse hooks in ~/.claude/ and per-project .claude/settings.json
#   - Codex hooks and profiles in ~/.codex/
#   - Tier classifications in system-config/policies/
#   - Hard-coded command allow/deny lists in scripts
#   - Runbook prose that describes tiers (grep-based; advisory)
#
# Output: $OUT_DIR/governance-inventory.jsonl (one entry per artifact)

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
assert_read_only_host_paths
script_banner "measure-governance-inventory"

SYSTEM_CONFIG="$HOME/Organizations/jefahnierocks/system-config"

record() {
  local category="$1"
  local path="$2"
  local kind="$3"
  local excerpt="${4:-}"
  local path_escaped="$(printf '%s' "$path" | sed 's/"/\\"/g')"
  local excerpt_redacted="$(redact "$excerpt" | sed 's/"/\\"/g' | tr -d '\n' | cut -c1-200)"
  jsonl_append "governance-inventory.jsonl" \
    "{\"ts\":\"$(iso_now)\",\"category\":\"$category\",\"path\":\"$path_escaped\",\"kind\":\"$kind\",\"excerpt\":\"$excerpt_redacted\"}"
}

# 1. Claude Code user-global hooks
# Safe count helper — grep -c exits 1 on no match.
_count_matches() {
  local pat="$1" file="$2"
  local c
  c=$(grep -cE "$pat" "$file" 2>/dev/null || printf '0')
  # Strip newlines/whitespace (defensive: some greps emit per-file counts)
  printf '%s' "${c//[^0-9]/}"
}

if [ -f "$HOME/.claude/settings.json" ]; then
  hook_count=$(_count_matches '"hooks"|"PreToolUse"|"PostToolUse"' "$HOME/.claude/settings.json")
  record "claude-hooks-user" "$HOME/.claude/settings.json" "settings" "hook_markers=${hook_count:-0}"
fi
if [ -f "$HOME/.claude/settings.local.json" ]; then
  hook_count=$(_count_matches '"hooks"|"PreToolUse"|"PostToolUse"' "$HOME/.claude/settings.local.json")
  record "claude-hooks-user-local" "$HOME/.claude/settings.local.json" "settings" "hook_markers=${hook_count:-0}"
fi
if [ -d "$HOME/.claude/agents" ]; then
  for agent in "$HOME"/.claude/agents/*.md; do
    [ -f "$agent" ] || continue
    name="$(basename "$agent" .md)"
    record "claude-agents-user" "$agent" "subagent" "name=$name"
  done
fi

# 2. Codex hooks + profiles
if [ -f "$HOME/.codex/config.toml" ]; then
  profile_count=$(_count_matches '^\[profiles\.' "$HOME/.codex/config.toml")
  hook_count=$(_count_matches '^\[hooks\.|^\[\[hooks\.' "$HOME/.codex/config.toml")
  record "codex-config-user" "$HOME/.codex/config.toml" "settings" "profiles=${profile_count:-0} hooks=${hook_count:-0}"
fi

# 3. Existing PreToolUse hooks for this project (HCS repo)
if [ -f "$HCS_ROOT/.claude/settings.json" ]; then
  hook_count=$(_count_matches '"hooks"|"PreToolUse"|"PostToolUse"' "$HCS_ROOT/.claude/settings.json")
  record "claude-hooks-project" "$HCS_ROOT/.claude/settings.json" "settings" "hook_markers=${hook_count:-0}"
fi

# 4. system-config policies (live authority)
if [ -d "$SYSTEM_CONFIG/policies" ]; then
  for policy in "$SYSTEM_CONFIG"/policies/*.md "$SYSTEM_CONFIG"/policies/**/*.md \
                "$SYSTEM_CONFIG"/policies/*.yaml "$SYSTEM_CONFIG"/policies/**/*.yaml \
                "$SYSTEM_CONFIG"/policies/*.rego "$SYSTEM_CONFIG"/policies/**/*.rego; do
    [ -f "$policy" ] || continue
    # Read first 5 lines for a kind hint
    head5="$(head -5 "$policy" 2>/dev/null | tr -d '\n\r' | cut -c1-120)"
    record "system-config-policies" "$policy" "policy" "$head5"
  done
fi

# 5. HCS policy stubs (test snapshot only; NOT live policy)
if [ -d "$HCS_ROOT/policies" ]; then
  for f in "$HCS_ROOT"/policies/*.md "$HCS_ROOT"/policies/**/*; do
    [ -f "$f" ] || continue
    record "hcs-policies-snapshot" "$f" "snapshot-fixture" ""
  done
fi

# 6. Hard-coded command allow/deny in system-config scripts
if [ -d "$SYSTEM_CONFIG/scripts" ]; then
  for f in "$SYSTEM_CONFIG"/scripts/*.sh; do
    [ -f "$f" ] || continue
    allow_denies=$(_count_matches '(deny|allow|forbidden)' "$f")
    if [ "${allow_denies:-0}" -gt 0 ]; then
      record "system-config-scripts" "$f" "script" "allow_deny_lines=${allow_denies:-0}"
    fi
  done
fi

# 7. MCP configuration (tells us what servers are active globally)
if [ -f "$SYSTEM_CONFIG/scripts/mcp-servers.json" ]; then
  server_names=$(grep -oE '"[a-z-]+":\s*\{' "$SYSTEM_CONFIG/scripts/mcp-servers.json" 2>/dev/null | head -20 | sed 's/[":{]//g' | tr -d '\n' | cut -c1-200)
  record "mcp-baseline" "$SYSTEM_CONFIG/scripts/mcp-servers.json" "config" "servers=$server_names"
fi

# 8. secrets policy (confirm authority version)
if [ -f "$SYSTEM_CONFIG/docs/secrets.md" ]; then
  secret_version=$(grep '^version:' "$SYSTEM_CONFIG/docs/secrets.md" | head -1 | awk '{print $2}')
  record "secrets-policy" "$SYSTEM_CONFIG/docs/secrets.md" "policy-doc" "version=$secret_version"
fi

# Summary counts
total_records=$(wc -l < "$OUT_DIR/governance-inventory.jsonl" | tr -d ' ')
echo "  ✓ catalogued $total_records governance artifacts"
echo "  → $(log_dir)/governance-inventory.jsonl"
