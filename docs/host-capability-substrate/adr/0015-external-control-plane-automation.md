---
adr_number: 0015
title: External control planes are typed evidence surfaces
status: accepted
date: 2026-04-26
charter_version: 1.2.0
tags: [external-control-plane, cloudflare, mcp, oauth, rate-limit, provider]
---

# ADR 0015: External control planes are typed evidence surfaces

## Context

The Cloudflare Stage 3a workflow exposed several agent failure classes:

- path scoping was placed in the wrong provider object
- optional verification spent scarce API budget
- 429 was treated as retry pressure rather than cooldown evidence
- one-time secrets required capture at the mutation response
- provider object IDs were confused with credential material
- CLI syntax was guessed from memory
- HTTP MCP bearer tokens needed audience/resource validation
- Cloudflare Access auth succeeded while `cloudflared` rejected the child app
  AUD before origin
- authenticated Cloudflare MCP fan-out created principal-scoped quota pressure

These are not Cloudflare-only lessons. GitHub, 1Password CLI, DNS providers,
Hetzner, OAuth MCP servers, and similar systems are external control planes.
HCS must model them as typed operation/evidence surfaces, not shell strings.

## Options considered

### Option A: Keep provider automation as shell/curl scripts

**Pros:**
- Fast to write for one-off incidents.
- Easy for agents to understand initially.

**Cons:**
- Repeats model-memory syntax failures.
- Hides quota, identity, one-time secret, and audit-correlation semantics.
- Cannot reliably distinguish provider layers such as Access, tunnel validator,
  and origin reachability.

### Option B: Thin provider adapters returning typed evidence

**Pros:**
- Adapters stay translators, not policy engines.
- Kernel can reason about rate limits, approvals, receipts, and verification.
- Matches the four-ring architecture.

**Cons:**
- Requires schema work before broad provider automation.
- Requires per-provider fixtures and docs evidence.

### Option C: Treat all external APIs as MCP tools and trust MCP auth

**Pros:**
- Reuses an existing protocol surface.
- Avoids custom adapters initially.

**Cons:**
- MCP tools can hide fan-out inside one visible call.
- HTTP MCP auth itself requires typed resource metadata and audience validation.
- Does not model shared token/account budgets across dashboard, direct API,
  wrappers, and MCP sessions.

## Decision

External control planes are typed evidence-producing surfaces. Provider
mutations require an `OperationShape`, a minimal-request plan, quota/budget
evidence, provider-shape evidence, explicit secret semantics, and typed receipts
before they can become command or API request renderings.

ADR 0015 also resolves Q-004:

- Model Cloudflare tunnel/origin rejection as an `OriginAccessValidator` evidence
  surface with nested or linked `AudienceValidationBinding` facts.
- `PathCoverage` and `McpAuthorizationSurface` are necessary but insufficient.
- HCS must distinguish Access app AUDs, tunnel validator allowlists, and origin
  reachability receipts before proposing more Access policy mutations.

Initial Ring 0 candidates for Phase 1 reconciliation:

- `RateLimitObservation`
- `RemoteMutationReceipt`
- `CredentialIssuanceReceipt`
- `ProviderObjectReference`
- `PathCoverage`
- `McpAuthorizationSurface`
- `OriginAccessValidator`
- `McpSessionObservation`
- `ControlPlaneBackoffMarker`

These may land as entities or as `Evidence` subtypes after ontology review.

## Consequences

### Accepts

- Provider automation waits for schemas, fixtures, and policy/gateway paths.
- One-time-secret operations depend on ADR 0012's broker path.
- Cloudflare mutations must account for local authenticated MCP fan-out and
  `last_cf_mcp_429` before writes.
- Dashboard summaries must show mutation receipts separately from deferred
  verification.

### Rejects

- Long curl scripts as the canonical provider operation.
- Treating HTTP 429 as a reason to retry immediately.
- Treating provider object IDs, public client IDs, policy selectors, secrets,
  and secret references as interchangeable strings.
- Treating "Access accepted JWT" as proof that origin received the request.
- Accepting arbitrary bearer tokens for HTTP MCP without protected-resource
  metadata and audience validation.

### Future amendments

- Provider-specific retry/idempotency semantics (`If-Match`, idempotency keys,
  eventual consistency windows) need follow-up ADRs or schema extensions.
- If Q-003's coordination store lands, provider receipts may become promotion
  sources for coordination facts.
- If MCP auth specs materially change, `McpAuthorizationSurface` and related
  gateway policy must be re-reviewed.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0,
  invariants 1, 2, 5, 7, 8, 13, 14, 15
- Decision ledger: `DECISIONS.md` D-030, D-032
- Cloudflare lessons: `docs/host-capability-substrate/research/external/2026-04-24-cloudflare-lessons.md`
- Tunnel audience addendum: `docs/host-capability-substrate/research/external/2026-04-24-cloudflare-tunnel-audience-addendum.md`
- Cloudflare MCP diagnostics addendum: `docs/host-capability-substrate/research/external/2026-04-25-cloudflare-mcp-diagnostics-addendum.md`
- Regression seed corpus: `packages/evals/regression/seed.md` #19-#25, #36, #38
- Research plan: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` §2, §6, §18, §22

### External

- Cloudflare Access and service-token documentation
- Cloudflare API rate-limit documentation
- Model Context Protocol authorization and protected resource metadata specification
