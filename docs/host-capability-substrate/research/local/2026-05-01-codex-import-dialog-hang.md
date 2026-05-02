---
title: Codex Import Dialog Hang and Process-Inspection Evidence
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-05-01
tags: [research, local, codex, app, import, migration, process-inspection, secrets, execution-context]
priority: high
---

# Codex Import Dialog Hang and Process-Inspection Evidence

## Status

This memo records a live Codex macOS app observation from 2026-05-01 AKDT /
2026-05-02 UTC. The user reported that the Settings / Codex import dialog was
still open, all options were disabled, and force-quit had not yet occurred.

Treat this as first-party local host evidence for HCS planning. It does not
change schema, policy, adapters, hooks, repo settings, or live Codex
configuration.

## Evidence Captured

Observed local app build:

- Codex macOS app bundle id: `com.openai.codex`
- `CFBundleShortVersionString`: `26.429.30905`
- `CFBundleVersion`: `2345`
- Main app process started: `2026-05-01 11:46:13 AKDT`
- App-server process: PID `87329`, command name `codex`, started
  `2026-05-01 11:46:16 AKDT`

The app was still alive during the probe at about `2026-05-01 18:26 AKDT`.
The main app, renderer, app-server, and Chronicle sidecar were sleeping rather
than crash-looping.

The app-server had a large direct child set. A secret-safe command-name-only
count showed:

| Command name | Count |
|---|---:|
| `node` | 119 |
| `SkyComputerUseCl` | 16 |
| `node_repl` | 6 |

The count does not prove which child belongs to the import dialog, but it does
show that the app-server was retaining or launching many MCP/session-related
children while the UI was stuck.

## Repo State Correction

The earlier working theory assumed several Codex project targets were missing.
That no longer describes the current worktree.

Current HCS `main` is clean, and commit
`f7e8c3cefd735e757456ceb19e5677081a9431dd` (`chore: add codex project
directives`, authored `2026-05-01 18:08:48 AKDT`) already tracks:

- `.codex/agents/hcs-*.toml`
- `.codex/hooks.json`
- `.codex/hooks/hcs-hook`
- `.codex/hooks/hcs-log-hook.sh`

It also updates `.codex/config.toml`, `AGENTS.md`, `IMPLEMENT.md`, and
`docs/host-capability-substrate/hook-contracts.md`.

Current `.codex/config.toml` is intentionally minimal and points Codex at the
repo contract. It no longer matches the stale pasted claim that the file
contained project MCP server stanzas.

Implication: the live hang should be modeled as a Codex app dialog state /
completion-path failure after Codex project directives already exist, not as a
simple "missing `.codex/agents` and `.codex/hooks.json`" case.

## Log Findings

Targeted app-log search across:

- `~/Library/Logs/com.openai.codex/2026/05/01`
- `~/Library/Logs/com.openai.codex/2026/05/02`
- `~/Library/Application Support/Codex/sentry`

found repeated `Skills/list` calls but no app-log lines for:

- `migrate-to-codex`
- `applyMigration`
- `external_agent_config`
- `agent config`

Representative `Skills/list` behavior:

- Multiple calls with `cwdsCount=21` returned successfully with
  `missingShortDescriptionCount=774`, usually in about 0.9 to 1.9 seconds.
- Later calls with `cwdsCount=1` returned successfully with
  `missingShortDescriptionCount=53`, in about 0.1 to 0.4 seconds.

This makes workspace-root skill scanning a real cost and UI-noise contributor,
but not enough by itself to explain a dialog that remains disabled indefinitely.
The more important gap is that the logs do not expose a clear import-agent
completion, failure, cancellation, or recovery event.

No `.codex/migrate-to-codex-report.txt` was present in the HCS repo after the
probe.

## Curated Import Skill Evidence

The curated import skill was present at:

`~/.codex/vendor_imports/skills/skills/.curated/migrate-to-codex/`

Important local facts:

- `SKILL.md` size: `7939` bytes
- `SKILL.md` mtime: `2026-05-01 11:46:25 AKDT`
- total skill tree size by `wc -c`: `135150` bytes

