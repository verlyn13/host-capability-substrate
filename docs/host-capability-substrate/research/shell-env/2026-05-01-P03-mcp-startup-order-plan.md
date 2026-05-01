---
title: P03 MCP Startup Order Plan
category: research
component: host_capability_substrate
status: operation-plan
version: 1.0.0
last_updated: 2026-05-01
tags: [phase-1, p03, codex, mcp, setup-script, startup-order, execution-context, operation-proof]
priority: high
---

# P03 MCP Startup Order Plan

This memo advances P03 from an open runtime question to an operation-proofed
probe packet. It is not runtime evidence for Codex app, CLI, or IDE startup
ordering. It defines the setup-script marker, MCP startup logger, sequence log,
and approval gates for real surface rows.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-05-01T03:49Z |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| macOS | `26.4.1`, build `25E253` |
| bash | `/bin/bash`, `3.2.57(1)-release` |
| python | `Python 3.13.13` |
| Codex CLI | `codex-cli 0.128.0`; above baseline `0.125.0` |
| Packet helper | `scripts/dev/prepare-codex-mcp-startup-order.sh` |
| Verification recipe | `just codex-mcp-startup-probe-fixture` |

## Scope

The packet helper creates:

- a candidate Codex app local-environment setup script
- a candidate `.codex/config.toml` with a stdio startup logger and disabled
  HTTP bearer placeholder
- `mcp-startup-logger.py`, which records startup and marker presence only
- `sequence.jsonl`, the intended ignored observation log

Default packet output is under `.logs/phase-1/shell-env/<date>/` and remains
gitignored. Fixture mode uses a temporary directory and proves that the setup
script and logger write only marker names and presence booleans.

The helper does not:

- launch Codex CLI, Codex app, or an IDE extension
- set `launchctl` environment variables
- bind localhost ports
- enable the HTTP bearer-token placeholder
- put real credentials in `HCS_BEARER_FAKE`
- treat setup-script/MCP order as measured runtime evidence

## Matrix Dimensions

Each future runtime row should record:

| Dimension | Values |
|---|---|
| Surface | `codex_app`, `codex_cli`, `codex_ide_ext`, or a more precise observed surface |
| Launch origin | `finder`, `dock`, `terminal`, `ide_ui`, `terminal_proxy`, `unknown` |
| Credential path | `setup_script_export`, `pre_session_env`, `launchd_user_session`, `none` |
| MCP path | `stdio_startup_logger`, `http_bearer_placeholder_with_capture` |
| Evidence kind | `existence_only` plus event timestamps |

Do not promote the packet fixture to an ordering claim. The fixture runs setup
then logger in a controlled local sequence only to prove the redaction contract.

## Operation Proofs

### Operation
Prepare P03 MCP startup-order probe packet

### Host context
- OS: macOS 26.4.1 25E253
- cwd: `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate`
- Workspace: `host-capability-substrate`
- Shell mode: non_interactive
- Resolved tool: `/bin/bash@3.2.57(1)-release`, `python3@3.13.13`

### Evidence
- Source: `scripts/dev/prepare-codex-mcp-startup-order.sh --fixture`; `docs/host-capability-substrate/shell-environment-research.md` v2.10.0 P03
- Observed at: 2026-05-01T03:49Z
- Parser version: p03-startup-order-event.v1
- Cache status: miss
- Confidence: high for packet generation; no Codex runtime ordering claim

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "/bin/bash",
  "argv": ["/bin/bash", "scripts/dev/prepare-codex-mcp-startup-order.sh"],
  "env_profile_id": "none",
  "lane": "preview"
}
```

### Risk
- Mutation scope: write-local
- Target resources: `.logs/phase-1/shell-env/<date>/p03-mcp-startup-order-*`
- Policy tier: not available: substrate policy classifier is not implemented in this repo yet

### Preflight
`just codex-mcp-startup-probe-fixture`

### Preview
Creates a gitignored packet containing candidate setup/config files, an MCP
startup logger, and instructions. It does not launch Codex, set launchd env,
or enable the HTTP bearer-token placeholder.

### Rollback
Remove the generated packet under `.logs/phase-1/shell-env/**` only after
confirming it is not load-bearing evidence.

### Verification
The fixture validates that sequence records contain marker names and presence
booleans without synthetic marker values.

### Operation
Run P03 Codex app startup-order runtime row

### Host context
- OS: macOS 26.4.1 25E253
- cwd: selected synthetic packet project
- Workspace: `host-capability-substrate` synthetic packet
- Shell mode: interactive GUI
- Resolved tool: not available: Codex app launch/control path is not resolved yet

### Evidence
- Source: this operation plan and shell research P03
- Observed at: not available: runtime probe has not run
- Parser version: p03-startup-order-event.v1
- Cache status: miss
- Confidence: best-effort until the Codex app control path and project trust state are resolved

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "not-ready",
  "argv": [],
  "env_profile_id": "synthetic-marker-only",
  "lane": "interactive"
}
```

### Risk
- Mutation scope: none unless selected Codex app path writes session or project trust state
- Target resources: selected Codex app session, synthetic packet project, ignored `.logs/phase-1/shell-env/**`
- Policy tier: not available: substrate policy classifier is not implemented in this repo yet

### Preflight
Resolve exact Codex app version, launch origin, project trust state, and
observation path. Get explicit human approval for the app turn. Confirm that
`HCS_BEARER_FAKE` is synthetic and that only `sequence.jsonl` records marker
presence booleans.

### Preview
Expected output is a JSONL sequence with setup-script and MCP-startup records.
Ordering and marker presence determine whether setup-script exports are
available before MCP startup for the selected surface.

### Rollback
Quit/reset the selected Codex app session only with human approval. Preserve
the observation file until it is classified as non-load-bearing evidence.

### Verification
Curated P03 memo records surface, launch origin, project trust state, event
order, marker presence booleans, and whether the HTTP bearer-token row was run.

### Operation
Run P03 launchd pre-session env comparison row

### Host context
- OS: macOS 26.4.1 25E253
- cwd: selected synthetic packet project
- Workspace: `host-capability-substrate` synthetic packet
- Shell mode: interactive GUI plus host env setup
- Resolved tool: not available: launchd env operation is not approved

### Evidence
- Source: this operation plan and shell research P03
- Observed at: not available: runtime probe has not run
- Parser version: p03-startup-order-event.v1
- Cache status: miss
- Confidence: best-effort until launchd operation proof is approved

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "not-ready",
  "argv": [],
  "env_profile_id": "synthetic-marker-only",
  "lane": "interactive"
}
```

### Risk
- Mutation scope: write-host
- Target resources: per-user launchd environment, selected Codex app session, ignored `.logs/phase-1/shell-env/**`
- Policy tier: not available: substrate policy classifier is not implemented in this repo yet

### Preflight
Requires a separate launchd env operation proof with explicit set/unset values,
approval, and rollback. Do not use real credentials or secret-shaped values.

### Preview
Expected output compares `pre_session_env` against `setup_script_export` without
printing marker values.

### Rollback
Unset any launchd synthetic marker with an approved rollback command and restart
affected app sessions only with human approval.

### Verification
Curated P03 memo records whether pre-session env reaches MCP startup separately
from setup-script exports.

## Current Result

`just codex-mcp-startup-probe-fixture` validates the packet/probe redaction
contract. Runtime startup-order rows remain pending explicit approval and a
selected Codex observation path.
