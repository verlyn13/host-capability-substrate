---
adr_number: 0031
title: Q-008(d) worktree-ownership composition
status: proposed
date: 2026-05-03
charter_version: 1.3.2
tags: [worktree, lease, workspace-context, coordination-fact, q-008, q-003, phase-1]
---

# ADR 0031: Q-008(d) worktree-ownership composition

## Status

proposed (v1)

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Context

Q-008(d) asks: how should worktree ownership compose with
`WorkspaceContext`, `Lease`, and Q-003 coordination facts?

The 2026-04-30 ScopeCam exchange synthesis surfaced the motivating
failure family at the broader Q-008 level: an agent treating
worktree state as implicit, then performing destructive operations
against worktrees whose ownership state was never typed. Q-008(a)
settled execution-mode receipts; Q-008(b) settled anomalous-capture
blocking thresholds; Q-008(c) settled `BranchDeletionProof`
composite; Q-008(d) is the remaining sub-decision.

Q-008(d) was gated on Q-003 (coordination/shared-state architecture)
because worktree ownership becomes a typed gateable assertion best
expressed as a `CoordinationFact`. With Q-003 accepted in ADR 0019
v3 (2026-05-03), `CoordinationFact` shape is committed, including
`subject_kind: "worktree"` reserved. Q-008(d) commits the
composition layer.

Pre-draft sub-decisions approved by user (2026-05-03):
- (A) `WorkspaceContext` ↔ worktree cardinality: one-to-one.
- (B) `Lease` shape: per-(session, repository_id, worktree_path).
- (C) `CoordinationFact` shape for worktree ownership: typed
  gateable fact with `subject_kind: "worktree"` + `predicate_kind:
  "leased_to"`.
- (D) `worktree_mutation` matrix cells: keep defaults; add new
  worktree-specific rejection classes.
- (E) Conflict resolution: typed Decision events for all
  patterns; Layer 1/2/3 enforcement.
