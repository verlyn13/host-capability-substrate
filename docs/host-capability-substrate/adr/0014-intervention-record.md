---
adr_number: 0014
title: InterventionRecord for human and substrate interventions
status: accepted
date: 2026-04-26
charter_version: 1.2.0
tags: [ontology, interventions, audit, evidence]
---

# ADR 0014: InterventionRecord for human and substrate interventions

## Context

Phase 0b produced several high-value events that were neither ordinary audit
events nor regular run artifacts: the aborted `rm -rf .logs` attempt, the
1Password IPC contention field report, the Codex process-inspection cleanup, and
Cloudflare MCP quarantine. These are interventions: a human or guardrail changed
the trajectory to prevent or contain harm.

Keeping interventions only in prose makes them hard to query, promote into
traps, or display in the dashboard.

## Options considered

### Option A: Store interventions only as markdown notes

**Pros:**
- Fast and human-readable.
- Already works in `.logs/phase-0/interventions/`.

**Cons:**
- Not queryable by policy or dashboard.
- No typed relationship to sessions, evidence, traps, or decisions.
- Easy to lose when `.logs/` is pruned.

### Option B: Model interventions as generic `Evidence`

**Pros:**
- Reuses the existing provenance model.
- Avoids adding another entity.

**Cons:**
- Blurs fact observations with operator actions.
- Does not capture intervention-specific fields like prevented operation,
  actor, trigger, containment, rollback, or follow-up trap.

### Option C: Add `InterventionRecord` as a Ring 0 entity

**Pros:**
- Keeps interventions first-class without exposing audit-write tools.
- Links sessions, evidence, decisions, and regression traps.
- Gives dashboard and weekly review a stable contract.

**Cons:**
- Adds a schema and persistence surface to Milestone 1/3 work.
- Requires redaction rules because intervention notes can mention sensitive
  operations.

## Decision

Add `InterventionRecord` as a Ring 0 entity candidate for Phase 1 schema work.
It records human, hook, sandbox, broker, quarantine, or policy interventions
with provenance and links to the triggering session/evidence/trap. It is not an
agent-callable audit-write endpoint; records are created by the kernel or by
trusted import of reviewed intervention notes.

Minimum fields:

- `schema_version`
- `intervention_id`
- `kind`
- `actor`
- `trigger_summary`
- `prevented_or_modified_operation`
- `evidence_ids`
- `session_id`
- `artifact_refs`
- `follow_up_trap`
- `observed_at`
- `authority`
- `redaction_status`

## Consequences

### Accepts

- Phase 1 schemas must reconcile `InterventionRecord` with `Evidence`,
  `Decision`, `Run`, and `Artifact`.
- Dashboard eventually gets an `/interventions` view.
- Regression trap authoring can cite typed intervention records rather than
  free-form logs.

### Rejects

- Treating interventions as unstructured memory.
- Agent-callable audit-write or intervention-write tools.
- Promoting sandbox observations to host-authoritative facts without verifier
  promotion.

### Future amendments

- If Q-003's coordination store lands, `InterventionRecord` may link to
  `CoordinationFact` promotion workflows.
- If audit chain schema can represent interventions directly without coupling,
  this ADR can be narrowed to a typed audit-event subtype.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0,
  invariants 4, 7, 8, 10
- Decision ledger: `DECISIONS.md` D-025, D-026, D-032, Q-003
- Phase 0b closeout: `docs/host-capability-substrate/phase-0b-closeout.md`
- Research plan: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` §2, §16, §18

### External

- N/A
