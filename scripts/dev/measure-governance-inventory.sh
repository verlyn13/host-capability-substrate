#!/usr/bin/env bash
# measure-governance-inventory.sh — Phase 0b: enumerate current governance surface.
#
# REVISED after P2 critique:
#   - MCP servers parsed via jq (the previous regex falsely captured `env` as a
#     server name because it matched `"env": {` inside a server's env block).
#   - Expanded scope: chezmoi-managed MCP wrappers, dot_local/bin templates,
#     runbook docs under system-config/docs/, additional script directories,
#     1Password reference conventions.
#
# Snapshot semantics: overwrites governance-inventory.jsonl fresh each run.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-governance-inventory"

OUT="governance-inventory.jsonl"
snapshot_begin "$OUT"

SYSTEM_CONFIG="$HOME/Organizations/jefahnierocks/system-config"

# _count_matches + first_match are provided by measure-common.sh.
# Alias to keep existing names readable.
_count_matches() { count_matches "$@"; }

record() {
  local category="$1" path="$2" kind="$3" excerpt="${4:-}"
  local path_escaped excerpt_redacted
  path_escaped="$(printf '%s' "$path" | sed 's/"/\\"/g')"
  excerpt_redacted="$(redact "$excerpt" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n' | cut -c1-200)"
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"category\":\"$category\",\"path\":\"$path_escaped\",\"kind\":\"$kind\",\"excerpt\":\"$excerpt_redacted\"}"
}

# 1. Claude Code user-global settings + hooks + subagents
for f in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json"; do
  if [ -f "$f" ]; then
    hook_count=$(_count_matches '"hooks"|"PreToolUse"|"PostToolUse"' "$f")
    record "claude-settings-user" "$f" "settings" "hook_markers=${hook_count:-0}"
  fi
done

if [ -d "$HOME/.claude/agents" ]; then
  for agent in "$HOME"/.claude/agents/*.md; do
    [ -f "$agent" ] || continue
    name="$(basename "$agent" .md)"
    tools=$(first_match '^tools:' "$agent" | sed 's/^tools:[[:space:]]*//' | tr -d '\n' | cut -c1-120)
    record "claude-agents-user" "$agent" "subagent" "name=$name tools=$tools"
  done
fi

# HCS project-scoped subagents
if [ -d "$HCS_ROOT/.claude/agents" ]; then
  for agent in "$HCS_ROOT"/.claude/agents/*.md; do
    [ -f "$agent" ] || continue
    name="$(basename "$agent" .md)"
    tools=$(first_match '^tools:' "$agent" | sed 's/^tools:[[:space:]]*//' | tr -d '\n' | cut -c1-120)
    record "claude-agents-hcs-project" "$agent" "subagent" "name=$name tools=$tools"
  done
fi

# 2. Codex user-scope config
if [ -f "$HOME/.codex/config.toml" ]; then
  profile_count=$(_count_matches '^\[profiles\.' "$HOME/.codex/config.toml")
  hook_count=$(_count_matches '^\[hooks\.|^\[\[hooks\.' "$HOME/.codex/config.toml")
  trust_count=$(_count_matches '^\[projects\.' "$HOME/.codex/config.toml")
  record "codex-config-user" "$HOME/.codex/config.toml" "settings" \
    "profiles=${profile_count:-0} hooks=${hook_count:-0} trust_entries=${trust_count:-0}"
fi

# 3. HCS project-scoped settings
if [ -f "$HCS_ROOT/.claude/settings.json" ]; then
  hook_count=$(_count_matches '"hooks"|"PreToolUse"|"PostToolUse"' "$HCS_ROOT/.claude/settings.json")
  deny_count=$(_count_matches '"deny"|"Bash\\(' "$HCS_ROOT/.claude/settings.json")
  record "claude-settings-hcs-project" "$HCS_ROOT/.claude/settings.json" "settings" \
    "hook_markers=${hook_count:-0} deny_count=${deny_count:-0}"
fi

