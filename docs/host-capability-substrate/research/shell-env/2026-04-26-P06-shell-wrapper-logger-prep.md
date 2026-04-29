---
title: P06 Shell Wrapper Logger Preparation
category: research
component: host_capability_substrate
status: partial
version: 1.7.0
last_updated: 2026-04-28
tags: [phase-1, p06, shell-wrapper, redaction, fixture]
priority: high
---

# P06 Shell Wrapper Logger Preparation

Partial evidence for shell/environment research prompt P06: shell binary and
invocation-form validation per execution surface.

This memo records the in-repo wrapper implementation, regression fixture,
approved host installation, and the first approved live-routing attempt. The
live route used a temporary PATH prefix and did **not** change `$SHELL` or any
persistent agent configuration.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26; updated 2026-04-27T01:25Z |
| macOS | 26.4.1, build 25E253 |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| Wrapper | `scripts/dev/hcs-shell-logger.sh` |
| Fixture | `scripts/dev/run-shell-logger-fixture.sh` |
| Installed wrapper | `/usr/local/bin/hcs-shell-logger` |
| Verification recipe | `just shell-logger-fixture` |

## Implementation Summary

`scripts/dev/hcs-shell-logger.sh` logs invocation shape, then execs the real
shell with the original argv. The real shell defaults to `/bin/bash` and can be
overridden with `HCS_SHELL_LOGGER_REAL_SHELL` for fixture testing. The script
uses an absolute `#!/bin/bash` shebang so PATH-shadowing `bash` does not recurse
through `/usr/bin/env bash`.

Each JSON record is assembled before append. This avoids interleaving when
multiple wrapper processes write to the same JSONL log concurrently.

The wrapper log includes:

- schema version, timestamp, pid, ppid, cwd, wrapper argv0
- real shell path
- arg count
- recognized shell flags such as `-c` or `-lc`
- redacted argv shape

The wrapper log intentionally excludes:

- environment values
- shell command strings passed to `-c` / `-lc`
- arbitrary non-flag argument values

## Fixture Result

`scripts/dev/run-shell-logger-fixture.sh` routes the wrapper to a fake shell and
passes a command payload containing the marker
`SHOULD_NOT_APPEAR_IN_WRAPPER_LOG`.

Observed result:

- wrapper returned the fake shell exit status
- fake shell received the original command payload
- wrapper log recorded `shell_flags=["-lc"]`
- wrapper log recorded `arg_shape=["shell_flag:-lc","command_string_redacted"]`
- wrapper log did not contain the command payload marker
- wrapper log did not contain `env` or `environment` fields

## Host Install Result

The reviewed wrapper was installed to `/usr/local/bin/hcs-shell-logger` after
the direct install attempt failed with `Permission denied` and the approved
`sudo install` path succeeded.

Observed result:

- installed path: `/usr/local/bin/hcs-shell-logger`
- mode/owner: `-rwxr-xr-x`, `root:wheel`
- repo-vs-installed comparison: `cmp` exit `0`
- SHA-256 for both repo script and installed wrapper after the live-routing
  fixes:
  `5d3c9b324e200fb347fb520011548c8990c4b9db8e792345f09a200f15651598`

## Live Routing Result

Approved live routing ran on 2026-04-26 using a temporary wrapper PATH at
`/tmp/hcs-p06-shell-route.eT6AW6` and logs under
`.logs/phase-1/shell-env/2026-04-26/`.

Initial observations:

- The first PATH-shadowing attempt failed before logging with
  `env: bash: Argument list too long`. Root cause: the wrapper shebang used
  `#!/usr/bin/env bash`, and PATH-shadowing `bash` recursively re-entered the
  wrapper.
- After switching the shebang to `#!/bin/bash`, a parallel three-shell run wrote
  malformed JSONL because the wrapper appended one record through many separate
  `printf` calls. The malformed log is preserved as
  `P06-live-routing.jsonl` under the ignored local evidence directory.
- After changing the wrapper to assemble each JSON record before append, the
  clean serial route wrote `P06-live-routing-fixed.jsonl`.

