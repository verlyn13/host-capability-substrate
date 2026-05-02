---
adr_number: 0024
title: Charter v1.3.0 wave-2 and wave-3 enforcement plumbing
status: accepted
date: 2026-05-02
charter_version: 1.3.1
tags: [charter, enforcement, boundary-observation, execution-context, security, phase-1]
---

# ADR 0024: Charter v1.3.0 wave-2 and wave-3 enforcement plumbing

## Status

accepted

## Date

2026-05-02

## Charter version

Written against charter v1.3.1. Authorizes the prior v1.3.1 wave-2 changes
retroactively and the v1.3.2 wave-3 changes prospectively.

## Context

ADR 0021 authorized charter v1.3.0 wave-1 — invariants 16 (external-control-
plane evidence-first) and 17 (execution-context declared, not inferred) — under
a charter-and-bookkeeping-only scope. Wave-1 landed in commit `7012678` as
invariant text only, with boundary-enforcement bullets and forbidden-pattern
entries explicitly deferred.

The post-merge `hcs-architect` review on commit `fd60f5f` identified the
absence of enforcement plumbing as the first invariant wave in HCS history to
ship without supporting bullets, and recommended a wave-2 follow-up PR. Wave-2
landed in commit `f9e30d4` as charter v1.3.1, adding 3 boundary-enforcement
bullets and 6 forbidden-pattern entries.

The post-merge `hcs-policy-reviewer` review on `f9e30d4` recorded wave-2 as
defensible under ADR 0021's continuing authority, with no escalation holes or
forbidden-tier leaks, but recommended a thin ADR to close the change-policy
compliance question. The post-merge `hcs-security-reviewer` review on the same
commit identified six material gaps warranting a v1.3.2 patch in the same
cadence: cross-context evidence reuse, fabricated `BoundaryObservation`
records, `ExecutionContext` misclassification, surface-enumeration omissions,
inheritance-dimension omissions, and a self-implemented-backoff residual on
the rate-limit forbidden pattern.

This ADR records the authority for wave-2 (already landed in v1.3.1) and
wave-3 (landing in v1.3.2 alongside this ADR).

## Options considered

### Option A: No ADR; rely on ADR 0021 continuing authority for both waves

**Pros:**
- Minimal documentation churn.
- Defensible per the policy reviewer's reading of ADR 0021's scope.

**Cons:**
- Leaves the change-policy compliance question open. Charter §Change policy
  says "Amendments require an ADR"; relying on ADR 0021 to cover unrelated
  follow-on amendments stretches its original scope.
- Future readers do not have a single authority record for the wave-2/wave-3
  enforcement amendments.

### Option B: One ADR per wave (separate ADRs for v1.3.1 and v1.3.2)

**Pros:**
- Clean per-wave attribution.
- Each ADR is narrowly scoped.

**Cons:**
- Proliferates ADRs for what is effectively one amendment cycle.
- The wave-2 ADR would itself be retroactive, which is an unusual ADR pattern
  if the wave already landed.

### Option C: One ADR for the v1.3.0 amendment cycle covering wave-2 and wave-3

**Pros:**
- Records continuing authority for both waves in a single document.
- Makes the wave-1 → wave-2 → wave-3 progression visible as one cycle.
- Pragmatic and matches the cadence the post-merge reviewers recommended.

**Cons:**
- Combines retroactive (wave-2) and prospective (wave-3) authority in one
  ADR, which requires careful scoping to avoid implying the same pattern is
  acceptable for invariant changes (which it is not).

## Decision

Choose Option C. ADR 0024 is the authority for charter v1.3.0 wave-2 (already
landed in v1.3.1) and wave-3 (landing in v1.3.2). Both waves operationalize
invariants 16 and 17 without changing invariant text. Both remain
charter-and-bookkeeping-only per ADR 0021's original scope discipline.

### Wave-2 scope (v1.3.1, retroactive)

Per the post-merge `hcs-architect` review on `fd60f5f`. Already landed in
commit `f9e30d4`:

- 3 boundary-enforcement bullets:
  - `OperationShape` carries a resolved `ExecutionContext` reference;
  - capabilities with `provider_kind != "local"` declare typed evidence
    requirements consumed by the gateway;
  - `OperationShape` and `CommandShape` arguments distinguish
    `ProviderObjectReference`, `PublicClientId`, `PolicySelectorValue`,
    `SecretReference`, and raw secret material as separate typed slots.
- 6 forbidden-pattern entries covering: rate-limit-as-retry-trigger;
  conflated provider/credential/secret references; mutation against
  separable validators without binding evidence; `OperationShape` lacking
  `ExecutionContext`; parent-context capability inheritance without typed
  evidence; surface-specific operators (Codex `inherit` / `include_only` and
  equivalents) treated as authority proof.

