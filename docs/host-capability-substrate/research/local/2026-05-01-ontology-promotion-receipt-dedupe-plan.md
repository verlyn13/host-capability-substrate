---
title: Ontology Promotion and Receipt Dedupe Plan
category: research
component: host_capability_substrate
status: active
version: 0.1.0
last_updated: 2026-05-01
tags: [research, ontology, evidence, receipts, phase-1, schema-planning, q-011]
priority: high
---

# Ontology Promotion and Receipt Dedupe Plan

## Status

This is Phase 1 planning evidence. It does not add schemas, generated JSON
Schema, policy tiers, hooks, adapters, dashboard routes, GitHub settings, or
mutation operations.

The purpose is to keep the Q-003/Q-005/Q-006/Q-007/Q-008/Q-009/Q-010 candidate
names from hardening into incompatible Ring 0 shapes before ontology review.

## Problem

Recent Phase 1 intakes intentionally widened the design space. That produced a
useful but risky candidate backlog:

- Q-003 adds coordination and derived knowledge candidates.
- Q-005 adds runner and check evidence candidates.
- Q-006 / ADR 0020 adds Git/GitHub/source-control receipts.
- Q-007 adds boundary and quality-gate candidates.
- Q-008 adds execution-reality and destructive-Git hygiene candidates.
- Q-009 adds diagnostic-surface and cleanup request candidates.
- Q-010 adds cross-agent containment and remote-environment candidates.

The repeated unresolved question is not only "which names should exist?" It is
"what kind of thing is this name?" A candidate can be an observed fact, a
standalone lifecycle object, a point-in-time proof composite, or an authored
coordination fact. Those shapes have different freshness, authority, approval,
and dashboard semantics.

## Promotion Buckets

Use these buckets during review. They are not final schema classes.

### 1. Evidence subtype

Use when the object is an observation of the world. It has source, authority,
confidence, observed time, freshness, and execution context. It can become stale
without being mutated.

Default suffix: `*Observation`.

Use `*Receipt` only when the observation records a discrete event or run output
at a point in time. A receipt can still be an `Evidence` subtype.

Examples: `GitRemoteObservation`, `WorkflowRunReceipt`,
`StatusCheckSourceObservation`, `ExecutionModeObservation`.

### 2. Standalone entity

Use when the object has durable identity, lifecycle, ownership, references from
multiple domains, or is mutated/leased/approved independently.

Default suffix: no suffix unless the domain already has a stable term.

Examples already accepted or landed: `WorkspaceContext`, `Lease`,
`ExecutionContext`, `CredentialSource`, `ApprovalGrant`.

### 3. Composite or authored decision artifact

Use when the object is neither a direct observation nor a normal entity.

Proof composites consume one or more evidence records, are valid for a specific
moment and target operation, and may be consumed once by an `OperationShape`.
They should be reviewed against `ApprovalGrant` before becoming peer Ring 0
entities.

Derived authored facts are produced by an agent or verifier from sources. They
are not observations themselves. Gateability must be explicit, not inferred from
confidence alone.

Default suffixes:

- `*Proof` for proof composites.
- `*Fact` or `*Summary` for Q-003 authored coordination/knowledge records.

Examples: `BranchDeletionProof`, `CleanRoomSmokeReceipt` if it gates a specific
operation, `CoordinationFact`, `DerivedSummary`.

## Candidate Inventory

This table is intentionally conservative. "Initial bucket" means "review this
way first," not "commit schema in this shape."

