---
adr_number: 0023
title: Evidence base shape
status: accepted
date: 2026-05-01
charter_version: 1.2.0
tags: [evidence, ontology, provenance, freshness, authority, phase-1, q-011]
---

# ADR 0023: Evidence base shape

## Status

accepted

## Date

2026-05-01

## Charter version

Written against charter v1.2.0.

## Context

`Evidence` is one of the 20 core Ring 0 entities in the HCS ontology. The
current schema slice does not yet implement the full entity. Instead,
`packages/schemas/src/common.ts` has a small `evidenceRefSchema` described as a
temporary provenance reference "until the full Evidence entity lands."

Q-011 approved the ontology promotion and receipt dedupe rule. That approval
made the full `Evidence` base shape a prerequisite for accepting any
`Evidence` subtype envelope such as ADR 0022's proposed `BoundaryObservation`.
The same base contract is also needed before Q-006 source-control receipts,
Q-005 runner/check receipts, Q-008 execution receipts, and Q-009 diagnostic
observations can converge on one provenance model.

The pressure is simple: every observed fact needs source, observed time,
freshness, authority, parser version, and confidence. Without one base shape,
each domain will reinvent those fields and HCS will lose the ability to compare
facts across execution contexts, credential surfaces, Git/GitHub surfaces,
runner surfaces, app boundaries, and dashboard views.

This ADR records the architecture posture only. It does not add Zod schemas,
generated JSON Schema, policy tiers, hooks, adapters, dashboard routes, runtime
probes, or mutation operations. Schema implementation must later use the
`hcs-schema-change` workflow and move Zod source, generated JSON Schema,
ontology docs, tests, and fixtures together.

## Options considered

### Option A: Keep embedded evidence_refs as the only contract

**Pros:**
- Minimal schema churn.
- The current shell/env schema slice already parses.
- Avoids designing the full entity before all evidence subtypes are known.

**Cons:**
- Leaves no canonical place for payload, subject, freshness, parser, or
  authority semantics.
- Lets `BoundaryObservation`, Git receipts, runner receipts, and diagnostics
  each define provenance differently.
- Keeps `evidence_refs` doing more work than a reference object should do.
- Makes sandbox-authority downgrade harder to enforce consistently.

### Option B: Define Evidence as the canonical fact base entity first

**Pros:**
- Matches the existing ontology and Q-011 dependency order.
- Gives every observation, receipt, and future evidence subtype one provenance
  and freshness contract.
- Keeps authority comparison centralized, including sandbox downgrade behavior.
- Lets `evidenceRefSchema` narrow into a true reference while the full entity
  carries the complete fact record.

**Cons:**
- Requires one more Ring 0 schema before `BoundaryObservation` can be accepted.
- Forces later schema work to reconcile existing embedded provenance fields.
- Requires dashboard and policy consumers to tolerate missing, stale, and
  lower-authority facts explicitly.

### Option C: Let every evidence subtype own its provenance fields

**Pros:**
- Domain payloads can evolve independently.
- Short-term implementation may be faster for one domain at a time.
- Specialized receipts can express exact provider needs.

**Cons:**
- Duplicates source, freshness, authority, parser, and confidence semantics.
- Makes cross-domain policy and dashboard behavior brittle.
- Risks adapter-specific evidence shapes leaking into Ring 0.
- Undercuts Q-011's dedupe rule before it can do useful work.

### Option D: Promote every repeated fact into a standalone entity

**Pros:**
- Durable identity is explicit for every named concept.
- Lifecycle and ownership can be modeled directly.
- Could make some dashboard inventories easy to query.

**Cons:**
- Overstates the lifecycle of freshness-bound observations.
- Duplicates core entities such as `ExecutionContext`, `CredentialSource`,
  `WorkspaceContext`, `ResolvedTool`, and future evidence subtypes.
- Makes stale observations look like mutable state instead of expiring facts.
- Expands Ring 0 before Phase 1 schema reconciliation is complete.

## Decision

Define `Evidence` as the canonical Ring 0 fact base entity before
accepting any `Evidence` subtype envelope. Every evidence record must carry, at
minimum, `source`, `observed_at`, `valid_until`, `authority`,
`parser_version`, and `confidence`, plus a stable evidence identifier and schema
version. Evidence subtypes and receipts inherit or wrap this base contract.
`evidenceRefSchema` should remain a lightweight reference or embedded
provenance shim during migration; it is not a competing substitute for the full
entity.

Candidate minimum fields for later schema work:

