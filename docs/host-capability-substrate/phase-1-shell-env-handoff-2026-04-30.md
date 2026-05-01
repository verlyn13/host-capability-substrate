---
title: Phase 1 Shell Environment Handoff
category: handoff
component: host_capability_substrate
status: current
version: 1.4.0
last_updated: 2026-05-01
tags: [phase-1, shell-env, handoff, agent-context, fixtures]
priority: high
---

# Phase 1 Shell Environment Handoff

Current handoff after P08/P09/P11/P12 implementation work through the
2026-05-01 P11 commit. This supersedes
`phase-1-shell-env-handoff-2026-04-26.md`.

## Current State

| Field | Value |
|---|---|
| Observed at | 2026-05-01T03:14Z |
| Branch | `main` |
| Current HEAD | `a4f6ee3 phase1: add launchagent env policy table` |
| Git relation | `main` five commits ahead of `origin/main` |
| Worktree expectation | Clean after the P11 commit; future work should start as a new scoped diff. |
| Validation | `just verify` passed for the P11 orientation update before commit. |

## Toolchain Snapshot

| Tool | Observed |
|---|---|
| macOS | `26.4.1`, build `25E253` |
| Node | `24.15.0` |
| npm | `11.12.1` |
| Codex CLI | `0.128.0`; above baseline `0.125.0`; `--version` printed a sandbox PATH warning but returned successfully |
| Claude Code CLI | `2.1.123`; above baseline `2.1.120` |
| mise-managed tools | `shellcheck 0.11.0`, `shfmt 3.13.1`, `just 1.50.0`, `bun 1.3.13`, `python 3.13.13`, `uv 0.11.8`, `pnpm 10.33.2` |

## Prompt Status

| Prompt | Status | Artifact / recipe |
|---|---|---|
| P01 Codex auth metadata | Migration blocked; keep GitHub MCP PAT/broker posture until a static-client/manual OAuth or broker decision lands. | `research/shell-env/2026-04-26-P01-codex-auth-metadata.md` |
| P02 GUI env inheritance | Finder-origin Codex app launch did not inherit terminal-only marker. | `research/shell-env/2026-04-26-P02-codex-app-gui-launch-env.md` |
| P05 Claude Desktop auth boundary | Runtime smoke complete. | `research/shell-env/2026-04-26-P05-claude-desktop-auth-boundary.md` |
| P06 shell provenance | Closed for Codex CLI and Claude Code CLI; app/IDE surfaces remain separate execution contexts. | `research/shell-env/2026-04-28-P06-host-telemetry-rerun.md`; `just shell-logger-fixture` |
| P08 provenance snapshot | Initial Codex CLI tool-call subprocess fixture landed. It is `authority: sandbox-observation`, not host-authoritative. | `packages/fixtures/provenance-snapshot-2026-04-30.json`; `just provenance-snapshot-fixture` |
| P09 direnv/mise visibility | Terminal fixtures landed for blocked/untrusted and isolated allowed/trusted paths; GUI/IDE matrix remains open. | `scripts/dev/run-direnv-mise-fixture.sh`; `scripts/dev/run-direnv-mise-terminal-fixture.sh`; `just direnv-mise-fixture`; `just direnv-mise-terminal-fixture` |
| P11 LaunchAgent env policy | Design memo landed; not an accepted ADR or live policy. | `research/shell-env/2026-04-30-P11-launchagent-env-policy-table.md` |
| P12 env inspection | Repo-local prototype landed for names-only, existence, classified, and hashed env inspection. | `scripts/dev/hcs-env-inspect.py`; `just env-inspect-fixture` |
| P13 Codex app sandbox | Open/narrowed; needs reachable GUI app-server control or human-run sterile Codex app UI probe. | `research/shell-env/2026-04-26-P13-codex-app-bundle-signing.md` |

## Recent Scope

Recent file categories across the P08/P09/P11/P12 pass:

- Ring 3 scripts/fixtures:
  `scripts/dev/hcs-env-inspect.py`,
  `scripts/dev/run-env-inspect-fixture.sh`,
  `scripts/dev/capture-provenance-snapshot.py`,
  `scripts/dev/run-provenance-snapshot-fixture.sh`,
  `scripts/dev/run-direnv-mise-fixture.sh`,
  `scripts/dev/run-direnv-mise-terminal-fixture.sh`,
  `packages/fixtures/provenance-snapshot-2026-04-30.json`.
- Validation wiring:
  `justfile`, `scripts/ci/verify.sh`.
- Orientation docs:
  `PLAN.md`, `shell-environment-research.md`,
  `phase-1-shell-env-direct-test-runbook.md`,
  `research/shell-env/README.md`,
  P08/P09/P11/P12 memos, and trap #18 notes.

No Ring 0 schema, Ring 1 kernel, Ring 2 adapter, live policy, hook, or runtime
state changes are part of this scope.

At this handoff, the P08/P12 commit, P09 baseline commit, P09 terminal matrix
commit, and P11 policy-table commit are already in `main`.

## Guardrails

- Keep `.logs/` as ignored but potentially load-bearing evidence; do not delete
  it because it is ignored.
- Do not use `printenv | grep`, `env | grep`, direct secret-variable echoes, or
  broad process argv dumps.
- Treat P08 snapshots as per-surface evidence. Do not reuse the Codex CLI
  tool-call snapshot for GUI app, IDE, Claude Desktop, or MCP server claims.
- Do not edit live policy from this repo. The canonical policy path remains in
  `system-config`, and that directory was not available in this session.
- Do not start P03/P04/P09 GUI or host-write probes without an operation proof
  and approval when they touch launchd, GUI app state, `direnv allow`, or
  `mise trust`.
- Do not treat the P11 memo as accepted LaunchAgent policy; it is synthesis
  input for a future ADR.

## Recommended Next Step

Continue P09 with an operation-proofed GUI/IDE matrix:

1. Keep marker reporting to presence/absence only.
2. Do not use terminal `open` as a clean GUI-origin proxy.
3. Use a human-run sterile app/IDE turn or a proven GUI control path.
4. Preserve the distinction between terminal, GUI app, IDE extension, and MCP
   server execution contexts.

## Validation Notes

The latest full gate passed:

```text
just verify
```

Focused checks that passed during the P08/P09/P12 work:

- `python3 -m py_compile scripts/dev/capture-provenance-snapshot.py scripts/dev/hcs-env-inspect.py`
- `just env-inspect-fixture`
- `just provenance-snapshot-fixture`
- `just direnv-mise-fixture`
- `just direnv-mise-terminal-fixture`
- `just shellcheck-scan`
- `just forbidden-string-scan`
- `git diff --check`

## Change Log

| Version | Date | Change |
|---|---:|---|
| 1.4.0 | 2026-05-01 | Refreshed handoff after the P11 commit and updated the current branch state. |
| 1.3.0 | 2026-04-30 | Added P11 design memo status and guardrail. |
| 1.2.0 | 2026-04-30 | Added P09 isolated allowed/trusted terminal fixture and moved next step to GUI/IDE matrix. |
| 1.1.0 | 2026-04-30 | Added P09 non-mutating direnv/mise baseline fixture and updated next step. |
| 1.0.0 | 2026-04-30 | Current handoff after P08/P12 prototype and fixture work. |
