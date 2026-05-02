---
adr_number: 0021
title: Charter v1.3.0 wave 1 amendment
status: accepted
date: 2026-05-01
charter_version: 1.2.0
tags: [charter, external-control-plane, execution-context, evidence, phase-1]
---

# ADR 0021: Charter v1.3.0 wave 1 amendment

## Status

accepted

## Date

2026-05-01

## Charter version

Written against charter v1.2.0.

## Context

Charter v1.2.0 added three Phase 0b closeout invariants:

- deletion authority is not gitignore state;
- config-spec claims require authority provenance;
- GUI/app/IDE shell-env inheritance must not be assumed.

Phase 1 work since then produced two stronger generalizations that are ready
for focused charter review:

- ADR 0015 accepted that external control planes are typed evidence surfaces.
- ADR 0016 accepted the shell/environment ownership boundary and the
  `ExecutionContext` / `EnvProvenance` vocabulary.
- Q-011 records the ontology promotion and receipt dedupe rule that will decide
  final `*Observation`, `*Receipt`, `*Proof`, and entity naming. This ADR
  should not lock names ahead of that review.

Other candidate charter amendments remain queued but are not ready for this
wave:

- invariant 18: derived retrieval results are never decision authority;
- invariant 19: boundary claims are freshness-bound and execution-context-bound;
- invariant 20: command symptoms are not diagnoses.

Those depend on Q-003, Q-007, and Q-008. This ADR keeps them out of wave 1 so
the uncontroversial external-control-plane and execution-context rules can be
reviewed without forcing the larger ontology and coordination decisions.

This ADR does not amend the charter by itself. The active charter remains
v1.2.0 until a separate charter-edit PR lands with the accepted invariant text
from this ADR.

If Q-012 accepts one invariant and rejects or defers the other, the charter-edit
PR should land only the accepted invariant. The default drafter for that PR is
`hcs-architect` because the change is docs/ADR/charter-scoped; implementation
agents should not fold schema, policy, hook, adapter, dashboard, or mutation
work into the same PR.

## Options considered

### Option A: Amend all queued v1.3.0 invariants together

**Pros:**
- One charter bump instead of multiple waves.
- Captures the full Phase 1 posture in one document.
- Reduces administrative churn.

**Cons:**
- Couples settled lessons to unsettled Q-003/Q-007/Q-008 decisions.
- Risks orphaning broad invariants before their schema and evidence shapes are
  reviewed.
- Makes charter review harder because disagreement with one invariant blocks
  all others.

### Option B: Amend only invariants 16 and 17 in wave 1

**Pros:**
- Keeps the amendment narrow and evidence-backed.
- Separates independent votes for external-control-plane evidence and
  execution-context declaration.
- Preserves the charter rule that amendments land in their own PR.
- Avoids prematurely committing Q-003/Q-007/Q-008 outcomes.

**Cons:**
- Requires a later v1.3.x or v1.4.0 wave for invariants 18-20.
- Charter readers must track queued principles in `PLAN.md` until later
  amendments land.
- Still depends on careful wording so intentional inheritance remains allowed
  when typed and surface-bound.

### Option C: Keep invariants 16 and 17 as ADR/PLAN guidance only

**Pros:**
- No charter churn during Phase 1.
- Lets ADR 0015 and ADR 0016 carry the detailed design discussion.
- Avoids creating reviewer work before schema synthesis.

**Cons:**
- Leaves two already-repeated agent failure classes out of the binding
  operating contract.
- Makes future external-control-plane and execution-context reviews cite
  multiple lower-authority documents instead of one charter invariant.
- Weakens the early safety posture while mutation surfaces are being designed.

## Decision

Proposed: amend the charter in a separate wave-1 charter PR to add invariants
16 and 17 only. Invariant 16 should bind external-control-plane operations to
typed evidence before provider mutations, without depending on final Q-011
receipt naming. Typed evidence is necessary for provider-side mutation, not
sufficient authorization by itself. It never bypasses policy/gateway decisions,
approval-grant consumption, broker finite-state-machine requirements, audit,
dashboard review, or lease requirements. Invariant 17 should require operations
to declare the execution context they rely on, while preserving intentional
typed inheritance only for the dimension the evidence or operator actually
governs. ADR 0016's Codex `inherit` / `include_only` vocabulary can establish
environment materialization for a named target context when represented through
secret-safe `EnvProvenance` evidence; it cannot prove credential authority,
sandbox scope, app/TCC permission, provider mutation authority, or HCS
`ApprovalGrant` status.

Proposed invariant text:

```text
16. External-control-plane operations are evidence-first. Operations against
remote control planes must produce typed evidence before provider-side
mutation is proposed or rendered. HCS must distinguish provider object
references, public client IDs, policy selector values, secret references, and
secret material. Where the provider exposes a separable validator surface, such
as ADR 0015's OriginAccessValidator/AudienceValidationBinding precedent, HCS
must model that validator binding before proposing mutations that depend on it.
Rate-limit/backoff state is evidence rather than retry pressure. Typed evidence
is necessary, not sufficient; it does not bypass policy/gateway decisions,
ApprovalGrant consumption, broker finite-state-machine requirements, audit,
dashboard review, or lease requirements.

17. Execution context is declared, not inferred. Every operation carries a
resolved ExecutionContext surface reference. Agents must not assume a
subprocess inherits any sandbox, capability, environment, or credential scope
from a parent context unless that inheritance is intentionally represented by
typed evidence bound to the target execution context and to the specific
dimension being asserted. Surface-specific operators such as Codex
shell_environment_policy inherit/include_only are environment-materialization
evidence only for the named target context; they do not prove credential
authority, sandbox scope, app/TCC permission, provider mutation authority, or
HCS ApprovalGrant status.
```

The charter-edit PR should bump the charter to v1.3.0 and leave invariants
18-20 queued.

## Consequences

### Accepts

- External-control-plane evidence-first becomes binding charter language rather
  than only ADR 0015 posture.
- Execution-context declaration becomes binding charter language rather than
  only ADR 0016 and shell research guidance.
- Intentional inheritance remains legal only when modeled explicitly, bound to
  the target context, and scoped to the exact dimension the evidence or operator
  governs.
- Invariant 17 creates a deliberate forward binding: Milestone 1 schema
  reconciliation must either promote `ExecutionContext` into the canonical Ring
  0 entity list or provide an equivalent canonical entity that satisfies this
  invariant.
- `ExecutionContext` is additional operation context. It does not replace
  principal, session, agent-client, or audit attribution.
- Charter v1.3.0 wave 1 remains independent from Q-003, Q-007, and Q-008.
- Invariants 16 and 17 should be voted and reviewed separately even if they
  land in one charter PR.
- Partial acceptance is allowed. If only invariant 16 or only invariant 17
  passes review, the charter-edit PR may land only the accepted invariant.
- `hcs-architect` should own the charter-edit PR draft after Q-012 approval;
  policy/security reviewers file objections before human approval.

### Rejects

- Adding invariants 18, 19, and 20 before their parent Q-* decisions settle.
- Treating a parent process, app, CLI, IDE, MCP server, setup script, or
  subagent as evidence for a different execution context without a receipt that
  names the target context.
- Treating provider object IDs, public client IDs, policy selectors, secret
  material, and `SecretReference` values as interchangeable strings.
- Treating rate-limit errors or MCP fan-out symptoms as prompts to retry or
  mutate more.
- Treating an environment operator such as Codex `inherit` or `include_only` as
  proof of credential authority, sandbox scope, app/TCC permission, provider
  mutation authority, or HCS `ApprovalGrant` status.
- Changing live policy, schemas, hooks, adapters, dashboard routes, or mutation
  endpoints as part of the charter amendment.

### Future amendments

- Add invariant 18 after Q-003 resolves coordination facts, derived summaries,
  and gateability.
- Add invariant 19 after Q-007 resolves `BoundaryObservation` and quality-gate
  composition.
- Add invariant 20 after Q-008 resolves execution-mode receipts and destructive
  Git hygiene.
- Re-review invariant 17 if ADR 0016 materially changes the inheritance
  vocabulary or if a vendor publishes a stronger execution-context contract.
- Re-review invariant 16 if ADR 0015 is superseded by a broader provider
  automation ADR.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0
- ADR 0015:
  `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
- ADR 0016:
  `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- ADR 0017:
  `docs/host-capability-substrate/adr/0017-codex-app-execution-context.md`
- ADR 0018:
  `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
- Decision ledger: `DECISIONS.md` Q-003, Q-007, Q-008, Q-011, Q-012
- Ontology promotion/dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- Plan: `PLAN.md` charter v1.3.0 candidate invariants 16-20
- External-control-plane lessons:
  `docs/host-capability-substrate/research/external/2026-04-24-cloudflare-lessons.md`
- Shell/env research:
  `docs/host-capability-substrate/shell-environment-research.md` v2.12.0
- Codex config/app settings ingest:
  `docs/host-capability-substrate/research/shell-env/2026-05-01-codex-official-config-app-settings-ingest.md`
- Claude app/settings ingest:
  `docs/host-capability-substrate/research/shell-env/2026-05-01-claude-desktop-code-settings-ingest.md`
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- OpenAI Codex config, sandbox, approvals, hooks, MCP, and local-environments
  documentation
- Anthropic Claude Code settings, hooks, authentication, MCP, and subagent
  documentation
- Model Context Protocol authorization and protected-resource metadata
  specifications
- Cloudflare Access, tunnel, service-token, and API rate-limit documentation