Clean wrapper evidence:

| Probe | `argv0` | Real shell | Flags | Arg shape |
|---|---|---|---|---|
| bash route | `/tmp/hcs-p06-shell-route.eT6AW6/bash` | `/bin/bash` | `["-lc"]` | `["shell_flag:-lc","command_string_redacted"]` |
| sh route | `/tmp/hcs-p06-shell-route.eT6AW6/sh` | `/bin/sh` | `["-c"]` | `["shell_flag:-c","command_string_redacted"]` |
| zsh route | `/tmp/hcs-p06-shell-route.eT6AW6/zsh` | `/bin/zsh` | `["-lc"]` | `["shell_flag:-lc","command_string_redacted"]` |

The clean log has three valid JSONL records. A scan for `P06_`,
`TOKEN`, `SECRET`, `KEY`, `PASSWORD`, `env`, and `environment` produced no
matches. The wrapper did not persist command payloads or environment fields.

True agent-surface probes:

- Codex CLI `0.125.0` initially failed inside the sandbox because it could not
  access `/Users/verlyn13/.codex/sessions`. The approved rerun outside the
  sandbox completed.
- In that rerun, Codex CLI displayed its executed shell command as
  `/bin/zsh -lc "printf \"%s\\n\" P06_CODEX_CLI_TOOL_OK"`. No wrapper JSONL was
  written because the CLI used an absolute `/bin/zsh` path, bypassing PATH
  routing.
- This host-local observation contradicts the previous expected P06 shorthand
  "Codex CLI = `bash -lc`" for this launch context. P06 should not claim Codex
  CLI uses `bash -lc` on this host until the discrepancy is reproduced and
  reconciled against CLI configuration and launch context.
- Claude Code CLI `2.1.119` under the minimal-env probe returned `Not logged in`
  before any Bash tool call. No Claude shell-routing evidence was captured, and
  this remains below the repo baseline of `2.1.120+`.
- During later approved Claude app runtime activity, the user observed one Bash
  request that they allowed, then a Touch ID approval, then three more Bash
  requests that they allowed. This is live app-surface evidence that Claude can
  request Bash through an approval path, but it is not a wrapper-captured shell
  transcript and does not establish argv, shell path, cwd, or environment.
- A follow-up nested `codex exec --json` absolute-shell probe was interrupted
  intentionally because this session itself is running through Codex CLI. A
  narrow post-interruption process check found no lingering nested Codex probe.

## Claude-Run Evidence (Test A + Test B, 2026-04-27)

The following observations were captured from a Claude Code CLI session, not
the Codex CLI controlling session. This avoids the prior interruption hazard
where nesting `codex exec` inside Codex CLI risked terminating the controller.

### Test A — Claude Bash tool self-introspection

Claude's Bash tool ran a single redaction-safe self-introspection script. The
script captured PID/PPID, `argv0`, shell family, login-shell flag, and a
`-c`/`-lc` redacted form of `ps -p $$ -o args=`. No environment values were
read or echoed.

| Field | Value |
|---|---|
| Marker | `HCS_P06_CLAUDE_OPUS_SHELL_20260427` |
| `argv0` | `/bin/zsh` |
| Shell family | `zsh` |
| Login shell | `true` |
| `ps args` (redacted) | `/bin/zsh -c <command_string_redacted>` |

Interpretation: Claude Code's Bash tool was observed from inside the spawned
shell as `/bin/zsh` at an absolute path, with the `-c` flag and no explicit
`-l`, yet the spawned shell reports `login=true`. This discrepancy is
preserved as evidence; it should not be normalized away or treated as proof of
the parent `execve` vector. Like the Codex CLI absolute-path observation, this
surface bypasses PATH-prefix wrapper interception.

### Test B — Codex CLI from Claude

`codex exec --ephemeral --full-auto --json -C <repo>` was launched from the
Claude Bash tool with a single harmless `printf` payload. Running Codex from
Claude — rather than nested inside the Codex CLI controlling session —
removed the prior interruption hazard.

