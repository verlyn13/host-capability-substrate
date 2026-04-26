---
title: P06 Shell Wrapper Logger Preparation
category: research
component: host_capability_substrate
status: partial
version: 1.0.0
last_updated: 2026-04-26
tags: [phase-1, p06, shell-wrapper, redaction, fixture]
priority: high
---

# P06 Shell Wrapper Logger Preparation

Partial evidence for shell/environment research prompt P06: shell binary and
invocation-form validation per execution surface.

This memo records the in-repo wrapper implementation and regression fixture. It
does **not** install `/usr/local/bin/hcs-shell-logger`, change `$SHELL`, modify
`PATH`, or route any live agent surface through the wrapper.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26 |
| macOS | 26.4.1, build 25E253 |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| Wrapper | `scripts/dev/hcs-shell-logger.sh` |
| Fixture | `scripts/dev/run-shell-logger-fixture.sh` |
| Verification recipe | `just shell-logger-fixture` |

## Implementation Summary

`scripts/dev/hcs-shell-logger.sh` logs invocation shape, then execs the real
shell with the original argv. The real shell defaults to `/bin/bash` and can be
overridden with `HCS_SHELL_LOGGER_REAL_SHELL` for fixture testing.

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

## Interpretation

P06 is now ready for a separate host-routing operation proof. The in-repo
wrapper is suitable for review because it preserves original shell argv while
redacting command payloads from persisted logs.

Host-wide installation and live surface routing remain open and should be
approved separately because they can affect shell invocation behavior outside
this repo.

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
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-04-26 | Initial P06 wrapper implementation and fixture result. |
