---
adr_number: 0025
title: BranchDeletionProof composite shape and force-deletion handling
status: proposed
date: 2026-05-02
revision: 2
charter_version: 1.3.2
tags: [branch-deletion, proof-composite, version-control, evidence, q-008, q-006, phase-1]
---

# ADR 0025: BranchDeletionProof composite shape and force-deletion handling

## Status

proposed (revision 2)

## Date

2026-05-02

## Charter version

Written against charter v1.3.2 and `docs/host-capability-substrate/ontology-registry.md`
v0.2.0 (the codified naming suffix discipline).

## Context

Q-008(c) asks: what proof is required before branch deletion, and should
force deletion be non-escalable or approval-only?

Existing authority:

- ADR 0020 names `BranchDeletionProof` as one of five load-bearing review
  receipts for Q-006 source-control authority. ADR 0020 commits the *name*
  and the rule that branch deletion can only become a rendered mutating
  operation with a `BranchDeletionProof`; it does not define the composite's
  shape.
- The 2026-04-30 ScopeCam exchange synthesis surfaced the motivating failure:
  an agent treated remote-gone branch state as branch-deletion authority and
  cleaned up branches without ancestry, patch-equivalence, worktree, or
  lease proof.
- Q-011's review grammar identifies three buckets: evidence subtype,
  standalone Ring 0 entity, and proof composite. `BranchDeletionProof` fits
  the third: an authored artifact that aggregates multiple evidence records
  into a gating shape.
- Charter v1.3.2 wave-3 forbids cross-context evidence reuse and fabricated
  evidence; `BranchDeletionProof` must compose evidence whose target
  references match the proof's repository/branch/worktree binding.
- Ontology-registry v0.2.0 codifies the naming suffix discipline:
  `*Proof` for authored decision composites; `<thing>_evidence_refs` arrays
  for component evidence with embedded provenance.

This is revision 2. Revision 1 was reviewed by `hcs-architect`,
`hcs-ontology-reviewer`, and `hcs-security-reviewer` on 2026-05-02 and
returned 15 blocking findings plus 3 additional shape gaps. Revision 2
addresses all of them.

This ADR does not implement schemas, generated JSON Schema, policy tiers,
hooks, adapters, dashboard routes, runtime probes, or mutation operations.
It records the proof composite's shape decisions, the defense-in-depth
enforcement architecture, and the force-deletion-handling posture so
downstream Q-006 / Q-008 / Q-007 schema work has a stable target.

## Options considered

### Option A: Single observation — `BranchDeletionProof` as one evidence record with embedded fields

**Pros:**
- Simpler schema; one Zod object with worktree, remote, ancestry, etc.
  embedded as primitive fields.
- Easy for an agent to construct at the moment of deletion.

**Cons:**
- Inlines fields that have their own observation lifecycles. Worktree state,
  remote state, ancestry state, and PR state each have independent
  producers, freshness windows, authority sources, and audit trails.
- Conflicts with Q-011's "evidence subtype vs. proof composite" distinction:
  authored decision artifacts are not observations.
- Hard to compose with Q-006 source-control receipts.

### Option B: Proof composite that references multiple `Evidence` subtypes (chosen)

**Pros:**
- Each component evidence keeps its own producer, freshness, authority, and
  trace.
- Composition is explicit; the proof is auditable as "these N evidence
  records collectively justify the deletion."
- Matches Q-011's proof-composite bucket and ADR 0020's posture that
  source-control facts start as evidence subtypes / receipts.
- Lets the gateway and dashboard render the proof as a structured argument.
- Cross-context evidence reuse (forbidden by charter v1.3.2) is naturally
  enforced because each component evidence carries its own target reference.

**Cons:**
- Requires the underlying evidence subtypes (`GitWorktreeObservation`,
  `GitBranchAncestryObservation`, `GitRemoteObservation`, etc.) to land
  before the proof can be constructed in practice. Q-006 controls those.
- Adds a Ring 0 concept (proof composite) that the schema package has not
  yet shipped.

### Option C: No composite — gate at the operation surface using per-component evidence directly

**Pros:**
- Avoids a new Ring 0 concept.
- Each evidence record could be attached to the `OperationShape` directly.