### Wave-3 scope (v1.3.2, prospective)

Per the post-merge `hcs-security-reviewer` review on `f9e30d4`. Closes
material gaps identified by that review:

- New forbidden pattern: cross-context evidence reuse — using a
  `BoundaryObservation` whose target reference does not match the consuming
  `OperationShape`'s execution context as evidence for that operation.
- New forbidden pattern: fabricated `BoundaryObservation` (or other evidence
  subtype envelope) records claiming an `authority` value the producer cannot
  justify with provenance.
- New forbidden pattern: `ExecutionContext` records whose sandbox profile,
  env-inheritance mode, or surface kind is materially inconsistent with the
  observed runtime.
- Extension of the v1.3.1 parent-context-inheritance surface enumeration to
  add Warp, Zed external agent, Cursor, Windsurf, JetBrains AI Assistant,
  GitHub Copilot CLI, and launchd `EnvironmentVariables`.
- Extension of the v1.3.1 parent-context-inheritance dimension list to add
  egress policy, filesystem authority, and `BoundaryObservation` records
  themselves.
- Tightening of the v1.3.1 rate-limit-as-retry-trigger forbidden pattern to
  cover both immediate retry and agent-self-implemented backoff, and to
  require a `Decision` record referencing the recorded observation by
  `evidence_id`.

### Out of scope for this ADR

This ADR does not authorize:

- New invariants (charter v1.4.0+ requires a separate ADR per the change
  policy).
- Schema, kernel, adapter, dashboard, runtime probe, mutation operation, or
  policy-tier work landing in the same PRs as the charter changes.
- Any retroactive change to the text of invariants 16 or 17 (those were
  accepted under ADR 0021).
- Domain-payload schemas for boundary dimensions (Q-007 work).
- The CI plumbing that implements the boundary-enforcement bullets — that
  lands in separate kernel/CI PRs once the supporting schema exists.

## Consequences

### Accepts

- Waves 2 and 3 are documented authority within the v1.3.0 amendment cycle.
- The change-policy compliance question raised by the `hcs-policy-reviewer`
  is closed: ADR 0024 is the authority for both follow-on waves.
- Wave-3 is bounded to the security-reviewer-flagged gaps; no additional
  invariant or forbidden-pattern surface lands without further review.
- Charter v1.3.1 and v1.3.2 prose is binding from acceptance; CI plumbing
  follows when the supporting schema lands.
- Future invariant amendments (charter v1.4.0+) require their own ADR,
  not this one.

### Rejects

- Folding schema, kernel, adapter, dashboard, or mutation work into wave-2
  or wave-3 charter PRs.
- Treating ADR 0024 as continuing authority for any future wave-4 or beyond.
  If post-merge reviews on v1.3.2 identify additional gaps, a new ADR is
  required.
- Treating "or any equivalent operator" in the parent-context-inheritance
  forbidden pattern as a license to omit named surfaces from the surface
  enumeration; the named list is an authority floor, not a ceiling.

### Future amendments

- A wave-4 may be needed if subsequent post-merge reviews on v1.3.2 surface
  additional gaps. Track in PLAN.md until justified by an observed incident
  or a new reviewer finding.
- Domain-payload schemas for boundary dimensions remain Q-007 work; that is
  not authorized by this ADR.
- The "any Ring 0 entity payload that participates in the audit hash chain"
  scope extension that the security reviewer suggested for the
  secret-conflation forbidden pattern is queued for review when the audit
  hash chain ships.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.3.1
  (this ADR brings it to v1.3.2)
- ADR 0021:
  `docs/host-capability-substrate/adr/0021-charter-v1-3-wave-1.md`
  (originating authority for invariants 16 and 17)
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (envelope shape that wave-2/wave-3 enforcement plumbing relies on)
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract that boundary observations subtype)
- DECISIONS.md Q-012 (charter v1.3 wave-1 approval)
- Wave-1 commit: `7012678` (charter v1.3.0)
- Wave-2 commit: `f9e30d4` (charter v1.3.1)
- Wave-2 motivating review: post-merge `hcs-architect` review on commit
  `fd60f5f`, recorded in conversation 2026-05-02
- Wave-3 motivating review: post-merge `hcs-security-reviewer` review on
  commit `f9e30d4`, recorded in conversation 2026-05-02
- Wave-2 change-policy reading: post-merge `hcs-policy-reviewer` review on
  commit `f9e30d4`, recorded in conversation 2026-05-02

### External

- No external specification is authoritative for this ADR. The decision is
  grounded in HCS charter invariants, the v1.3.0 amendment cycle, and local
  Phase 1 reviewer findings.
