---
title: Phase 1 Shell Environment Handoff
category: handoff
component: host_capability_substrate
status: current
version: 1.5.0
last_updated: 2026-04-27
tags: [phase-1, shell-env, handoff, agent-context]
priority: high
---

# Phase 1 Shell Environment Handoff

Handoff for the next agent after the 2026-04-26 Phase 0b closeout and same-day
Phase 1 shell/environment prep work.

## Current State

| Field | Value |
|---|---|
| Observed at | 2026-04-27T01:09:50Z |
| Local time | 2026-04-26 17:09:50 AKDT |
| Branch | `main` |
| Pre-handoff tip | `a4d936c docs: add phase 1 shell env handoff` |
| Validation | `just verify` passed after P06 provenance-plan ingestion at 2026-04-27T05:45:01Z |
| Worktree expectation | Contains P06 wrapper, provenance-plan, and documentation updates until committed |

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
| P01 Codex auth metadata | Migration blocked | `docs/host-capability-substrate/research/shell-env/2026-04-26-P01-codex-auth-metadata.md` | Codex account is logged in via ChatGPT, but `codex mcp login github` failed because dynamic client registration is unsupported; GitHub MCP still uses `GITHUB_PAT`. |
| P02 GUI env inheritance | Validated locally | `docs/host-capability-substrate/research/shell-env/2026-04-26-P02-codex-app-gui-launch-env.md` | Treat Finder-origin cold launch as not inheriting terminal-only markers. Retest on Codex app upgrade. |
| P05 Claude Desktop auth boundary | Runtime smoke complete | `docs/host-capability-substrate/research/shell-env/2026-04-26-P05-claude-desktop-auth-boundary.md` | Terminal `open -b` propagated a synthetic marker, but Finder-origin launch did not; Finder-launched process lacked common Claude credential env names by existence-only check. |
| P06 shell provenance | Open / narrowed with plan | `docs/host-capability-substrate/research/shell-env/2026-04-26-P06-shell-wrapper-logger-prep.md`; `docs/host-capability-substrate/research/shell-env/2026-04-27-P06-provenance-experiment-plan.md` | Runtime shape is captured for Claude Bash tool (`/bin/zsh -c`, `login=true` by self-introspection) and Codex CLI (`/bin/zsh -lc` by tool JSON). Both use absolute `/bin/zsh`, so PATH interception is closed as unsuitable except for negative controls. Next proof is a three-lane provenance experiment: tool-native trace, startup-file sentinels, and host-level process telemetry. |
| P13 Codex app sandbox | Typed status probe complete | `docs/host-capability-substrate/research/shell-env/2026-04-26-P13-codex-app-bundle-signing.md` | GUI control socket was absent, but temporary stdio app-server initialized and `command/exec` `/usr/bin/true` returned exit code 0. Filesystem/network status-code probes remain open. |

## Host State Outside Repo

- `/usr/local/bin/hcs-shell-logger` is installed, mode `0755`, owner
  `root:wheel`.
- Installed wrapper matches `scripts/dev/hcs-shell-logger.sh` by byte compare.
- SHA-256 for both files:
  `5d3c9b324e200fb347fb520011548c8990c4b9db8e792345f09a200f15651598`.
- `/usr/local/bin/hcs-shell-logger` now uses `#!/bin/bash`; the previous
  `#!/usr/bin/env bash` shebang recursed when `bash` was PATH-shadowed.
- Wrapper JSON records are assembled before append; the previous multi-`printf`
  append interleaved under a parallel live-routing run.
- Clean P06 PATH-routed evidence was written under
  `.logs/phase-1/shell-env/2026-04-26/P06-live-routing-fixed.jsonl`.
- The malformed parallel-run evidence remains under
  `.logs/phase-1/shell-env/2026-04-26/P06-live-routing.jsonl`.
- Raw P02 JSONL evidence was written under `.logs/phase-1/shell-env/2026-04-26/`;
  `.logs/` is intentionally ignored and not part of the committed handoff.

## Open Next Steps

1. Execute P06 only through the new provenance experiment plan:
   `docs/host-capability-substrate/research/shell-env/2026-04-27-P06-provenance-experiment-plan.md`.
   Claude Bash runtime shape is observed as `/bin/zsh -c` with `login=true`
   via in-tool self-introspection, and Codex CLI `/bin/zsh -lc` is reproduced
   from a Claude-run probe. Remaining gap: host-level `execve` argv,
   shell-startup-file effects, and parent provenance for both surfaces. Close
   P06 through tool-native trace, startup-file sentinels, and host-level process
   telemetry; PATH routing is closed as unsuitable except for negative
   controls. Continue to avoid nested Codex CLI probes from the active Codex
   session.
2. For P13, extend the approved typed app-server approach to filesystem and
   network status-code probes only. Avoid `thread/shellCommand` because the
   schema says it runs unsandboxed with full access.
3. For P01, decide whether GitHub MCP OAuth needs a static-client/manual auth
   strategy or whether the PAT/broker pattern remains the deliberate baseline.
   Do not remove `GITHUB_PAT` wiring from system-config based on this failed
   migration attempt.
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
- Do not treat the old P06 shorthand "Codex CLI = `bash -lc`" as host-proven;
  the approved 2026-04-26 Codex CLI probe displayed `/bin/zsh -lc`.
- Do not use broad Codex process cleanup while operating from inside Codex CLI.
  If a nested probe is interrupted, identify exact probe PIDs first and avoid
  terminating the controlling session.
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
| 1.5.0 | 2026-04-27 | Ingested `research/external/2026-04-27-p06-probe-shape.md` as a P06 provenance experiment plan and updated the next step to require tool-native trace, startup-file sentinels, and host-level telemetry. |
| 1.4.0 | 2026-04-27 | Advanced P06 to open/narrowed after Claude-run Test A self-introspection (`/bin/zsh -c`, login=true) and Test B Codex-from-Claude probe reproducing `/bin/zsh -lc` (exit 0). Closed PATH-prefix interception as unsuitable and kept host-level `execve` provenance/startup effects open. |
| 1.3.0 | 2026-04-26 | Recorded approved Wave 1 live-probe results: P01 OAuth migration blocked by unsupported dynamic registration, P05 Finder-origin runtime smoke, P13 stdio app-server status probe, and P06 nested-Codex caution. |
| 1.2.0 | 2026-04-26 | Added P01 Codex login/MCP auth-shape status, P05 CLI auth-status context, and P13 app-server protocol schema status to remaining Wave 1 handoff. |
| 1.1.0 | 2026-04-26 | Recorded approved P06 live-routing partial, wrapper shebang/append fixes, clean PATH-routed evidence, and Codex CLI `/bin/zsh -lc` discrepancy. |
| 1.0.0 | 2026-04-26 | Initial next-agent handoff after P01/P02/P05/P06/P13 prep. |
