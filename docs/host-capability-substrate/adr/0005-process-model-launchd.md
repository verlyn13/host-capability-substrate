---
adr_number: 0005
title: Process model — launchd LaunchAgent
status: accepted
date: 2026-04-22
charter_version: 1.1.0
tags: [launchd, process-model, reverse-dns]
---

# ADR 0005: Process model — launchd LaunchAgent

## Context

HCS is always-on. macOS-native process management is launchd. LaunchAgent (user scope) is appropriate since HCS is user-bound, not system-level.

## Decision

- **Scheme:** LaunchAgent under `~/Library/LaunchAgents/`
- **Label:** `com.jefahnierocks.host-capability-substrate` (reverse-DNS)
- **`RunAtLoad`:** true
- **`KeepAlive`:** true
- **`ThrottleInterval`:** 10s
- **Stdout/Stderr:** `$HCS_LOG_DIR/stdout.log`, `$HCS_LOG_DIR/stderr.log`
- **State:** `$HCS_STATE_DIR` (`~/Library/Application Support/host-capability-substrate/`)
- **Install:** `scripts/install/install-launchd.sh` renders the template and `launchctl bootstrap`s it. Deprecated `launchctl load`/`unload` are forbidden (charter invariant 11).

## Consequences

### Accepts

- macOS-native lifecycle; survives sleep/wake/login cycles.
- User-scoped (no sudo, no system domain).

### Rejects

- System-domain LaunchDaemon (unnecessary for a user-bound service).
- Third-party service managers.

### Future amendments

- Hardening (e.g., sandboxing via macOS sandbox-exec) in a later ADR if justified.

## References

### Internal

- Research plan §§22.11, 22.12
- Boundary decision §4 (runtime paths)
- Decision ledger: `DECISIONS.md` entry D-020

### External

- `launchctl(1)` bootstrap/bootout semantics