**Cons:**
- Defers the question of which evidence is required for which deletion class
  to the gateway/policy code, where the rule is harder to inspect.
- Loses the audit story: "this is the proof package the operator presented
  at deletion time" becomes derivable but not first-class.
- Repeats the design issue Q-011 identified: facts that get composed for
  decisions deserve a named composite.

## Decision

Choose Option B. `BranchDeletionProof` is a Ring 0 proof composite per
Q-011's third bucket. It does not subtype `Evidence`; it composes evidence
references into a gating shape that the gateway consumes alongside the
deletion `OperationShape`. The composite is **minted by a Ring 1 kernel
service**; agents request a proof for a deletion intent, but agents never
author the composite body.

### Authoring discipline (Ring 1 minting)

The proof has two distinct principal fields, set by trusted layers, never
by agents:

- `authoring_service_id` is set by the kernel from the minting Ring 1
  service's trusted identity. It records *which kernel service* composed
  the proof.
- `requesting_principal_id` is set by the gateway from the authenticated
  session principal. It records *which agent or human* requested the
  deletion.

Agent-supplied values for either field are rejected at the proof-mint API.
Agent-produced *component evidence* remains acceptable (an agent can run
`git worktree list` and the result becomes a `GitWorktreeObservation`); the
Ring 1 service controls which evidence is composed into the proof and
stamps the proof body.

### Composite shape (candidate field block)

```text
schema_version
proof_schema_version optional
evidence_schema_version
branch_deletion_proof_id
authoring_service_id
requesting_principal_id
repository_id
repository_observation_evidence_refs
branch_identity:
  name
  ref
  commit_sha
  is_remote
  is_protected
deletion_intent:
  is_force_deletion
worktree_attachment_evidence_refs    optional
worktree_inventory_evidence_refs     optional
remote_state_evidence_refs           optional
merge_proof_kind  enum: ancestry | patch_equivalence | vacuous
ancestry_evidence_refs               optional
patch_equivalence_evidence_refs      optional
empty_branch_evidence_refs           optional
dirty_state_evidence_refs            optional
pr_state_kind  enum: absent | open | closed_unmerged | merged
pr_state_evidence_refs
lease_evidence_refs                  optional
approval_grant_ref                   optional
proof_authored_at
proof_valid_until
```

Field-naming notes per ontology-registry v0.2.0:

- `<thing>_evidence_refs` arrays use `evidenceRefSchema` from
  `packages/schemas/src/common.ts` with `min(1)` when required.
- `merge_proof_kind` and `pr_state_kind` are discriminators that select
  which sibling `_evidence_refs` array is required. This replaces the
  revision-1 collapsed-OR fields per ontology-reviewer findings.
- `repository_id` is a typed FK (`<entity>_id` form), set by the minting
  service, not agent-supplied.
- `branch_identity` is a substructure of branch-intrinsic facts only;
  `is_force_deletion` is operation intent and lives in `deletion_intent`.

### Component-presence rules

Required components depend on the deletion class:

- **Local branch (`is_remote: false`):**
  `worktree_attachment_evidence_refs`, `dirty_state_evidence_refs`, and
  `lease_evidence_refs` are required.
- **Remote branch (`is_remote: true`):**
  `remote_state_evidence_refs` is required. If the local repository has
  tracking refs for the remote branch, `worktree_attachment_evidence_refs`
  is also required so the proof cannot silently delete a tracking-ref the
  agent's session is using.
- **Multi-worktree case:** if the branch is attached to more than one
  worktree, `worktree_inventory_evidence_refs` is required. The proof
  cannot silently delete a branch still in use elsewhere.
- **`merge_proof_kind`:** `ancestry`, `patch_equivalence`, or `vacuous`.
  - `ancestry` requires `ancestry_evidence_refs`.
  - `patch_equivalence` requires `patch_equivalence_evidence_refs`.
  - `vacuous` requires `empty_branch_evidence_refs` showing the branch's
    `commit_sha` is the empty-tree sentinel and that no commits are unique
    to the branch. This is positive evidence; absence of ancestry alone is
    not vacuous.