| Field | Value |
|---|---|
| Marker | `HCS_P06_CODEX_FROM_CLAUDE_20260427` |
| Completed | yes |
| Exit code | `0` |
| Codex `command_execution.command` (redacted) | `/bin/zsh -lc <command_string_redacted>` |
| Still absolute `/bin/zsh -lc` | yes |
| Controlling session | Claude Code CLI |

Interpretation: Codex CLI's `command_execution` event reproduces the
2026-04-26 `/bin/zsh -lc` absolute-path observation from a non-Codex
controlling session. The flag form is independent of nesting context: Codex
CLI invokes the shell with `-lc` regardless of whether the parent is a
terminal, Codex CLI, or Claude Code CLI.

### Finding P06-2026-04-27

On the tested host, both Claude Code CLI Bash and Codex CLI command execution
route through absolute `/bin/zsh`, defeating PATH-prefix shell-wrapper
interception. Codex's JSON command event showed
`/bin/zsh -lc <command_string_redacted>`; Claude's Bash self-introspection
showed a spawned `/bin/zsh -c <command_string_redacted>` process with runtime
login-shell state. These differ by surface and must be modeled as
surface-specific `ExecutionContext` properties.

Remaining uncertainty is pre-`-c` provenance: parent argv, exact `execve`
vector, and startup-file effects.

### Cross-surface flag-form contrast

| Surface (this host) | Shell binary | Flag form (per `ps args` or tool-reported) | Login shell |
|---|---|---|---|
| Claude Code CLI Bash tool | `/bin/zsh` | `-c` | `true` |
| Codex CLI `command_execution` | `/bin/zsh` | `-lc` | not directly reported |
| Wrapper-routed manual `bash` probe | `/bin/bash` | `-lc` | (synthetic harness) |
| Wrapper-routed manual `sh` probe | `/bin/sh` | `-c` | (synthetic harness) |
| Wrapper-routed manual `zsh` probe | `/bin/zsh` | `-lc` | (synthetic harness) |

Both Claude and Codex use absolute `/bin/zsh`, so a PATH-prefix wrapper does
not intercept either by default. Their flag forms differ: `-c` for Claude
versus `-lc` for Codex. Treat shell binary and flag form as per-surface
properties of `ExecutionContext`, not as a single global Codex/Claude trait.

A sanitized JSONL summary of both probes is at
`.logs/phase-1/shell-env/2026-04-26/P06-from-claude-summary.jsonl`. The file
is not committed; it is local evidence under the ignored `.logs/` tree.

## Interpretation

P06 live routing proved the wrapper can safely capture PATH-routed shell
invocation shape after the shebang and atomic-append fixes. It also showed that
PATH routing is insufficient for surfaces that invoke absolute shell paths.
The PATH-prefix interception branch is closed as unsuitable except for
negative-control tests.

The 2026-04-27 Claude-run evidence narrows two prior P06 gaps without
introducing new wrapper-state risk:

1. Claude Code's Bash-tool runtime shell shape is now observed on this machine:
   `/bin/zsh -c` with `login=true`. Earlier P06 work could not capture this
   because the minimal-env Claude probe returned `Not logged in` on
   `2.1.119`. This is an in-tool self-introspection result, not host-level
   `execve` truth.
2. Codex CLI's `/bin/zsh -lc` form is reproduced from a non-Codex
   controlling session, so the previous "Codex CLI = `bash -lc`" shorthand
   stays retired and the `/bin/zsh -lc` finding does not depend on the
   sandbox/auth context of the original Codex-from-terminal probe.

At the 2026-04-27 checkpoint, P06 remained open but narrowed. Close it only
when tool-native trace, startup-file sentinels, and host-level process
provenance agree or any
discrepancy is documented. Self-introspection scripts inside the agent are
sufficient for runtime shape capture but cannot observe parent argv,
shell-startup-file effects, or full pre-`-c` flag history without additional
tooling. Do not rerun nested Codex CLI probes from the active Codex session
unless the probe is isolated well enough that cleanup cannot terminate the
controlling session; the 2026-04-27 Codex probe was launched from Claude
specifically to avoid that hazard.

