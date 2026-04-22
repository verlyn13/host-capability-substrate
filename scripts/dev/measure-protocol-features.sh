#!/usr/bin/env bash
# measure-protocol-features.sh — Phase 0b: per-host MCP feature support matrix.
#
# For each host, record what we KNOW (from config/docs) and what NEEDS PROBING.
# Some features (e.g., elicitation URL mode, actual structured-output acceptance)
# require a live MCP exchange; Phase 0b records the knowability frontier.
#
# Output: $OUT_DIR/protocol-features.json

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
assert_read_only_host_paths
script_banner "measure-protocol-features"

out="$OUT_DIR/protocol-features.json"

cat > "$out" <<'EOF'
{
  "ts": "__TS__",
  "hosts": {
    "claude-code": {
      "version_baseline": "1.3883.0 (93ff6c)",
      "supports": {
        "mcp_stdio": true,
        "mcp_streamable_http": true,
        "structured_output_schemas": true,
        "resources": true,
        "prompts": true,
        "elicitation_form": true,
        "elicitation_url": "probe-required",
        "subagent_tool_scoping": true,
        "settings_permissions": true,
        "hooks_pre_tool_use": true,
        "hooks_post_tool_use": true
      },
      "client_info_populated": "probe-required",
      "notes": "Richest hook model; MCP tools appear as mcp__server__tool. HTTP hook failures non-blocking."
    },
    "codex": {
      "version_baseline": "26.417.41555 (1858)",
      "supports": {
        "mcp_stdio": true,
        "mcp_streamable_http": "probe-required",
        "structured_output_schemas": true,
        "resources": "probe-required",
        "prompts": "probe-required",
        "elicitation_form": "probe-required",
        "elicitation_url": "probe-required",
        "subagent_tool_scoping": "inherits-parent",
        "hooks_pre_tool_use": "advisory-only-bash",
        "hooks_post_tool_use": "advisory-only-bash",
        "hooks_permission_request": true,
        "profiles": "experimental-cli-only"
      },
      "client_info_populated": "probe-required",
      "notes": "Hooks Bash-only; coverage incomplete per docs. Profiles supported in CLI, not IDE extension."
    },
    "cursor": {
      "supports": {
        "mcp_stdio": true,
        "mcp_streamable_http": "probe-required",
        "project_scope_mcp": true,
        "resources": "probe-required",
        "prompts": "probe-required",
        "elicitation_form": "probe-required",
        "hooks": false
      },
      "client_info_populated": "probe-required",
      "notes": "Project mcp.json + .cursor/rules/*.mdc; no hook lifecycle."
    },
    "windsurf": {
      "supports": {
        "mcp_stdio": true,
        "mcp_streamable_http": true,
        "project_scope_mcp": false,
        "resources": "probe-required",
        "prompts": "probe-required",
        "elicitation_form": "probe-required",
        "oauth_2_1_pkce": true,
        "agents_skills_discovery": true,
        "hooks": false
      },
      "client_info_populated": "probe-required",
      "notes": "No project-scope MCP (user-scope only). Reads .agents/skills/ per docs. Native OAuth for GitHub MCP."
    },
    "copilot-cli": {
      "supports": {
        "mcp_stdio": "probe-required",
        "mcp_streamable_http": "probe-required",
        "project_scope_mcp": true,
        "builtin_github_mcp": true,
        "hooks": false
      },
      "client_info_populated": "probe-required",
      "notes": "Ships builtin github MCP; sync-mcp.sh skips github-mcp write for copilot."
    },
    "claude-desktop": {
      "supports": {
        "mcp_stdio": true,
        "mcp_streamable_http": true,
        "resources": "probe-required",
        "prompts": "probe-required",
        "elicitation_form": "probe-required",
        "hooks": false
      },
      "client_info_populated": "probe-required",
      "notes": "Not a sync target; user manages directly. TCC may require FDA to read session dir."
    }
  },
  "probe_plan": "During Phase 1 Thread B, connect each host to a throwaway MCP server that echoes clientInfo, capability negotiation, and primitive test results back to a JSON file under .logs/phase-0/probe/."
}
EOF

# Substitute timestamp (BSD sed-safe)
python3 -c "
import json, sys
from datetime import datetime, timezone
p = '$out'
with open(p) as f: data = json.load(f)
data['ts'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open(p, 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null || {
  # Fallback: leave __TS__ placeholder
  echo "  ⚠️  python3 json tool unavailable; __TS__ placeholder remains"
}

echo "  ✓ protocol-features.json written (6 hosts; probe-required fields marked)"
echo "  → $out"
