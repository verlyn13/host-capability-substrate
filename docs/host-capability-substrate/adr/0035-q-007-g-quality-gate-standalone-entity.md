---
adr_number: 0035
title: Q-007(g) QualityGate standalone Ring 0 entity
status: proposed
date: 2026-05-03
charter_version: 1.3.2
tags: [quality-gate, ring-0-entity, q-007, phase-1]
---

# ADR 0035: Q-007(g) QualityGate standalone Ring 0 entity

## Status

proposed (v1)

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Context

Q-007(g) settles the QualityGate standalone Ring 0 entity, the
final Q-007 sub-decision. ADR 0034 v2 §Sub-decision (b)
explicitly deferred QualityGate to a standalone follow-up ADR
after Q-005 / Q-006 (b)–(g) / Q-007 (b)–(f) settled. Those
prerequisites all settled 2026-05-03 in ADRs 0032 v2, 0033 v2,
and 0034 v2. ADR 0035 is the follow-up.

Per Q-011 dedupe-plan line 142: `QualityGate` is a Q-011
bucket 2 standalone Ring 0 entity ("durable gate definition with
evidence inputs; defer until BoundaryObservation, Q-005, and
Q-006 shapes settle"). All three prerequisites are now settled.

ADR 0034 v2 §Sub-decision (b) framing: QualityGate is an
**aggregation/identity layer atop the §Sub-decision (d) three-
state matrix, NOT a new threshold layer**. Gate-consuming
operations gate on `BoundaryObservation` evidence_refs in the
interim via the matrix; QualityGate provides aggregation,
gate-identity, and gate_kind-specific composition rules — but
not new gating thresholds beyond what the matrix and existing
operation-class enforcement already commit.

Source materials:

- 2026-04-29 quality-management synthesis
  (`docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md`)
  — primary source for the six gate_kind candidates.
- 2026-05-01 ontology-promotion-receipt-dedupe-plan
  (`docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`)
  — line 142 Q-011 bucket 2 classification for QualityGate.
- ADR 0034 v2 §Sub-decision (b) — the deferral rationale; gate_kind
  candidate values; "aggregation/identity layer not threshold
  layer" framing.

This ADR is doc-only and posture-only, mirroring ADR 0029 v2 /
ADR 0030 v2 / ADR 0031 v1 / ADR 0032 v2 / ADR 0033 v2 / ADR 0034
v2 acceptance pattern. It does not author Zod schema source,
canonical policy YAML, runtime probes, dashboard route React
components, MCP adapter contracts, charter invariant text, or
per-(gate_kind, operation_class) policy rules. Schema
implementation lands per `.agents/skills/hcs-schema-change`
after acceptance.

Pre-draft decisions approved by user (2026-05-03) per
research-grounded recommendations:

1. **Gate identity** triple `(gate_id, gate_kind,
   target_subject_ref)`.
2. **Gate state lifecycle** four-state enum
   (`provisional | proven | expired | denied`).
3. **Evidence binding** single polymorphic `evidence_refs`
   array (NOT per-kind discriminator-and-array).
4. **Gate-vs-matrix composition** parallel layers, NOT sequential.
5. **Per-gate_kind evidence sketches** documented narratively for
   all six kinds.

## Decision

### 1. Gate identity

`QualityGate` is a standalone Ring 0 entity (Q-011 bucket 2)
with durable identity and lifecycle. Identity triple:

- **`gate_id`** — primary key (UUID; mint-API-allocated).
- **`gate_kind`** — closed-enum discriminator per registry
  Sub-rule 6, with six reserved values:
  - `identity_binding`
  - `credential_shadow`
  - `signing_identity`
  - `filesystem_trust`
  - `tool_provenance`
  - `mutation_class`
  Future gate_kind values require an ontology-controlled
  vocabulary update (registry §Adding a new suffix or
  convention). The six values land in the registry update PR
  alongside ADR 0034 v2's four `boundary_dimension` candidates.
- **`target_subject_ref`** — polymorphic typed FK per ADR 0019
  v3 §`CoordinationFact.subject_ref` precedent (the
  `<thing>_ref` polymorphic single-FK pattern). Resolves to the
  Ring 0 entity the gate gates against, selected by `gate_kind`.

Per-kind `target_subject_ref` resolution (illustrative; schema
PR commits final shape):

| gate_kind | target_subject_ref resolves to |
|---|---|
| `identity_binding` | `(workspace_id, surface_id)` pair (the local Git surface being gated) |
| `credential_shadow` | `credential_source_id` (the credential whose shadow is being gated) |
| `signing_identity` | `(workspace_id, repository_id)` pair (the repo whose signing identity is being gated) |
| `filesystem_trust` | `(execution_context_id, surface_id)` pair (the filesystem-trust scope being gated) |
| `tool_provenance` | `tool_or_provider_ref` (the tool whose provenance is being gated) |
| `mutation_class` | `operation_class` (one of the six from ADR 0029 v2; the meta-gate composes per-class evidence) |

**Rejected alternative: separate `gate_name` field.** Would
invite name-based decisions instead of gate_kind-based.

### 2. Gate state lifecycle

Four-state enum mirroring ADR 0031 v1 Lease lifecycle pattern
(NOT ADR 0022 seven-state observer-side enum):

- **`provisional`** — freshly minted; evidence not yet
  evaluated. Initial state for newly-created gates. Operations
  consuming a `provisional` gate reject with `gate_provisional`
  reason_kind.
- **`proven`** — evidence passes; gate satisfies. Operations
  consuming a `proven` gate proceed (subject to per-class
  matrix and ApprovalGrant rules).
- **`expired`** — `valid_until` passed; gate needs re-mint with
  fresh evidence. Operations consuming an `expired` gate
  reject with `gate_expired` reason_kind.
- **`denied`** — evidence fails; gate rejects. Operations
  consuming a `denied` gate reject with `gate_denied`
  reason_kind. Non-escalable per inv. 6 unless a
  `gate_evidence_acknowledgment` ApprovalGrant cleared the
  rejection (see §`Decision.required_grant_kind` reservations
  below).

State transitions emit typed `Decision` events in the audit
hash chain per registry v0.3.1 §Audit-chain coverage of
rejections (extended to lifecycle events by inheritance,
mirroring ADR 0031 v1 Lease lifecycle and ADR 0019 v3
CoordinationFact promotion).

**Transition rules (kernel-set):**

- **Mint**: Layer 1 mint API creates gate with state
  `provisional` (always); evidence chain validated for
  structural consistency but not yet evaluated for gate
  satisfaction.
- **Provisional → Proven**: Layer 1 mint API or Layer 2 broker
  FSM evaluates evidence chain against per-gate_kind
  composition rules; transitions to `proven` if evidence
  satisfies; emits typed Decision recording the transition.
- **Provisional → Denied**: Same evaluation; transitions to
  `denied` if evidence fails composition rules.
- **Proven → Expired**: Layer 2 broker FSM or Layer 3 gateway
  re-derive detects `valid_until` passed; sets `expired_at`;
  emits typed Decision.
- **Expired → Provisional**: re-mint with fresh evidence
  creates a new gate (new `gate_id`); the expired gate is
  retained in audit chain for forensics. (Re-mint is a
  separate mint event, NOT a lifecycle transition on the
  existing gate.)

**No `allowed_for_gate` boolean**. ADR 0019 v3
CoordinationFact's promotion workflow (false → true via
verifier promotion) does NOT apply to QualityGate. Gates are
aggregations of typed evidence, not authored claims; the
state machine is evidence-driven, not promotion-workflow-driven.

