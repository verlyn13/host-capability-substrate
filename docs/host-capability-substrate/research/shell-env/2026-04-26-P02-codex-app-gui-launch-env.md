---
title: P02 Codex App GUI Launch Environment Probe
category: research
component: host_capability_substrate
status: validated
version: 1.1.0
last_updated: 2026-04-26
tags: [phase-1, p02, codex-app, launch-services, environment]
priority: high
---

# P02 Codex App GUI Launch Environment Probe

Evidence for shell/environment research prompt P02: determine whether a Codex
app session launched from a GUI surface inherits terminal-local environment
variables.

This memo records two observations:

- Terminal `open -n` is not a valid GUI-origin proxy on this host because it
  forwarded a synthetic terminal-local marker into a new Codex app process.
- A true Finder-origin cold start did **not** inherit a synthetic terminal-only
  marker from the helper process that sent the Finder AppleEvent.

No credential-shaped variable names were used. No environment values were
printed. The only environment observation was a present/absent check for the
synthetic marker names.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26 |
| macOS | 26.4.1, build 25E253 |
| Codex app | `/Applications/Codex.app` |
| Codex app version | `26.422.30944` |
| Codex app build | `2080` |
| Existing Codex main PID before first probe | `50075` |
| Finder-cold-start Codex main PID | `53495` |

## Evidence Summary

| Probe | Result |
|---|---|
| Existing Codex app process | One main Codex process was already running before the first probe: PID `50075`. |
| Terminal launch attempt | `/usr/bin/env HCS_P02_TERMINAL_ONLY_MARKER_20260426=<synthetic> /usr/bin/open -n -a /Applications/Codex.app` started a second Codex main process: PID `21647`. |
| Redacted process-env check | A filtered `ps eww -p 21647` check printed only `p02_marker_present=true`. |
| Cleanup | The probe process PID `21647` was terminated. The pre-existing Codex PID `50075` remained running. |
| Cold-start preflight | `launchctl getenv HCS_P02_GUI_COLD_MARKER_20260426` returned no value. |
| GUI-origin launch | The pre-existing Codex app process was quit, then Finder was asked to open `Codex.app` while the helper process carried only `HCS_P02_GUI_COLD_MARKER_20260426=<synthetic>`. |
| Finder-launched process | New Codex main process PID `53495`, parent PID `1`. |
| Finder-launch marker check | A filtered `ps eww -p 53495` check printed only `p02_gui_marker_present=false`. |
| Post-check state | Codex app remains running as PID `53495`; the synthetic marker was not added to launchd. |
| Raw evidence path | `.logs/phase-1/shell-env/2026-04-26/P02.jsonl` stores name-only JSONL records. |

## Interpretation

`open -n` from a terminal is not a safe stand-in for Spotlight, Dock, or Finder
launch behavior on this host. The synthetic terminal marker was visible to the
new Codex app process, which means this route behaves as a terminal-origin
launch for the purpose of P02.

The Finder-origin cold-start result resolves the local P02 claim for a real GUI
launch path: Codex app did not inherit the synthetic terminal-only marker. This
supports modeling the Codex app GUI launch environment as separate from
terminal-local shell exports.

This result should not be overextended to credential behavior beyond the tested
environment inheritance boundary. It does support the Phase 1 design rule that
HCS must not assume shell-exported variables such as `GITHUB_PAT` are available
to Codex app sessions launched from GUI surfaces.

## Follow-Up

1. Treat P02 as locally validated for Finder-origin cold launch on 2026-04-26.
2. Do not use terminal `open -n` as the GUI-launch proxy for future app-launch
   environment probes.
3. Retest on Codex app upgrades per charter invariant 14.
4. If a future run needs exact Spotlight parity, repeat the same present/absent
   probe with keyboard-driven Spotlight launch and the app fully quit first.

## Commands Used

Key commands used for evidence were read-only except for launching/quitting
Codex app probe processes:

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
  },
  {
    "file": "/usr/bin/launchctl",
    "argv": ["launchctl", "getenv", "HCS_P02_GUI_COLD_MARKER_20260426"]
  },
  {
    "file": "/usr/bin/osascript",
    "argv": ["/usr/bin/osascript", "-e", "tell application id \"com.openai.codex\" to quit"]
  },
  {
    "file": "/usr/bin/env",
    "argv": ["/usr/bin/env", "HCS_P02_GUI_COLD_MARKER_20260426=<synthetic>", "/usr/bin/osascript", "-e", "tell application \"Finder\" to open application file \"Codex.app\" of folder \"Applications\" of startup disk"]
  },
  {
    "file": "/usr/bin/pgrep",
    "argv": ["pgrep", "-fl", "/Applications/Codex.app/Contents/MacOS/Codex"]
  },
  {
    "file": "/usr/bin/ps",
    "argv": ["ps", "-o", "pid,ppid,comm,args", "-p", "53495"]
  },
  {
    "file": "/bin/zsh",
    "argv": ["/bin/zsh", "-lc", "if ps eww -p 53495 | tr ' ' '\\n' | rg -q '^HCS_P02_GUI_COLD_MARKER_20260426='; then printf 'p02_gui_marker_present=true\\n'; else printf 'p02_gui_marker_present=false\\n'; fi"]
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.1.0 | 2026-04-26 | Added true Finder-origin cold-start absence result. |
| 1.0.0 | 2026-04-26 | Initial partial P02 method-validation result. |
