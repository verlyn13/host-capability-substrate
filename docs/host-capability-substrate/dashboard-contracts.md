---
title: HCS Dashboard Contracts
category: reference
component: host_capability_substrate
status: stub
version: 0.2.2
last_updated: 2026-05-01
tags: [dashboard, view-models, contracts, source-control, github, evidence, boundary-observation]
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
- `VersionControlPosture` (candidate from Q-006 / ADR 0020)

## Minimum views (read-only, Phase 3)

```
/health                      kernel version, DB status, policy version, degraded state
/sessions                    current sessions and clients
/tools                       recent tool resolutions and help cache status
/policy                      recent classifications and why
/audit                       recent events, read-only
/dashboard-summary.json      same data exposed to system.dashboard.summary.v1
```

## Candidate source-control posture view

Status: Phase 1 planning only. This does not add a dashboard route, schema, API
endpoint, policy tier, or GitHub mutation. It records the read model that Q-006
and ADR 0020 need the dashboard to make visible before source-control mutation
operations can exist.

Candidate route:

```text
/source-control              Git/GitHub authority posture, read-only
```

Candidate `VersionControlPosture` payload:

```json
{
  "schema_version": "0.1.0-proposed",
  "observed_at": "2026-05-01T00:00:00Z",
  "repository": {
    "workspace_id": "host-capability-substrate",
    "repo_root": "/path",
    "remote_url": "git@github.com:owner/repo.git",
    "default_branch": "main",
    "head_sha": "sha",
    "dirty_state": "clean|dirty|unknown",
    "evidence_ids": []
  },
  "protection": {
    "state": "fresh|stale|missing|contradictory|unknown",
    "rulesets": [],
    "branch_protection": [],
    "required_reviews": "present|missing|unknown",
    "admin_bypass": "allowed|disallowed|unknown",
    "force_push": "disabled|enabled|unknown",
    "deletion": "disabled|enabled|unknown",
    "evidence_ids": []
  },
  "required_checks": [
    {
      "name": "check-name",
      "expected_source": "github-app-or-workflow-source",
      "last_observed_sha": "sha",
      "conclusion": "success|failure|neutral|skipped|cancelled|unknown",
      "freshness": "fresh|stale|missing|unknown",
      "evidence_ids": []
    }
  ],
  "actions": {
    "default_token_permissions": "read|write|none|unknown",
    "workflow_policy": "pinned|mixed|unpinned|unknown",
    "runner_classes": ["github-hosted"],
    "pull_request_target": "present|absent|unknown",
    "oidc_use": "present|absent|unknown",
    "evidence_ids": []
  },
  "credentials": [
    {
      "surface": "gh|ssh|git-signing|github-app|actions-token|oidc|mcp-pat|mcp-oauth|agent-app",
      "principal": "redacted-or-reference",
      "scope_summary": "read-only|write|admin|unknown",
      "health": "healthy|degraded|unknown",
      "evidence_ids": []
    }
  ],
  "worktrees": [
    {
      "path": "/path",
      "branch": "main",
      "locked": false,
      "lease_id": null,
      "dirty_state": "clean|dirty|unknown",
      "evidence_ids": []
    }
  ],
  "cleanup_proposals": [
    {
      "target_ref": "refs/heads/example",
      "proof_status": "complete|incomplete|blocked|unknown",
      "missing_proof": ["BranchDeletionProof"],
      "evidence_ids": []
    }
  ]
}
```

Display rules:

- Show missing, stale, and contradictory evidence explicitly; do not hide it
  behind a green summary.
- A check row is not gateable unless the expected source, commit SHA, workflow
  or provider source, conclusion, and freshness are all present.
- Branch cleanup rows show proof status, not just branch names.
- Credential rows stay separated by authority surface. A healthy `gh` row does
  not imply SSH, MCP, Actions, or web-agent authority.
- Dashboard display is read-only until the approval/audit/dashboard/lease stack
  exists. Source-control mutations remain blocked by charter invariant 7.

## Candidate Capability State Vocabulary

Status: Phase 1 planning only. This vocabulary is for future per-surface
capability rows such as Codex app Keychain/filesystem/network, runner
containment, remote-agent environment, or source-control posture facets.

Use seven visible states:

- `proven`: evidence for this exact surface/version is fresh and supports the
  row.
- `denied`: evidence for this exact surface/version is fresh and rejects the
  capability.
- `pending`: the capability or dimension applies, but no valid observation path
  or receipt exists yet.
- `stale`: a prior observation exists, but its freshness window expired or a
  material version/build/dependency update requires re-observation.
- `contradictory`: two or more fresh-enough observations disagree and need
  reconciliation.
- `inapplicable`: the capability does not apply to that surface.
- `unknown`: HCS does not yet know whether the capability or dimension applies
  to that surface.

Dashboard code must not collapse `pending`, `stale`, `denied`,
`contradictory`, `unknown`, and `inapplicable` into one null/false state. Views
may display a subset only when the subset is explicitly mapped back to this
seven-state vocabulary.

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
| 0.2.2 | 2026-05-01 | Expanded candidate capability states from five to seven to align with ADR 0022 boundary observations. |
| 0.2.1 | 2026-05-01 | Added candidate per-surface capability state vocabulary for pending/stale/denied/inapplicable distinctions. |
| 0.2.0 | 2026-05-01 | Added candidate Q-006 source-control posture view model for future read-only dashboard planning. |
| 0.1.0 | 2026-04-22 | Initial stub. |
