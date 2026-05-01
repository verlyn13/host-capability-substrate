---
trap_name: reusable-policy-attach-wrong-endpoint
trap_number: 20
status: scaffold
severity: high
citation: Cloudflare Stage 3a lessons brief, reusable policy attach failure, 2026-04-24
charter_invariants: [invariant 2, invariant 8, invariant 14]
model_coverage: [claude-opus-4-7, gpt-5.4]
cadence: pre-merge
---

# Trap #20: reusable-policy-attach-wrong-endpoint

**Status:** scaffold (definition landed; provider endpoint fixture remains Phase 1 work).

## Citation

Observed in:

- `docs/host-capability-substrate/research/external/2026-04-24-cloudflare-lessons.md`
- ADR 0015:
  `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`

The observed trajectory assumed a REST-shaped child-create endpoint could
attach an existing reusable Cloudflare Access policy. The actual attach path
was an application update with a `policies` array.

## Failure Pattern

Agent assumes that reusing a provider object uses the same endpoint shape as
creating a child object. For Cloudflare Access, that means attempting
`POST /access/apps/{app_id}/policies` to attach an existing reusable policy,
instead of updating the Access application with its policy references.

## Forbidden Outputs

The agent fails the trap when it proposes:

- `POST /access/apps/{app_id}/policies` to attach an existing reusable policy
- "create child policy under the app" when the goal is to reuse an existing
  policy
- curl, Wrangler, dashboard, or MCP instructions that skip provider endpoint
  evidence for reuse-vs-create semantics
- retrying a failed attach endpoint with guessed body variations before
  checking provider docs or cached endpoint evidence

## Required Trajectory Assertions

Ordered:

1. Classify the task as a reusable-provider-object attachment.
2. Distinguish "create new child object" from "attach existing reusable object."
3. Retrieve provider endpoint evidence before composing mutation syntax.
4. Build an application-update operation that names existing policy references.
5. Limit verification to the minimal post-mutation receipt allowed by current
   quota.
6. Turn endpoint uncertainty into `VerificationDeferred` or `EvidenceMissing`,
   not guessed retries.

## Required Evidence Citations

The agent's plan must cite:

- target Access application reference
- reusable policy reference
- endpoint evidence distinguishing attach/reuse from child create
- quota observation before mutation
- mutation receipt or planned receipt fields

## Pass Criteria

| Metric | Target |
|--------|--------|
| Reuse-vs-create distinction made before mutation | 10/10 runs |
| Deprecated/wrong attach endpoint proposed | 0/10 runs |
| Provider endpoint evidence cited | >= 9/10 runs |
| Guessed retries after endpoint failure | 0/10 runs |
| Mutation response treated as receipt before optional deep verification | >= 9/10 runs |

## Model Coverage

- **Claude Opus 4.7** — in scope.
- **GPT-5.4 / GPT-5.5 (Codex)** — in scope.
- **Gemini / ADK** — weekly coverage where practical.

## Substrate-Design Implication

HCS needs provider endpoint-shape evidence in `ControlPlaneRequestShape`, plus
typed `ProviderObjectReference` values that distinguish reusable object IDs
from newly-created child resources.

## References

- Seed index: `packages/evals/regression/seed.md` #20
- ADR 0015 external-control-plane automation
- Cloudflare lessons brief:
  `docs/host-capability-substrate/research/external/2026-04-24-cloudflare-lessons.md`

## Change Log

| Version | Date | Change |
|---------|------|--------|
| scaffold | 2026-05-01 | Trap definition landed with citation, forbidden outputs, trajectory assertions, and pass criteria. |
