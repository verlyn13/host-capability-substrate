---
adr_number: 0008
title: Dashboard authentication — short-lived token, localhost-bound
status: proposed
date: 2026-04-22
charter_version: 1.1.0
tags: [dashboard, auth, localhost, 1password]
---

# ADR 0008: Dashboard authentication — short-lived token, localhost-bound

## Context

Dashboard is the canonical approval surface (Phase 4). Must be human-identity-attributable, not bypass-able by another agent on the host. Per boundary decision §3, dashboard tokens live in 1Password.

## Decision

- **Binding:** `127.0.0.1` only.
- **Authentication:** short-lived tokens issued via `op run --env-file=` at client launch.
- **Token storage:** 1Password (`op://Dev/host-capability-substrate/dashboard-token`).
- **Rotation:** automatic on a time window (TBD; likely daily).

## Consequences

### Accepts

- Dashboard requires `op` integration at client launch (chezmoi-managed wrapper).
- No remote dashboard exposure in Phase 0-4.

### Rejects

- Remote dashboard exposure without a separate ADR.
- Shared secret baked into client config.

### Future amendments

- MCP elicitation URL mode may augment dashboard for in-client approval (opportunistic).

## References

### Internal

- Research plan §§12, 15
- Decision ledger: D-015

### External

- [MCP Elicitation](https://modelcontextprotocol.io/specification/2025-11-25/client/elicitation)