### 3. Evidence binding

Single polymorphic `evidence_refs` array following ADR 0019 v3
/ ADR 0022 / ADR 0034 v2 linked-observations pattern. Field
shape (illustrative; schema PR commits):

- **`evidence_refs`** — array of `evidenceRefSchema` references
  (one canonical type from `packages/schemas/src/common.ts`
  per ADR 0023). Polymorphism over the expanding
  `evidenceSubjectKindSchema` enum is intentional and absorbed
  by `evidenceRefSchema`. NOT a per-kind discriminator-and-
  array (no `identity_binding_evidence_refs` /
  `credential_shadow_evidence_refs` / etc. fields).

Per-gate_kind evidence-composition rules are documented in
§5 below (narratively) and committed canonically in policy YAML
at Milestone 2.

**Rejected alternative: per-kind discriminator-and-array.**
Would force schema revision when new gate_kinds are added or
existing kind evidence needs change. Single polymorphic array
+ runtime composition rules is more maintainable.

### 4. Gate-vs-matrix composition

QualityGate and the ADR 0034 v2 §Sub-decision (d) three-state
matrix are **parallel layers**, NOT sequential.

- **Matrix layer** (ADR 0034 v2): per-(boundary-evidence-anomaly,
  operation-class) Decision per invocation. No persistent
  identity. Re-derives every operation. Operates on individual
  `BoundaryObservation` evidence anomaly states (`stale | missing
  | contradictory`).
