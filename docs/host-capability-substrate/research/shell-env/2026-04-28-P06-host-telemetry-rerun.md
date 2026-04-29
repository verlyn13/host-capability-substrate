---
title: P06 Host Telemetry Rerun
category: research
component: host_capability_substrate
status: complete
version: 1.2.0
last_updated: 2026-04-28
tags: [phase-1, p06, shell-env, execution-context, host-telemetry]
priority: high
---

# P06 Host Telemetry Rerun

Fresh action-time P06 evidence captured after iTerm2 was restarted with Full
Disk Access. This memo records host-level Endpoint Security evidence for Codex
CLI `0.125.0` and Claude Code CLI `2.1.122` for the CLI surfaces in scope for
P06 closure.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-29T00:46Z to 2026-04-29T01:00Z; focused closure run 2026-04-29T01:48Z to 2026-04-29T01:52Z |
| macOS | 26.4.1, build 25E253 |
| Codex CLI | 0.125.0 |
| Claude Code | 2.1.122; sandboxed `claude auth status` reported `loggedIn=false`, host-context `claude auth status` reported `loggedIn=true` before the closure run |
| Agent runtime note | GPT-5.5/Codex agents run in the Codex surface on this host; Opus 4.7 runs from the Claude Code surface |
| zsh | 5.9 |
| Initial rerun id | `p06-20260429T004624Z-7e468e86` |
| Focused closure run id | `p06-20260429T013832Z-7e468e86` |
| Retained initial host artifact | `.logs/phase-1/shell-env/2026-04-28/p06-runs/p06-20260429T004624Z-7e468e86/host/eslogger.sanitized.valid.ndjson` |
| Retained closure host artifact | `.logs/phase-1/shell-env/2026-04-28/p06-runs/p06-20260429T013832Z-7e468e86/host/eslogger.sanitized.valid.ndjson` |

## Method

The first post-Full-Disk-Access attempt used
`eslogger --select /bin/zsh exec fork exit`. That proved Full Disk Access was
working but was not sufficient for P06 closure because it missed exec-into-shell
events where the parent was not already zsh. Its raw capture also included
environment values and was removed after creating a redacted derivative.

The retained rerun used all-process `eslogger exec fork exit` with live `jq`
redaction. The collector wrote only sanitized NDJSON:

- environment values dropped
- shell `-c` / `-lc` bodies redacted
- Codex prompt values redacted
- sandbox profiles redacted
- Codex plugin turn payloads redacted

The initial sanitized host trace has 32,168 valid JSON events: 5,509 `exec`,
13,325 `fork`, and 13,334 `exit`. The focused closure run has 48,339 valid JSON
events: 9,874 `exec`, 19,234 `fork`, and 19,231 `exit`.

Artifact integrity:

| Check | Result |
|---|---|
| Sanitized trace | 32,168 parseable NDJSON lines |
| Event counts | 5,509 `exec`; 13,325 `fork`; 13,334 `exit` |
| Prompt/body scan | no prompt/body payload markers in retained host trace |
| Secret-shaped scan | no secret-shaped matches in retained host trace |
| Raw host traces | removed; retained artifact is sanitized valid NDJSON |
| Cleanup | no leftover `eslogger`, collector, nested `codex exec`, or `claude -p` process after run |

Focused closure run artifact integrity:

| Check | Result |
|---|---|
| Sanitized trace | 48,339 parseable NDJSON lines |
| Event counts | 9,874 `exec`; 19,234 `fork`; 19,231 `exit` |
| Prompt/body scan | no prompt/body payload markers in retained artifacts after excluding the scrubber source itself |
| Secret-shaped scan | only expected deny-pattern self-matches inside `host/run-sanitized-eslogger.sh`; no matches in retained host/sentinel/tool evidence when collector scripts are excluded |
| Raw Codex JSONL | removed after safe derivatives with command payloads redacted |
| Prompt files | removed; retained only `tool/prompt.sha256` |
| Cleanup | no leftover `eslogger`, collector, nested `codex exec`, or `claude -p` process after run |

## Findings

### Codex X1 Baseline

Tool-native result:

| Field | Value |
|---|---|
| Codex exit | `0` |
| Reported tool shell pid | `28920` |
| Reported parent pid | `28460` |
| Reported `$0` | `/bin/zsh` |
| `P06_RUN_ID` visible in tool shell | yes |
| `ZSH_VERSION` visible | yes |
| `/bin/ps` | denied by sandbox |

Host telemetry for the tool shell:

1. Codex native binary pid `28460` forked child `28920`.
2. `28920` execed `/usr/bin/sandbox-exec` with a redacted profile and final
   argv segment `-- /bin/zsh -c <command_string_redacted>`.
3. `28920` then execed `/bin/zsh` with argv
   `["/bin/zsh", "-c", "<command_string_redacted>"]`.
4. Startup sentinel for pid `28920` recorded `.zshenv` only:
   `login=off`, `interactive=off`.

This is host-level evidence that the Codex CLI tool-call subprocess in this
run was `/bin/zsh -c` under `sandbox-exec`, not `/bin/zsh -lc`.

