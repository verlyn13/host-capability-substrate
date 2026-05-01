---
title: P09 Direnv/Mise Terminal Matrix
category: research
component: host_capability_substrate
status: terminal-fixture
version: 1.0.0
last_updated: 2026-04-30
tags: [phase-1, p09, direnv, mise, env, execution-context, fixture]
priority: high
---

# P09 Direnv/Mise Terminal Matrix

Isolated terminal-surface fixture for shell/environment research prompt P09:
direnv + mise marker visibility after explicit allow/trust.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-30 |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| direnv | `2.37.1` |
| mise | `2026.4.27 macos-arm64` |
| Fixture | `scripts/dev/run-direnv-mise-terminal-fixture.sh` |
| Verification recipe | `just direnv-mise-terminal-fixture` |

## Scope

This fixture uses a synthetic temp project with `.envrc` and `.mise.toml`
marker declarations. It runs `direnv allow` and `mise trust` only with temporary
`HOME`, `DIRENV_CONFIG`, `XDG_CONFIG_HOME`, `MISE_DATA_DIR`, `MISE_CACHE_DIR`,
and `MISE_STATE_DIR` paths. The fixture deletes the entire temp tree on exit.

It does **not** use the real user direnv or mise trust stores, does **not**
launch GUI apps, and does **not** write to system-config or HCS runtime state.

## Observed Result

- After isolated `direnv allow`, a `direnv exec` terminal-style subprocess sees
  `HCS_DIRENV_MARKER`.
- After isolated `mise trust`, a `mise exec --no-deps` terminal-style
  subprocess sees `HCS_MISE_MARKER`.
- The fixture output records only marker presence and value-match booleans.
- The synthetic marker values are not emitted in fixture output.

## Interpretation

P09 now has two terminal fixtures:

- blocked/untrusted baseline: no marker visibility before allow/trust
- isolated allowed/trusted terminal surface: marker visibility after allow/trust

This supports the Phase 1 conclusion that direnv/mise visibility is not a
workspace fact. It is an execution-context fact controlled by trust/activation
state and launch surface.

The remaining P09 work is GUI/IDE coverage. Those probes require separate
operation proofs because launch origin and app state are material to the
evidence.

## Validation

`just direnv-mise-terminal-fixture` passed on 2026-04-30.