- **Gate layer** (this ADR): durable typed entity with identity
  and state. Aggregates across multiple observations into a
  reusable gate-state Decision. Operations reference gates via
  `evidence_refs` (or future `gate_refs` field; not committed
  here).

Both layers produce typed `Decision` records; both participate
in audit chain per registry v0.3.1. Operations may consume:

- **Matrix only**: read-only diagnostic operations,
  agent_internal_state operations, or single-dimension boundary
  checks. Matrix is sufficient.
- **Gate only**: operations whose decision depends on cross-
  dimension aggregation (e.g., destructive_git operations
  needing `mutation_class` gate which composes
  identity_binding + signing_identity + tool_provenance +
  filesystem_trust). Gate is the canonical surface.
- **Both**: when an operation invokes a gate AND has its own
  per-invocation matrix re-check (e.g., operation cites a
  `proven` gate whose underlying evidence has since become
  `stale` per the matrix). Layer 3 gateway re-derive enforces
  the more restrictive of the two outcomes per registry v0.3.2
  §Cross-context enforcement layer §Layer-disagreement
  tiebreaker.

**Why parallel and not sequential.** Sequential composition
(matrix-then-gate, or gate-then-matrix) would make one redundant
to the other. The matrix is the per-invocation policy table;
the gate is the longer-lived aggregation. Both are needed:
operations that don't invoke a gate still benefit from
matrix-level blocking; operations that do invoke a gate
benefit from cross-dimension aggregation.

### 5. Per-gate_kind evidence sketches

The six `gate_kind` values have distinct evidence-composition
rules, sketched narratively here. Canonical evidence-
composition rules land in policy YAML at Milestone 2.

#### `identity_binding`

Gates Git surface identity for a given `(workspace_id,
surface_id)` pair.

**Required evidence (illustrative):**
- One or more `GitIdentityBinding` records (ADR 0034 v2)
  matching the target `(workspace_id, surface_id)`.
- A `RepositoryIdentityReconciliation` record (ADR 0033 v2)
  for the workspace's `repository_id`.

**Composition rule:** evidence chain must demonstrate a
consistent Git identity binding across config, signing, and
remote-credential planes. `plane_disagreement` outcomes from
the reconciliation block the gate (denied state).

#### `credential_shadow`

Gates credential shadowing for a given `credential_source_id`.

**Required evidence (illustrative):**
- A `CredentialSource` record (ADR 0018) for the target
  credential.
- One or more `MCPCredentialAudienceObservation` records (ADR
  0033 v2) showing the credential's audience binding.
- A `BoundaryObservation` with the new
  `credential_source_boundary` dimension (ADR 0034 v2)
  documenting credential health/rotation/audience-binding
  state.

**Composition rule:** evidence chain must demonstrate the
credential is reachable via exactly one canonical audience
(no shadowing). Multiple audiences for the same logical
credential (e.g., human PAT + GitHub App PAT both claiming
"the GitHub credential") trigger shadow → denied state.

