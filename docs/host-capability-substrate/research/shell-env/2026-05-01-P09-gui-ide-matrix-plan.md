---
title: P09 Direnv/Mise GUI IDE Matrix Plan
category: research
component: host_capability_substrate
status: operation-plan
version: 1.0.0
last_updated: 2026-05-01
tags: [phase-1, p09, direnv, mise, gui, ide, execution-context, operation-proof]
priority: high
---

# P09 Direnv/Mise GUI IDE Matrix Plan

This memo advances P09 from terminal-only coverage to an operation-proofed
GUI/IDE packet. It is not runtime evidence for GUI or IDE surfaces. It defines
the probe contract and the approvals needed before those surfaces are touched.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-05-01T03:14Z |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| macOS | `26.4.1`, build `25E253` |
| bash | `/bin/bash`, `3.2.57(1)-release` |
| python | `Python 3.13.13` |
| direnv | `2.37.1` |
| mise | `2026.4.27 macos-arm64 (2026-04-29)` |
| Packet helper | `scripts/dev/prepare-direnv-mise-gui-matrix.sh` |
| Verification recipe | `just direnv-mise-gui-probe-fixture` |

## Scope

The packet helper creates a synthetic project with:

- `.envrc` declaring `HCS_DIRENV_MARKER`
- `.mise.toml` declaring `HCS_MISE_MARKER`
- `probe-p09-env.py`, which reports marker presence only

Default packet output is under `.logs/phase-1/shell-env/<date>/` and remains
gitignored. Fixture mode uses a temporary directory and proves that the probe
does not print marker values.

The helper does not:

- launch a GUI app or IDE
- run `direnv allow`
- run `mise trust`
- write to real direnv or mise trust stores
- inspect broad environment output

## Matrix Dimensions

Each future runtime row should record:

| Dimension | Values |
|---|---|
| Surface | `codex_app`, `codex_ide_ext`, `claude_code_ide_ext`, `zed_external_agent`, or a more precise observed surface |
| Launch origin | `finder`, `dock`, `ide_ui`, `terminal_proxy`, `unknown` |
| Activation mode | `plain_subprocess`, `direnv_exec`, `mise_exec`, `agent_default` |
| Trust mode | `blocked_untrusted`, `isolated_allowed_trusted`, `real_user_trust_store` |
| Evidence kind | `existence_only` |

Do not collapse terminal, GUI app, IDE extension, and MCP server results into
one workspace fact. P09 remains an `ExecutionContext` observation.

## Operation Proofs

### Operation
Prepare P09 GUI/IDE probe packet

### Host context
- OS: macOS 26.4.1 25E253
- cwd: `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate`
- Workspace: `host-capability-substrate`
- Shell mode: non_interactive
- Resolved tool: `/bin/bash@3.2.57(1)-release`, `python3@3.13.13`

### Evidence
- Source: `scripts/dev/prepare-direnv-mise-gui-matrix.sh --fixture`; `docs/host-capability-substrate/shell-environment-research.md` v2.8.0 P09
- Observed at: 2026-05-01T03:14Z
- Parser version: p09-gui-ide-probe.v1
- Cache status: miss
- Confidence: high for packet generation; no GUI/IDE runtime claim

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "/bin/bash",
  "argv": ["/bin/bash", "scripts/dev/prepare-direnv-mise-gui-matrix.sh"],
  "env_profile_id": "none",
  "lane": "preview"
}
```

### Risk
- Mutation scope: write-local
- Target resources: `.logs/phase-1/shell-env/<date>/p09-gui-ide-matrix-*`
- Policy tier: not available: substrate policy classifier is not implemented in this repo yet

### Preflight
`just direnv-mise-gui-probe-fixture`

### Preview
Creates a gitignored packet containing marker declarations, the probe script,
and local instructions. It does not launch GUI apps, run `direnv allow`, or run
`mise trust`.

### Rollback
Remove the generated packet under `.logs/phase-1/shell-env/**` only after
confirming it is not load-bearing evidence.

### Verification
The fixture validates that probe output reports marker presence and does not
include synthetic marker values.

### Operation
Run P09 GUI/IDE plain-subprocess probe

### Host context
- OS: macOS 26.4.1 25E253
- cwd: selected synthetic packet project
- Workspace: `host-capability-substrate` synthetic packet
- Shell mode: interactive
- Resolved tool: not available: selected GUI or IDE surface is not resolved yet

### Evidence
- Source: P09 terminal fixtures and this operation plan
- Observed at: not available: runtime probe has not run
- Parser version: p09-gui-ide-probe.v1
- Cache status: miss
- Confidence: best-effort until the selected GUI or IDE surface is resolved

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
- Mutation scope: none unless the selected app or IDE writes session state
- Target resources: selected GUI/IDE app session, synthetic packet project, ignored `.logs/phase-1/shell-env/**` observation file
- Policy tier: not available: substrate policy classifier is not implemented in this repo yet

### Preflight
Resolve the exact app/IDE surface, version, launch origin, and observation path.
Get explicit human approval for the GUI/IDE turn. Confirm the probe command is
`probe-p09-env.py` only and does not use broad `env` or `printenv`.

### Preview
Expected output is one JSON line with marker names and presence booleans only.
The output must not contain marker values.

### Rollback
Quit or reset the selected GUI/IDE session only with human approval. Preserve
the observation file until it is classified as non-load-bearing evidence.

### Verification
Curated P09 memo records the selected surface, launch origin, activation mode,
trust mode, and presence booleans.

### Operation
Run P09 GUI/IDE direnv allow or mise trust path

### Host context
- OS: macOS 26.4.1 25E253
- cwd: selected synthetic packet project
- Workspace: `host-capability-substrate` synthetic packet
- Shell mode: interactive
- Resolved tool: `direnv@2.37.1`, `mise@2026.4.27`; GUI/IDE surface not resolved yet

### Evidence
- Source: `2026-04-30-P09-direnv-mise-terminal-matrix.md`; this operation plan
- Observed at: not available: GUI/IDE trust-path probe has not run
- Parser version: p09-gui-ide-probe.v1
- Cache status: miss
- Confidence: best-effort until trust-store and GUI/IDE launch mechanics are resolved

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
- Mutation scope: write-host unless isolated direnv/mise state is proven for the selected GUI/IDE launch
- Target resources: direnv allow store, mise trust store, selected GUI/IDE app state, ignored `.logs/phase-1/shell-env/**`
- Policy tier: not available: substrate policy classifier is not implemented in this repo yet

### Preflight
Choose one trust strategy: isolated temp `HOME`/`DIRENV_CONFIG`/`MISE_*` state
for the GUI/IDE launch, or explicit human approval for writes to real user
trust stores. Without that choice, this operation is not ready.

### Preview
Expected output is one JSON line per activation mode with marker names and
presence booleans only.

### Rollback
For isolated state, remove the temp tree after confirming evidence is no longer
load-bearing. For real user trust stores, rollback is not available without a
separate audited cleanup plan.

### Verification
Curated P09 memo distinguishes blocked/untrusted, isolated allowed/trusted, and
real-user-trust-store observations by surface and launch origin.

## Current Result

`just direnv-mise-gui-probe-fixture` validates the packet/probe redaction
contract. GUI and IDE runtime rows remain pending explicit approval and a
selected observation path.