```text
schema_version
evidence_id
evidence_kind = observation | receipt | derived | human_decision | fixture
subject_refs
source
source_ref optional
observed_at
valid_until
authority
confidence
parser_version
producer optional
host_id optional
workspace_id optional
execution_context_id optional
session_id optional
run_id optional
payload_schema_version optional
payload optional
redaction_mode optional
```

Field-block conventions:

- `source`, `observed_at`, `valid_until`, `authority`, `parser_version`, and
  `confidence` are required on every evidence record.
- `valid_until` records gateability freshness, not necessarily historical truth.
  A point-in-time receipt may prove that an event happened while still becoming
  stale for future gate decisions.
- `authority: sandbox-observation` cannot be promoted to a stronger authority
  without a separate non-sandbox evidence record.
- When `authority` is `sandbox-observation`, the evidence must be traceable to
  the sandboxed source. Schema implementation should require an
  `execution_context_id` plus at least one concrete trace reference such as
  `session_id`, `run_id`, or `source_ref`. Sandbox-sourced data must be written
  at `sandbox-observation` authority; a stronger authority requires a separate
  non-sandbox evidence record.
- Evidence payloads may contain redacted, classified, hashed, or reference-only
  data. They must not contain raw secret material.
- `subject_refs` names what the evidence is about. Domain-specific subtypes may
  require narrower subject references such as `execution_context_id`,
  `credential_source_id`, `workspace_id`, or provider object references.
- `parser_version` is required even for human or fixture sources; those producers
  use explicit parser labels rather than omitting the field.
- `evidenceRefSchema` should eventually reference `Evidence` records by ID and
  may carry a small provenance preview for embedded fixtures. It should not grow
  into a second full evidence object.

The field names and enum values remain candidates until schema implementation
review.

## Consequences

### Accepts

- `Evidence` becomes the base contract for observations, receipts, and future
  evidence subtype envelopes.
- ADR 0022's `BoundaryObservation` remains gated until this base shape is
  accepted and implemented.
- This ADR acceptance is not, by itself, the full Q-011 prerequisite for accepting
  `BoundaryObservation`; the Evidence base entity must still land through the
  schema-change workflow before evidence subtype envelopes are accepted.
- Q-006 source-control receipts, Q-005 runner/check receipts, Q-008 execution
  receipts, and Q-009 diagnostics should reuse the same base provenance
  semantics.
- Dashboard and policy consumers must handle stale, missing, contradictory, and
  lower-authority evidence explicitly.
- `evidenceRefSchema` remains acceptable as transitional embedded provenance,
  but only as a reference/shim.

### Rejects

- Treating `evidence_refs` as the permanent fact model.
- Letting each domain define its own incompatible provenance contract.
- Treating sandbox observations as host-authoritative evidence.
- Storing raw secret values in Ring 0 evidence payloads.
- Accepting `BoundaryObservation` or any other evidence subtype envelope before
  the base `Evidence` entity is defined.
- Adding schema code, generated JSON Schema, policy tiers, hooks, adapters,
  dashboard routes, runtime probes, or mutation operations as part of this ADR.

### Future amendments

- Reopen if Q-003 decides authored coordination facts should specialize
  `Evidence` instead of remaining peer authored artifacts.
- Reopen if Q-005 runner/check evidence or Q-006 source-control receipts prove
  that receipts need a narrower base contract than observations.
- Reopen if ADR 0022 changes the evidence envelope versioning model after
  ontology review.
- Reopen if security review finds the payload/redaction model still permits
  secret-shaped material to persist in Ring 0.
- Reopen if schema implementation shows `evidenceRefSchema` cannot migrate
  cleanly to references without breaking fixtures.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0,
  invariants 5, 8, 10, 13, 14, and 15
- Decision ledger: `DECISIONS.md` Q-003, Q-005, Q-006, Q-007, Q-008, Q-009,
  Q-010, and Q-011
- Human decision report:
  `docs/host-capability-substrate/human-decision-report-2026-05-01.md`
- Ontology reference:
  `docs/host-capability-substrate/ontology.md`
- Temporary provenance schema:
  `packages/schemas/src/common.ts`
- ADR 0015:
  `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
- ADR 0016:
  `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- ADR 0017:
  `docs/host-capability-substrate/adr/0017-codex-app-execution-context.md`
- ADR 0018:
  `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
- ADR 0020:
  `docs/host-capability-substrate/adr/0020-version-control-authority.md`
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- No external specification is authoritative for this ADR. The decision is
  grounded in HCS charter invariants, ontology planning, and local Phase 1
  evidence intake.
