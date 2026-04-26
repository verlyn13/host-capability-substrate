---
title: P06 Shell Wrapper Logger Preparation
category: research
component: host_capability_substrate
status: partial
version: 1.1.0
last_updated: 2026-04-26
tags: [phase-1, p06, shell-wrapper, redaction, fixture]
priority: high
---

# P06 Shell Wrapper Logger Preparation

Partial evidence for shell/environment research prompt P06: shell binary and
invocation-form validation per execution surface.

This memo records the in-repo wrapper implementation, regression fixture, and
approved host installation. It does **not** change `$SHELL`, modify `PATH`, or
route any live agent surface through the wrapper.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26 |
| macOS | 26.4.1, build 25E253 |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| Wrapper | `scripts/dev/hcs-shell-logger.sh` |
| Fixture | `scripts/dev/run-shell-logger-fixture.sh` |
| Installed wrapper | `/usr/local/bin/hcs-shell-logger` |
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

## Host Install Result

The reviewed wrapper was installed to `/usr/local/bin/hcs-shell-logger` after
the direct install attempt failed with `Permission denied` and the approved
`sudo install` path succeeded.

Observed result:

- installed path: `/usr/local/bin/hcs-shell-logger`
- mode/owner: `-rwxr-xr-x`, `root:wheel`
- repo-vs-installed comparison: `cmp` exit `0`
- SHA-256 for both repo script and installed wrapper:
  `5321eb6f3a22a04a4863c14826a71d558a0034c399269b4f8e80a7a247670847`

## Interpretation

P06 is now ready for a separate live-surface routing operation proof. The
installed wrapper matches the reviewed repo script and preserves original shell
argv while redacting command payloads from persisted logs.

Live surface routing remains open and should be approved separately because it
can affect shell invocation behavior outside this repo.

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
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.1.0 | 2026-04-26 | Added approved host-install result for `/usr/local/bin/hcs-shell-logger`. |
| 1.0.0 | 2026-04-26 | Initial P06 wrapper implementation and fixture result. |