The skill says to keep going until the selected migration is complete and not
ask before creating, editing, replacing, or deleting generated Codex artifacts
in selected targets such as `AGENTS.md`, `.codex/`, `.agents/`, or
`~/.codex/`. It also says unrelated existing Codex config entries should be
preserved.

The bundled migration reference explicitly marks hooks as partial conversion:

- Claude hooks can map to `.codex/hooks.json`, but Codex hook runtime behavior
  is not one-to-one with Claude.
- Codex `PreToolUse` is currently shell-command oriented.
- Prompt, agent, HTTP, async, skill-local, agent-local, and plugin-local hook
  shapes need manual review or wrapper commands.

HCS implication: automated Claude-to-Codex import is a Ring 3 workflow helper,
not an authority source. Its output still requires HCS boundary review,
especially for hooks and generated agents.

## Secret-Safety Finding

The strongest new HCS lesson from this investigation is about diagnostics, not
the import dialog itself.

Raw process-argv inspection of Codex app-server children is unsafe. During the
live probe, argv-shaped process output exposed token-bearing MCP launch
arguments for app-managed child processes. The raw values are intentionally not
recorded here.

Safer probes:

- use `ps -o pid,ppid,stat,lstart,etime,ucomm` for process-name-only evidence;
- use counts grouped by `ucomm` for process-shape summaries;
- use `rg -l` or count-only searches for token-shaped strings in logs;
- avoid `pgrep -fl`, `ps ... command`, `ps ... args`, and macOS `ps ... comm`
  unless output is redacted before model exposure.

This directly reinforces existing Q-009 safe-process-inspection planning and
the process-argv secret-exposure trap family. In macOS Codex app contexts,
"just inspect the child process tree" is not a safe operation unless the
inspection surface is typed and redacted.

## Interpretation

The best current model is:

1. The Codex import UI can enter a disabled/loading state with no visible
   recovery path.
2. The current repo already contains tracked Codex project directives, so the
   old "fresh target paths are missing" diagnosis is stale for this worktree.
3. App logs show skill-list scans completing, but do not show import lifecycle
   telemetry that explains the stuck UI.
4. The app-server can retain many child MCP/session processes while the dialog
   is stuck, so process state is relevant but must be inspected through a
   redacted process contract.
5. The curated migration skill is intentionally autonomous and broad enough to
   edit generated Codex artifacts, so HCS should not treat import output as
   trusted without repo-local review.

## HCS Planning Inputs

This observation feeds existing planning questions rather than opening a new
accepted decision.

| HCS item | Input from this observation |
|---|---|
| Q-009 diagnostic surface | Add Codex app child-process inspection to the `system.process.inspect_safe.v1` candidate requirements. The safe surface must never expose raw argv/env. |
| Q-010 isolation taxonomy | Codex app import/settings UI is a separate app `ExecutionContext` from Codex CLI, Codex cloud, and IDE extensions. |
| ADR 0017 / Codex app context | App-server child processes and app-managed MCP launch behavior are host-visible evidence, not proof of GUI-internal completion or capability state. |
| Tooling surface matrix | Codex app settings/import UI remains observe-only. Project `.codex/` artifacts are repo-controlled after creation. |
| Regression traps | This is further real evidence for `process-argv-secret-exposure`; if expanded, the trap should assert that agents choose redacted process summaries before reading full argv. |

## Open Questions

- Which app-side request marks import start, success, failure, or cancellation?
  Current logs did not expose that lifecycle in a clearly searchable way.
- Does the disabled dialog wait for an internal agent session, a persisted
  import state flag, a background MCP/session child, or a frontend state machine
  that missed an error branch?
- Does reopening Codex after force-quit clear the dialog because repo artifacts
  now exist, or does it re-enter the same import state from app-managed storage?
- Should HCS later add a redacted Codex-app process snapshot fixture for P13 /
  Q-009, using only `ucomm`, PID lineage, start time, and counts?