- **`pr_state_kind`:** always required, with `pr_state_evidence_refs`
  always required. `absent` requires a `PullRequestAbsenceReceipt`
  (positive-absence claim per ontology-registry §Naming suffix discipline);
  it is never satisfied by a missing field. `open`, `closed_unmerged`, and
  `merged` require the corresponding `PullRequestReceipt` shape.
- **`approval_grant_ref`:** required when
  `deletion_intent.is_force_deletion = true` AND `branch_identity.is_protected = false`,
  or when `merge_proof_kind` evidence does not cleanly prove merged for a
  non-force deletion. The grant must scope to this repository, this
  `branch_identity`, and this `deletion_intent.is_force_deletion`, per
  `ApprovalGrant`'s scope contract (deferred to Milestone 2). This ADR
  does not pre-specify `ApprovalGrant.scope`'s field shape.

### Force-deletion regime (defense in depth)

Five-layer enforcement, with each layer named explicitly so future code
PRs implement them in the right ring:

1. **Ring 1 mint API (authoritative authoring).** The minting service
   refuses to construct a proof asserting
   `deletion_intent.is_force_deletion = true` AND
   `branch_identity.is_protected = true`. The combination is unrepresentable
   at the API; no proof is returned to the requester.
2. **Schema validation (defense-in-depth structural guard).** The Zod
   schema also refuses the same combination as a structural guard. This is
   bypassable by code that constructs an object without using the canonical
   parser, so this layer alone is *not* authoritative; it is defense-in-depth
   for adapters and renderers.
3. **Gateway / policy (authoritative non-escalable per inv. 6).** Force
   deletion of protected branches is in the forbidden tier; the gateway
   refuses such operations regardless of any approval grant. This is the
   binding non-escalable enforcement point. Force deletion of unprotected
   branches and non-force deletion without merge proof require a matching
   `ApprovalGrant`.
4. **Substrate enforcement (`hcs-hook`).** `hcs-hook` MUST intercept the
   three direct git command shapes — `git branch -D <ref>`,
   `git push <remote> --delete <ref>`, and `git update-ref -d <ref>` —
   against a literal-protected-list (`main`, `master`, `HEAD`) as defense
   in depth. The authoritative protection classification (matching
   non-literal protected refs such as `release-2026-04`) is queued as
   ADR 0026 once `BranchProtectionObservation` exists; the literal list is
   the floor enforcement until then.
5. **Broker FSM (operation-execution binding).** The broker rejects any
   operation whose effective force flag does not match
   `proof.deletion_intent.is_force_deletion`. The broker marks the proof
   `consumed` at deletion time; the proof is single-use and a re-deletion
   attempt requires a freshly authored proof. The broker rejects proofs
   whose component evidence records contain inconsistent observed payloads
   (for example, two records with disagreeing `commit_sha` for the same
   branch); inconsistency fails composition.

The five layers are non-redundant. Layer 1 prevents construction; layer 2
prevents structural malformation by adjacent code; layer 3 is the
authoritative non-escalable point; layer 4 catches direct shell paths that
bypass HCS; layer 5 binds the proof to the actual operation execution and
prevents replay.

### Freshness semantics

The proof composite has its own freshness independent of any single
component:

- `proof_valid_until` is bounded by `min(min_component_valid_until,
  proof_authored_at + composite_freshness_window)`. Each component evidence
  record carries a non-null `valid_until` per ADR 0023's `Evidence` base
  contract; the minimum is well-defined.
- The composite freshness window is tier-dependent: standard deletions use
  a short window (the numeric value is canonical-policy-driven, not pinned
  in this ADR); force and approval-required deletions use a window scoped
  to the `approval_grant_ref` validity.
- The composite cannot be re-used after `proof_valid_until`, and is
  single-use even within its window (broker marks it consumed).

### Cross-context discipline

Each evidence ref's primary target reference must compose consistently with
`repository_id` and `branch_identity`:

- `worktree_attachment_evidence_refs` must reference the same
  `repository_id` and a worktree whose attached branch matches
  `branch_identity.name` and `branch_identity.commit_sha`.
- `worktree_inventory_evidence_refs` must reference the same
  `repository_id` and enumerate all attached worktrees for
  `branch_identity.name`.
