---
title: HCS shell/environment research artifacts
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-30
tags: [research, shell-env, execution-context, provenance, credentials, fixtures]
priority: medium
---

# Shell/Environment Research Artifacts

This directory preserves curated Phase 1 shell/environment evidence. Raw local
evidence lives under `.logs/phase-1/shell-env/` and remains gitignored; commit
only redacted memos or golden fixtures.

## Status Discipline

- Treat CLI, GUI app, IDE extension, MCP server, subagent, and setup-script
  processes as separate `ExecutionContext` surfaces.
- Do not promote sandbox observations to host-authoritative evidence.
- Do not echo secret-shaped environment values. Use names-only,
  existence-only, classified, or hashed inspection.
- Terminal `open` launches are not clean GUI-origin proxies.
- Runtime version changes require re-baselining per charter invariant 14.

## Prompt Status

| Prompt | Current status | Primary artifact |
|---|---|---|
| P01 Codex auth metadata | Migration blocked; GitHub MCP dynamic registration unsupported. | `2026-04-26-P01-codex-auth-metadata.md` |
| P02 Codex GUI env inheritance | Validated locally for Finder-origin cold launch. | `2026-04-26-P02-codex-app-gui-launch-env.md` |
| P05 Claude Desktop auth boundary | Runtime smoke complete. | `2026-04-26-P05-claude-desktop-auth-boundary.md` |
| P06 Shell provenance | Closed for Codex CLI and Claude Code CLI; app/IDE surfaces remain separate. | `2026-04-28-P06-host-telemetry-rerun.md` |
| P08 Provenance snapshot | Initial Codex CLI tool-call fixture committed. | `2026-04-30-P08-provenance-snapshot.md` |
| P09 direnv/mise visibility | Non-mutating baseline fixture committed; allowed/trusted and GUI/IDE matrix remains. | `2026-04-30-P09-direnv-mise-baseline.md` |
| P12 Env inspection | Repo-local safe-inspection prototype committed. | `2026-04-30-P12-env-inspect-prototype.md` |
| P13 Codex app sandbox | Open/narrowed; needs GUI app-internal evidence. | `2026-04-26-P13-codex-app-bundle-signing.md` |

## Contents

| File | Date | Scope |
|---|---:|---|
| `2026-04-26-P01-codex-auth-metadata.md` | 2026-04-26 | Metadata-only Codex auth state and failed `codex mcp login github` migration attempt. |
| `2026-04-26-P02-codex-app-gui-launch-env.md` | 2026-04-26 | Terminal `open` proxy failure plus Finder-origin Codex app marker absence. |
| `2026-04-26-P05-claude-desktop-auth-boundary.md` | 2026-04-26 | Claude Desktop auth/config metadata and Finder-origin credential-env absence smoke. |
| `2026-04-26-P06-shell-wrapper-logger-prep.md` | 2026-04-26 | Redaction-safe shell wrapper, fixture, host install, and PATH-routing lessons. |
| `2026-04-26-P13-codex-app-bundle-signing.md` | 2026-04-26 | Codex app bundle/signing/process sandbox evidence and narrowed app-server probe status. |
| `2026-04-27-P06-provenance-experiment-plan.md` | 2026-04-27 | Three-lane P06 proof plan: tool-native trace, startup sentinels, host telemetry. |
| `2026-04-28-P06-host-telemetry-rerun.md` | 2026-04-28 | P06 closure evidence for Codex CLI and Claude Code CLI host telemetry. |
| `2026-04-28-iterm2-dynamic-profile-stale-symlink.md` | 2026-04-28 | iTerm2 dynamic profile stale-symlink observation. |
| `2026-04-30-P08-provenance-snapshot.md` | 2026-04-30 | Codex CLI tool-call subprocess provenance snapshot and fixture validation. |
| `2026-04-30-P09-direnv-mise-baseline.md` | 2026-04-30 | Non-mutating direnv/mise marker baseline with isolated temp config/state. |
| `2026-04-30-P12-env-inspect-prototype.md` | 2026-04-30 | Secret-safe env inspection prototype and fixture validation. |

## Fixture Hooks

| Recipe | Purpose |
|---|---|
| `just shell-logger-fixture` | P06 wrapper redaction and argv preservation. |
| `just provenance-snapshot-fixture` | P08 snapshot schema/redaction/hash validation. |
| `just direnv-mise-fixture` | P09 non-mutating blocked/untrusted marker baseline. |
| `just env-inspect-fixture` | P12 safe env inspection regression coverage. |

## Change Log

| Version | Date | Change |
|---|---:|---|
| 1.1.0 | 2026-04-30 | Added P09 non-mutating direnv/mise baseline fixture. |
| 1.0.0 | 2026-04-30 | Added shell/env research index and current prompt status. |
