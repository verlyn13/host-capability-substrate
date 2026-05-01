---
title: P09 Direnv/Mise Baseline
category: research
component: host_capability_substrate
status: baseline-fixture
version: 1.0.0
last_updated: 2026-04-30
tags: [phase-1, p09, direnv, mise, env, execution-context, fixture]
priority: high
---

# P09 Direnv/Mise Baseline

Non-mutating baseline fixture for shell/environment research prompt P09:
direnv + mise cross-surface visibility.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-30 |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| direnv | `2.37.1` |
| mise | `2026.4.27 macos-arm64` |
| Fixture | `scripts/dev/run-direnv-mise-fixture.sh` |
| Verification recipe | `just direnv-mise-fixture` |

## Scope

This fixture intentionally does **not** run `direnv allow`, does **not** run
`mise trust`, does **not** launch GUI apps, and does **not** write to host-level
direnv/mise trust databases. It creates an isolated synthetic project under a
temporary directory with:

- `.envrc` exporting `HCS_DIRENV_MARKER`
- `.mise.toml` defining `[env] HCS_MISE_MARKER`

All tool invocations use sanitized process environments plus temporary
`HOME`, `DIRENV_CONFIG`, and `MISE_*` state directories.

## Observed Baseline

- A plain noninteractive process in the synthetic project does not see either
  marker.
- `direnv export json` reports the synthetic `.envrc` as blocked before allow.
- `mise env --json` reports the synthetic `.mise.toml` as not trusted before
  trust.
- Neither tool output exposes the marker names or marker values before allow or
  trust.

## Interpretation

The baseline confirms HCS should not assume `.envrc` or `.mise.toml` values are
visible merely because a process starts in a workspace. Visibility depends on
the execution context and on an explicit direnv/mise trust or activation path.

This is not the full P09 matrix. The remaining P09 work is to run explicit,
operation-proofed tests for allowed/trusted terminal surfaces and any GUI/IDE
surfaces selected for the Phase 1 matrix.

## Validation

`just direnv-mise-fixture` passed on 2026-04-30.