#### `signing_identity`

Gates commit signing identity for a given `(workspace_id,
repository_id)` pair.

**Required evidence (illustrative):**
- A `GitIdentityBinding` record (ADR 0034 v2) with
  `git_signing_format_kind != "none"`.
- The `CredentialSource` record (ADR 0018) referenced by
  `git_signing_key_id` (ADR 0034 v2).
- A commit signing receipt — Q-006 stage-3 candidate name:
  `CommitSigningReceipt` (deferred to follow-up Q-006 ADR;
  not committed here).

**Composition rule:** evidence chain must demonstrate that
recent commits in the repository carry valid signatures from
the credential source the binding cites. Missing
`CommitSigningReceipt` for recent commits → provisional;
mismatched signatures → denied.

**Note**: until Q-006 stage-3 commits `CommitSigningReceipt`,
the gate remains in provisional state; Layer 1 mint API does
NOT auto-promote to proven without the receipt. Composes
with ADR 0034 v2 §Sub-decision (b) "no posture vacuum" framing
— gate-consuming operations still gate on the matrix until
Q-006 stage-3 lands.

#### `filesystem_trust`

Gates filesystem-trust scope for a given `(execution_context_id,
surface_id)` pair.

**Required evidence (illustrative):**
- A `BoundaryObservation` with the `filesystem_authority`
  dimension (ADR 0022; existing) for the target.
- A `GitDirtyStateObservation` (ADR 0030 v2) for any worktrees
  in the surface's scope.
- A `BoundaryObservation` with the new
  `execution_context_boundary` dimension (ADR 0034 v2)
  documenting launch-context state.

**Composition rule:** evidence chain must demonstrate that the
filesystem-trust scope is consistent with the execution
context's expected scope (sandbox vs host, allowed roots,
denied paths). Mismatch (e.g., destructive operation against a
worktree outside the declared filesystem-authority scope)
triggers denied state.

#### `tool_provenance`

Gates tool provenance for a given `tool_or_provider_ref`.

**Required evidence (illustrative):**
- A `ToolProvenance` record (ADR 0034 v2) for the target tool.
- For critical tools (git, gh, ssh, op), the gate's
  composition rule may require `version_drift_kind:
  "matches_lockfile"` or `"no_lockfile"` (NOT
  `"behind_lockfile"`).

**Composition rule:** evidence chain must demonstrate the tool
is at the expected version, installed via the expected source,
and shimmed (if applicable) through the expected chain.
Drift (mismatched version, unexpected install source, suspicious
shim) → denied state.

#### `mutation_class`

Meta-gate composing multiple gate_kinds. Used for destructive
operation classes (per ADR 0029 v2: `destructive_git`,
`external_control_plane_mutation`, `worktree_mutation`,
`merge_or_push`).

**Required evidence (illustrative):**
- One `proven` `identity_binding` gate.
- One `proven` `signing_identity` gate.
- One `proven` `tool_provenance` gate (for git, gh, signing
  tools).
- One `proven` `filesystem_trust` gate.

**Composition rule:** the meta-gate aggregates four sub-gates;
all must be `proven` for the meta-gate to be `proven`. Any
sub-gate in `denied` / `expired` / `provisional` state blocks
the meta-gate's `proven` transition.

**Audit-chain attribution:** the meta-gate's `evidence_refs`
cites the four sub-gates by `gate_id` (via `evidenceRefSchema`
where the subject kind is `quality_gate`); audit consumers can
trace which sub-gate failed when the meta-gate is denied.

### Cross-cutting rules

#### Authority discipline

Per registry v0.3.2 §Producer-vs-kernel-set:

- **Kernel-set**: `gate_id` (mint-API-allocated), `gate_state`
  (lifecycle transitions are kernel-only), `provisional_at`,
  `proven_at`, `expired_at`, `denied_at` (all timestamp
  transitions), `valid_until` (kernel-set per per-`gate_kind`
  policy at Milestone 2; producer cannot extend).