### Codex X2 `allow_login_shell=false`

Tool-native result:

| Field | Value |
|---|---|
| Codex exit | `0` |
| Reported tool shell pid | `29713` |
| Reported parent pid | `29186` |
| Reported `$0` | `/bin/zsh` |
| `P06_RUN_ID` visible in tool shell | no |
| `ZSH_VERSION` visible | yes |
| `/bin/ps` | denied by sandbox |

Host telemetry for the tool shell:

1. Codex native binary pid `29186` forked child `29713`.
2. `29713` execed `/usr/bin/sandbox-exec` with final argv segment
   `-- /bin/zsh -c <command_string_redacted>`.
3. `29713` then execed `/bin/zsh` with argv
   `["/bin/zsh", "-c", "<command_string_redacted>"]`.
4. No startup sentinel was recorded for pid `29713`, consistent with the
   tool-native observation that `P06_RUN_ID` was not present in that shell.

`allow_login_shell=false` did not change the observed shell argv in this run.
It did correlate with loss of the synthetic marker environment in the actual
tool shell. The focused matrix below resolves that sub-question for Codex CLI
`0.125.0` in this config by checking repeatability against baseline repeats.

### Internal Codex Startup Shells

Both corrected Codex runs also spawned earlier `/bin/zsh -lc` processes that
read the temporary `ZDOTDIR` startup files:

- X1 internal shell pid `28483`: `.zshenv`, `.zprofile`, `.zlogin`, `.zshrc`
- X1 internal shell pid `28685`: `.zshenv`
- X2 internal shell pid `29207`: `.zshenv`, `.zprofile`, `.zlogin`, `.zshrc`
- X2 internal shell pid `29409`: `.zshenv`

These processes are important ExecutionContext evidence, but they are not the
same process as the tool-call subprocess that ran the probe command. Do not use
the internal `/bin/zsh -lc` startup shell as the tool-call shell model.

### Codex `allow_login_shell=false` Propagation Matrix

The focused closure run used real `HOME`, temporary `ZDOTDIR`, the same
workspace-write sandbox, all-process host telemetry, and a sterile existence-only
probe. It resolved the open X2 sub-question for Codex CLI `0.125.0` on this
host.

| Case | Codex pid | Tool shell pid | Carrier | Final shell argv | Marker visible | Tool shell sentinel | Tool exit | Codex exit |
|---|---:|---:|---|---|---|---|---:|---:|
| C1 baseline | `30606` | `31206` | `/usr/bin/sandbox-exec` | `/bin/zsh -c <redacted>` | yes | `.zshenv`; login off; interactive off | `0` | `0` |
| C2 `allow_login_shell=false` | `31547` | `31958` | `/usr/bin/sandbox-exec` | `/bin/zsh -c <redacted>` | no | none observed; marker env absent | `0` | `0` |
| C3 `allow_login_shell=false` repeat | `33307` | `34113` | `/usr/bin/sandbox-exec` | `/bin/zsh -c <redacted>` | no | none observed; marker env absent | `0` | `0` |
| C4 baseline repeat | `34355` | `34769` | `/usr/bin/sandbox-exec` | `/bin/zsh -c <redacted>` | yes | `.zshenv`; login off; interactive off | `0` | `0` |

Interpretation: `allow_login_shell=false` repeatably prevented the synthetic
marker from reaching the actual sandboxed tool subprocess in this Codex version
and config. It did not change the host-observed tool subprocess carrier or final
shell argv form.

The same run again observed separate internal Codex startup shells before the
tool-call subprocess:

| Case | Internal shell pids | Host argv forms | Sentinels |
|---|---|---|---|
| C1 baseline | `30627`, `30829` | `/bin/zsh -lc <redacted>`, then `/bin/zsh -c <redacted>` | first pid: `.zshenv`, `.zprofile`, `.zlogin`, `.zshrc`; second pid: `.zshenv` |
| C2 `allow_login_shell=false` | `31567`, `31769` | `/bin/zsh -lc <redacted>`, then `/bin/zsh -c <redacted>` | first pid: `.zshenv`, `.zprofile`, `.zlogin`, `.zshrc`; second pid: `.zshenv` |
| C3 `allow_login_shell=false` repeat | `33347`, `33549` | `/bin/zsh -lc <redacted>`, then `/bin/zsh -c <redacted>` | first pid: `.zshenv`, `.zprofile`, `.zlogin`, `.zshrc`; second pid: `.zshenv` |
| C4 baseline repeat | `34375`, `34578` | `/bin/zsh -lc <redacted>`, then `/bin/zsh -c <redacted>` | first pid: `.zshenv`, `.zprofile`, `.zlogin`, `.zshrc`; second pid: `.zshenv` |

### Claude Code CLI Host Telemetry

Claude auth was available in host context for the focused closure run. The
probe used Claude Code CLI `2.1.122`, model `opus`, and Bash tool access with a
single sterile `printf` payload.

Tool-native result:

| Field | Value |
|---|---|
| Claude exit | `0` |
| Reported tool shell pid | `35799` |
| Reported parent pid | `35004` |
| Reported `$0` | `/bin/zsh` |
| `P06_RUN_ID` visible in tool shell | yes |
| `ZSH_VERSION` visible | yes |

