---
title: Phase 1 Shell Environment Handoff
category: handoff
component: host_capability_substrate
status: current
version: 1.0.0
last_updated: 2026-04-26
tags: [phase-1, shell-env, handoff, agent-context]
priority: high
---

# Phase 1 Shell Environment Handoff

Handoff for the next agent after the 2026-04-26 Phase 0b closeout and same-day
Phase 1 shell/environment prep work.

## Current State

| Field | Value |
|---|---|
| Observed at | 2026-04-26T22:20:55Z |
| Local time | 2026-04-26 14:20:55 AKDT |
| Branch | `main` |
| Pre-handoff tip | `c73e815 docs: record shell logger host install` |
| Validation | `just verify` passed after the P06 host-install documentation update |
| Worktree expectation | Clean after this handoff commit |

## Relevant Commits

| Commit | Summary |
|---|---|
| `57de4fd` | Added semantic redundancy measurement map and fixture. |
| `00ee3ba` | Added advisory trap scanner catch-up and fixture coverage. |
| `169774b` | Added Phase 1 shell/env direct-test runbook. |
| `c73d034` | Captured initial P13 Codex app bundle/signing evidence. |
| `1fe0b1e` | Captured P01 Codex auth metadata. |
| `62f5579` | Captured P05 Claude Desktop auth-boundary metadata. |
| `478301d` | Captured initial P02 terminal `open -n` proxy failure. |
| `aa76aa0` | Validated true P02 Finder-origin GUI cold-start absence. |
| `6c3f7e0` | Extended P13 with Codex app process sandbox flag evidence. |
| `c50e201` | Added redaction-safe P06 shell wrapper and fixture. |
| `c73e815` | Recorded approved host install of `/usr/local/bin/hcs-shell-logger`. |

## Shell/Environment Prompt Status

| Prompt | Status | Artifact | Next action |
|---|---|---|---|
| P01 Codex auth metadata | Partial | `docs/host-capability-substrate/research/shell-env/2026-04-26-P01-codex-auth-metadata.md` | Do not migrate MCP auth off env/PAT patterns until interactive OAuth + restart check passes. |
| P02 GUI env inheritance | Validated locally | `docs/host-capability-substrate/research/shell-env/2026-04-26-P02-codex-app-gui-launch-env.md` | Treat Finder-origin cold launch as not inheriting terminal-only markers. Retest on Codex app upgrade. |
| P05 Claude Desktop auth boundary | Partial | `docs/host-capability-substrate/research/shell-env/2026-04-26-P05-claude-desktop-auth-boundary.md` | GUI runtime smoke remains open; use synthetic marker names only. |
| P06 shell wrapper logging | Prep complete, host install complete | `docs/host-capability-substrate/research/shell-env/2026-04-26-P06-shell-wrapper-logger-prep.md` | Live routing of selected surfaces still needs separate approval. |
| P13 Codex app sandbox | Partial | `docs/host-capability-substrate/research/shell-env/2026-04-26-P13-codex-app-bundle-signing.md` | App-internal Keychain/filesystem/network status-code probes remain open. |

## Host State Outside Repo

- `/usr/local/bin/hcs-shell-logger` is installed, mode `0755`, owner
  `root:wheel`.
- Installed wrapper matches `scripts/dev/hcs-shell-logger.sh` by byte compare.
- SHA-256 for both files:
  `5321eb6f3a22a04a4863c14826a71d558a0034c399269b4f8e80a7a247670847`.
- No live agent surface has been routed through the wrapper yet.
- Raw P02 JSONL evidence was written under `.logs/phase-1/shell-env/2026-04-26/`;
  `.logs/` is intentionally ignored and not part of the committed handoff.

## Open Next Steps

1. Decide whether to run live P06 routing. This is a host-affecting operation
   and needs action-time approval. Use `/usr/local/bin/hcs-shell-logger` and
   keep logs redaction-only.
2. Resolve P05 GUI runtime smoke without real Anthropic credential variables.
3. Design P13 app-internal probes that report status codes only for Keychain,
   filesystem, and network checks.
4. Begin Wave 2 only after Wave 1 decisions are accepted: P04
   `shell_environment_policy.include_only`, P03 MCP startup vs setup ordering,
   P08 provenance snapshot, and P09 direnv/mise matrix.
5. Claude Code #18692 remains blocked until local Claude Code is updated from
   `2.1.119` to the target `2.1.120` or newer.

## Guardrails For The Next Agent

- Target ring for these artifacts is Ring 3 measurement/research docs plus dev
  fixtures; do not introduce Ring 0 schema or policy changes without the
  matching ADR.
- Do not read or persist secret values. Use existence-only, name-only, hashed,
  or classified outputs.
- Do not treat process argv as safe to paste wholesale. Trap #37 exists because
  argv can carry secret material.
- Do not route live shells through the P06 wrapper without an operation proof
  and explicit action-time approval.
- Run `just verify` before committing.

## Verification Notes

Expected soft skips remain:

- Biome not installed.
- `tsc` not installed.
- Unit tests are still Phase 0a scaffold/noop.
- Schema drift is noop while `packages/schemas/src` is empty.

Expected fixture output includes:

- semantic redundancy fixture pass
- trap fixture pass with advisory hits for
  `process-argv-secret-exposure` and
  `cloudflare-mcp-mutation-without-fanout-check`
- shell logger fixture pass

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-04-26 | Initial next-agent handoff after P01/P02/P05/P06/P13 prep. |