- **Producer-asserted, kernel-verifiable**: `gate_kind`
  (closed enum), `target_subject_ref` (resolved against host
  state at mint time), `evidence_refs` (FK refs validated at
  Layer 1 + Layer 2/3 re-check).

#### Cross-context binding rules per Ring 1 layer

Per registry v0.3.0 §Cross-context enforcement layer:

- **Layer 1 (mint API)**: enforces `gate_kind` + `target_subject_ref`
  consistency (the target resolves to a real Ring 0 entity);
  enforces `evidence_refs` are minted in the same
  `execution_context_id` (cross-context strict default per
  registry v0.3.0); rejects sandbox-derived `Evidence.authority`
  per inv. 8 inheritance.
- **Layer 2 (broker FSM re-check)**: re-evaluates per-`gate_kind`
  composition rules at operation-execution time; re-checks
  evidence freshness; transitions `proven → expired` when
  `valid_until` passes.
- **Layer 3 (gateway re-derive)**: authoritative non-escalable
  per inv. 6; re-evaluates composition rules at decision
  time; rejects with `gate_denied` if any sub-evidence has
  become stale or contradictory between mint and execution.

#### Sandbox-promotion rejection (charter inv. 8)

Inherited from ADR 0034 v2 §Sandbox-promotion rejection rule
+ ADR 0019 v3 §Secret-referenced sources sandbox-asymmetry
pattern:

- **Evidence-side rule**: `QualityGate` records whose
  `evidence_refs` cite any record with `Evidence.authority` in
  `{sandbox-observation, self-asserted}` cannot transition to
  `proven` state. The gate remains `provisional` until host-
  authoritative evidence replaces the sandbox-derived
  references.
- **Grant-side rule**: `gate_evidence_acknowledgment` grants
  whose cited evidence_refs carry sandbox-observation /
  self-asserted authority rejected at Layer 1 mint API.
  Mirrors ADR 0034 v2 boundary-evidence grant-side rejection
  rule.
- **Cross-authority gate composition**: a `mutation_class`
  meta-gate cannot aggregate sub-gates whose underlying
  evidence carries sandbox/self-asserted authority. The meta-
  gate's composition rule forbids it.

### `Decision.reason_kind` reservations

Four new rejection-class names reserved (posture-only;
schema enum lands per `.agents/skills/hcs-schema-change`):

- **`gate_provisional`** — operation cited a gate in
  `provisional` state; gate's evidence has not yet been
  evaluated. Layer 1 / Layer 2 reject with this reason.
- **`gate_denied`** — operation cited a gate in `denied`
  state; gate's evidence failed composition rules. Layer 1 /
  Layer 2 / Layer 3 reject with this reason. Non-escalable
  per inv. 6 unless `gate_evidence_acknowledgment` grant
  cleared the rejection.
- **`gate_expired`** — operation cited a gate in `expired`
  state; gate's `valid_until` passed. Layer 2 / Layer 3
  reject; consumer must re-mint with fresh evidence.
- **`gate_evidence_insufficient`** — operation cited a gate
  whose `evidence_refs` array does not satisfy the per-
  `gate_kind` composition rules. Layer 1 mint API rejects
  before gate state is set.

Per ADR 0029 v2 §`block` vs forbidden-tier framing, all four
are *Decision-level* (this-invocation rejects); none promotes
the operation to forbidden tier.

### `Decision.required_grant_kind` reservations

One new grant-kind name reserved (posture-only):

- **`gate_evidence_acknowledgment`** — typed grant binding
  acknowledgment that operations may proceed with a `denied`
  or `provisional` gate state (e.g., a documented break-glass
  case where evidence is missing but the operation is
  authorized by human review). Single-use per operation_id
  (mirrors ADR 0030 v2 / ADR 0031 v1 / ADR 0034 v2 grant
  patterns). NOT applicable to `expired` state — re-mint with
  fresh evidence is the canonical path for expired gates.

