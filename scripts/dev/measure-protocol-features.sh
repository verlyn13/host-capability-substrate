#!/usr/bin/env bash
# measure-protocol-features.sh — Phase 0b: per-host MCP feature support matrix.
#
# Snapshot semantics: overwrites protocol-features.json fresh each run.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-protocol-features"

out_path="$OUT_DIR/protocol-features.json"

python3 - "$out_path" <<'PYEOF'
import json, sys, os
from datetime import datetime, timezone

out_path = sys.argv[1]
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

data = {
    "ts": ts,
    "hosts": {
        "claude-code": {
            "version_baseline": "1.3883.0 (93ff6c)",
            "supports": {
                "mcp_stdio": True,
                "mcp_streamable_http": True,
                "structured_output_schemas": True,
                "resources": True,
                "prompts": True,
                "elicitation_form": True,
                "elicitation_url": "probe-required",
                "subagent_tool_scoping": True,
                "settings_permissions": True,
                "hooks_pre_tool_use": True,
                "hooks_post_tool_use": True,
            },
            "client_info_populated": "probe-required",
            "notes": "Richest hook model. MCP tools appear as mcp__server__tool. HTTP hook failures non-blocking; command hooks enforce per D-005/006.",
        },
        "codex": {
            "version_baseline": "26.417.41555 (1858)",
            "supports": {
                "mcp_stdio": True,
                "mcp_streamable_http": "probe-required",
                "structured_output_schemas": True,
                "resources": "probe-required",
                "prompts": "probe-required",
                "elicitation_form": "probe-required",
                "elicitation_url": "probe-required",
                "subagent_tool_scoping": "inherits-parent",
                "hooks_pre_tool_use": "advisory-only-bash",
                "hooks_post_tool_use": "advisory-only-bash",
                "hooks_permission_request": True,
                "profiles": "experimental-cli-only",
            },
            "client_info_populated": "probe-required",
            "notes": "Hooks Bash-only per D-007. Profiles CLI-only, not IDE extension.",
        },
        "cursor": {
            "supports": {
                "mcp_stdio": True,
                "mcp_streamable_http": "probe-required",
                "project_scope_mcp": True,
                "resources": "probe-required",
                "prompts": "probe-required",
                "elicitation_form": "probe-required",
                "hooks": False,
            },
            "client_info_populated": "probe-required",
            "notes": "Project .cursor/mcp.json + .cursor/rules/*.mdc. No hook lifecycle.",
        },
        "windsurf": {
            "supports": {
                "mcp_stdio": True,
                "mcp_streamable_http": True,
                "project_scope_mcp": False,
                "resources": "probe-required",
                "prompts": "probe-required",
                "elicitation_form": "probe-required",
                "oauth_2_1_pkce": True,
                "agents_skills_discovery": True,
                "hooks": False,
            },
            "client_info_populated": "probe-required",
            "notes": "No project-scope MCP. Reads .agents/skills/ per Windsurf docs.",
        },
        "copilot-cli": {
            "supports": {
                "mcp_stdio": "probe-required",
                "mcp_streamable_http": "probe-required",
                "project_scope_mcp": True,
                "builtin_github_mcp": True,
                "hooks": False,
            },
            "client_info_populated": "probe-required",
            "notes": "Ships builtin github MCP; sync-mcp.sh skips github-mcp write.",
        },
        "claude-desktop": {
            "supports": {
                "mcp_stdio": True,
                "mcp_streamable_http": True,
                "resources": "probe-required",
                "prompts": "probe-required",
                "elicitation_form": "probe-required",
                "hooks": False,
            },
            "client_info_populated": "probe-required",
            "notes": "User-scope config at ~/Library/Application Support/Claude/. TCC may gate session-dir access.",
        },
    },
    "probe_plan": "During Phase 1 Thread B, connect each host to a throwaway MCP server that echoes clientInfo, capability negotiation, and primitive test results to .logs/phase-0/probe/<host>.json. All probe-required fields become measurable at that point.",
}

with open(out_path, 'w') as f:
    json.dump(data, f, indent=2)
PYEOF

echo "  ✓ protocol-features.json written (6 hosts; probe-required fields marked)"
echo "  → $out_path"
