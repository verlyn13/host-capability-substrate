---
adr_number: 0022
title: BoundaryObservation evidence envelope
status: proposed
date: 2026-05-01
charter_version: 1.2.0
tags: [boundary-observation, evidence, quality-gate, execution-context, phase-1, q-007]
---

# ADR 0022: BoundaryObservation evidence envelope

## Status

proposed

## Date

2026-05-01

## Charter version

Written against charter v1.2.0.

## Context

Q-007 exists because Phase 1 research found that host boundaries are loose and
version-sensitive. macOS app sandboxing, TCC grants, launch source, app bundle
identity, package-manager shims, Git/GitHub identity routing, credential helper
precedence, worktree state, and remote/cloud execution posture can all change
without a source diff in this repo.

The existing schema slice already gives HCS `ExecutionContext`,
`EnvProvenance`, `CredentialSource`, and `StartupPhase` candidates. Q-006 adds
Git/GitHub authority evidence. Q-008 adds command/execution-mode anomalies and
destructive Git hygiene. Q-010 adds cross-agent containment vocabulary. Q-011
then recommends promoting `BoundaryObservation` first as an `Evidence` subtype
candidate so those domains do not each invent their own incompatible boundary
envelope.

The immediate question is Q-007a: how should HCS represent contextual boundary
claims before it commits to `QualityGate` or broader policy behavior?

This ADR does not add schemas, generated JSON Schema, policy tiers, hooks,
adapters, dashboard routes, live GitHub settings, macOS permission probes, or
mutation operations.

## Options considered

### Option A: Put all boundary facts directly on ExecutionContext

**Pros:**
- Reuses the surface entity already introduced by ADR 0016 and ADR 0017.
- Makes app/CLI/IDE distinctions visible at the context boundary.
- Avoids another candidate evidence name.

**Cons:**
- `ExecutionContext` would grow into a catch-all for Git, package managers,
  TCC, remote/cloud execution, worktree state, and provider settings.
- Boundary observations can become stale independently of the context identity.
- Cross-surface drift, such as CLI versus app or normal versus escalated mode,
  needs comparison records rather than one embedded field.

### Option B: Define QualityGate first and embed boundary evidence inside gates

**Pros:**
- Starts from the decision the human cares about: pass, warn, require approval,
  or block.
- Could make dashboard views and policy behavior feel concrete sooner.
- Matches the quality-management report's gate vocabulary.

**Cons:**
- Prematurely couples evidence shape to policy behavior.
- Violates the Phase 1 ordering from Q-011: boundary evidence should come
  before `QualityGate`.
- Makes it too easy for adapters or dashboards to own gate decisions instead of
  Ring 1 policy/gateway services.

### Option C: Promote BoundaryObservation as an Evidence subtype envelope first

**Pros:**
- Fits Q-011's evidence-subtype rule: boundary claims are observations with
  source, freshness, authority, confidence, and execution context.
- Gives macOS, GitHub, package-manager, runner, remote-agent, and execution-mode
  observations one shared envelope without collapsing their domains.
- Keeps `QualityGate` deferred until its evidence inputs are stable.
- Lets dashboard rows show `proven`, `denied`, `pending`, `stale`,
  `contradictory`, `inapplicable`, and `unknown` states without treating
  unknown as false.

**Cons:**
- Requires one more schema concept during Milestone 1 reconciliation.
- Still needs domain-specific observation payloads for TCC, bundle identity,
  runner isolation, GitHub rulesets, and tool provenance.
- Requires reviewers to prevent `BoundaryObservation` from becoming a generic
  "anything uncertain" bucket.

### Option D: Promote BoundaryObservation as a standalone Ring 0 entity now

**Pros:**
- Gives boundary posture durable identity and cross-domain references.
- Could support a dashboard inventory of active boundary claims.
- Makes long-lived boundary state explicit.

**Cons:**
- Overstates the lifecycle. Most boundary facts are freshness-bound
  observations, not independently owned objects.
- Conflicts with Q-011's recommendation to start as an `Evidence` subtype.
- Risks duplicating `ExecutionContext`, `CredentialSource`, `ResolvedTool`,
  `WorkspaceContext`, and future `QualityGate`.

## Decision

Proposed: model `BoundaryObservation` as an `Evidence` subtype envelope first.
It represents a contextual boundary claim about one surface, version/build,
execution context, provider surface, workspace, or credential/tool binding. It
inherits `Evidence` provenance, authority, confidence, observed time, and
freshness semantics. It does not decide policy and does not replace
`ExecutionContext`, `CredentialSource`, `ResolvedTool`, `WorkspaceContext`,
`Lease`, or Q-006 source-control receipts.

Candidate minimum fields for later schema work:

```text
schema_version
evidence_schema_version
payload_schema_version optional
boundary_observation_id
surface_id optional
execution_context_id optional
workspace_id optional
credential_source_id optional
tool_or_provider_ref optional
boundary_dimension
observed_state
expected_state optional
observation_state = proven | denied | pending | stale | contradictory | inapplicable | unknown
discrepancy_class optional
evidence_refs
```

Field-block conventions:

- Fields not marked optional are required unless schema review proves a
  narrower shape.
- At least one target reference must be present: `surface_id`,
  `execution_context_id`, `workspace_id`, `credential_source_id`, or
  `tool_or_provider_ref`.
- `surface_id` and `execution_context_id` are distinct nullable references, not
  one union field. Query paths should not need a second discriminator to know
  which reference type was used.
- `boundary_dimension` is the discriminator for the domain payload. Values
  belong to an ontology-reviewed taxonomy, not ad hoc adapter emission.
  Candidate dimensions include `sandbox`, `tcc`, `bundle_identity`,
  `network_egress`, `filesystem_scope`, `credential_routing`,
  `worktree_ownership`, `containment_class`, `runner_isolation`,
  `source_control_continuity`, and `check_source_identity`.