`ApprovalGrant.scope` per-class extension binds the specific
`gate_id` + `execution_context_id`. Scope-key disjointness
preserved per ADR 0019 v3 / ADR 0031 v1 / ADR 0033 v2 /
ADR 0034 v2: gate-evidence grants do NOT overlap with
`worktree_mutation`, `destructive_git`, `merge_or_push`,
`external_control_plane_mutation`, `runner_registration` /
`runner_deregistration`, or `boundary_evidence_*` per-class
extensions.

### Out of scope

This ADR does not authorize:

- Zod schema source for `QualityGate`. Schema lands per
  `.agents/skills/hcs-schema-change` after acceptance.
- `evidenceSubjectKindSchema` enum extension for
  `quality_gate` (NEW subject-kind value). Schema PR commits.
- `gate_kind` and `gate_state` enum extensions to registry.
  Registry update PR follows after acceptance.
- `Decision.reason_kind` / `Decision.required_grant_kind` enum
  extensions for the five new reservations.
- Per-(gate_kind, operation_class) composition rules in
  canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. Land at
  Milestone 2.
- Per-`gate_kind` `valid_until` window policy. Canonical policy
  at Milestone 2 commits per-kind maxima (e.g.,
  `signing_identity` gate may carry 7-day window;
  `tool_provenance` gate may carry 30-day window).
- Q-006 stage-3 `CommitSigningReceipt` (referenced by
  `signing_identity` gate but not yet committed). Reserved for
  future Q-006 stage-3 ADR.
- Dashboard `/quality-gates` view React component implementation.
  Reserved for separate dashboard ADR per ADR 0019 v3 / ADR 0034
  v2 precedent.
- Charter inv. 19 amendment text. Charter amendments follow
  change-policy in separate PR (per ADR 0021 / ADR 0024
  precedent).
- Q-009 / Q-010 sub-decisions (separate Q-rows).
- ADR 0026 substrate hook architecture (still gated on
  stage-1 `BranchProtectionObservation` schema landing).

## Consequences

### Accepts

- Q-007(g) settled at the design layer with `QualityGate`
  standalone Ring 0 entity (Q-011 bucket 2). Q-007 is now
  fully accepted ((a) ADR 0022, (b)–(f) ADR 0034 v2, (g)
  ADR 0035 v1).
- Gate identity triple committed: `(gate_id, gate_kind,
  target_subject_ref)`. Six `gate_kind` reserved values:
  `identity_binding`, `credential_shadow`, `signing_identity`,
  `filesystem_trust`, `tool_provenance`, `mutation_class`.
  Per-kind `target_subject_ref` resolution table committed.
- Gate state lifecycle committed: four-state enum
  (`provisional | proven | expired | denied`) mirroring
  ADR 0031 v1 Lease pattern. Transitions emit typed Decision
  events per registry v0.3.1 audit-chain coverage.
- Evidence binding committed: single polymorphic
  `evidence_refs` array (NOT per-kind discriminator-and-array)
  following ADR 0019 v3 / ADR 0022 / ADR 0034 v2 linked-
  observations pattern.
- Gate-vs-matrix composition committed: parallel layers, NOT
  sequential. Matrix (ADR 0034 v2) operates per-invocation on
  individual BoundaryObservation evidence; QualityGate
  aggregates across multiple observations into a durable typed
  entity. Both produce Decisions; Layer 3 gateway enforces the
  more restrictive when both apply.
- Per-gate_kind evidence sketches committed for all six
  gate_kinds. `signing_identity` notes Q-006 stage-3
  `CommitSigningReceipt` dependency; gate remains
  `provisional` until that receipt lands.
- `mutation_class` meta-gate composition committed:
  aggregates four sub-gates (identity_binding +
  signing_identity + tool_provenance + filesystem_trust); all
  must be `proven` for meta-gate to be `proven`.
- Sandbox-promotion rejection rule (charter inv. 8)
  inherited: gates whose evidence_refs cite sandbox-observation
  / self-asserted authority cannot transition to `proven`.
  Cross-authority gate composition forbidden in `mutation_class`
  meta-gate.