| Candidate | Source | Initial bucket | Freshness / lifecycle model | Dedupe or disposition note |
|---|---|---|---|---|
| `ExecutionContext` | ADR 0016/0017 | Standalone entity | Lifecycle-bound surface record with evidence refs | Already landed as initial schema; future containment fields still require review. |
| `EnvProvenance` | ADR 0016 | Evidence-like entity | Freshness-bound env-name provenance | Already landed; no raw values. |
| `CredentialSource` | ADR 0018 | Standalone entity | Durable credential authority with health and rotation | Already landed; future `mutation_scope` is a field candidate, not a Q-006 commitment. |
| `StartupPhase` | ADR 0016 | Standalone value/entity | Stable ordering vocabulary | Already landed. |
| `RateLimitObservation` | ADR 0015 | Evidence subtype | Freshness-bound provider budget state | Keep generic; Q-005 `ResourceBudgetObservation` should not duplicate it. |
| `RemoteMutationReceipt` | ADR 0015 | Evidence receipt | Point-in-time provider mutation receipt | Generic external-control-plane receipt; provider-specific receipts should specialize or reference it. |
| `CredentialIssuanceReceipt` | ADR 0015 | Proof/receipt candidate | One-time issuance capture moment | Review with ADR 0012 broker and `ApprovalGrant` semantics. |
| `ProviderObjectReference` | ADR 0015 | Structured value candidate | Durable reference, not evidence by itself | Likely value type used by receipts. |
| `PathCoverage` | ADR 0015 | Evidence subtype | Freshness-bound route/path observation | Could become `BoundaryObservation` specialization. |
| `McpAuthorizationSurface` | ADR 0015 | Evidence subtype | Freshness-bound auth-surface observation | Dedupe with provider-specific MCP session observations. |
| `OriginAccessValidator` | ADR 0015 | Evidence subtype | Freshness-bound validator binding | Could become `BoundaryObservation` specialization. |
| `AudienceValidationBinding` | ADR 0015 | Evidence subtype/value | Freshness-bound audience binding | Keep separate from secret material. |
| `McpSessionObservation` | ADR 0015 | Evidence subtype | Freshness-bound MCP session state | Dedupe with `GitHubMcpSessionObservation` by adding provider/surface fields. |
| `ControlPlaneBackoffMarker` | ADR 0015 | Evidence subtype | Time-windowed cooldown marker | Related to `RateLimitObservation`; do not make policy state. |
| `KnowledgeSource` | Q-003 | Standalone entity candidate | Durable source identity | Q-003 decides peer vs specialization. |
| `KnowledgeChunk` | Q-003 | Derived artifact candidate | Rebuildable derived index chunk | Never gateable without source/evidence promotion. |
| `CoordinationFact` | Q-003 | Derived authored fact | Authored fact with verification lifecycle | Needs first-class `allowed_for_gate` decision before ADR 0019. |
| `DerivedSummary` | Q-003 | Derived authored fact | Agent-authored summary, derived and rebuildable | Default non-gateable. |
| `RunnerHostObservation` | Q-005 | Evidence subtype | Freshness-bound runner host state | Defer until Q-005 after Q-006 check-source shape. |
| `RunnerIsolationObservation` | Q-005 | Evidence subtype | Freshness-bound containment observation | Likely `BoundaryObservation` specialization. |
| `WorkflowRunReceipt` | Q-005 | Evidence receipt | Point-in-time workflow run | Dedupe with `CheckRunReceipt`; preserve run vs check distinction. |
| `CleanRoomSmokeReceipt` | Q-005 | Proof/receipt candidate | Point-in-time clean-room run proof | If used to gate mutation, review as proof composite. |
| `ResourceBudgetObservation` | Q-005 | Evidence subtype | Freshness-bound budget observation | Should feed accepted `ResourceBudget`; avoid standalone duplicate. |
| `PolicyPlanReceipt` | Q-005 | Proof/receipt candidate | Point-in-time PaC/plan receipt | If consumed by operation approval, review as proof composite. |
| `GitRepositoryObservation` | Q-006 / ADR 0020 | Evidence subtype | Freshness-bound repo identity/state | Candidate. |
| `GitRemoteObservation` | Q-006 / ADR 0020 | Evidence subtype | Freshness-bound remote/ref state | Candidate. |
| `GitConfigResolution` | Q-006/Q-007 | Evidence subtype | Freshness-bound effective-config resolution | One of the five load-bearing Q-006 names to review first. |
| `GitIdentityBinding` | Q-006/Q-007 | Evidence subtype | Freshness-bound identity binding | One of the five load-bearing Q-006 names to review first. |
| `GitWorktreeObservation` | Q-006 | Evidence subtype | Freshness-bound worktree state | Dedupe with `WorktreeStateObservation`. |
| `GitRefObservation` | Q-006 | Evidence subtype | Freshness-bound ref state | Candidate. |
| `GitBranchAncestryObservation` | Q-006 | Evidence subtype | Freshness-bound ancestry/equivalence observation | Feeds `BranchDeletionProof`. |
| `BranchDeletionProof` | Q-006/Q-008 | Proof composite | Point-in-time operation-bound proof | Single canonical name; review against `ApprovalGrant` consumption semantics. |
| `GitHubRepositorySettingsObservation` | Q-006 | Evidence subtype | Freshness-bound repo settings observation | Prefer over shorter duplicate `GitHubRepoSettingsObservation`. |
| `GitHubRulesetObservation` | Q-006 | Evidence subtype | Freshness-bound ruleset observation | Prefer provider-specific name unless generic `RulesetObservation` is later needed. |
| `BranchProtectionObservation` | Q-006/Q-007 | Evidence subtype | Freshness-bound protection observation | Candidate. |
| `WorkflowPolicyObservation` | Q-005/Q-006/Q-007 | Evidence subtype | Freshness-bound workflow posture | Shared Q-005/Q-006 name; avoid duplicate runner-owned shape. |
| `CheckRunReceipt` | Q-006 | Evidence receipt | Point-in-time check-run receipt | Dedupe with `WorkflowRunReceipt`; check vs run are related but not identical. |
| `StatusCheckSourceObservation` | Q-006 | Evidence subtype | Freshness-bound expected-source binding | One of the five load-bearing Q-006 names to review first. |
| `GitHubCredentialObservation` | Q-006 | Evidence subtype | Freshness-bound credential posture | Should reference `CredentialSource`, not duplicate it. |
| `GitHubMcpSessionObservation` | Q-006 | Evidence subtype | Freshness-bound MCP session state | Dedupe with generic `McpSessionObservation` plus provider/surface fields. |
| `PullRequestReceipt` | Q-006 | Evidence receipt | Point-in-time PR state/action | Candidate; may specialize `RemoteMutationReceipt` for mutating PR ops. |
| `PullRequestReviewReceipt` | Q-006 | Evidence receipt | Point-in-time review state/action | Candidate. |
| `SourceControlContinuityReceipt` | Q-006 | Evidence receipt | Control-start/lapse/restart continuity window | One of the five load-bearing Q-006 names to review first; naming may become `SourceControlContinuityObservation`. Do not also emit `source_control_continuity` as a `BoundaryObservation` dimension unless Q-006/Q-011 approve the wrapper relationship. |
| `BoundaryObservation` | Q-007/Q-010 | Evidence subtype | Freshness-bound boundary claim | Highest-leverage near-term candidate after Q-011 and Evidence base-shape sequencing. |
| `QualityGate` | Q-007 | Standalone entity candidate | Durable gate definition with evidence inputs | Defer until `BoundaryObservation`, Q-005, and Q-006 shapes settle. |
| `CredentialBinding` | Q-007 | Evidence subtype candidate | Freshness-bound credential-to-surface binding | Dedupe with `CredentialSource` + `GitIdentityBinding`. |
| `SigningIdentity` | Q-007 | Evidence/entity candidate | Freshness-bound signing identity or durable principal mapping | Defer; likely part of `GitIdentityBinding` plus `CredentialSource`. |
| `BundleObservation` | Q-007/Q-010 | Evidence subtype | Freshness-bound app bundle fact | Likely `BoundaryObservation` specialization. |
| `SandboxContext` | Q-007/Q-010 | Evidence/entity candidate | Freshness-bound containment fact | Dedupe with `ExecutionContext.sandbox` and `BoundaryObservation`; Q-011 must decide whether `ExecutionContext.sandbox` remains direct snapshot fields, narrows to last-observed pointers, or gets a deprecation path once boundary observations exist. |
| `TCCGrantObservation` | Q-007 | Evidence subtype | Freshness-bound macOS permission fact | Likely `BoundaryObservation` specialization. |
| `LaunchContext` | Q-007 | Evidence subtype/value | Freshness-bound launch-source fact | Dedupe with `ExecutionContext` fields before adding entity. |
| `VolumeObservation` | Q-007 | Evidence subtype | Freshness-bound filesystem/volume fact | Likely `BoundaryObservation` specialization. |
| `WorktreeStateObservation` | Q-007 | Evidence subtype | Freshness-bound worktree state | Rename/dedupe to `GitWorktreeObservation` unless non-Git worktrees emerge. |
| `ToolProvenance` | Q-007 | Evidence subtype candidate | Freshness-bound tool provenance | Dedupe with `ResolvedTool` evidence. |
| `ShimResolution` | Q-007 | Evidence subtype candidate | Freshness-bound shim chain | Could feed `ResolvedTool`; avoid standalone duplicate. |
| `PackageManagerObservation` | Q-007 | Evidence subtype | Freshness-bound package-manager state | Candidate. |
| `ToolMutationClaim` | Q-007 | Derived authored fact candidate | Authored claim about tool mutation | Treat as non-gateable until evidence-backed. |
| `ToolInvocationReceipt` | Q-008 | Evidence receipt | Point-in-time tool invocation | Defer until Q-009 operation input shape. |
| `CommandCaptureReceipt` | Q-008 | Evidence receipt | Point-in-time command capture | Defer until Q-009 operation input shape and trap #37 handling. |
| `ExecutionModeObservation` | Q-008 | Evidence subtype | Freshness-bound execution-mode fact | Likely `BoundaryObservation`/`ExecutionContext` companion. |
| `AuthOperationProbe` | Q-008 | Evidence receipt | Point-in-time exact auth operation proof | Dedupe with source-control credential/check receipts. |
| `BranchFlowObservation` | Q-008 | Evidence subtype | Freshness-bound branch-flow invariant | Repo-policy-specific; do not assume universal branch model. |
| `ProcessInspectionRequest` | Q-009 | Operation input shape | Request shape, not evidence | Must be typed; no free-form CLI string. |
| `CleanupPlanRequest` | Q-009 | Operation input shape | Request shape, not evidence | Must carry deletion authority source per D-025. |
| `WorkspaceManifest` | Q-009 | Generated view candidate | Generated from `WorkspaceContext` and facts unless Q-009 decides otherwise | Avoid a second source of truth. |
| `RemoteAgentEnvironmentReceipt` | Q-010 | Evidence receipt | Point-in-time remote/cloud environment claim | Defer until Q-005/Q-006 check-source and runner evidence settle. |
| `PermissionPostureObservation` | Q-010 | Evidence subtype | Freshness-bound UI/tool permission mode | Must not imply OS containment. |
| `ContainmentObservation` | Q-010 | Evidence subtype | Freshness-bound containment fact | Likely `BoundaryObservation` specialization. |
| `SharedAgentPolicySchema` | Q-010 source report | Rejected as canonical HCS shape | Not applicable | Keep only vocabulary; do not import vendor adapter schema. |