- `remote_state_evidence_refs` must reference the same `repository_id` and
  a remote ref matching `branch_identity.ref`.
- `ancestry_evidence_refs` / `patch_equivalence_evidence_refs` /
  `empty_branch_evidence_refs` must reference the same `repository_id` and
  `branch_identity.commit_sha`.
- `dirty_state_evidence_refs`, `pr_state_evidence_refs`, and
  `lease_evidence_refs` must reference the same `repository_id` and the
  branch/worktree under deletion.
- `repository_observation_evidence_refs` provides the audit trail for how
  `repository_id` was resolved by the minting service from
  `WorkspaceContext`.

This composes cleanly with charter v1.3.2's wave-3 forbidden pattern on
cross-context evidence reuse: a `BoundaryObservation` from a different
execution context, or a Git observation against a different repository,
fails the proof's per-component target-binding check at the mint API.

### Audit posture

`BranchDeletionProof` records participate in the audit hash chain via
`audit_events`. The proof composite is itself a Ring 0 record with a
`branch_deletion_proof_id` primary key; component `evidence_refs` preserve
provenance and provenance-preview per `evidenceRefSchema`. Component
evidence with payload-bearing fields applies the `redaction_mode` contract
from ADR 0023's `Evidence` base. Raw secret material never appears in the
proof or its component evidence; provider object IDs, branch names, and
commit SHAs are not classified as secret-shaped.

The field names, component-presence rules, force-deletion regime,
discriminator value sets, and freshness window values remain candidates
until schema review.

## Consequences

### Accepts

- `BranchDeletionProof` is the canonical name and composite shape for the
  pre-deletion gating artifact. Q-008(c) is settled at the design layer.
- `BranchDeletionProof` is a Ring 0 proof composite (Q-011 bucket 3), not
  an `Evidence` subtype. ADR 0023's `Evidence` base contract does not
  constrain the composite's own shape; it only constrains the evidence the
  composite references.
- The proof is minted by a Ring 1 kernel service; agents never author the
  composite body.
- `authoring_service_id` is kernel-set from trusted service identity;
  `requesting_principal_id` is gateway-set from the authenticated session.
- `repository_id` is resolved by the minting service from
  `WorkspaceContext`; agent-supplied `repository_id` is rejected at the
  mint API. The proof embeds `repository_observation_evidence_refs` as the
  audit trail for repository identity resolution.
- Force-deletion of protected branches is forbidden at five enforcement
  layers; the gateway/policy layer is the authoritative non-escalable
  point per inv. 6. The schema's structural guard is defense-in-depth.
- `hcs-hook` substrate-level interception of direct git deletion commands
  is committed as defense-in-depth against a literal-protected-list. The
  full hook architecture for non-literal protected refs is queued as ADR
  0026.
- The broker FSM binds the proof's `is_force_deletion` to operation
  execution and rejects mismatch.
- `BranchDeletionProof` is single-use; the broker marks it consumed at
  deletion time. Re-deletion requires a freshly authored proof.
- Multi-worktree branches require `worktree_inventory_evidence_refs`.
- `merge_proof_kind` and `pr_state_kind` are explicit discriminators; the
  vacuous merge case requires positive empty-branch evidence; the absent
  PR case requires `PullRequestAbsenceReceipt`.
- Inconsistent component evidence (disagreeing observed payloads) fails
  composition at the broker.
- The proof participates in the audit hash chain.

### Rejects

- Inlining branch/worktree/remote/ancestry/PR state into a single
  observation-shaped record (Option A).
- Gating at the operation surface without a named composite (Option C).
- Treating `BranchDeletionProof` as a `human_decision`-kind `Evidence`
  record per ADR 0023's `evidence_kind` enum. Although structurally
  similar, the proof composite is an authored composite that *references*
  evidence; making it itself an `Evidence` subtype would conflate the
  composer with the composed.
- Reusing an `ApprovalGrant` issued for a non-force operation as
  authorization for a force operation, or reusing one issued for a
  different `branch_identity` or `repository_id`.
- Treating remote-gone state as branch-deletion authority (the ScopeCam
  failure mode this ADR closes).
- Treating UI absence ("branch not visible in GitHub UI") as
  `pr_state_evidence`.
