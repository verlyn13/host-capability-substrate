---
title: P08 Provenance Snapshot
category: research
component: host_capability_substrate
status: fixture
version: 1.0.0
last_updated: 2026-04-30
tags: [phase-1, p08, provenance, env, execution-context, fixture]
priority: high
---

# P08 Provenance Snapshot

Fixture evidence for shell/environment research prompt P08: provenance of
`PATH`, `SHELL`, `HOME`, `PWD`, `TMPDIR`, and `CODEX_HOME`.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-30T22:26:55Z |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| Surface | `codex_cli_tool_call_subprocess` |
| Authority | `sandbox-observation` |
| Fixture | `packages/fixtures/provenance-snapshot-2026-04-30.json` |
| Capture helper | `scripts/dev/capture-provenance-snapshot.py` |
| Verification recipe | `just provenance-snapshot-fixture` |

## Snapshot Scope

This is a golden regression fixture for the current Codex CLI tool-call
subprocess, not host-authoritative evidence. Per charter invariant 8, the
snapshot keeps `authority: sandbox-observation` and `confidence: best-effort`.

Captured variables:

- `PATH`
- `SHELL`
- `HOME`
- `PWD`
- `TMPDIR`
- `CODEX_HOME`

Values are allowed only for these P08 target variables. The capture helper
includes a secret-shaped value guard; if a selected value unexpectedly matches
known token/key patterns, it emits only the hash and redaction status.

## Observed Result

- `PATH`, `SHELL`, `HOME`, `PWD`, and `TMPDIR` were present.
- `CODEX_HOME` was not set in this tool-call process.
- `PWD` matched `getcwd()`.
- `PATH` included Codex runtime entries, mise-managed tool entries, Homebrew,
  and system paths.

## Validation

`scripts/dev/run-provenance-snapshot-fixture.sh` validates both the committed
fixture and a freshly generated temporary snapshot. It checks:

- target variables are exactly the P08 set and in stable order
- authority remains `sandbox-observation`
- record confidence remains `best-effort`
- emitted values match their SHA-256 hashes
- `PATH` entries match the serialized `PATH` value
- absent variables do not emit value material
- emitted values do not match known secret-shaped patterns

`just provenance-snapshot-fixture` passed on 2026-04-30.