- Four new `Decision.reason_kind` rejection classes reserved:
  `gate_provisional`, `gate_denied`, `gate_expired`,
  `gate_evidence_insufficient`.
- One new `Decision.required_grant_kind` reservation:
  `gate_evidence_acknowledgment` (single-use per operation_id;
  scope binds `gate_id` + `execution_context_id`; not
  applicable to `expired` state).
- One new `evidence_subject_kind` enum value reserved:
  `quality_gate`. Allows other entities to cite
  `QualityGate` records via `evidenceRefSchema`.
- Authority discipline follows registry v0.3.2: identity and
  state transition fields kernel-set; gate_kind and
  target_subject_ref producer-asserted but kernel-verifiable.
- Cross-context binding rules per Ring 1 layer explicit per
  registry v0.3.0 requirement.
- Phase 1 entity inventory now includes QualityGate as a
  durable Ring 0 entity; Q-007 fully closes.

### Rejects

- Separate `gate_name` field. Would invite name-based
  decisions instead of gate_kind-based.
- ADR 0022 seven-state observer-side enum
  (`proven | denied | pending | stale | contradictory |
  inapplicable | unknown`) for gate state. The seven states
  are evidence-source-side classifications; QualityGate
  consumes evidence after observation, so observer-side
  states don't apply. Four-state lifecycle is simpler and
  cleaner.
- `allowed_for_gate` boolean (ADR 0019 v3 CoordinationFact
  pattern). QualityGate is an aggregation of typed evidence,
  not an authored claim requiring promotion. State machine is
  evidence-driven, not promotion-workflow-driven.
- Per-kind discriminator-and-array evidence binding (e.g.,
  `identity_binding_evidence_refs` /
  `credential_shadow_evidence_refs` / etc.). Would force
  schema revision when new gate_kinds are added or existing
  kind evidence needs change.
- Sequential gate-then-matrix or matrix-then-gate composition.
  Both layers are needed independently; redundancy would
  result if one strictly preceded the other.
- `gate_evidence_acknowledgment` for `expired` state. Re-mint
  with fresh evidence is the canonical path; an acknowledgment
  grant for a stale-evidence gate would launder freshness.
- Sandbox-derived evidence promoting to `proven` gate state.
  Charter inv. 8 inherited.
- Cross-organization meta-gate composition. Meta-gate
  sub-gates must share `execution_context_id` (or carry
  explicit cross-context-reference per future Q-003
  amendment).

### Future amendments

- Schema PR per `.agents/skills/hcs-schema-change` for
  `QualityGate` standalone entity + four new
  `Decision.reason_kind` reservations + one
  `Decision.required_grant_kind` reservation +
  `ApprovalGrant.scope` per-class extension binding `gate_id`.
- Registry update PR adding `gate_kind` (six values),
  `gate_state` (four values), and `quality_gate`
  evidence_subject_kind enum extensions.
- Canonical policy YAML at Milestone 2: per-(gate_kind,
  operation_class) composition rules; per-`gate_kind`
  `valid_until` window maxima; verifier-class privileges for
  `gate_evidence_acknowledgment` grants; matrix entries for
  `mutation_class` meta-gate composition.
- Q-006 stage-3 ADR commits `CommitSigningReceipt` (referenced
  by `signing_identity` gate; until that ADR lands, the gate
  remains `provisional`).
- Separate dashboard ADR commits `/quality-gates` view
  React component implementation per ADR 0034 v2 §Sub-decision
  (e) view-shape commitment.
- Charter v1.4.0 amendment PR for invariant 19 text (per
  ADR 0034 v2 §Sub-decision (f) candidate). May land alongside
  inv. 18 (Q-003 candidate from ADR 0019 v3) in a single wave
  or stand alone.
- Q-009 / Q-010 sub-decisions (separate Q-rows; Q-009 HCS
  diagnostic surface, Q-010 cross-agent isolation taxonomy).