- `boundary_dimension` is singular. The taxonomy must define mutually exclusive
  values, a primary target reference, and allowed supplemental target
  references for each dimension before schema acceptance. When multiple
  dimensions could apply, emit the narrowest matching dimension; umbrella
  values such as `containment_class` apply only when no narrower dimension
  captures the observation. Genuinely multi-dimensional evidence should be
  represented as linked observations, not an unconstrained list on one envelope.
- Version/build/dependency changes are freshness and invalidation signals for
  specific dimensions, not a standalone boundary dimension unless Q-011 later
  approves a narrower registry entry.
- `observed_state` is a domain-specific discriminated payload whose
  discriminator is `boundary_dimension`. Payload schemas are owned by
  domain-specific evidence subtypes; the envelope reasons over
  `observation_state`, `discrepancy_class`, freshness, and evidence refs.
- `schema_version` names the `BoundaryObservation` envelope schema,
  `evidence_schema_version` names the base `Evidence` contract, and
  `payload_schema_version` names the domain payload when one exists. Those
  versions are independent. A TCC payload can evolve without forcing an
  `Evidence` base-shape version bump, and an `Evidence` base-shape bump should
  not silently change a domain payload.

The field names, taxonomy values, and enum values remain candidates until
schema review.

## Consequences

### Accepts

- Q-007a can proceed before `QualityGate`.
- Boundary claims are freshness-bound and execution-context-bound by default.
- `BoundaryObservation` can specialize or wrap observations such as
  `TCCGrantObservation`, `BundleObservation`, `RunnerIsolationObservation`,
  `ContainmentObservation`, `ExecutionModeObservation`, `PathCoverage`,
  `OriginAccessValidator`, and `McpAuthorizationSurface` if ontology review
  approves that relationship.
- Dashboard contracts should preserve the full seven-state vocabulary:
  `proven`, `denied`, `pending`, `stale`, `contradictory`, `inapplicable`,
  and `unknown`.
- Domain payloads remain separate. A boundary envelope can describe a GitHub
  ruleset, macOS TCC grant, app sandbox, package-manager shim, or remote runner
  posture without making those domains interchangeable.
- Q-010 sub-decision (a) is partially constrained: containment posture is
  reachable through the `BoundaryObservation` envelope as a
  `ContainmentObservation` payload. The `AgentClient` containment-mechanism
  field shape remains open under Q-010.
- Acceptance of this ADR does not commit charter v1.3.0 invariant 19. The
  envelope is structurally useful without that charter amendment; invariant 19
  would generalize the freshness-bound and execution-context-bound rule across
  future ADRs.

### Rejects

- Treating `ExecutionContext` alone as sufficient for every boundary claim.
- Defining `QualityGate` before boundary evidence shape is settled.
- Treating permission modes, worktrees, or app settings as proof of OS/process,
  network, credential, or sandbox isolation.
- Treating unknown, stale, or not-observable boundary evidence as `false`.
- Copying vendor policy schemas or UI permission modes into HCS Ring 0 as
  canonical policy.
- Letting adapters, hooks, or dashboard code decide boundary policy locally.

### Future amendments

Likely to reopen this envelope shape:

- Reopen after Q-011 if ontology review changes the evidence/receipt/proof
  promotion rule.
- Q-011 must choose the `boundary_dimension` registry artifact, final version
  field names, and primary-target encoding before schema implementation.
- Reopen after Q-008/Q-009 if execution-mode or safe-process-inspection
  receipts need a narrower observation shape or additional versioning fields.

Expected to fit inside the envelope unless review proves otherwise:

- Reopen after Q-005 only if runner isolation evidence needs a standalone
  lifecycle object rather than a boundary observation.
- Reopen after Q-006 only if source-control continuity or check-source evidence
  owns a conflicting boundary envelope.

Downstream consumers:

- Define how `Decision` / `ApprovalGrant` consume `BoundaryObservation`
  `evidence_refs` when `observation_state` is `stale`, `contradictory`, or
  `unknown`. This is Q-007's remaining gate-behavior question and the natural
  Milestone 2 approval entry point.
- Q-010 must be re-read against this envelope before drafting `AgentClient`
  containment schema. If Q-010 resolves containment outside the envelope, this
  ADR needs amendment.
- Draft `QualityGate` only after `BoundaryObservation`, Q-005 runner/check
  evidence, and Q-006 source-control evidence have settled.
- Any schema implementation must use `.agents/skills/hcs-schema-change` and
  move Zod source, generated JSON Schema, ontology docs, tests, and fixtures
  together.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0,
  invariants 1, 2, 7, 8, 13, 14, and 15
- Decision ledger: `DECISIONS.md` Q-007, Q-010, Q-011
- ADR 0015:
  `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
- ADR 0016:
  `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- ADR 0017:
  `docs/host-capability-substrate/adr/0017-codex-app-execution-context.md`
- ADR 0021:
  `docs/host-capability-substrate/adr/0021-charter-v1-3-wave-1.md`
- Quality-management synthesis:
  `docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md`
- Agentic tool isolation synthesis:
  `docs/host-capability-substrate/research/local/2026-05-01-agentic-tool-isolation-synthesis.md`
- Ontology promotion/dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- Dashboard contracts:
  `docs/host-capability-substrate/dashboard-contracts.md`
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- Apple launchd, Launch Services, sandbox, and TCC documentation
- OpenAI Codex sandbox, approvals, local-environments, and config documentation
- Anthropic Claude Code settings, hooks, MCP, permissions, and subagent
  documentation
- GitHub Actions, protected branches, rulesets, and status-check source
  documentation
