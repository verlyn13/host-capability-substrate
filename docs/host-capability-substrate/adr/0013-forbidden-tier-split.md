---
adr_number: 0013
title: Forbidden tier split and non-escalable denials
status: accepted
date: 2026-04-26
charter_version: 1.2.0
tags: [policy, forbidden, gateway, traps]
---

# ADR 0013: Forbidden tier split and non-escalable denials

## Context

Phase 0b showed that one broad `forbidden` bucket hides important differences:
deprecated syntax, macOS security bypasses, secret disclosure, load-bearing
state deletion, and missing evidence are not the same failure. The policy layer
needs reason-coded denials while preserving charter invariant 6:
`forbidden` is non-escalable.

## Options considered

### Option A: Keep one flat `forbidden` tier

**Pros:**
- Simple.
- Matches current Phase 0b classifier vocabulary.

**Cons:**
- Hard to explain denials in dashboard cards.
- Hard to write targeted regression traps.
- Encourages accidental approval paths because all severe cases look alike.

### Option B: Split `forbidden` into reason-coded non-escalable subtypes

**Pros:**
- Preserves non-escalability.
- Makes dashboard and audit explanations precise.
- Lets traps #16, #18, and #37 map to different failure families.

**Cons:**
- Requires schema and policy-loader work in Phase 1/2.
- More cases to document and test.

### Option C: Move severe cases into `write-destructive` with approval

**Pros:**
- Reuses an existing approvable tier.

**Cons:**
- Violates charter invariant 6 for truly forbidden operations.
- Would make secret echo or SIP-disable look human-overridable at the gateway.

## Decision

Split forbidden outcomes into reason-coded non-escalable denials while keeping
the public decision class `forbidden`. Initial reason families are:

- `deprecated_syntax`
- `host_security_bypass`
- `secret_disclosure`
- `load_bearing_state_deletion`
- `policy_source_violation`
- `missing_required_authority`

`write-host` and `write-destructive` remain approvable classes only when the
operation is otherwise valid and has the required evidence. A forbidden reason
never gains an `approval_required_for` path.

## Consequences

### Accepts

- Policy schemas and dashboard cards need a reason field.
- Regression traps can assert both class and reason.
- Hooks may carry only minimal literal patterns until the kernel policy service
  exists; canonical classification remains Ring 1.

### Rejects

- Human override for forbidden operations.
- Copying full policy tiers into hooks, adapters, or client config.
- Downgrading secret disclosure to advisory warning.

### Future amendments

- If OPA adoption occurs, forbidden reason families become policy outputs rather
  than hand-coded classifier constants.
- If a reason family becomes too broad, split it in a schema-versioned policy
  change.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0,
  invariants 1, 6, 13, 14, 15
- Decision ledger: `DECISIONS.md` D-025, D-026, D-032
- Regression seed corpus: `packages/evals/regression/seed.md`
- Research plan: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` §18, §22

### External

- N/A