- Reopen if a future incident shows the four-state lifecycle
  misses a transition (e.g., a state for "evidence partially
  satisfied — needs human input") or the six-gate_kind
  inventory needs expansion.

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md`
  v1.3.2 (especially inv. 1, 4, 5, 6, 7, 8, 16, 17; inv. 19
  candidate per ADR 0034 v2).
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
  (Authority discipline, Cross-context enforcement layer,
  Naming suffix discipline; six new `gate_kind` values, four
  new `gate_state` values, one new `evidence_subject_kind`
  value queued for registry update PR).
- Decision ledger: `DECISIONS.md` Q-007.
- ADR 0018:
  `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
  (CredentialSource entity; consumed by `credential_shadow`
  and `signing_identity` gates).
- ADR 0019:
  `docs/host-capability-substrate/adr/0019-knowledge-and-coordination-store.md`
  (Q-003 v3 final; CoordinationFact composition pattern;
  scope-key disjointness rule).
- ADR 0021:
  `docs/host-capability-substrate/adr/0021-charter-v1-3-wave-1.md`
  (charter amendment workflow precedent).
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (Q-007(a) accepted; envelope shape; QualityGate deferral
  origin; `filesystem_authority` boundary dimension consumed
  by `filesystem_trust` gate).
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract).
- ADR 0024:
  `docs/host-capability-substrate/adr/0024-charter-v1-3-wave-2-and-3.md`
  (charter amendment wave precedent).
- ADR 0029:
  `docs/host-capability-substrate/adr/0029-q-008-b-anomalous-capture-blocking-thresholds.md`
  (Q-008(b) v2 final; six operation classes consumed by
  `mutation_class` gate; `block` vs forbidden-tier framing).
- ADR 0030:
  `docs/host-capability-substrate/adr/0030-q-006-stage-2-source-control-evidence-subtypes.md`
  (Q-006 stage-2 v2 final; `GitDirtyStateObservation`
  consumed by `filesystem_trust` gate; single-use grant
  pattern).
- ADR 0031:
  `docs/host-capability-substrate/adr/0031-q-008-d-worktree-ownership-composition.md`
  (Q-008(d) v1 final; Lease lifecycle pattern that QualityGate
  state lifecycle mirrors; ApprovalGrant.scope per-class
  extension pattern).
- ADR 0032:
  `docs/host-capability-substrate/adr/0032-q-005-ci-runner-evidence-model.md`
  (Q-005 v2 final; runner/check evidence; load-bearing
  prerequisite for Q-007(g)).
- ADR 0033:
  `docs/host-capability-substrate/adr/0033-q-006-b-g-github-authority-and-identity.md`
  (Q-006 (b)-(g) v2 final; `RepositoryIdentityReconciliation`
  consumed by `identity_binding` gate;
  `MCPCredentialAudienceObservation` consumed by
  `credential_shadow` gate; load-bearing prerequisite for
  Q-007(g)).
- ADR 0034:
  `docs/host-capability-substrate/adr/0034-q-007-b-f-boundary-evidence-composition-quality-gate-posture.md`
  (Q-007 (b)-(f) v2 final; immediate prerequisite for
  Q-007(g); `GitIdentityBinding` consumed by
  `identity_binding`/`signing_identity` gates;
  `ToolProvenance` consumed by `tool_provenance` gate; four
  new boundary_dimension candidates consumed by various
  gates; three-state matrix that QualityGate composes in
  parallel).
- 2026-04-29 quality-management synthesis:
  `docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md`
  (primary research source; six gate_kind candidate origin).
- 2026-05-01 ontology promotion + receipt dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
  (line 142 Q-011 bucket 2 classification).
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`.

### External

- SLSA framework (source-track requirements consumed by
  `signing_identity` gate composition):
  <https://slsa.dev/spec/v1.0/source-requirements>
- Conceptual model: "policy is the union of evidence" from
  the broader supply-chain-security literature; not directly
  cited but informs gate-as-aggregation framing.
