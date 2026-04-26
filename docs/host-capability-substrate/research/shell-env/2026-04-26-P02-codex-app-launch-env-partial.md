---
title: P02 Codex App Launch Environment Partial Probe
category: research
component: host_capability_substrate
status: partial
version: 1.0.0
last_updated: 2026-04-26
tags: [phase-1, p02, codex-app, launch-services, environment]
priority: high
---

# P02 Codex App Launch Environment Partial Probe

Partial evidence for shell/environment research prompt P02: determine whether a
Codex app session launched from a GUI surface such as Spotlight, Dock, or Finder
inherits terminal-local environment variables.

This memo does **not** resolve the Spotlight/Dock/Finder question. It records a
method-validation result: launching Codex with terminal `open -n` on this host
forwarded a synthetic terminal-local marker into the new Codex app process, so
that launch path is not a valid proxy for a GUI-origin launch.

No credential-shaped variable names were used. No environment values were
printed. The only environment observation was a present/absent check for the
synthetic marker name.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26 |
| macOS | 26.4.1, build 25E253 |
| Codex app | `/Applications/Codex.app` |
| Codex app version | `26.422.30944` |
| Codex app build | `2080` |
| Existing Codex main PID before probe | `50075` |

## Evidence Summary

| Probe | Result |
|---|---|
| Existing Codex app process | One main Codex process was already running: PID `50075`. |
| Terminal launch attempt | `/usr/bin/env HCS_P02_TERMINAL_ONLY_MARKER_20260426=<synthetic> /usr/bin/open -n -a /Applications/Codex.app` started a second Codex main process: PID `21647`. |
| Redacted process-env check | A filtered `ps eww -p 21647` check printed only `p02_marker_present=true`. |
| Cleanup | The probe process PID `21647` was terminated. The pre-existing Codex PID `50075` remained running. |
| Raw evidence path | `.logs/phase-1/shell-env/2026-04-26/P02.jsonl` stores a name-only JSONL record. |

## Interpretation

`open -n` from a terminal is not a safe stand-in for Spotlight, Dock, or Finder
launch behavior on this host. The synthetic terminal marker was visible to the
new Codex app process, which means this route behaves as a terminal-origin
launch for the purpose of P02.

This result should not be inverted into a claim that Spotlight-launched Codex
inherits terminal-local variables. It only rules out one proposed observation
mechanism.

The expected P02 conclusion remains unverified on this host: a true
Spotlight/Dock/Finder cold launch is still expected to omit a marker that exists
only in a terminal shell, but that absence has not been captured yet.

## Follow-Up

1. Do not use terminal `open -n` as the GUI-launch proxy for P02.
2. Run a true GUI-origin cold-start probe after explicitly approving disruption
   to the active Codex app session, or choose a GUI automation path that starts
   Codex without inheriting the terminal process environment.
3. Keep the observation present/absent-only and use synthetic marker names, not
   credential-shaped names such as `GITHUB_PAT`.
4. Record whether the app was warm, cold-started, or already running before the
   GUI launch.

## Commands Used

Key commands used for evidence were read-only except for launching and cleaning
up the second Codex probe process:

```json
[
  {
    "file": "/usr/bin/pgrep",
    "argv": ["pgrep", "-fl", "/Applications/Codex.app/Contents/MacOS/Codex"]
  },
  {
    "file": "/usr/bin/env",
    "argv": ["/usr/bin/env", "HCS_P02_TERMINAL_ONLY_MARKER_20260426=<synthetic>", "/usr/bin/open", "-n", "-a", "/Applications/Codex.app"]
  },
  {
    "file": "/bin/zsh",
    "argv": ["/bin/zsh", "-lc", "if ps eww -p 21647 | tr ' ' '\\n' | rg -q '^HCS_P02_TERMINAL_ONLY_MARKER_20260426='; then printf 'p02_marker_present=true\\n'; else printf 'p02_marker_present=false\\n'; fi"]
  },
  {
    "file": "/bin/kill",
    "argv": ["kill", "-TERM", "21647"]
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-04-26 | Initial partial P02 method-validation result. |