## Dedupe Matrix Rules

For each pair of candidates, compare four axes:

1. Domain: same provider/surface/object family?
2. Observation source: same command/API/probe/doc/source?
3. Lifecycle: same freshness window or same durable lifecycle?
4. Consumer: same policy gate, dashboard view, or operation shape?

If three or more axes match, treat the pair as a dedupe candidate. Do not add
both names to Ring 0 until a reviewer explains why the split is necessary.

## Initial Dedupe Clusters

| Cluster | Candidate names | Initial disposition |
|---|---|---|
| GitHub repo settings | `GitHubRepositorySettingsObservation`, `GitHubRepoSettingsObservation` | Prefer `GitHubRepositorySettingsObservation`. |
| Rulesets | `GitHubRulesetObservation`, `RulesetObservation` | Prefer provider-specific name for Q-006; reserve generic only if another provider needs it. |
| Worktrees | `GitWorktreeObservation`, `WorktreeStateObservation` | Prefer `GitWorktreeObservation` for Git; non-Git workspace state should stay under `WorkspaceContext`. |
| MCP sessions | `McpSessionObservation`, `GitHubMcpSessionObservation` | Prefer generic with provider/surface fields unless Q-006 needs provider-specific constraints. |
| Check and workflow evidence | `CheckRunReceipt`, `WorkflowRunReceipt`, `StatusCheckSourceObservation`, `WorkflowPolicyObservation` | Preserve distinctions: check result, workflow run, expected source, and workflow posture. |
| Tool provenance | `ToolProvenance`, `ShimResolution`, `PackageManagerObservation`, `ResolvedTool` evidence | Let `ResolvedTool` remain the durable answer; observations feed it. |
| Boundary evidence | `BoundaryObservation`, `SandboxContext`, `TCCGrantObservation`, `BundleObservation`, `LaunchContext`, `VolumeObservation`, `ContainmentObservation` | Promote `BoundaryObservation` only after Q-011 and the Evidence base-shape prerequisite; specialize only after repeated use. |
| Credential binding | `CredentialSource`, `CredentialBinding`, `GitHubCredentialObservation`, `GitIdentityBinding`, `SigningIdentity` | Keep `CredentialSource` durable; use observations for resolved bindings. |
| Branch cleanup | `BranchDeletionProof`, `GitBranchAncestryObservation`, `BranchFlowObservation`, `GitWorktreeObservation` | Keep `BranchDeletionProof` as one proof composite consuming the others. |
| External mutation receipts | `RemoteMutationReceipt`, `PullRequestReceipt`, `PullRequestReviewReceipt`, `PolicyPlanReceipt` | Use generic receipt plus provider-specific fields unless the operation lifecycle differs. |

