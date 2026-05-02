---
adr_number: 0025
title: BranchDeletionProof composite shape and force-deletion handling
status: proposed
date: 2026-05-02
charter_version: 1.3.2
tags: [branch-deletion, proof-composite, version-control, evidence, q-008, q-006, phase-1]
---

# ADR 0025: BranchDeletionProof composite shape and force-deletion handling

## Status

proposed

## Date

2026-05-02

## Charter version

Written against charter v1.3.2.

## Context

Q-008(c) asks: what proof is required before branch deletion, and should force
deletion be non-escalable or approval-only?

Existing authority:

- ADR 0020 names `BranchDeletionProof` as one of five load-bearing review
  receipts for Q-006 source-control authority. ADR 0020 commits the *name* and
  the rule that branch deletion can only become a rendered mutating operation
  with a `BranchDeletionProof`; it does not define the composite's shape.
- The 2026-04-30 ScopeCam exchange synthesis surfaced the motivating failure:
  an agent treated remote-gone branch state as branch-deletion authority and
  cleaned up branches without ancestry, patch-equivalence, worktree, or lease
  proof.
- Q-011's review grammar identifies three buckets: evidence subtype,
  standalone Ring 0 entity, and proof composite. `BranchDeletionProof` fits
  the third: an authored artifact that aggregates multiple evidence records
  into a gating shape.
- Charter v1.3.2 wave-3 forbids cross-context evidence reuse and fabricated
  evidence; `BranchDeletionProof` must compose evidence whose target
  references match the proof's repository/branch/worktree binding.

This ADR does not implement schemas, generated JSON Schema, policy tiers,
hooks, adapters, dashboard routes, runtime probes, or mutation operations. It
records the proof composite's shape decisions and the force-deletion-handling
posture so downstream Q-006 / Q-008 schema work has a stable target.

## Options considered

### Option A: Single observation — `BranchDeletionProof` as one evidence record with embedded fields

**Pros:**
- Simpler schema; one Zod object with worktree, remote, ancestry, etc.
  embedded as primitive fields.
- Easy for an agent to construct at the moment of deletion.

**Cons:**
- Inlines fields that have their own observation lifecycles. Worktree state,
  remote state, ancestry state, and PR state each have independent producers,
  freshness windows, authority sources, and audit trails.
- Conflicts with Q-011's "evidence subtype vs. proof composite" distinction:
  authored decision artifacts are not observations.
- Hard to compose with Q-006 source-control receipts (`GitWorktreeObservation`,
  `GitBranchAncestryObservation`, etc.) — would force ADR 0020's deferred
  receipt list to either be observation-only or to migrate later.

### Option B: Proof composite that references multiple `Evidence` subtypes

**Pros:**
- Each component evidence keeps its own producer, freshness, authority, and
  trace.
- Composition is explicit; the proof is auditable as "these N evidence records
  collectively justify the deletion."
- Matches Q-011's proof-composite bucket and ADR 0020's posture that
  source-control facts start as evidence subtypes / receipts.
- Lets the gateway and dashboard render the proof as a structured argument
  rather than as one opaque blob.
- Cross-context evidence reuse (forbidden by charter v1.3.2) is naturally
  enforced because each component evidence carries its own target reference.

**Cons:**
- Requires the underlying evidence subtypes (`GitWorktreeObservation`,
  `GitBranchAncestryObservation`, `GitRemoteObservation`, etc.) to land before
  the proof can be constructed in practice. Q-006 controls those.
- Adds a Ring 0 concept (proof composite) that the schema package has not yet
  shipped.

### Option C: No composite — gate at the operation surface using per-component evidence directly

**Pros:**
- Avoids a new Ring 0 concept.
- Each evidence record could be attached to the `OperationShape` directly.

**Cons:**
- Defers the question of which evidence is required for which deletion class
  to the gateway/policy code, where the rule is harder to inspect.