- Treating an empty `pr_state_evidence_refs` array as "no PR exists." A
  positive `PullRequestAbsenceReceipt` is required.
- Treating `git push --delete` exit code 0 as a deletion-completed proof
  for any future re-deletion attempt; the proof is single-use.
- Authoring a proof in a `sandbox-observation` execution context and
  asserting `host-observation` authority on the composite. (Sandbox-
  authority component evidence is acceptable, but the composite's
  authority follows the minting service's authority class, not the
  requesting principal's.)
- Reusing a `BranchDeletionProof` across same-named branches in different
  repositories.
- Tag-ref deletion through this composite. `branch_identity.ref` must be a
  branch ref; tag deletion requires a separate composite (out of scope).

### Future amendments

- **ADR 0026 (queued)**: substrate hook architecture for protected-branch
  classification beyond the literal-protected-list. Lands once
  `BranchProtectionObservation` exists from Q-006.
- Schema implementation requires the underlying Q-006 evidence subtypes
  (`GitRepositoryObservation`, `GitWorktreeObservation`,
  `GitWorktreeInventoryObservation`, `GitBranchAncestryObservation`,
  `GitRemoteObservation`, `GitDirtyStateObservation`,
  `PullRequestReceipt`, `PullRequestAbsenceReceipt`, and friends) to land
  first. Schema implementation must use `.agents/skills/hcs-schema-change`
  and move Zod source, generated JSON Schema, ontology docs, tests, and
  fixtures together.
- The `composite_freshness_window` numeric value is canonical-policy-driven
  and lives in `system-config/policies/host-capability-substrate/` once
  the policy schema is in place.
- `ApprovalGrant.scope` shape is settled in its own ADR (Milestone 2). This
  ADR does not pre-specify the scope field shape; it specifies what the
  scope must bind (repository, branch_identity, force-deletion).
- Reopen if Q-003 coordination facts decide that worktree ownership is
  authoritatively a `Lease` artifact rather than a separate observation.
- Reopen if Q-005 runner work introduces remote-only deletion classes
  (e.g., release branches, build-artifact branches) that need a different
  composite shape.
- Reopen if a future incident shows that the five enforcement layers miss
  a class of failure.

### Out of scope

This ADR does not authorize:

- Schema, kernel, adapter, dashboard, runtime probe, mutation operation,
  or policy-tier work landing in the same PR as this ADR.
- Setting the canonical composite-freshness-window value (that is
  policy-canonical, not ADR-canonical).
- The `ApprovalGrant.scope` field-level shape (deferred to its own ADR
  in Milestone 2).
- The full hook architecture for non-literal protected-branch
  classification (queued as ADR 0026).
- Branch creation, branch protection edits, tag deletion, or any other
  Git mutation beyond branch deletion.
- Any change to ADR 0020's broader version-control authority posture;
  this ADR specializes one of ADR 0020's named receipts.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.3.2,
  invariants 1, 5, 6, 7, 8, 16, 17 (and the v1.3.2 wave-3 cross-context
  evidence reuse forbidden pattern; the fabricated-evidence-subtype-envelope
  forbidden pattern; the parent-context-inheritance forbidden pattern)
- Ontology registry: `docs/host-capability-substrate/ontology-registry.md`
  v0.2.0 (codified naming suffix discipline)
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
- ADR 0024:
  `docs/host-capability-substrate/adr/0024-charter-v1-3-wave-2-and-3.md`
  (charter enforcement plumbing this composite respects)
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- Ontology promotion/dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- Human decision report:
  `docs/host-capability-substrate/human-decision-report-2026-05-01.md`
  (Q-011 sub-decision (d) suffix discipline approval)
- Ontology overview:
  `docs/host-capability-substrate/ontology.md`
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- Git `git-branch` documentation:
  <https://git-scm.com/docs/git-branch>
- Git `git-worktree` documentation:
  <https://git-scm.com/docs/git-worktree>
- Git `git-update-ref` documentation:
  <https://git-scm.com/docs/git-update-ref>
- GitHub protected branches:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>
- GitHub rulesets:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>
- SLSA Source requirements v1.2:
  <https://slsa.dev/spec/v1.2/source-requirements>