## Naming Rules For Review

- Use `*Observation` for freshness-bound observed facts.
- Use `*Receipt` for a point-in-time event, run, or action record.
- Use `*Proof` for composite evidence consumed by a specific operation.
- Avoid `*Context` unless the object is a durable execution/workspace surface.
- Avoid `*Claim` for gateable objects; claims are authored and need
  verification before gate use.
- Prefer provider-neutral names only when at least two providers need the same
  shape. Otherwise name the provider explicitly.

## Near-Term Dispositions

These are planning recommendations for human/reviewer approval:

1. Resolve the full `Evidence` base shape or explicit canonical substitute
   before accepting any `Evidence` subtype envelope. The schema package still
   uses embedded `evidence_refs` as a temporary provenance reference.
2. Promote `BoundaryObservation` first as an `Evidence` subtype candidate after
   Q-011 and the Evidence base-shape prerequisite. It unblocks Q-007a and
   reduces duplicate sandbox/TCC/bundle/containment names.
3. Treat `BranchDeletionProof` as the single canonical branch-cleanup proof.
   Review whether it derives from or is consumed by `ApprovalGrant` before
   making it a standalone Ring 0 entity.
4. For ADR 0020 acceptance review, treat these five Q-006 names as the
   load-bearing minimum: `GitConfigResolution`, `GitIdentityBinding`,
   `BranchDeletionProof`, `StatusCheckSourceObservation`, and
   `SourceControlContinuityReceipt`.
