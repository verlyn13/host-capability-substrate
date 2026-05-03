---
adr_number: 0030
title: Q-006 stage-2 source-control evidence subtypes
status: proposed
date: 2026-05-03
charter_version: 1.3.2
tags: [source-control, evidence-subtypes, git-worktree, pull-request, ancestry, q-006, phase-1]
---

# ADR 0030: Q-006 stage-2 source-control evidence subtypes

## Status

proposed (v1)

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Context

Q-006 stage-1 was settled in ADR 0027 v2 (accepted 2026-05-02): three
foundational receipts — `GitRepositoryObservation`, `GitRemoteObservation`,
`BranchProtectionObservation` — landed as `evidenceSchema`-direct typed
payloads (Q-011 bucket 1), with `BranchProtectionObservation` carrying
the `branch_protection` boundary dimension when emitted as a
`BoundaryObservation`. ADR 0027 v2 left six stage-2 receipts queued.

Q-008(c) was settled in ADR 0025 v2 (accepted 2026-05-02): the
`BranchDeletionProof` composite names component evidence requirements
through `<thing>_evidence_refs` arrays + `merge_proof_kind` /
`pr_state_kind` discriminators. The composite cannot be schema-implemented
until its component evidence subtypes exist. Specifically,
`BranchDeletionProof` requires:

- worktree attachment evidence (`worktree_evidence_refs`),
- worktree inventory evidence for multi-worktree branches
  (`worktree_inventory_evidence_refs`),
- ancestry-or-equivalence evidence per `merge_proof_kind`
  (`ancestry`, `patch_equivalence`, or `vacuous`),
- PR-state evidence per `pr_state_kind` (`absent`, `open`,
  `closed_unmerged`, or `merged`).

Stage-2 commits the six receipt shapes that close those gaps:

- `GitWorktreeObservation` — single-worktree state,
- `GitWorktreeInventoryObservation` — per-(repository, branch_ref)
  worktree inventory,
- `GitBranchAncestryObservation` — ancestry / patch-equivalence /
  vacuous proof,
- `GitDirtyStateObservation` — per-worktree dirty state,
- `PullRequestReceipt` — PR existence and state proof,
- `PullRequestAbsenceReceipt` — positive-absence PR proof.

This ADR is doc-only and posture-only, mirroring ADR 0027 v2 acceptance
pattern. It does not author Zod schema source, JSON Schema, runtime
probes, or canonical policy YAML. Schema implementation lands per
`.agents/skills/hcs-schema-change` after acceptance and unblocks
ADR 0025 v2 BranchDeletionProof Zod source as well as ADR 0026
substrate hook architecture (which is gated on stage-1's
`BranchProtectionObservation` schema, landing first; stage-2's
worktree/PR receipts are not on the ADR 0026 critical path).

## Options considered

### Option A: All six receipts as `evidenceSchema`-direct typed payloads (chosen)

**Pros:**
- Matches the ADR 0027 stage-1 pattern exactly: receipts carry a
  domain payload via the existing `Evidence` base contract.
- No new envelope shape; no new versioning surface beyond the
  three canonical version fields per registry §Version-field naming.
- Composes cleanly with `BranchDeletionProof.<thing>_evidence_refs`
  arrays via `evidenceRefSchema`.
- Q-011 bucket 1 ("evidence subtype").

**Cons:**
- `GitBranchAncestryObservation` carries an internal `ancestry_kind`
  discriminator that selects which sibling proof field is required;
  this adds payload-level discriminator surface (already an
  established pattern per registry Sub-rule 5).

### Option B: BoundaryObservation envelope per receipt

**Pros:**
- Inherits multi-target reference shape from `BoundaryObservation`.
- Inherits `boundary_dimension` taxonomy entry per receipt.

**Cons:**
- Stage-1 receipts that fit the boundary-fact pattern (e.g.,
  `BranchProtectionObservation` for the `branch_protection`
  dimension) do use `BoundaryObservation`. Stage-2 receipts are
  not "facts about a surface boundary" in the same way; they are
  observations of Git/PR state. Forcing them through
  `BoundaryObservation` introduces ontological mismatch.
- Adds boundary-dimension registry entries that don't carry
  boundary semantics (worktree, PR state are not boundaries).