- Loses the audit story: "this is the proof package the operator presented at
  deletion time" becomes derivable but not first-class.
- Repeats the design issue Q-011 identified: facts that get composed for
  decisions deserve a named composite.

## Decision

Choose Option B. `BranchDeletionProof` is a Ring 0 proof composite per Q-011's
third bucket. It does not subtype `Evidence`; it composes evidence references
into a gating shape that the gateway consumes alongside the deletion
`OperationShape`.

### Composite shape (candidate field block)

```text
schema_version
proof_schema_version optional
branch_deletion_proof_id
repository_id
branch_identity:
  name
  ref
  commit_sha
  is_remote
  is_protected
  is_force_deletion
worktree_attachment_evidence_ref optional
remote_state_evidence_ref optional
ancestry_or_equivalence_evidence_ref
dirty_state_evidence_ref optional
pr_state_evidence_ref optional
lease_evidence_ref optional
approval_grant_ref optional
proof_authored_at
proof_valid_until
authoring_principal_id
```

### Component-presence rules

Required components depend on the deletion class:

- For local branch deletion (`is_remote: false`): `worktree_attachment_evidence_ref`,
  `dirty_state_evidence_ref`, and `lease_evidence_ref` are required.
- For remote branch deletion (`is_remote: true`):
  `remote_state_evidence_ref` is required.
- `ancestry_or_equivalence_evidence_ref` is required for every proof except
  empty branches with no commits (vacuous case).
- `pr_state_evidence_ref` is required when a known PR exists for the branch;
  the absence of a PR must itself be evidenced (e.g., a
  `PullRequestReceipt` showing no open PR for the branch SHA).
- `approval_grant_ref` is required when `is_force_deletion: true` and
  `is_protected: false`, or when ancestry/patch-equivalence does not cleanly
  prove merged for a non-force deletion.

### Force-deletion handling

Three regimes:

1. **`is_force_deletion: true` AND `is_protected: true` is forbidden.**
   The composite must fail schema validation for this combination. The
   gateway never sees a valid proof for force-deleting a protected branch;
   no operation can be rendered. This is a schema-level non-escalable
   rejection (no `approval_grant_ref` carve-out applies).
2. **`is_force_deletion: true` AND `is_protected: false` requires an
   `approval_grant_ref`.** The grant must scope to the specific repository,
   branch identity, and `is_force_deletion: true`; reusing a grant from a
   non-force operation is forbidden by charter inv. 7's approval-grant
   discipline.
3. **`is_force_deletion: false`** is gated by the
   `ancestry_or_equivalence_evidence_ref`. If the evidence cleanly proves the
   branch is merged or its diff is patch-equivalent to another protected
   branch, no `approval_grant_ref` is required. If the evidence does not
   prove either, the proof requires an `approval_grant_ref`.

### Freshness semantics

The proof composite has its own freshness independent of any single component:

- `proof_valid_until` is bounded by `min(min_component_valid_until,
  proof_authored_at + composite_freshness_window)`. The composite freshness
  window is tier-dependent: standard deletions use a short window (the
  numeric value is canonical-policy-driven, not pinned in this ADR); force
  and approval-required deletions use a window scoped to the
  `approval_grant_ref` validity.
- Each component evidence record retains its own `valid_until`; the gateway
  checks all component evidence is unexpired at decision time.
- The composite cannot be re-used after `proof_valid_until`. Re-deletion
  attempts require a freshly authored proof.

### Cross-context discipline

Each evidence ref's primary target reference must compose consistently with
`repository_id` and `branch_identity`:

- `worktree_attachment_evidence_ref` must reference the same `repository_id`
  and a worktree whose attached branch matches `branch_identity.name` and
  `branch_identity.commit_sha`.
- `remote_state_evidence_ref` must reference the same `repository_id` and a
  remote ref matching `branch_identity.ref`.
- `ancestry_or_equivalence_evidence_ref` must reference the same
  `repository_id` and `branch_identity.commit_sha`.