5. Defer `QualityGate` until `BoundaryObservation`, Q-005 runner/check evidence,
   and Q-006 source-control evidence are reconciled.
6. Before `BoundaryObservation` schema work, decide the
   `boundary_dimension` registry artifact, singular dimension rule, primary
   target binding convention, and whether version/build drift remains a
   freshness invalidation signal rather than a standalone dimension.
7. Defer `ToolInvocationReceipt`, `CommandCaptureReceipt`, and
   `ExecutionModeObservation` until Q-009 locks typed operation inputs for
   `system.process.inspect_safe.v1` and `system.cleanup.plan.v1`.
8. Defer Q-003 authored-fact shapes until Q-003 decides whether coordination
   state is peer to `Evidence` or a specialization, and whether
   `allowed_for_gate` is first-class.
9. Keep `SharedAgentPolicySchema` rejected as canonical HCS shape.

## Dependency Order

Recommended review order:

1. Q-011: approve or amend this promotion/dedupe rule.
2. Evidence base shape: define the full `Evidence` entity or explicit
   canonical substitute required before any `Evidence` subtype envelope is
   accepted.
3. Q-007a: `BoundaryObservation` evidence subtype.
4. Q-003: coordination authored facts and gateability.
5. Q-006(g): expected check-source gateability.
6. Q-006(f): `BranchDeletionProof` minimum proof.
7. Q-008: command-symptom invariant and branch-cleanup reuse.
8. Q-009: typed `ProcessInspectionRequest` and `CleanupPlanRequest` inputs.
9. Q-005: runner/check receipt taxonomy.
10. Q-007b: `QualityGate`.
11. Q-010: cross-agent containment and remote-agent receipts.

## Reviewer Path

- `hcs-ontology-reviewer`: review candidate buckets, dedupe clusters, and
  whether proof composites should derive from `ApprovalGrant`.
- `hcs-architect`: review ADR sequencing and whether Q-011 should become an ADR
  or stay as a schema-synthesis rule.
- `hcs-policy-reviewer`: only after a candidate begins classifying operations.
- `hcs-security-reviewer`: only after a candidate touches credentials, process
  inspection, sandbox claims, or destructive cleanup.

## References

- `DECISIONS.md` Q-003, Q-005, Q-006, Q-007, Q-008, Q-009, Q-010
- `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
- `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- `docs/host-capability-substrate/adr/0017-codex-app-execution-context.md`
- `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
- `docs/host-capability-substrate/adr/0020-version-control-authority.md`
- `docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md`
- `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- `docs/host-capability-substrate/research/local/2026-04-30-hcs-evidence-planning-synthesis.md`
- `docs/host-capability-substrate/research/local/2026-05-01-agentic-tool-isolation-synthesis.md`
- `docs/host-capability-substrate/research/local/2026-05-01-version-control-authority-consult-synthesis.md`

## Change Log

| Version | Date | Change |
|---|---:|---|
| 0.1.0 | 2026-05-01 | Initial cross-Q ontology promotion and receipt dedupe plan. |