## Host Telemetry Rerun Addendum

`docs/host-capability-substrate/research/shell-env/2026-04-28-P06-host-telemetry-rerun.md`
records the first post-Full-Disk-Access host-telemetry rerun.

The rerun changes how the earlier `/bin/zsh -lc` Codex evidence should be used:

- Codex internal startup shells can use `/bin/zsh -lc` and read more temporary
  zsh startup sentinels.
- The corrected Codex CLI tool-call subprocesses in the host-telemetry rerun
  execed through `sandbox-exec -- /bin/zsh -c <redacted>`.
- Baseline X1 propagated the synthetic marker and recorded `.zshenv` only in
  the actual tool shell.
- X2 with `allow_login_shell=false` preserved `/bin/zsh -c` but did not
  propagate the synthetic marker into the actual tool shell.

The focused 2026-04-28/29 closure run in the same memo resolved the remaining
CLI-surface P06 gaps:

- Codex baseline repeats propagated the marker into the actual tool shell and
  recorded `.zshenv` only for the tool pid.
- Codex `allow_login_shell=false` repeats preserved
  `sandbox-exec -- /bin/zsh -c <redacted>` but did not propagate the marker into
  the actual tool shell for Codex CLI `0.125.0` in this config.
- Claude Code CLI `2.1.122` Bash-tool subprocess is now host-observed as
  `/bin/zsh -c <redacted>` with marker propagation and `.zshenv` only for the
  actual tool shell.

Do not model the internal `/bin/zsh -lc` process as the Codex tool-call
subprocess. P06 is closed for Codex CLI and Claude Code CLI; app/IDE surfaces
remain separate `ExecutionContext` work.

## Closure Criteria

P06 should stay open until each target surface has all of the following:

1. Host-level process telemetry confirms the exact shell executable and argv
   vector.
2. Parent process chain is captured far enough back to identify the constructing
   controller.
3. Startup-file marker results match the expected shell startup class.
4. Tool-native trace agrees with host-level trace, or the discrepancy is
   documented.
5. The run is reproducible on a fresh session with pinned tool versions and
   recorded config.
6. The artifact contains no environment values, no raw command payloads, and no
   secret-bearing startup-file contents.

## Next Proof Plan

The next P06 run is specified in
`docs/host-capability-substrate/research/shell-env/2026-04-27-P06-provenance-experiment-plan.md`.

That plan ingests the staged external brief
`docs/host-capability-substrate/research/external/2026-04-27-p06-probe-shape.md`
as a three-lane provenance experiment:

1. Tool-native trace for controller intent.
2. Temporary `ZDOTDIR` startup-file sentinels for user startup-file effects.
3. Host-level process telemetry for OS `execve` truth and parent provenance.

The key rule is evidence-lane separation: host telemetry wins for `execve`
truth, sentinels win for startup-file effects, and tool telemetry wins for tool
intent. Do not infer one lane from another.

## Commands Used

