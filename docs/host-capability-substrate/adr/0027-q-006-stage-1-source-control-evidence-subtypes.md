---
adr_number: 0027
title: Q-006 stage-1 source-control evidence subtypes (Repository, Remote, BranchProtection)
status: proposed
date: 2026-05-02
charter_version: 1.3.2
tags: [git, github, evidence-subtype, branch-protection, q-006, q-008, phase-1]
---

# ADR 0027: Q-006 stage-1 source-control evidence subtypes

## Status

proposed

## Date

2026-05-02

## Charter version

Written against charter v1.3.2 and `docs/host-capability-substrate/ontology-registry.md`
v0.2.1.

## Context

ADR 0020 (accepted 2026-05-01) committed Q-006's limited posture: five
near-term review names plus a deferred broader inventory of fourteen
candidate Q-006 receipts pending Q-011-guided ontology review. Q-011 was
approved 2026-05-01 and the registry codification landed in registry
v0.2.0 (2026-05-02) and v0.2.1 (2026-05-02).

This ADR is the first **stage-1 expansion** of the broader Q-006 inventory.
It commits posture for three foundational receipts:

- `GitRepositoryObservation`
- `GitRemoteObservation`
- `BranchProtectionObservation`

Selection rationale (load-bearing minimum):

- `GitRepositoryObservation` is foundational. ADR 0025 v2's
  `repository_id` provenance ("set by the minting service from
  `WorkspaceContext` resolution") needs a typed observation behind it.
  Without it, every other Q-006 receipt has a forgeable repository
  binding.
- `GitRemoteObservation` directly closes the 2026-04-30 ScopeCam
  exchange motivating failure: "remote-gone" becomes a typed observation
  about one remote at one time, not an agent assertion.
- `BranchProtectionObservation` unblocks the architecturally interesting
  half of ADR 0026 (substrate hook architecture for non-literal
  protected refs); without it, ADR 0026 reduces to a documentation
  refinement of the existing literal-protected-list.

The remaining five Q-006 receipts queued in ADR 0025 v2 schema gating —
`GitWorktreeObservation`, `GitWorktreeInventoryObservation`,
`GitBranchAncestryObservation`, `GitDirtyStateObservation`,
`PullRequestReceipt`, `PullRequestAbsenceReceipt` — are stage-2 work.
They depend on the foundational three; a separate stage-2 ADR will
follow.

This ADR does not implement schemas, generated JSON Schema, policy
tiers, hooks, adapters, dashboard routes, runtime probes, or mutation
operations. It is doc-only and posture-only, mirroring ADR 0020's
limited-posture pattern.

## Options considered

### Option A: All three as standalone Evidence subtype envelopes (own envelope shapes)

**Pros:**
- Parallel structure to `BoundaryObservation` (each receipt has its own
  envelope with provenance fields and target binding).
- Type-system clarity at the envelope level.

**Cons:**
- Multiplies envelope shapes when most receipts can use ADR 0023's
  `Evidence` base directly with a typed `payload_schema_version` and
  `payload`.
- Couples Q-006 receipts more tightly than they need to be.

### Option B: All three as `BoundaryObservation` payloads

**Pros:**
- Reuses one canonical envelope.
- Cross-context binding discipline already enforced.

**Cons:**
- Pollutes the `boundary_dimension` registry with non-boundary
  identification facts (a repository's existence and a remote's last-
  fetch state are not contextual boundary claims; they are factual
  observations).
- Conflates two distinct mental models: BoundaryObservation is for
  delineation between contexts/surfaces; Q-006 receipts are about
  observed Git state.

### Option C: Mixed — `evidenceSchema` direct for Repository and Remote; `BoundaryObservation` payload for BranchProtection (chosen)

**Pros:**
- `GitRepositoryObservation` and `GitRemoteObservation` are factual
  state observations that fit ADR 0023's `Evidence` base contract with
  a typed payload directly. No new envelope is needed; `evidence_kind:
  "observation"` already exists; `subject_refs` already supports
  `git_repository` and `git_ref` subject kinds.
- `BranchProtectionObservation` is a contextual classification (the
  branch is on the protected side of a boundary or on the unprotected
  side); it fits BoundaryObservation's mental model. Reusing the
  envelope inherits target binding, observation_state seven-state
  vocabulary, and freshness semantics for free.
- Avoids both pitfalls: no envelope-multiplication; no
  registry-pollution.

**Cons:**
- Requires the `boundary_dimension` registry to gain a new dimension
  (`branch_protection`) when schema implementation lands. The
  registration flow is already established; this is followed-not-
  invented.
- A future Q-006 receipt that crosses categories will need to choose
  per-receipt; the precedent says "default to `evidenceSchema` direct;
  use BoundaryObservation only when the fact is truly a contextual
  boundary claim."

## Decision

Choose Option C.

### `GitRepositoryObservation`

A typed `Evidence` record using `evidenceSchema` from ADR 0023 directly,
with:

- `evidence_kind: "observation"`
- `subject_refs` includes a `{subject_kind: "git_repository",
  subject_id: <repository_id>}` reference.
- `payload_schema_version: "git_repository_observation:v1"` (canonical
  exact value to be set when schema implementation lands).
- `payload` shape (candidate field block):

```text
repository_id
git_dir_path
work_tree_path optional
default_branch optional
remote_observation_evidence_refs   array (min(1) when remotes exist)
detected_at
detected_by   enum: kernel_probe | host_telemetry | sandbox_marker
```

Cross-context binding rules:

- `repository_id` is resolved by a Ring 1 service from
  `WorkspaceContext`; agent-supplied `repository_id` is rejected at the
  observation-mint API. The resolution audit trail is the
  `subject_refs` chain plus the `WorkspaceContext` reference in the
  `Evidence` base.
- `remote_observation_evidence_refs` references `GitRemoteObservation`
  records consistent with the same `repository_id`. Multi-remote
  repositories (fork + upstream + mirror) are first-class: each remote
  is a distinct observation, and the inventory composes via this
  array.

### `GitRemoteObservation`

A typed `Evidence` record using `evidenceSchema` directly, with
**per-(repository, remote_name, ref) grain**:

- `evidence_kind: "observation"`
- `subject_refs` includes `{subject_kind: "git_ref", subject_id:
  "<repository_id>/<remote_name>/<ref_name>"}`.
- `payload_schema_version: "git_remote_observation:v1"`.
- `payload` shape (candidate field block):

```text
repository_id
remote_name
remote_url
ref_name
observed_commit_sha   nullable    // null when ref is gone
last_fetch_at
last_fetch_outcome   enum: ok | network_error | auth_error | rejected
ref_state            enum: present | gone | ambiguous | unknown
```

Cross-context binding rules:

- `repository_id` must match the parent `GitRepositoryObservation`'s
  `repository_id`.
- `ref_state: gone` is the canonical typed answer for the ScopeCam
  failure mode. An agent that observed `ref_state: gone` from a stale
  fetch is required to refresh before treating the observation as
  deletion-relevant.

The "remote-as-a-whole" question (e.g., does `origin` exist as a
remote? what is its current URL?) is captured in
`GitRepositoryObservation.payload.remote_observation_evidence_refs`
plus per-remote-per-ref `GitRemoteObservation` records. A separate
`GitRemoteInventoryObservation` is queued only if a future incident
shows the per-(remote, ref) shape leaves a gap.

### `BranchProtectionObservation`

A `BoundaryObservation` payload (per ADR 0022's envelope) for a new
`branch_protection` boundary dimension, registered as `proposed` in
`docs/host-capability-substrate/ontology-registry.md` when schema
implementation lands.

- `BoundaryObservation.boundary_dimension: "branch_protection"`
- `BoundaryObservation.tool_or_provider_ref`: the branch / ruleset
  target reference (e.g., `<repository_id>:branch:<ref_name>`).
- `BoundaryObservation.observed_payload` shape (candidate, payload
  schema family `branch_protection:v1`):

```text
repository_id
ref_name
protection_kind   enum: classic_protection | ruleset | both | none | unknown
ruleset_id        optional
ruleset_version   optional
required_check_names   array
required_review_count  optional
restrictions_push     enum: blocked | allowed | bypass_only
restrictions_delete   enum: blocked | allowed | bypass_only
restrictions_force_push enum: blocked | allowed | bypass_only
bypass_actor_count    optional
linear_history_required optional
last_observed_at
```

Cross-context binding rules:

- The `repository_id` in the payload must match the
  `GitRepositoryObservation` for the same surface. A
  `BranchProtectionObservation` whose `repository_id` does not resolve
  to a current `GitRepositoryObservation` fails composition under
  charter v1.3.2 wave-3 cross-context evidence reuse.
- The `boundary_dimension: branch_protection` registry entry will name
  `tool_or_provider_ref` as the primary target reference and
  `workspace_id` as an allowed supplemental.

### Authority handling (all three)

- Local Git operations (e.g., `git remote -v`, `git config --get
  remote.origin.url`, fetched state from `.git`) produce
  `host-observation` authority when run on host or
  `sandbox-observation` when run inside a sandbox per inv. 8 (charter
  v1.3.2 fabricated-evidence-envelope forbidden pattern).
- GitHub API responses (e.g., `gh api repos/.../branches/.../protection`)
  produce `installed-runtime` authority when issued by a verified
  authoritative tool installation; `vendor-doc` authority is reserved
  for static documentation citations and is not appropriate for
  runtime observation.
- Sandbox-context observations remain `sandbox-observation` and cannot
  be promoted (charter inv. 8). A `BranchProtectionObservation`
  produced inside a sandbox without a host-side counterpart cannot
  satisfy ADR 0025 v2's `is_protected` field for the gateway's
  layer-3 re-check.

### Out of scope

This ADR does not authorize:

- Schema source (Zod, generated JSON Schema, tests, fixtures). Schema
  implementation uses `.agents/skills/hcs-schema-change` after this
  ADR's acceptance.
- The remaining five Q-006 stage-2 receipts
  (`GitWorktreeObservation`, `GitWorktreeInventoryObservation`,
  `GitBranchAncestryObservation`, `GitDirtyStateObservation`,
  `PullRequestReceipt`, `PullRequestAbsenceReceipt`).
- Adding `branch_protection` to the `boundary_dimension` registry or
  to `boundaryDimensionSchema` enum. That registry/enum update lands
  with the schema implementation PR per ontology-registry §Adding or
  removing a dimension and §Registration rules rule 7.
- ADR 0026 substrate hook architecture (separate ADR, gated on
  `BranchProtectionObservation` schema acceptance).
- Q-006 broader receipt inventory beyond the three stage-1 picks.
- GitHub API call shapes, MCP tool definitions, dashboard routes, or
  runtime probes.
- Mutating Git operations (push, ref delete, ruleset edit). Any
  mutation surface remains gated on ADR 0025 v2's
  `BranchDeletionProof`-style proof composites for its category.

## Consequences

### Accepts

- The three stage-1 Q-006 receipts are committed by name and shape.
  Future schema work targets these names without re-litigation.
- `evidenceSchema` (ADR 0023) is the canonical envelope for non-
  contextual-boundary Q-006 receipts. New Q-006 receipts default to
  this envelope unless they make a deliberate `BoundaryObservation`
  payload case.
- `GitRemoteObservation` per-(repository, remote_name, ref) grain is
  the canonical answer for ScopeCam-style "remote-gone" observations.
- `BranchProtectionObservation` is a `BoundaryObservation` payload for
  a future `branch_protection` dimension. The registry update happens
  with schema implementation, not with this ADR.
- The repository identity chain (`WorkspaceContext` →
  `GitRepositoryObservation.repository_id` → child observations) is
  the canonical cross-context binding for Q-006 work.
- ADR 0025 v2 component evidence subtypes named here
  (`GitRepositoryObservation`, `GitRemoteObservation`) are now committed
  at posture level, unblocking the `BranchDeletionProof` schema
  implementation step that depends on them.
- ADR 0026 substrate hook architecture has a typed
  `BranchProtectionObservation` to consume for non-literal protected
  ref classification.

### Rejects

- Embedding repository identity, remote state, and branch protection
  into a single `OperationShape` argument shape (loses observation
  identity and cross-context binding).
- Treating "ref not visible in last fetch" as deletion authority
  without a fresh `GitRemoteObservation` (the ScopeCam failure mode).
- Using `BoundaryObservation` as the envelope for
  `GitRepositoryObservation` or `GitRemoteObservation` (Option B).
- Inventing new envelope shapes for receipts that fit
  `evidenceSchema` directly (Option A).
- Adding `branch_protection` to the registry/enum in this ADR's
  commit (deferred to schema implementation PR).
- Promoting sandbox-observed branch protection to host-authoritative
  evidence (charter inv. 8).
- Treating `gh api` response in a sandbox-observation execution
  context as `host-observation` authority (charter v1.3.2 wave-3
  fabricated-evidence-envelope forbidden pattern).

### Future amendments

- Stage-2 ADR (next in sequence) covers `GitWorktreeObservation`,
  `GitWorktreeInventoryObservation`, `GitBranchAncestryObservation`,
  `GitDirtyStateObservation`, `PullRequestReceipt`, and
  `PullRequestAbsenceReceipt`. ADR 0025 v2 schema implementation gates
  on stage-2 plus stage-1 landing.
- ADR 0026 (substrate hook architecture) follows once
  `BranchProtectionObservation` schema lands.
- Reopen if Q-005 runner work introduces remote-only repository facts
  (e.g., release-only mirrors) that need different repository-identity
  semantics.
- Reopen if Q-006 sub-decision (e) (split GitHub MCP read/mutation
  authority) changes the authority assignment for these observations.
- Reopen if a future incident shows the per-(remote, ref) grain misses
  a class of remote-state failure.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md`
  v1.3.2, invariants 1, 5, 8, 16, 17 (and v1.3.2 wave-3 forbidden
  patterns)
- Ontology registry: `docs/host-capability-substrate/ontology-registry.md`
  v0.2.1
- Decision ledger: `DECISIONS.md` Q-006, Q-008, Q-011
- ADR 0020:
  `docs/host-capability-substrate/adr/0020-version-control-authority.md`
  (originating Q-006 limited posture; deferred receipt list)
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (BoundaryObservation envelope used by `BranchProtectionObservation`)
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract used by all three stage-1 receipts)
- ADR 0024:
  `docs/host-capability-substrate/adr/0024-charter-v1-3-wave-2-and-3.md`
  (charter enforcement plumbing)
- ADR 0025:
  `docs/host-capability-substrate/adr/0025-branch-deletion-proof.md`
  (consumes stage-1 receipts for BranchDeletionProof composition)
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- Ontology promotion/dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`

### External

- Git `git-remote` documentation:
  <https://git-scm.com/docs/git-remote>
- Git `git-config` documentation:
  <https://git-scm.com/docs/git-config>
- GitHub branch protection API:
  <https://docs.github.com/en/rest/branches/branch-protection>
- GitHub rulesets API:
  <https://docs.github.com/en/rest/repos/rules>
- GitHub repository settings:
  <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features>