- `dirty_state_evidence_ref`, `pr_state_evidence_ref`, and
  `lease_evidence_ref` must reference the same `repository_id` and the
  branch/worktree under deletion.

This composes cleanly with charter v1.3.2's wave-3 forbidden pattern on
cross-context evidence reuse: a `BoundaryObservation` from a different
execution context, or a Git observation against a different repository,
fails the proof's per-component target-binding check.

The field names, component-presence rules, force-deletion regime, and
freshness window values remain candidates until schema review.

## Consequences

### Accepts

- `BranchDeletionProof` is the canonical name and composite shape for the
  pre-deletion gating artifact. Q-008(c) is settled at the design layer.
- Force-deletion of protected branches is a schema-level non-escalable
  rejection. Force-deletion of unprotected branches is approval-only.
  Non-force deletion without ancestry/patch-equivalence proof is
  approval-only.
- `BranchDeletionProof` is a Ring 0 proof composite, not an `Evidence`
  subtype. ADR 0023's `Evidence` base contract does not constrain the
  composite's own shape; it only constrains the evidence the composite
  references.
- Q-011's review grammar's third bucket gets its first concrete schema
  candidate.

### Rejects

- Inlining branch/worktree/remote/ancestry/PR state into a single
  observation-shaped record (Option A).
- Gating at the operation surface without a named composite (Option C).
- Reusing an `ApprovalGrant` issued for a non-force operation as
  authorization for a force operation.
- Treating remote-gone state as branch-deletion authority (the ScopeCam
  failure mode this ADR closes).
- Treating UI absence ("branch not visible in GitHub UI") as
  `pr_state_evidence`.

### Future amendments

- Schema implementation requires the underlying Q-006 evidence subtypes
  (`GitWorktreeObservation`, `GitBranchAncestryObservation`,
  `GitRemoteObservation`, `PullRequestReceipt` and friends) to land first.
  Schema implementation must use `.agents/skills/hcs-schema-change` and move
  Zod source, generated JSON Schema, ontology docs, tests, and fixtures
  together.
- The `composite_freshness_window` numeric value is canonical-policy-driven
  and lives in `system-config/policies/host-capability-substrate/` once the
  policy schema is in place.
- Reopen if Q-003 coordination facts decide that worktree ownership is
  authoritatively a `Lease` artifact rather than a separate observation.
- Reopen if Q-005 runner work introduces remote-only deletion classes
  (e.g., release branches, build-artifact branches) that need a different
  composite shape.
- Reopen if a future incident shows that the three force-deletion regimes
  miss a class of failure.

### Out of scope

This ADR does not authorize:

- Schema, kernel, adapter, dashboard, runtime probe, mutation operation, or
  policy-tier work landing in the same PR as this ADR.
- Setting the canonical composite-freshness-window value (that is
  policy-canonical, not ADR-canonical).
- Branch creation, branch protection edits, or any other Git mutation
  beyond deletion.
- Any change to ADR 0020's broader version-control authority posture; this
  ADR specializes one of ADR 0020's named receipts.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.3.2,
  invariants 1, 5, 7, 8, 16, 17 (and the v1.3.2 wave-3 cross-context evidence
  reuse forbidden pattern)
- Decision ledger: `DECISIONS.md` Q-006, Q-008, Q-011
- ADR 0020:
  `docs/host-capability-substrate/adr/0020-version-control-authority.md`
  (originating authority for the `BranchDeletionProof` name)
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (precedent for evidence-binding composites)
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md` (base
  shape that component evidence inherits)
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- Ontology promotion/dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- Ontology overview:
  `docs/host-capability-substrate/ontology.md`
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- Git `git-branch` documentation:
  <https://git-scm.com/docs/git-branch>
- GitHub protected branches:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>
- GitHub rulesets:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>
- SLSA Source requirements v1.2:
  <https://slsa.dev/spec/v1.2/source-requirements>
