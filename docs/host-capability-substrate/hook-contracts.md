---
title: HCS Hook Contracts
category: reference
component: host_capability_substrate
status: stub
version: 0.1.0
last_updated: 2026-04-22
tags: [hooks, claude-code, codex, policy, contracts]
priority: medium
---

# HCS Hook Contracts

Defines how hooks interact with the HCS substrate. Populated in Phase 3 when the kernel exposes `system.tool.resolve.v1` and `system.policy.classify_operation.v1`. At Phase 0a, hooks log only.

## Phase 0a (log-only)

`.claude/hooks/hcs-hook` script:

- Reads JSON event from stdin
- Writes to `.logs/phase-0/hook-events.jsonl`
- Blocks only on literal forbidden patterns (SIP, Gatekeeper, `rm -rf /`, etc.)
- Exit codes:
  - 0 → allow
  - 1 → log and continue (advisory)
  - 2 → block with stderr reason

## Phase 3+ (RPC to substrate)

Hook upgrades to:

- Call `system.tool.resolve.v1` with 50ms timeout + cache fallback
- Call `system.policy.classify_operation.v1` with 50ms timeout + cache fallback
- Classification `read-safe` → allow
- Classification `write-local` / `write-project` → allow with warning
- Classification `write-host` → ask (substrate not yet running execute lane)
- Classification `write-destructive` or `forbidden` → block
- Fail-open for reads (warn + allow on timeout or substrate-unreachable)
- Fail-closed for writes (deny when command is confidently mutating/destructive and substrate can't classify)

## Phase 4+ (gateway integration)

Hook additionally:

- Proposes via `system.gateway.propose.v1`
- Consumes `ApprovalGrant` via `system.gateway.consume_grant.v1`
- Records pass-through events in audit log

## Codex hooks

Advisory only. Bash-only coverage per D-007. Codex hook logs + warns; substrate enforces.

## Populated by

- Phase 3 — hooks connected to substrate
- `hcs-hook-integrator` subagent maintains

## References

- Research plan §22.8 (implementation-phase hook strategy)
- Charter invariants 1 (no policy in adapters), 4 (audit internal)
- Boundary decision §11 (stage-by-stage config)
- D-005, D-006, D-007 in `DECISIONS.md`

## Change log

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-04-22 | Initial stub. |
