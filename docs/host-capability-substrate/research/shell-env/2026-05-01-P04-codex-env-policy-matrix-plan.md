---
title: P04 Codex Env Policy Matrix Plan
category: research
component: host_capability_substrate
status: operation-plan
version: 1.0.0
last_updated: 2026-05-01
tags: [phase-1, p04, codex, shell-environment-policy, include-only, execution-context, operation-proof]
priority: high
---

# P04 Codex Env Policy Matrix Plan

This memo advances P04 from an open runtime question to an operation-proofed
probe packet. It is not runtime evidence for Codex CLI, app, or IDE behavior.
It defines the env-vector, candidate config variants, probe contract, and
approval gates for real surface rows.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-05-01T03:49Z |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| macOS | `26.4.1`, build `25E253` |
| bash | `/bin/bash`, `3.2.57(1)-release` |
| python | `Python 3.13.13` |
| Codex CLI | `codex-cli 0.128.0`; above baseline `0.125.0` |
| Packet helper | `scripts/dev/prepare-codex-env-policy-matrix.sh` |
| Verification recipe | `just codex-env-policy-probe-fixture` |

## Scope

The packet helper creates:

- candidate `.codex/config.toml` variants for
  `shell_environment_policy.include_only`
- `probe-p04-env-policy.py`, which reports marker presence only
- `env-vector.json`, which records marker names and classes without values

Default packet output is under `.logs/phase-1/shell-env/<date>/` and remains
gitignored. Fixture mode uses a temporary directory and proves that the probe
does not print marker values.

The helper does not:

- launch Codex CLI, Codex app, or an IDE extension
- change user or project Codex profiles
- call a model or require network
- inspect broad environment output
- treat candidate config syntax as runtime evidence

## Matrix Dimensions

Each future runtime row should record:

| Dimension | Values |
|---|---|
| Surface | `codex_cli`, `codex_app`, `codex_ide_ext`, or a more precise observed surface |
| Launch origin | `terminal`, `finder`, `dock`, `ide_ui`, `terminal_proxy`, `unknown` |
| Config variant | `inherit-all-default-filter`, `inherit-all-ignore-default-excludes`, `inherit-none-set-only` |
| Marker class | `plain_parent_env`, `secret_shaped_parent_env_synthetic`, `include_only_parent_env`, `config_set_value` |
| Evidence kind | `existence_only` |

The row output must be a names/presence truth table. Synthetic marker values
must never be persisted.

## Operation Proofs

### Operation
Prepare P04 Codex env-policy probe packet

### Host context
- OS: macOS 26.4.1 25E253
- cwd: `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate`
- Workspace: `host-capability-substrate`
- Shell mode: non_interactive
- Resolved tool: `/bin/bash@3.2.57(1)-release`, `python3@3.13.13`

### Evidence
- Source: `scripts/dev/prepare-codex-env-policy-matrix.sh --fixture`; `docs/host-capability-substrate/shell-environment-research.md` v2.9.0 P04
- Observed at: 2026-05-01T03:49Z
- Parser version: p04-codex-env-policy-probe.v1
- Cache status: miss
- Confidence: high for packet generation; no Codex runtime claim

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "/bin/bash",
  "argv": ["/bin/bash", "scripts/dev/prepare-codex-env-policy-matrix.sh"],
  "env_profile_id": "none",
  "lane": "preview"
}
```

### Risk
- Mutation scope: write-local
- Target resources: `.logs/phase-1/shell-env/<date>/p04-codex-env-policy-*`
- Policy tier: not available: substrate policy classifier is not implemented in this repo yet

### Preflight
`just codex-env-policy-probe-fixture`

### Preview
Creates a gitignored packet containing candidate config variants, the probe
script, an env-vector manifest, and local instructions. It does not launch
Codex, edit profiles, or require network.

### Rollback
Remove the generated packet under `.logs/phase-1/shell-env/**` only after
confirming it is not load-bearing evidence.

### Verification
The fixture validates that probe output reports marker presence and does not
include synthetic marker values.

### Operation
Run P04 Codex CLI env-policy runtime row

### Host context
- OS: macOS 26.4.1 25E253
- cwd: selected synthetic packet variant
- Workspace: `host-capability-substrate` synthetic packet
- Shell mode: interactive or non_interactive, depending on selected Codex CLI path
- Resolved tool: `codex@0.128.0`

### Evidence
- Source: this operation plan and Codex CLI version output
- Observed at: not available: runtime probe has not run
- Parser version: p04-codex-env-policy-probe.v1
- Cache status: miss
- Confidence: best-effort until the exact CLI invocation and config-loading path are resolved

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
- Mutation scope: none to write-local, depending on Codex CLI session artifacts
- Target resources: synthetic packet project, selected Codex CLI session, ignored `.logs/phase-1/shell-env/**` observation file
- Policy tier: not available: substrate policy classifier is not implemented in this repo yet

### Preflight
Resolve a non-network or explicitly approved Codex CLI observation path that can
run `probe-p04-env-policy.py` in the selected variant without exposing marker
values. Confirm config loading from `.codex/config.toml` in that synthetic
project. Do not infer behavior from config syntax alone.

### Preview
Expected output is one JSON line with marker names and presence booleans only.
The output must not contain marker values.

### Rollback
Remove ignored local packet/session artifacts only after confirming they are
not load-bearing evidence. Do not change global Codex config without a separate
plan.

### Verification
Curated P04 memo records the selected Codex CLI version, config variant, launch
origin, and marker presence booleans.

### Operation
Run P04 Codex app or IDE env-policy runtime row

### Host context
- OS: macOS 26.4.1 25E253
- cwd: selected synthetic packet variant
- Workspace: `host-capability-substrate` synthetic packet
- Shell mode: interactive GUI or IDE-controlled
- Resolved tool: not available: selected app/IDE surface is not resolved yet

### Evidence
- Source: this operation plan and P13/P09 GUI guardrails
- Observed at: not available: runtime probe has not run
- Parser version: p04-codex-env-policy-probe.v1
- Cache status: miss
- Confidence: best-effort until app/IDE launch mechanics are resolved

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
- Mutation scope: none unless selected app/IDE writes session state
- Target resources: selected GUI/IDE app state, synthetic packet project, ignored `.logs/phase-1/shell-env/**`
- Policy tier: not available: substrate policy classifier is not implemented in this repo yet

### Preflight
Resolve the exact app/IDE surface, version, launch origin, project trust state,
and observation path. Get explicit human approval for the GUI/IDE turn. Confirm
the probe command is `probe-p04-env-policy.py` only and does not use broad
`env`, `printenv`, or secret-value output.

### Preview
Expected output is one JSON line per config variant with marker names and
presence booleans only.

### Rollback
Quit or reset the selected GUI/IDE session only with human approval. Preserve
the observation file until it is classified as non-load-bearing evidence.

### Verification
Curated P04 memo distinguishes CLI, app, and IDE behavior. Any divergence from
the documented `shell_environment_policy` order is preserved as observed
runtime evidence rather than normalized away.

## Current Result

`just codex-env-policy-probe-fixture` validates the packet/probe redaction
contract. Codex CLI/app/IDE runtime rows remain pending explicit approval and a
selected observation path.