### Option C: Three separate observation types for ancestry kinds

**Pros:**
- Each ancestry proof gets its own type
  (`GitBranchAncestryObservation`, `GitBranchPatchEquivalenceObservation`,
  `GitBranchVacuousObservation`).
- No internal discriminator field.

**Cons:**
- Three types where one with a `<thing>_kind` discriminator
  suffices (per registry Sub-rule 5: "discriminator-and-array pairs
  are the recommended pattern").
- ADR 0025 v2's `merge_proof_kind` discriminator already exists and
  selects which sibling `*_evidence_refs` is required; matching the
  proof-side discriminator with the consumption-side
  discriminator keeps the composition simple.
- Inflates the receipt-type registry without ontological gain.

## Decision

Choose Option A. All six stage-2 receipts use `evidenceSchema` directly
as typed payloads (Q-011 bucket 1; matches ADR 0027 stage-1 pattern).
`GitBranchAncestryObservation` carries an internal `ancestry_kind`
discriminator with sibling proof fields per registry Sub-rule 5.

### `GitWorktreeObservation`

Observation of a single Git worktree's state at a point in time.

**Evidence shape (posture):**

- `evidence_kind: "observation"`
- `evidence_subject_kind: "git_worktree"` (new enum value;
  schema-side enum extension in the schema PR per
  `.agents/skills/hcs-schema-change`)
- Standard `Evidence` base fields per ADR 0023 (`evidence_id`,
  `schema_version: "0.1.0"`, `observed_at`, `authority`, `producer`,
  `redaction_mode`, `subject_refs`, `target_refs`)
- Cross-context binding: `execution_context_id` per registry v0.3.0
  §Cross-context enforcement layer (Layer 1 mint API rejects records
  whose primary target reference does not resolve consistently with
  `ExecutionContext`)

**Domain payload fields (illustrative; schema PR commits final shape):**

- `repository_id` — the `GitRepositoryObservation`-resolved repository
  identity (kernel-set; agent-supplied `repository_id` rejected at
  mint API per ADR 0025 v2 precedent)
- `worktree_path` — absolute path of the worktree (producer-asserted,
  kernel-verifiable via filesystem stat)
- `worktree_kind: "primary" | "linked"` — discriminator per registry
  Sub-rule 6 (`primary` is the repo's main worktree;
  `linked` is a `git worktree add`-created worktree)
- `attached_branch_ref` — the branch ref the worktree currently has
  checked out, if any (`refs/heads/<name>` form). Null when detached
  HEAD or bare repo.
- `head_commit_sha` — the commit SHA at the worktree's HEAD
  (producer-asserted, kernel-verifiable via `git rev-parse HEAD`)
- `lock_state: "unlocked" | "locked" | "held_by_other_session"` —
  Git's `git worktree lock` state plus HCS lease binding state
  (see lease fields below)
- `lease_id` — kernel-set per registry v0.3.2 §Producer-vs-kernel-set
  authority fields. The HCS `Lease` ID currently bound to this
  worktree (when one exists).
- `owning_session_id` — kernel-set. The `Session` that holds the
  current lease, if any.
- `last_lease_check_at` — kernel-set timestamp of the most recent
  lease verification.

**Authority discipline:** payload-resident operational fields
(`worktree_path`, `worktree_kind`, `attached_branch_ref`,
`head_commit_sha`, `lock_state`) are producer-asserted but
kernel-verifiable; identity fields (`lease_id`, `owning_session_id`,
`last_lease_check_at`) are kernel-set. Producer-supplied
identity-field values rejected at the mint API per registry v0.3.2.

**Worktree-ownership composition:** the `lease_id` and
`owning_session_id` fields are committed at this stage; the
*composition rules* with `WorkspaceContext` / `Lease` / Q-003
coordination facts continue under Q-008(d) once Q-003 settles. This
ADR commits the field shape only; observation-only use is permitted
without composition rules.

### `GitWorktreeInventoryObservation`

Listing of all worktrees attached to a given (repository, branch_ref)
pair at a point in time. Required by `BranchDeletionProof` for
multi-worktree branches.

**Evidence shape:**

- `evidence_kind: "observation"`
- `evidence_subject_kind: "git_worktree_inventory"` (new enum value)
- Standard `Evidence` base fields

**Domain payload fields:**

- `repository_id`
- `branch_ref` — the branch the inventory is scoped to
  (`refs/heads/<name>`)
- `worktree_observations` — array of `GitWorktreeObservation`
  evidence references per `evidenceRefSchema`. Each entry must
  have `attached_branch_ref == this.branch_ref`. Empty array is a
  valid positive-zero-worktree inventory.
- `inventory_completeness_kind: "complete" | "partial_with_reason"`
  — discriminator per registry Sub-rule 6. `complete` requires
  that the inventory was observed via `git worktree list` (or
  equivalent) without errors. `partial_with_reason` requires
  populated `partial_reason` field.
- `partial_reason` — string, present iff
  `inventory_completeness_kind == "partial_with_reason"`.
- `observed_via: "git_worktree_list"` — kernel-set per registry
  v0.3.2 §Producer-vs-kernel-set authority fields (this is an
  authority-class signal, not operational state).

**Grain:** per-(repository_id, branch_ref) pair, matching
`GitRemoteObservation`'s per-(repository, remote_name, ref) grain
from ADR 0027. Closes the ADR 0025 v2 multi-worktree-branch
requirement.

**Cross-context binding:** `execution_context_id` per registry v0.3.0.

### `GitBranchAncestryObservation`

Proof that a candidate branch is one of: (a) ancestrally reachable
from a base ref, (b) patch-equivalent to a base ref, or (c) vacuous
(branch has no commits beyond its merge base). Required by
`BranchDeletionProof` per `merge_proof_kind`.

**Evidence shape:**

- `evidence_kind: "observation"` (when computed from `git log`,
  `git merge-base`, or equivalent telemetry) OR `evidence_kind:
  "derived"` (when computed from cached observations)
- `evidence_subject_kind: "git_branch_ancestry"` (new enum value)
- Standard `Evidence` base fields

**Domain payload fields:**

- `repository_id`
- `candidate_ref` — the branch being checked
  (`refs/heads/<name>` or `refs/remotes/<remote>/<name>`)
- `base_ref` — the ref the candidate is being checked against
  (typically `refs/heads/main` or equivalent)
- `candidate_head_sha` — commit SHA at the candidate's tip
- `base_head_sha` — commit SHA at the base's tip
- `ancestry_kind: "ancestry" | "patch_equivalence" | "vacuous"` —
  bare-noun discriminator per registry Sub-rule 8 (central concept of
  the receipt). Matches `BranchDeletionProof.merge_proof_kind`
  (ADR 0025 v2) so consumption-side and proof-side discriminators
  align.
- `ancestry_evidence` — present iff `ancestry_kind == "ancestry"`.
  Carries the merge-base SHA and the linear-chain proof shape.
- `patch_equivalence_evidence` — present iff `ancestry_kind ==
  "patch_equivalence"`. Carries patch-equivalence proof shape
  (e.g., squash-merge / rebase-merge identification, target commit
  SHAs that materially equal the candidate's commits).
- `vacuous_evidence` — present iff `ancestry_kind == "vacuous"`.
  Records that the candidate has no commits beyond its merge base
  with the base ref (positive empty-branch evidence per ADR 0025 v2).

**Discriminator-and-sibling pattern:** per registry Sub-rule 5,
`ancestry_kind` selects which one of `ancestry_evidence` /
`patch_equivalence_evidence` / `vacuous_evidence` is populated.
Multiple populated sibling fields → mint-API rejection at Layer 1.

**Authority:** the underlying `git merge-base`, `git log`,
`git diff` commands run by the producer carry `host-observation`
authority for direct execution and `derived` authority for
cached/computed-from-prior-observation cases. `evidenceSchema`'s
existing `evidence_kind` enum (`receipt`, `observation`, `derived`)
distinguishes the two cases.

### `GitDirtyStateObservation`

Working-tree dirty state for a single worktree. Required for safe
destructive operations (e.g., before branch deletion, the worktree
must be clean or the dirty state must be explicitly acknowledged).

**Evidence shape:**

- `evidence_kind: "observation"`
- `evidence_subject_kind: "git_dirty_state"` (new enum value)
- Standard `Evidence` base fields

**Domain payload fields:**

- `repository_id`
- `worktree_path` — must match a `GitWorktreeObservation`'s
  `worktree_path` (binding via `evidenceRefSchema` to the
  underlying worktree observation is the recommended composition
  pattern; mint API may also resolve worktree_path → worktree
  observation_id directly).
- `dirty_state_kind: "clean" | "dirty_uncommitted" |
  "dirty_with_untracked" | "dirty_with_ignored_only"` —
  discriminator per registry Sub-rule 6.
- `uncommitted_path_count` — number of paths with uncommitted
  changes (commit-staged or working-tree-modified). 0 iff
  `dirty_state_kind in {"clean", "dirty_with_untracked",
  "dirty_with_ignored_only"}`.
- `untracked_path_count` — number of untracked paths. 0 iff
  `dirty_state_kind == "clean"`.
- `ignored_path_count` — number of ignored paths surfaced (when
  the producer ran with `--ignored`). May be 0 even when ignored
  files exist if the producer did not check.
- `observed_via: "git_status_porcelain"` — kernel-set per registry
  v0.3.2 (authority-class signal).

**Grain:** per-worktree (per `worktree_path`), not per-repository.
Multiple worktrees within one repository have independent dirty
states.

### `PullRequestReceipt`

Typed receipt of a Pull Request's existence and current state.
Required by `BranchDeletionProof` when `pr_state_kind in {open,
merged, closed_unmerged}`.

**Evidence shape:**

- `evidence_kind: "receipt"`
- `evidence_subject_kind: "pull_request"` (new enum value)
- Standard `Evidence` base fields

**Domain payload fields:**

- `repository_id`
- `provider_id: "github"` — discriminator per registry Sub-rule 6
  (other providers added when supported)
- `pr_number` — provider-side PR identifier
- `pr_state_kind: "open" | "merged" | "closed_unmerged"` —
  discriminator per registry Sub-rule 6. **Does NOT include
  `absent`**; positive-absence is its own receipt
  (`PullRequestAbsenceReceipt`) per registry §Naming suffix
  discipline Sub-rule 2.
- `head_sha` — commit SHA at the PR head when this receipt was
  observed
- `base_ref` — the target branch
- `merge_commit_sha` — present iff `pr_state_kind == "merged"`;
  the commit SHA of the merge commit
- `closed_unmerged_reason_kind: "abandoned" | "superseded" |
  "manual_close" | "unknown"` — discriminator per Sub-rule 6;
  present iff `pr_state_kind == "closed_unmerged"`
- `provider_observed_via: "github_api_v3" | "github_api_v4" |
  "gh_cli" | "github_mcp"` — kernel-set per registry v0.3.2
  (authority-class signal for GitHub-side observation provenance).

**Authority ladder:** provider-API-direct observations (GraphQL or
REST) carry `host-observation`; `gh` CLI / GitHub MCP indirections
carry `derived` authority unless the producer can demonstrate
direct API origin.

### `PullRequestAbsenceReceipt`

Typed positive-absence receipt for "no PR exists for this branch
ref against the named base ref." Required by `BranchDeletionProof`
when `pr_state_kind == "absent"`.

**Evidence shape:**

- `evidence_kind: "receipt"`
- `evidence_subject_kind: "pull_request_absence"` (new enum value)
- Standard `Evidence` base fields

**Domain payload fields:**

- `repository_id`
- `provider_id: "github"`
- `head_ref` — the branch ref being checked (`refs/heads/<name>`)
- `base_ref` — the target branch the absence is being asserted
  against (typically `refs/heads/main`)
- `absence_window_observed_at` — timestamp the producer observed
  the absence; binds the freshness claim
- `query_observed_via: "github_api_v3_pr_search" |
  "github_api_v4_pull_requests" | "gh_pr_list" |
  "github_mcp_pr_search"` — kernel-set per registry v0.3.2.

**Positive-absence semantics:** per registry §Naming suffix
discipline Sub-rule 2, "no PR exists for this branch" is a
`PullRequestAbsenceReceipt`, not a missing field. The receipt is
itself an observation that must be produced, dated, and
authority-tagged; an absent record is structurally undefined and
does not satisfy `BranchDeletionProof.pr_state_kind == "absent"`.

**Freshness binding:** `absence_window_observed_at` is the
canonical freshness anchor. `BranchDeletionProof` consumption at
the gateway re-checks the absence against current state per
registry v0.3.2 §Cross-context enforcement layer Layer 3
(authoritative non-escalable layer); a stale absence proof fails
re-derive.

### Cross-cutting rules

**Authority discipline (registry v0.3.2 §Producer-vs-kernel-set
authority fields):**

- Authority-class signals (`observed_via`, `provider_observed_via`,
  `query_observed_via`) are kernel-set; producer-supplied values
  rejected at mint API.
- Identity fields (`lease_id`, `owning_session_id`,
  `last_lease_check_at`) are kernel-set.
- Operational fields (paths, SHAs, refs, state discriminators,
  counts) are producer-asserted but kernel-verifiable. Mint API
  validates structure only; broker FSM and gateway re-check via
  Ring 1 telemetry per registry v0.3.2 §Cross-context enforcement
  layer.

**Cross-context binding (registry v0.3.0 §Cross-context
enforcement layer):**

- Every receipt carries `execution_context_id`.
- Mint API rejects records whose primary target reference
  (typically `repository_id`) does not resolve consistently with
  the requesting session's `ExecutionContext`.
- Broker FSM and gateway re-check at Layers 2 and 3.

**Anomalous-capture composition (ADR 0029 v2):**

- All six receipts may surface in `Decision.reason_kind` rejection
  classes per ADR 0029 v2 closed-list discipline. New rejection
  classes proposed (posture-only; schema enum lands per
  `.agents/skills/hcs-schema-change`):
  - `worktree_attachment_drift` — observed
    `attached_branch_ref` differs from the consuming proof's
    expectation
  - `worktree_inventory_partial` — `inventory_completeness_kind
    == "partial_with_reason"` consumed by an operation that
    requires `complete`
  - `ancestry_proof_invalid` — `ancestry_kind` discriminator
    inconsistent with sibling fields, or sibling proof shape
    doesn't match the discriminator
  - `dirty_state_blocks_destructive_op` — `dirty_state_kind !=
    "clean"` consumed by a destructive Git operation without
    explicit acknowledgment grant
  - `pr_state_drift` — `pr_state_kind` observed differs from
    the consuming proof's expectation, or freshness window
    expired
  - `pr_absence_stale` — `absence_window_observed_at` outside
    the consuming proof's freshness window

**`Decision.required_grant_kind` reservations:**

- `worktree_clean_acknowledgment` — typed grant scope binding to
  acknowledge a non-clean worktree for a destructive op
  (composes with ADR 0029 v2 §`ApprovalGrant.scope` shape sketch
  per-class extensions)
- `pr_absence_acknowledgment` — typed grant for proceeding under
  a stale absence proof

These reservations are posture-only; canonical names land in
`tiers.yaml` once HCS Milestone 2 ships.

### Composition with `BranchDeletionProof` (ADR 0025 v2)

`BranchDeletionProof.worktree_evidence_refs` is satisfied by one or
more `GitWorktreeObservation` records.

`BranchDeletionProof.worktree_inventory_evidence_refs` is satisfied
by exactly one `GitWorktreeInventoryObservation` per repository, ref
when the branch has more than one attached worktree (positive
single-worktree case may use the inventory or rely on the
single `GitWorktreeObservation`; the proof composite consumption
side is ADR 0025 v2's call).

`BranchDeletionProof.merge_proof_kind` discriminator selects which
`GitBranchAncestryObservation.ancestry_kind` value the consuming
component evidence must carry (`ancestry` ↔ `ancestry`,
`patch_equivalence` ↔ `patch_equivalence`, `vacuous` ↔ `vacuous`).

`BranchDeletionProof.pr_state_kind` discriminator selects which
receipt type satisfies the proof: `absent` requires
`PullRequestAbsenceReceipt`; the other three require
`PullRequestReceipt` with matching `pr_state_kind`.

`BranchDeletionProof.dirty_state_evidence_refs` (committed by
ADR 0025 v2 component-evidence binding) is satisfied by a
`GitDirtyStateObservation` per worktree being acted on; per ADR
0029 v2, a `dirty_state_kind != "clean"` observation against
`destructive_git` operation class blocks unless an
`worktree_clean_acknowledgment` grant clears the
`approval_required` cell.

### Out of scope

This ADR does not authorize:

- Zod schema source for any of the six receipts. Schema
  implementation lands per `.agents/skills/hcs-schema-change` after
  this ADR's acceptance.
- The `evidenceSubjectKindSchema` enum extension that adds
  `git_worktree`, `git_worktree_inventory`,
  `git_branch_ancestry`, `git_dirty_state`, `pull_request`,
  `pull_request_absence`. The extension lands with the schema PR.
- The `Decision.reason_kind` enum extensions for the six
  rejection-class names above. Those land per
  `.agents/skills/hcs-schema-change`.
- The `Decision.required_grant_kind` enum extensions
  (`worktree_clean_acknowledgment`, `pr_absence_acknowledgment`).
- Q-008(d) worktree-ownership composition rules. Stage-2 commits
  the field shape (`lease_id`, `owning_session_id`,
  `last_lease_check_at` on `GitWorktreeObservation`); composition
  with `WorkspaceContext` / `Lease` / Q-003 coordination facts
  remains under Q-008(d) once Q-003 settles.
- ADR 0026 substrate hook architecture. ADR 0026 is gated on
  stage-1's `BranchProtectionObservation` schema landing, not on
  stage-2.
- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. The matrix
  of operation-class × receipt-anomaly cells from ADR 0029 v2
  governs gateway behavior; canonical numeric thresholds and
  per-cell refinements land in `tiers.yaml` once HCS Milestone 2
  ships.
- Provider-specific receipts beyond GitHub. `provider_id: "github"`
  is the only currently-supported provider value; other providers
  (GitLab, Bitbucket) follow under separate ADRs if and when
  needed.

## Consequences

### Accepts

- Q-006 stage-2 is settled at the design layer with six receipts:
  `GitWorktreeObservation`, `GitWorktreeInventoryObservation`,
  `GitBranchAncestryObservation`, `GitDirtyStateObservation`,
  `PullRequestReceipt`, `PullRequestAbsenceReceipt`.
- All six are `evidenceSchema`-direct typed payloads (Q-011 bucket 1),
  matching ADR 0027 stage-1 pattern.
- `GitBranchAncestryObservation` carries an internal `ancestry_kind`
  discriminator that matches `BranchDeletionProof.merge_proof_kind`
  (ADR 0025 v2); single observation type with three sibling proof
  fields per registry Sub-rule 5.
- `PullRequestReceipt` (`pr_state_kind: open | merged |
  closed_unmerged`) and `PullRequestAbsenceReceipt` (positive
  absence) are split per registry §Naming suffix discipline
  Sub-rule 2.
- `GitWorktreeInventoryObservation` is per-(repository_id,
  branch_ref) pair, matching `GitRemoteObservation` grain.
- `GitDirtyStateObservation` is per-worktree (per `worktree_path`),
  not per-repository.
- `GitWorktreeObservation` carries `lease_id`,
  `owning_session_id`, `last_lease_check_at` field shape; Q-008(d)
  commits the *composition* with `WorkspaceContext` / `Lease` /
  Q-003 coordination facts.
- Authority-class signals (`observed_via`, `provider_observed_via`,
  `query_observed_via`) are kernel-set per registry v0.3.2.
- Six new `Decision.reason_kind` rejection-class names reserved
  (posture-only): `worktree_attachment_drift`,
  `worktree_inventory_partial`, `ancestry_proof_invalid`,
  `dirty_state_blocks_destructive_op`, `pr_state_drift`,
  `pr_absence_stale`.
- Two new `Decision.required_grant_kind` names reserved
  (posture-only): `worktree_clean_acknowledgment`,
  `pr_absence_acknowledgment`.
- The six receipt subject-kind enum values
  (`git_worktree`, `git_worktree_inventory`,
  `git_branch_ancestry`, `git_dirty_state`, `pull_request`,
  `pull_request_absence`) are reserved for the schema PR per
  registry Sub-rule 7 (subject-kind enum values name the
  underlying subject, not the receipt envelope).

### Rejects

- BoundaryObservation envelope per stage-2 receipt (Option B).
  Stage-2 receipts are observations of Git/PR state, not boundary
  facts; forcing through the envelope introduces ontological
  mismatch.
- Three separate observation types for ancestry kinds (Option C).
  Single observation with `ancestry_kind` discriminator + sibling
  proof fields is the registry-canonical pattern (Sub-rule 5) and
  matches the consumption-side discriminator (ADR 0025 v2).
- `PullRequestReceipt` carrying `pr_state_kind == "absent"`.
  Positive absence is its own `*Receipt` per registry Sub-rule 2.
- Producer-supplied `observed_via` / `provider_observed_via` /
  `query_observed_via` values; these are authority-class signals
  per registry v0.3.2 and kernel-set only.
- Producer-supplied `lease_id` / `owning_session_id` /
  `last_lease_check_at`; identity fields kernel-set per registry
  v0.3.2.
- Stage-2 committing Q-008(d) worktree-ownership composition
  rules. Stage-2 commits field shape; composition deferred.

### Future amendments

- Q-008(d) closes the worktree-ownership composition (gated on
  Q-003 coordination/shared-state architecture).
- Stage-3 (if needed): cross-provider PR receipts (GitLab,
  Bitbucket); push-receipt shape; tag-receipt shape; submodule
  observation shape.
- Charter v1.3.x or v1.4.0 follow-up may codify "destructive Git
  operations against unverified worktree state are forbidden" as
  a forbidden pattern, composing with inv. 7 mutation_scope rules
  and ADR 0029 v2's `dirty_state_blocks_destructive_op`
  rejection class.
- Reopen if a future incident shows a stage-2 receipt misses a
  class of failure.

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md` v1.3.2,
  invariants 1, 4, 5, 7, 8, 16, 17
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
  (Naming suffix discipline including Sub-rule 2 positive-absence,
  Sub-rule 5 discriminator-and-array, Sub-rule 6 `_kind`, Sub-rule
  7 subject-kind enum, Sub-rule 8 bare-noun discriminator, Sub-rule
  9 enum-value casing; Authority discipline including
  Producer-vs-kernel-set; Cross-context enforcement layer including
  layer-disagreement tiebreaker and audit-chain coverage of
  rejections)
- Decision ledger: `DECISIONS.md` Q-006, Q-008
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract; the six receipts are subtypes of this)
- ADR 0025:
  `docs/host-capability-substrate/adr/0025-branch-deletion-proof.md`
  (BranchDeletionProof composite; consumes all six stage-2 receipts;
  `merge_proof_kind` and `pr_state_kind` discriminators align with
  this ADR's `ancestry_kind` and PR-receipt split)
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (Q-006 stage-1 receipts; established the
  `evidenceSchema`-direct typed payload pattern and per-(repo,
  remote, ref) grain for `GitRemoteObservation`)
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (Q-008(a) receipts; established the typed-receipt-as-positive-
  evidence pattern and the `Evidence.producer` kernel-set discipline)
- ADR 0029:
  `docs/host-capability-substrate/adr/0029-q-008-b-anomalous-capture-blocking-thresholds.md`
  (Q-008(b) blocking thresholds; consumes stage-2 receipts as
  `Decision.reason_kind` rejection-class inputs;
  `ApprovalGrant.scope` shape sketch composes with
  `worktree_clean_acknowledgment` / `pr_absence_acknowledgment`
  reservations)
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- Q-006 source synthesis:
  `docs/host-capability-substrate/research/local/2026-04-29-github-version-control-agentic-surface.md`
- Q-006 consult synthesis:
  `docs/host-capability-substrate/research/local/2026-05-01-version-control-authority-consult-synthesis.md`
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- Git documentation, `git-worktree(1)`:
  <https://git-scm.com/docs/git-worktree>
- Git documentation, `git-merge-base(1)`:
  <https://git-scm.com/docs/git-merge-base>
- Git documentation, `git-status(1)` porcelain format:
  <https://git-scm.com/docs/git-status#_porcelain_format_version_1>
- GitHub REST API v3, Pull Requests:
  <https://docs.github.com/en/rest/pulls/pulls>
- GitHub GraphQL API v4, PullRequest object:
  <https://docs.github.com/en/graphql/reference/objects#pullrequest>