- (F) Five new `Decision.reason_kind` reservations.
- (G) One new `Decision.required_grant_kind` reservation.
- (H) `ApprovalGrant.scope` per-class extension for
  `worktree_mutation` (commits ADR 0029 v2's deferred row).
- (I) `Lease` entity field-shape posture commitment.

This ADR is doc-only and posture-only, mirroring ADR 0029 v2 / ADR
0030 v2 / ADR 0019 v3 acceptance pattern. It does not author Zod
schema source, runtime probes, or canonical policy YAML. Schema
implementation lands per `.agents/skills/hcs-schema-change` after
acceptance.

## Options considered

### Option A: Per-(session, repository_id, worktree_path) lease grain (chosen)

**Pros:**
- Most specific grain; matches `GitWorktreeObservation` per-worktree
  grain (ADR 0030 v2) and `GitDirtyStateObservation` per-worktree
  grain (ADR 0030 v2).
- A session can hold leases over multiple worktrees in one
  repository (primary + linked worktrees) without lease collision
  across worktrees.
- Composition with `WorkspaceContext` is one-to-one per (A): each
  WorkspaceContext owns exactly one worktree, so Lease grain
  matches WorkspaceContext grain.
- Conflict resolution is straightforward: two sessions cannot hold
  the same `(repository_id, worktree_path)` lease concurrently.

**Cons:**
- More granular than Option B; for a single-worktree repository,
  a session holds one lease per `worktree_path` regardless of
  branch checkouts.

### Option B: Per-(session, repository_id, branch_ref) lease grain

**Pros:**
- Simpler: one lease per branch a session is working on.
- Composes naturally with `BranchDeletionProof` (ADR 0025 v2)
  which is branch-scoped.

**Cons:**
- A primary worktree on `branch_X` and a linked worktree on
  `branch_Y` would require two leases at the branch level even
  though they're both inside one repository — fine.
- BUT: a primary worktree on `branch_X` + a linked worktree
  also on `branch_X` (Git allows multiple worktrees of the same
  branch transiently) would force one Lease across two
  worktree paths. Lock state and dirty state are per-worktree,
  not per-branch; the Lease can't speak for both.
- Lease grain mismatch with `GitWorktreeObservation` /
  `GitDirtyStateObservation` per-worktree grain forces
  composition logic to re-derive the binding at every consumption.

### Option C: Per-WorkspaceContext lease grain

**Pros:**
- Lease ties directly to the higher-level entity that names what
  the session is working on.

**Cons:**
- WorkspaceContext is one-to-one with a worktree per (A), so this
  collapses to Option A in practice but loses the explicit
  per-(repository_id, worktree_path) typed reference shape.
- Cross-context coordination (e.g., release coordination spanning
  multiple WorkspaceContexts) becomes harder to express.

## Decision

Choose Option A. Q-008(d) commits per-(session, repository_id,
worktree_path) Lease grain with one-to-one WorkspaceContext ↔
worktree cardinality, typed `CoordinationFact` materialization of
ownership, and Layer 1/2/3 enforcement.

### `WorkspaceContext` ↔ worktree cardinality (one-to-one)

A `WorkspaceContext` owns exactly one worktree at any time.
Multi-worktree contexts (a context that spans a primary + linked
worktrees) are explicitly out of scope for Phase 1.

The one-to-one rule is enforced at Layer 1 mint API: a
`WorkspaceContext` carries a single `worktree_path` field (NEW;
previously implicit). Producer-supplied `WorkspaceContext` records
without a `worktree_path` are accepted at the mint API for
backward compatibility with existing contexts that pre-date this
ADR; canonical policy at Milestone 2 may tighten this rule once
all downstream contexts have the field.

The `worktree_path` on `WorkspaceContext` is paired with a
`repository_id` (typed FK to `GitRepositoryObservation`-resolved
repository identity per ADR 0027 v2). Together, the
`(repository_id, worktree_path)` pair is the canonical worktree
identity within a `WorkspaceContext`.

### `Lease` entity field-shape posture commitment

The existing `Lease` entity (no-suffix Ring 0 entity per registry
§Naming suffix discipline) gains the following fields for
worktree-ownership composition. The fields are committed at this
stage; the actual Zod schema lands per
`.agents/skills/hcs-schema-change` after acceptance.

**Domain shape (illustrative):**

- `lease_id` — primary key (existing).
- `lease_kind: "worktree" | "credential_audience" | "external_target"` —
  discriminator per registry Sub-rule 6 (NEW; existing leases
  default to a Phase 1 default value to be selected at schema
  time, e.g., `lease_kind: "worktree"` if Phase 0/0a leases were
  worktree-shaped).
- `held_by_session_id` — kernel-set FK to the `Session` holding
  the lease.
- `held_by_agent_client_id` — kernel-set FK to the `AgentClient`
  the holding session belongs to. Per registry v0.3.1 canonical
  attribution.
- `acquired_at` — kernel-set timestamp.
- `valid_until` — producer-asserted; canonical policy at Milestone
  2 may impose per-`lease_kind` maximum window.
- `released_at` — kernel-set timestamp; null until release event.
- `lease_state: "active" | "expired" | "released" |
  "force_broken"` — discriminator per registry Sub-rule 6;
  bare-noun central concept of the entity per Sub-rule 8.
- `force_break_grant_id` — kernel-set FK; populated only when
  `lease_state == "force_broken"`.

**Worktree-specific fields (when `lease_kind: "worktree"`):**

- `repository_id` — typed FK per ADR 0027 v2 first-commit-SHA-rooted
  resolution.
- `worktree_path` — absolute filesystem path to the worktree.
- `workspace_context_id` — typed FK to `WorkspaceContext` (per
  the one-to-one cardinality rule above).

**Authority discipline:**

- `held_by_session_id`, `held_by_agent_client_id`, `acquired_at`,
  `released_at`, `force_break_grant_id` are kernel-set per
  registry v0.3.2 §Producer-vs-kernel-set authority fields.
- `lease_kind`, `repository_id`, `worktree_path`,
  `workspace_context_id`, `valid_until` are producer-asserted but
  kernel-verifiable (filesystem stat for `worktree_path`;
  `WorkspaceContext` resolution for `workspace_context_id`).
- `lease_state` is kernel-set; transitions are typed Decision
  events (see §Lease lifecycle below).

### `CoordinationFact` shape for worktree ownership

Worktree ownership is materialized as a typed gateable
`CoordinationFact` per ADR 0019 v3:

- `subject_kind: "worktree"` (reserved in ADR 0019 v3; this ADR
  binds the per-kind `subject_ref` shape).
- `subject_ref: { repository_id, worktree_path }` — the
  polymorphic FK shape for `subject_kind == "worktree"`.
- `predicate_kind: "leased_to"` — NEW candidate value for the
  §Predicate-kind vocabulary registry follow-up entry per ADR
  0019 v3 §Predicate-kind registry reservation. Other candidate
  values for the worktree subject:
  - `attached_to` — branch-worktree binding state
  - `held_by` — generic ownership (less specific than
    `leased_to`; reserved for future use)
- `object_kind: "scoped_assertion"` — discriminator per ADR 0019
  v3.
- `object`: `{ session_id, lease_id, valid_until,
  lease_acquired_at }`.
- `evidence_refs`: array of `evidenceRefSchema` references to
  `GitWorktreeObservation` (current observed state) + the `Lease`
  record (the typed ownership claim).
- Standard `CoordinationFact` fields: `authority` (cannot be
  `self-asserted` per ADR 0019 v3 §`CoordinationFact`
  rule), `confidence`, kernel-set `allowed_for_gate` (false until
  promoted via Q-003 promotion workflow).

The `CoordinationFact` materializes ownership at the typed
gateable layer; consumers cite `coordination_fact_id` rather than
re-deriving from `Lease` + `GitWorktreeObservation` + `Session`
state at every consumption.

### `worktree_mutation` matrix cell refinements

ADR 0029 v2 §Operation classes class 5 named `worktree_mutation`
with default cells gated on Q-008(d). Q-008(d) commits the cells.

**Decision: keep ADR 0029 v2 defaults.** The default cells (block
for B/C/D/E/G/H, warn for A/F) handle generic capture anomalies.
Q-008(d) does NOT revise the cell content; instead, Q-008(d)
introduces NEW worktree-specific rejection classes that compose
*with* the matrix.

The matrix row for `worktree_mutation` from ADR 0029 v2 stands as:

| Combination | worktree_mutation |
|---|---|
| A. empty_apparent_success | warn |
| B. capture_failure | block |
| C. abnormal_termination | block |
| D. authority_self_asserted | block |
| E. mode_unknown | block |
| F. capture_truncated_at_cap | warn |
| G. producer_class_forgery_attempt | block |
| H. cross_receipt_inconsistency | block |

The new worktree-specific rejection classes (see §Decision.reason_kind
reservations below) fire *in addition* to the matrix; an operation
against a leased worktree must pass the matrix AND the
lease-binding checks.

### `ApprovalGrant.scope` per-class extension for `worktree_mutation`

ADR 0029 v2 §`ApprovalGrant.scope` shape sketch deferred the
`worktree_mutation` per-class extension to Q-008(d). Q-008(d)
commits:

A `worktree_mutation` operation-class grant must bind:

- `operation_class: "worktree_mutation"`
- `target_ref: { repository_id, worktree_path }` — per-worktree
  grain matching `Lease` and `GitWorktreeObservation`.
- `lease_id` — required; the specific Lease the grant authorizes
  the operation against.
- `execution_context_id` — per registry v0.3.0 §Cross-context
  enforcement layer.

A grant scoped without `lease_id` is rejected at Layer 1 mint
API. A grant scoped to a different `worktree_path` than the
operation's target is rejected at Layer 3 gateway re-derive per
inv. 6.

### Conflict resolution patterns

**1. Multiple sessions claiming same worktree.** Layer 1 mint API
rejects a second `Lease` whose `(repository_id, worktree_path)`
already has an `active` `lease_state` for a different
`held_by_session_id`. The rejection class is
`Decision.reason_kind: worktree_lease_held_by_other_session`. The
existing lease's holder retains ownership; the second-session
attempt does not implicitly displace it.

**2. Lease expiry mid-mutation.** A `Lease` whose `valid_until`
passes during operation execution is detected at Layer 2 broker
FSM re-check. The operation rejects with
`Decision.reason_kind: worktree_lease_expired_during_mutation`.
The mutation does not proceed; the session must reacquire a fresh
lease (which may require human acknowledgment if mid-mutation
rollback is not possible).

**3. Dirty state in leased worktree.** Composes with ADR 0030 v2
`dirty_state_blocks_destructive_op` rule. A leased worktree with
`GitDirtyStateObservation.dirty_state_kind != "clean"` against a
destructive operation still requires a `worktree_clean_acknowledgment`
grant (per ADR 0030 v2 §Decision.required_grant_kind reservations).
The lease does NOT override the dirty-state requirement; both
checks apply.

**4. Force-break-glass for stuck leases.** A session that holds
a stuck `Lease` (e.g., the holding session crashed without
releasing) is force-broken via a typed
`worktree_lease_force_break_acknowledgment` grant (NEW; mirrors
ADR 0030 v2 `worktree_clean_acknowledgment` pattern). The grant
binds the specific stuck `lease_id`; consumption flips
`lease_state: active → force_broken` and sets
`force_break_grant_id`. A new lease can then be acquired by the
requesting session.

**5. Operation against worktree not in WorkspaceContext.** A
mutation operation whose target `(repository_id, worktree_path)`
does not match the session's current `WorkspaceContext.worktree_path`
+ `WorkspaceContext.repository_id` rejects at Layer 1 mint API
with `Decision.reason_kind: worktree_not_in_workspace_context`.
This closes the failure mode where a session leases worktree A,
switches its `WorkspaceContext` to worktree B, then attempts a
mutation against A without re-establishing context.

### Lease lifecycle (typed Decision events)

The `Lease` lifecycle has four typed transitions, each emitting a
typed `Decision` in the audit chain:

- **Acquire** (`lease_state: null → active`): Layer 1 mint API
  creates the Lease record; emits Decision with the kernel-set
  six-field shape from ADR 0019 v3 §Promotion audit-record
  completeness extended to lease events (`agent_client_id`,
  `session_id`, `transition_layer: mint_api`,
  `lease_id`, `transition_kind: acquire`, `acquired_at`).
- **Release** (`lease_state: active → released`): explicit
  release by the holding session; sets `released_at`. Decision
  with `transition_kind: release`.
- **Expiry** (`lease_state: active → expired`): kernel-detected
  at Layer 2 broker FSM re-check or Layer 3 gateway re-derive
  when `valid_until` passes. Sets `released_at` to
  `valid_until`. Decision with `transition_kind: expiry`.
- **Force-break** (`lease_state: active → force_broken`):
  consumption of a `worktree_lease_force_break_acknowledgment`
  grant by the requesting (NOT the original) session. Sets
  `force_break_grant_id`. Decision with `transition_kind:
  force_break`.

All four transitions participate in the audit hash chain per
charter inv. 4 + registry v0.3.1 §Audit-chain coverage of
rejections (extended to lease lifecycle events by inheritance).

### Cross-context binding rules per Ring 1 layer

Per registry v0.3.0 §Cross-context enforcement layer requirement:

- **`Lease` (when `lease_kind: "worktree"`)**: Layer 1 enforces
  `(repository_id, worktree_path)` uniqueness against
  `lease_state: active` records; rejects double-lease attempts.
  Layer 1 also enforces `workspace_context_id` consistency with
  the requesting session's `ExecutionContext`. Layer 2 re-checks
  `valid_until` and `lease_state` at operation-execution time.
  Layer 3 re-derives at decision time per inv. 6.
- **`CoordinationFact` (subject_kind: "worktree")**: Layer 1
  enforces `evidence_refs` consistency (the cited
  `GitWorktreeObservation` and `Lease` must share
  `execution_context_id` per ADR 0019 v3 strict default). Layer
  1 also enforces `subject_ref.repository_id` matches the cited
  Lease's `repository_id`. Layer 2 re-checks `allowed_for_gate`
  and `valid_until`. Layer 3 re-derives.
- **`WorkspaceContext`**: Layer 1 enforces single `worktree_path`
  per context (one-to-one rule) once canonical policy tightens
  past the backward-compatibility default. Layer 2 re-checks
  consistency between `WorkspaceContext.worktree_path` and any
  `GitWorktreeObservation` records cited by the consuming
  operation. Layer 3 re-derives.

### Authority discipline

Authority-class signals across `Lease`, the worktree
`CoordinationFact`, and `WorkspaceContext` follow registry v0.3.2
§Producer-vs-kernel-set discipline:

- **Kernel-set**: `held_by_session_id`, `held_by_agent_client_id`,
  `acquired_at`, `released_at`, `force_break_grant_id`,
  `lease_state` (Lease); `subject_ref.repository_id` resolution,
  `allowed_for_gate`, `promoted_at`, `promotion_grant_id`
  (CoordinationFact, inherited from ADR 0019 v3).
- **Producer-asserted, kernel-verifiable**: `lease_kind`,
  `repository_id`, `worktree_path`, `workspace_context_id`,
  `valid_until` (Lease); `predicate_kind`, `object` payload
  (CoordinationFact); `worktree_path`, `repository_id`
  (WorkspaceContext).

### Predicate-kind vocabulary candidates

This ADR confirms three candidate values for the §Predicate-kind
vocabulary registry follow-up entry (per ADR 0019 v3 §Predicate-
kind registry reservation):

- `leased_to` — primary value committed by this ADR;
  `CoordinationFact` materializing worktree ownership uses this
  predicate.
- `attached_to` — reserved candidate; future use for branch-
  worktree attachment as a separate gateable assertion.
- `held_by` — reserved candidate; generic ownership predicate
  less specific than `leased_to`; reserved for future use only.

The registry update PR (precondition for `CoordinationFact`
schema implementation per ADR 0019 v3) commits the closed enum
including these and other ADR 0019-derived candidates.

### Out of scope

This ADR does not authorize:

- Zod schema source for `Lease`, `WorkspaceContext`, or the
  `subject_kind: "worktree"` `subject_ref` shape on
  `CoordinationFact`. Schema implementation lands per
  `.agents/skills/hcs-schema-change` after acceptance.
- `Lease.lease_kind` enum extension beyond the three reserved
  values (`worktree`, `credential_audience`, `external_target`).
  New `lease_kind` values require an ontology-controlled
  vocabulary update.
- Multi-worktree `WorkspaceContext` (a context spanning primary
  + linked worktrees). Phase 1 is one-to-one per (A);
  multi-worktree revisitable when an incident motivates it.
- `Lease` GC / expiry / extension policy windows. Canonical
  policy at Milestone 2 imposes per-`lease_kind` maximum
  windows.
- Cross-host lease (single-host posture per charter inv. 10).
- Charter invariant text for any worktree-ownership rule.
  Q-008(d) is doc-only / posture-only.
- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. Per-
  `lease_kind` windows, per-class force-break-glass authority,
  and verifier-class privileges all land in `tiers.yaml` once
  HCS Milestone 2 ships.
- ADR 0026 substrate hook architecture (still gated on
  stage-1 `BranchProtectionObservation` schema landing).
- Q-006 (b)–(g) sub-decisions (separate ADR cycle).

## Consequences

### Accepts

- Q-008(d) is settled at the design layer with per-(session,
  repository_id, worktree_path) Lease grain, one-to-one
  WorkspaceContext ↔ worktree cardinality, typed `CoordinationFact`
  materialization of ownership.
- `Lease` entity gains worktree-ownership composition fields:
  `lease_kind` discriminator (with new `"worktree"` value),
  `held_by_session_id`, `held_by_agent_client_id`, `acquired_at`,
  `valid_until`, `released_at`, `lease_state` discriminator,
  `force_break_grant_id`, plus worktree-specific
  `repository_id`, `worktree_path`, `workspace_context_id`.
- `WorkspaceContext` gains `worktree_path` + `repository_id`
  field-shape commitment (one-to-one cardinality with worktree).
  Backward compatibility: existing contexts without the field
  accepted at mint API; canonical policy at Milestone 2 may
  tighten.
- `CoordinationFact` `subject_kind: "worktree"` shape committed:
  `subject_ref: { repository_id, worktree_path }`;
  `predicate_kind: "leased_to"`; `object_kind: "scoped_assertion"`;
  `object: { session_id, lease_id, valid_until,
  lease_acquired_at }`; `evidence_refs` cite
  `GitWorktreeObservation` + `Lease`.
- `worktree_mutation` matrix cells from ADR 0029 v2 stand as
  defaults; Q-008(d) introduces NEW worktree-specific rejection
  classes that compose with the matrix.
- `ApprovalGrant.scope` per-class extension for
  `worktree_mutation` committed: `target_ref: { repository_id,
  worktree_path }` + required `lease_id` + `execution_context_id`.
- Conflict resolution patterns explicit: double-lease rejection
  at Layer 1; lease-expiry-mid-mutation rejection at Layer 2;
  dirty-state composition with ADR 0030 v2; force-break-glass
  via typed grant; out-of-context worktree rejection at Layer 1.
- `Lease` lifecycle has four typed Decision events: acquire,
  release, expiry, force-break. All participate in audit hash
  chain per inv. 4.
- Cross-context binding rules explicit per Ring 1 layer (mint
  API / broker FSM / gateway).
- Authority discipline follows registry v0.3.2 §Producer-vs-
  kernel-set; identity fields kernel-set; operational fields
  producer-asserted but kernel-verifiable.
- Five new `Decision.reason_kind` rejection-class names
  reserved (posture-only): `worktree_lease_unavailable`,
  `worktree_lease_held_by_other_session`,
  `worktree_lease_expired_during_mutation`,
  `worktree_not_in_workspace_context`,
  `coordination_fact_worktree_drift`.
- One new `Decision.required_grant_kind` reservation (posture-
  only): `worktree_lease_force_break_acknowledgment`.
- Three Predicate-kind vocabulary candidates confirmed for the
  registry follow-up: `leased_to` (primary, committed by this
  ADR), `attached_to` (reserved), `held_by` (reserved).

### Rejects

- Per-(session, repository_id, branch_ref) lease grain (Option
  B). Lease-grain mismatch with `GitWorktreeObservation` /
  `GitDirtyStateObservation` per-worktree grain; multiple
  worktrees of the same branch transient case forces one
  Lease across two worktree paths.
- Per-WorkspaceContext lease grain (Option C). Collapses to
  Option A in practice but loses explicit per-(repository_id,
  worktree_path) typed reference.
- Multi-worktree WorkspaceContext for Phase 1. Out of scope;
  revisit when an incident motivates.
- Lease over-riding dirty-state requirement. Both checks apply
  per ADR 0030 v2 composition.
- Implicit lease displacement on second-session claim. The
  existing lease's holder retains ownership; force-break
  requires a typed grant.
- Worktree `CoordinationFact` with `authority: self-asserted`.
  Inherited from ADR 0019 v3 §`CoordinationFact` authority rule.
- Cross-host lease. Single-host posture per charter inv. 10.

### Future amendments

- Multi-worktree `WorkspaceContext` ADR (revisit when an
  incident motivates).
- Schema PR per `.agents/skills/hcs-schema-change` for `Lease`
  field additions, `WorkspaceContext.worktree_path` +
  `repository_id`, `CoordinationFact` `subject_kind: "worktree"`
  `subject_ref` shape.
- `§Predicate-kind vocabulary` registry update including
  `leased_to`, `attached_to`, `held_by` (precondition for
  `CoordinationFact` schema implementation per ADR 0019 v3).
- `Decision.reason_kind` schema PR enumerating the five new
  worktree-specific values plus the eleven from ADR 0019 v3
  plus the prior values from ADR 0029 v2 / ADR 0030 v2.
- Canonical policy YAML at Milestone 2: per-`lease_kind` maximum
  windows; per-class force-break-glass authority (which
  authority class can mint the grant); verifier-class
  privileges; backward-compatibility tightening for
  `WorkspaceContext.worktree_path`.
- Q-008(d)-followup: ADR addressing what happens when a
  WorkspaceContext switches its worktree mid-session (does the
  prior Lease auto-release? require explicit release?). Phase
  1 default: explicit release required.
- Charter v1.4.0 candidate: codify "worktree mutations require
  typed lease + dirty-state + matrix-pass" as a forbidden-
  pattern violation when any of the three is missing. Charter
  amendment per change-policy in separate PR.
- Reopen if a future incident shows the per-worktree grain
  misses a class of failure (e.g., cross-worktree dependency
  graph) or over-blocks a legitimate flow.

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md` v1.3.2,
  invariants 1, 4, 5, 6, 7, 8, 10, 16, 17
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
- Decision ledger: `DECISIONS.md` Q-003, Q-008
- ADR 0019:
  `docs/host-capability-substrate/adr/0019-knowledge-and-coordination-store.md`
  (Q-003 v3 final; `CoordinationFact` shape; promotion workflow;
  `subject_kind: "worktree"` reserved; §Predicate-kind registry
  reservation)
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (`Evidence` base contract; `evidenceRefSchema`)
- ADR 0025:
  `docs/host-capability-substrate/adr/0025-branch-deletion-proof.md`
  (BranchDeletionProof composite; force-protected non-escalable
  enforcement)
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (`GitRepositoryObservation` first-commit-SHA-rooted
  `repository_id` resolution)
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (Q-008(a) execution-mode receipts)
- ADR 0029:
  `docs/host-capability-substrate/adr/0029-q-008-b-anomalous-capture-blocking-thresholds.md`
  (Q-008(b) v2 final; `worktree_mutation` operation class with
  default cells gated on Q-008(d); §`ApprovalGrant.scope` shape
  sketch deferred per-class extension; §`block` vs forbidden-
  tier framing)
- ADR 0030:
  `docs/host-capability-substrate/adr/0030-q-006-stage-2-source-control-evidence-subtypes.md`
  (Q-006 stage-2 v2 final; `GitWorktreeObservation` with
  kernel-set lease_id / owning_session_id / last_lease_check_at;
  `dirty_state_blocks_destructive_op` rejection class +
  `worktree_clean_acknowledgment` grant pattern)
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- Coordination-lessons brief:
  `docs/host-capability-substrate/research/external/2026-04-24-coordination-lessons.md`
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- Git documentation, `git-worktree(1)`:
  <https://git-scm.com/docs/git-worktree>
- Git documentation, `git-worktree-lock(1)` (Git's per-worktree
  lock; HCS `Lease` is a typed superset):
  <https://git-scm.com/docs/git-worktree#Documentation/git-worktree.txt-lock>
