---
title: HCS Dashboard Contracts
category: reference
component: host_capability_substrate
status: stub
version: 0.1.0
last_updated: 2026-04-22
tags: [dashboard, view-models, contracts]
priority: medium
---

# HCS Dashboard Contracts

View-model contracts for the read-only dashboard. Populated during Phase 3 when the dashboard ships; stubbed at Phase 0a so kernel code must produce dashboard-renderable output from day 1.

## View models

From research plan §12:

- `DashboardSummary`
- `LiveSessionRow`
- `HostFactCard`
- `ToolResolutionTrace`
- `PolicyDecisionCard`
- `OperationProposalCard`
- `AuditTimelineEvent`
- `CacheEntryCard`
- `LeaseRow`
- `HealthStatus`

## Minimum views (read-only, Phase 3)

```
/health                      kernel version, DB status, policy version, degraded state
/sessions                    current sessions and clients
/tools                       recent tool resolutions and help cache status
/policy                      recent classifications and why
/audit                       recent events, read-only
/dashboard-summary.json      same data exposed to system.dashboard.summary.v1
```

## Invariants

- Dashboard does not bypass policy. It calls the same gateway as every adapter.
- Dashboard is the canonical approval surface (Phase 4).
- Dashboard is local (127.0.0.1) and token-gated.
- View contracts are embeddable in MCP Apps later; canonical dashboard remains local.

## Populated by

- Phase 3 Milestone 5 — gateway propose + dashboard summary

## References

- Research plan §12
- Charter invariant 7 (execute lane gated on full stack including dashboard)

## Change log

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-04-22 | Initial stub. |