# 4. system-config policies/
if [ -d "$SYSTEM_CONFIG/policies" ]; then
  while IFS= read -r policy; do
    [ -f "$policy" ] || continue
    head5="$(head -5 "$policy" 2>/dev/null | tr -d '\n\r' | cut -c1-120)"
    kind="policy"
    case "$policy" in
      *.rego) kind="opa-rego" ;;
      *.yaml|*.yml) kind="policy-yaml" ;;
      *.md) kind="policy-doc" ;;
    esac
    record "system-config-policies" "$policy" "$kind" "$head5"
  done < <(find "$SYSTEM_CONFIG/policies" -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' -o -name '*.rego' \) 2>/dev/null)
fi

# 5. HCS repo generated-snapshot (fixture, NOT live policy)
if [ -d "$HCS_ROOT/policies" ]; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    record "hcs-policies-snapshot" "$f" "snapshot-fixture" ""
  done < <(find "$HCS_ROOT/policies" -type f 2>/dev/null)
fi

# 6. system-config scripts — flag any that look policy-adjacent.
if [ -d "$SYSTEM_CONFIG/scripts" ]; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    allow_denies=$(_count_matches '(deny|allow|forbidden|policy|tier)' "$f")
    if [ "${allow_denies:-0}" -gt 0 ]; then
      record "system-config-scripts" "$f" "script" "policy_keyword_lines=${allow_denies:-0}"
    fi
  done < <(find "$SYSTEM_CONFIG/scripts" -type f -name '*.sh' 2>/dev/null)
fi

# 7. Chezmoi-managed MCP wrappers (dot_local/bin)
if [ -d "$SYSTEM_CONFIG/home/dot_local/bin" ]; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    record "chezmoi-wrappers" "$f" "wrapper-template" "name=$name"
  done < <(find "$SYSTEM_CONFIG/home/dot_local/bin" -type f -name 'executable_mcp-*' 2>/dev/null)
fi

# 8. MCP baseline — parse as JSON, not regex.
mcp_servers_json="$SYSTEM_CONFIG/scripts/mcp-servers.json"
if [ -f "$mcp_servers_json" ] && command -v jq >/dev/null 2>&1; then
  # Emit one record per actual server name
  server_names=$(jq -r '.mcpServers | keys | join(",")' "$mcp_servers_json" 2>/dev/null || echo "")
  server_count=$(jq '.mcpServers | length' "$mcp_servers_json" 2>/dev/null || echo 0)
  record "mcp-baseline" "$mcp_servers_json" "config" "server_count=$server_count servers=$server_names"

  # Per-server records
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    transport=$(jq -r --arg n "$name" '.mcpServers[$n].type // "stdio"' "$mcp_servers_json" 2>/dev/null)
    record "mcp-baseline-server" "$mcp_servers_json" "server" "name=$name transport=$transport"
  done < <(jq -r '.mcpServers | keys[]' "$mcp_servers_json" 2>/dev/null)
fi

# 9. secrets policy version
if [ -f "$SYSTEM_CONFIG/docs/secrets.md" ]; then
  secret_version=$(first_match '^version:' "$SYSTEM_CONFIG/docs/secrets.md" | awk '{print $2}')
  record "secrets-policy" "$SYSTEM_CONFIG/docs/secrets.md" "policy-doc" "version=${secret_version:-unknown}"
fi

# 10. system-config runbook-style docs (agentic-tooling, mcp-config, project-conventions, etc.)
if [ -d "$SYSTEM_CONFIG/docs" ]; then
  for doc in agentic-tooling.md mcp-config.md github-mcp.md project-conventions.md claude-cli-setup.md codex-cli-setup.md copilot-cli-setup.md workspace-management.md; do
    f="$SYSTEM_CONFIG/docs/$doc"
    if [ -f "$f" ]; then
      version=$(first_match '^version:' "$f" | awk '{print $2}')
      record "system-config-docs" "$f" "runbook" "version=${version:-unknown}"
    fi
  done
fi

# 11. 1Password reference convention files
if [ -f "$SYSTEM_CONFIG/home/dot_config/mcp/common.env" ] || [ -f "$SYSTEM_CONFIG/home/dot_config/mcp/common.env.tmpl" ]; then
  for f in "$SYSTEM_CONFIG"/home/dot_config/mcp/common.env*; do
    [ -f "$f" ] || continue
    op_refs=$(_count_matches 'op://' "$f")
    record "op-reference-manifest" "$f" "op-uri-manifest" "op_references=${op_refs:-0}"
  done
fi

total_records=$(wc -l < "$OUT_DIR/$OUT" | tr -d ' ')
echo "  ✓ catalogued $total_records governance artifacts"
echo "  → $(log_dir)/$OUT"