Host telemetry:

1. Claude Code CLI pid `35004` execed
   `/Users/verlyn13/.local/share/claude/versions/2.1.122` from a host zsh
   launcher with argv `claude -p --no-session-persistence --model opus --tools
   Bash --allowedTools 'Bash(printf *)' --permission-mode acceptEdits
   <redacted>`.
2. Claude spawned internal shell pid `35752` as `/bin/zsh -c <redacted>
   SNAPSHOT_FILE=<redacted>`. Sentinel evidence for this internal shell recorded
   `.zshenv`, `.zprofile`, and `.zlogin`.
3. Claude then spawned the actual Bash-tool shell pid `35799` as
   `/bin/zsh -c <redacted>`.
4. Startup sentinel for pid `35799` recorded `.zshenv` only:
   `login=off`, `interactive=off`.
5. The tool shell and Claude process both exited `0`.

This replaces the earlier Claude self-introspection-only status with host-level
argv/provenance for the Claude Code CLI Bash-tool subprocess.

### Codex Correlation Table

| Case | Surface | Phase | Parent pid | Shell pid | Carrier | Exec path | Argv flags | Login | Interactive | Sentinels read | Marker visible | Sandbox policy | Exit |
|---|---|---:|---:|---:|---|---|---|---|---|---|---|---|---:|
| X1 | Codex CLI | internal startup shell | `28460` | `28483` | none observed | `/bin/zsh` | `-lc` | on | off | `.zshenv`, `.zprofile`, `.zlogin`, `.zshrc` | yes | n/a | `0` |
| X1 | Codex CLI | internal startup shell | `28460` | `28685` | none observed | `/bin/zsh` | not captured beyond zsh shell process | off | off | `.zshenv` | yes | n/a | `0` |
| X1 | Codex CLI | tool-call subprocess | `28460` | `28920` | `/usr/bin/sandbox-exec` | `/bin/zsh` | `-c` | off | off | `.zshenv` | yes | workspace-write profile redacted | non-zero tool command status from denied `ps`; Codex turn exit `0` |
| X2 | Codex CLI | internal startup shell | `29186` | `29207` | none observed | `/bin/zsh` | `-lc` | on | off | `.zshenv`, `.zprofile`, `.zlogin`, `.zshrc` | yes | n/a | `0` |
| X2 | Codex CLI | internal startup shell | `29186` | `29409` | none observed | `/bin/zsh` | not captured beyond zsh shell process | off | off | `.zshenv` | yes | n/a | `0` |
| X2 | Codex CLI | tool-call subprocess | `29186` | `29713` | `/usr/bin/sandbox-exec` | `/bin/zsh` | `-c` | not observed by sentinel | not observed by sentinel | none | no | workspace-write profile redacted | non-zero tool command status from denied `ps`; Codex turn exit `0` |

## Status

P06 is closed for the Codex CLI and Claude Code CLI surfaces measured here:

- Codex CLI tool-call subprocess: host-observed
  `/usr/bin/sandbox-exec -- /bin/zsh -c <redacted>`.
- Codex CLI internal startup shells: separately host-observed `/bin/zsh -lc`
  and `/bin/zsh -c` phases before tool execution; do not model these as the
  tool-call subprocess.
- Codex `allow_login_shell=false`: repeatably preserves the same host-observed
  tool subprocess argv but prevents the synthetic marker env from reaching that
  tool shell for Codex CLI `0.125.0` in this config.
- Claude Code CLI Bash-tool subprocess: host-observed `/bin/zsh -c <redacted>`
  with marker propagation and `.zshenv` startup exposure.

The closure does not claim Codex app, Codex IDE, Claude Desktop, or Claude IDE
extension behavior. Those remain separate `ExecutionContext` surfaces under P02,
P03, P04, and P13.

## Next Steps

1. Use all-process host telemetry with live redaction for any future
   re-baselining. Do not use `eslogger --select /bin/zsh` as the closure
   mechanism.
2. Model Codex CLI with at least two phases: internal startup shells and
   tool-call subprocess shells. The latter is the one that should drive
   `tool_call_subprocess` ExecutionContext fields.
3. Add ExecutionContext schema notes for `surface`, `phase`, `carrier`,
   `shell_path`, `argv_flags`, `login_observed`, `interactive_observed`,
   `startup_files_observed`, `marker_env_visible`, `host_telemetry_source`,
   `tool_native_source`, `confidence`, and `open_questions`.
4. Re-baseline after material Codex CLI or Claude Code CLI version changes.

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.2.0 | 2026-04-28 | Added focused Codex propagation matrix and Claude host telemetry; closed P06 for Codex CLI and Claude Code CLI surfaces. |
| 1.1.0 | 2026-04-28 | Added Codex correlation table, artifact integrity note, and host-context Claude auth availability note. |
| 1.0.0 | 2026-04-28 | Captured post-Full-Disk-Access all-process host telemetry for Codex X1/X2 and documented the `/bin/zsh -c` tool-call subprocess split from internal `/bin/zsh -lc` startup shells. |