```json
[
  {
    "file": "/bin/bash",
    "argv": ["bash", "scripts/dev/run-shell-logger-fixture.sh"]
  },
  {
    "file": "/opt/homebrew/bin/shellcheck",
    "argv": ["shellcheck", "scripts/dev/hcs-shell-logger.sh", "scripts/dev/run-shell-logger-fixture.sh"]
  },
  {
    "file": "/usr/bin/install",
    "argv": ["/usr/bin/install", "-m", "0755", "scripts/dev/hcs-shell-logger.sh", "/usr/local/bin/hcs-shell-logger"]
  },
  {
    "file": "/usr/bin/sudo",
    "argv": ["sudo", "/usr/bin/install", "-m", "0755", "scripts/dev/hcs-shell-logger.sh", "/usr/local/bin/hcs-shell-logger"]
  },
  {
    "file": "/usr/bin/cmp",
    "argv": ["cmp", "-s", "scripts/dev/hcs-shell-logger.sh", "/usr/local/bin/hcs-shell-logger"]
  },
  {
    "file": "/usr/bin/shasum",
    "argv": ["shasum", "-a", "256", "scripts/dev/hcs-shell-logger.sh", "/usr/local/bin/hcs-shell-logger"]
  },
  {
    "file": "/usr/bin/env",
    "argv": ["env", "-i", "HOME=/Users/verlyn13", "PATH=/tmp/hcs-p06-shell-route.eT6AW6:/usr/bin:/bin", "HCS_SHELL_LOGGER_LOG=/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate/.logs/phase-1/shell-env/2026-04-26/P06-live-routing-fixed.jsonl", "HCS_SHELL_LOGGER_REAL_SHELL=/bin/bash", "bash", "-lc", "printf <redacted>"]
  },
  {
    "file": "/usr/bin/env",
    "argv": ["env", "-i", "HOME=/Users/verlyn13", "PATH=/tmp/hcs-p06-shell-route.eT6AW6:/usr/bin:/bin", "HCS_SHELL_LOGGER_LOG=/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate/.logs/phase-1/shell-env/2026-04-26/P06-live-routing-fixed.jsonl", "HCS_SHELL_LOGGER_REAL_SHELL=/bin/sh", "sh", "-c", "printf <redacted>"]
  },
  {
    "file": "/usr/bin/env",
    "argv": ["env", "-i", "HOME=/Users/verlyn13", "PATH=/tmp/hcs-p06-shell-route.eT6AW6:/usr/bin:/bin", "HCS_SHELL_LOGGER_LOG=/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate/.logs/phase-1/shell-env/2026-04-26/P06-live-routing-fixed.jsonl", "HCS_SHELL_LOGGER_REAL_SHELL=/bin/zsh", "zsh", "-lc", "printf <redacted>"]
  },
  {
    "file": "/Users/verlyn13/.npm-global/bin/codex",
    "argv": ["codex", "exec", "--ephemeral", "--full-auto", "-C", "/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate", "Run one harmless shell command <redacted>"]
  },
  {
    "file": "/Users/verlyn13/.local/bin/claude",
    "argv": ["claude", "-p", "--no-session-persistence", "--tools", "Bash", "--allowedTools", "Bash(printf *)", "--permission-mode", "acceptEdits", "Run one harmless Bash command <redacted>"]
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.7.0 | 2026-04-28 | Linked the focused P06 closure run, resolving Codex CLI marker propagation and Claude Code CLI host telemetry for P06 CLI-surface closure. |
| 1.6.0 | 2026-04-28 | Linked the post-Full-Disk-Access host-telemetry rerun and clarified the Codex split between internal `/bin/zsh -lc` startup shells and tool-call `sandbox-exec -- /bin/zsh -c` subprocesses. |
| 1.5.0 | 2026-04-27 | Linked the P06 provenance experiment plan ingested from `research/external/2026-04-27-p06-probe-shape.md`, defining tool-native, startup-sentinel, and host-telemetry lanes as the next proof step. |
| 1.4.0 | 2026-04-27 | Added Claude-run evidence: Test A self-introspection (`/bin/zsh -c`, login=true) and Test B Codex-from-Claude probe reproducing `/bin/zsh -lc` (exit 0). Added cross-surface flag-form contrast table and clarified P06 as open/narrowed rather than closed. |
| 1.3.0 | 2026-04-26 | Added user-observed Claude app Bash/Touch ID approval sequence and noted that a nested Codex JSON retry was intentionally interrupted with no lingering nested process. |
| 1.2.0 | 2026-04-26 | Recorded the approved live-routing attempt, shebang and atomic-append fixes, clean PATH-routed shell evidence, Codex CLI `/bin/zsh -lc` observation, and Claude minimal-env auth blocker. |
| 1.1.0 | 2026-04-26 | Added approved host-install result for `/usr/local/bin/hcs-shell-logger`. |
| 1.0.0 | 2026-04-26 | Initial P06 wrapper implementation and fixture result. |
