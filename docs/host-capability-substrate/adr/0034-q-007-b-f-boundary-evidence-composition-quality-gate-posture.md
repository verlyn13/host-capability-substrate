---
adr_number: 0034
title: Q-007 (b)–(f) boundary evidence composition, degrade-to-warn matrix, dashboard views, charter inv. 19 candidate
status: proposed
date: 2026-05-03
charter_version: 1.3.2
tags: [boundary-evidence, quality-gate, dashboard-views, charter-inv-19, q-007, phase-1]
---

# ADR 0034: Q-007 (b)–(f) boundary evidence composition, degrade-to-warn matrix, dashboard views, charter inv. 19 candidate

## Status

proposed (v1)

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Context

Q-007 settles the quality-management and boundary-accommodation
model. Prior sub-decisions:

- **Q-007(a)** (BoundaryObservation envelope shape): accepted via
  ADR 0022 (2026-05-02). The envelope is settled as an `Evidence`
  subtype envelope; `boundary_dimension` taxonomy registry entry
  exists.

ADR 0034 settles the remaining five sub-decisions:

- **(b)** Should `QualityGate` remain deferred until
  BoundaryObservation, Q-005 runner/check evidence, and Q-006
  source-control evidence settle?
- **(c)** How does boundary evidence compose with `ExecutionContext`,
  `CredentialSource`, `GitIdentityBinding`, and `ToolProvenance`
  candidates?
- **(d)** What operations degrade to warning versus require approval
  when boundary evidence is stale, missing, or contradictory, and
  how do `Decision` / `ApprovalGrant` consume those evidence_refs?
- **(e)** Which dashboard views are needed before humans can review
  quality gates effectively?
- **(f)** Does "boundary claims are freshness-bound and
  execution-context-bound" warrant a charter v1.3.0 invariant, or
  stay as a Phase 1 design principle?

Q-007 (b)-(f) is now FULLY UNBLOCKED at the posture layer:
- Q-005 settled via ADR 0032 v2 (2026-05-03): runner/check
  evidence model committed.
- Q-006 (a) via ADR 0020 limited posture; (a) stage-1 via ADR
  0027 v2 (2026-05-02); (a) stage-2 via ADR 0030 v2 (2026-05-03);
  (b)-(g) via ADR 0033 v2 (2026-05-03): GitHub authority +
  identity reconciliation + check-source binding.
- Q-008 fully accepted: (a) ADR 0028 v4, (b) ADR 0029 v2, (c)
  ADR 0025 v2, (d) ADR 0031 v1, (e) AGENTS.md hard boundary.
- Q-003 settled via ADR 0019 v3: knowledge and coordination
  store; CoordinationFact composition pattern.

Source materials:

- 2026-04-29 quality-management synthesis
  (`docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md`)
  — primary research source for sub-decisions (b)-(f).
- 2026-05-01 ontology-promotion-receipt-dedupe-plan
  (`docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`)
  — Q-011 review-grammar bucket guidance for new entity
  candidates; line 142 explicitly defers `QualityGate` until
  BoundaryObservation + Q-005 + Q-006 settle.
- ADR 0022 (BoundaryObservation envelope) §Future amendments —
  defers `QualityGate` and the linked-observations pattern.
- ADR 0029 v2 (Q-008(b) anomalous-capture matrix) — provides
  the three-state matrix precedent (block | approval_required |
  warn) that this ADR mirrors for boundary-evidence stateness.

This ADR is doc-only and posture-only, mirroring ADR 0029 v2 /
ADR 0030 v2 / ADR 0031 v1 / ADR 0032 v2 / ADR 0033 v2 acceptance
pattern. It does not author Zod schema source, canonical policy
YAML, runtime probes, dashboard route React components, MCP
adapter contracts, charter invariant text, or the QualityGate
standalone entity. Schema implementation lands per
`.agents/skills/hcs-schema-change` after acceptance; charter
inv. 19 amendment lands per change-policy in a separate PR.

Pre-draft sub-decisions approved by user (2026-05-03) per
research-grounded recommendations:
- (b) Defer QualityGate to standalone follow-up ADR (Q-007(g)).
- (c) Linked-observations composition with two new evidence
  subtypes (`GitIdentityBinding`, `ToolProvenance`).
- (d) Three-state matrix mirroring ADR 0029 v2.
- (e) Six dashboard views named (posture-only).
- (f) Promote to charter v1.4.0 invariant 19 in separate
  amendment PR.

## Decision

### Sub-decision (b) — QualityGate timing

**Recommendation: defer to standalone follow-up ADR.** ADR 0034
does NOT define `QualityGate`. The follow-up ADR (provisional:
"ADR 0035 — Q-007(g) QualityGate standalone entity") commits the
gate identity, gate_kind discriminator (candidate values:
`identity_binding`, `credential_shadow`, `signing_identity`,
`filesystem_trust`, `tool_provenance`, `mutation_class`), gate
state lifecycle, and `evidence_refs` to BoundaryObservation +
Q-005 + Q-006 receipts.

**Rationale:** ADR 0022 §Future amendments explicitly defers
QualityGate; the dedupe plan line 142 reaffirms ("Defer until
BoundaryObservation, Q-005, and Q-006 shapes settle"). Mixing
gate-definition logic with evidence-composition logic in one
ADR violates the "one coherent change per ADR" discipline. With
Q-005 + Q-006 (b)-(g) just accepted (2026-05-03), QualityGate is
now structurally unblocked but warrants its own ADR for clean
review.

**Out-of-scope for this ADR:** QualityGate field shape,
gate_kind enum values, gate_state lifecycle, gate-consuming
operation classes, ApprovalGrant.scope per-class extension for
QualityGate operations.

### Sub-decision (c) — Boundary evidence composition

**Linked-observations pattern via `evidence_refs`** (NOT nested
fields). Each composition partner remains independently
observable, freshness-bound, and authority-scalable.

**Composition partners:**

| Entity | Status | Q-011 bucket |
|---|---|---|
| `ExecutionContext` | committed (charter inv. 17) | bucket 2 (standalone Ring 0 entity) |
| `CredentialSource` | committed (ADR 0018; charter inv. 15) | bucket 2 |
| `GitIdentityBinding` | NEW (this ADR) | bucket 1 (evidence subtype) |
| `ToolProvenance` | NEW (this ADR) | bucket 1 (evidence subtype) |

**`GitIdentityBinding` evidence subtype (Q-011 bucket 1):**

`evidenceSchema`-direct typed payload, per-(workspace_id,
surface_id) grain. Domain payload (illustrative; schema PR
commits final shape):

- `evidence_kind: "observation"`
- `evidence_subject_kind: "git_identity_binding"` (NEW enum
  value)
- Payload (illustrative):
  - `workspace_id` — typed FK to `Workspace`.
  - `surface_id` — typed FK to `Surface` (the shell/IDE/MCP
    context where Git config was resolved).
  - `git_user_name` — observed `user.name` Git config value
    (scrubber-eligible per registry v0.3.0; may encode
    identity-fingerprinting strings).
  - `git_user_email` — observed `user.email` Git config value
    (scrubber-eligible; PII).
  - `git_signing_key_id` — observed `user.signingkey` config
    value (typed FK or string identifier).
  - `git_signing_format_kind: "openpgp" | "x509" | "ssh" |
    "none"` — discriminator per registry Sub-rule 6.
  - `credential_source_evidence_ref` — typed `evidenceRefSchema`
    to a `CredentialSource` record naming the signing key /
    sigstore identity.
  - `provider_observed_via: "git_config_read" | "ssh_config_resolution"
    | "1password_op_cli_introspection"` — kernel-set per registry
    v0.3.2 (authority-class signal).
  - `provider_verified_at` — kernel-set freshness anchor.

One of five load-bearing Q-006 names per dedupe-plan §Q-006
near-term commitments.

**`ToolProvenance` evidence subtype (Q-011 bucket 1):**

`evidenceSchema`-direct typed payload, per-(`tool_or_provider_ref`,
`execution_context_id`) grain. Domain payload (illustrative;
schema PR commits final shape):

- `evidence_kind: "observation"`
- `evidence_subject_kind: "tool_provenance"` (NEW enum value)
- Payload (illustrative):
  - `tool_or_provider_ref` — polymorphic typed FK per
    `BoundaryObservation` precedent (e.g., `npm:7.24.0`,
    `git:2.46.0`, `mise:2024.10.5`, `docker:27.0.0`).
  - `execution_context_id` — typed FK.
  - `installed_path` — absolute filesystem path to the resolved
    tool binary (scrubber-eligible per registry v0.3.0).
  - `shim_chain` — array of resolved-via-shim hops; each entry
    is a `{ shim_path, target_path }` pair. Empty array for
    native (non-shimmed) tools.
  - `shim_depth` — derived integer (`shim_chain.length`); 0 =
    native, >0 = shimmed.
  - `install_source_kind: "homebrew" | "mise" | "asdf" | "npm" |
    "pip" | "uv" | "system_package_manager" | "manual" |
    "unknown"` — discriminator per registry Sub-rule 6.
  - `version_observed` — observed version string from
    `<tool> --version` or equivalent.
  - `version_drift_kind: "matches_lockfile" | "ahead_of_lockfile"
    | "behind_lockfile" | "no_lockfile" | "unknown"` —
    discriminator (when consuming evidence references a
    project/repo with a tool-version lockfile).
  - `provider_observed_via: "which_command" | "shim_introspection"
    | "package_manager_query"` — kernel-set per registry v0.3.2.
  - `provider_verified_at` — kernel-set freshness anchor.

Subsumes the dedupe-plan §Tool provenance candidate
(`ShimResolution` is a payload subtype, not a separate entity);
addresses both shim chain visibility and version drift in one
shape.

**`boundary_dimension` registry candidates (4 new):**

When the four composition partners surface as specialized
`BoundaryObservation` payloads (envelope-style, not direct):

- `execution_context_boundary` — primary target:
  `execution_context_id`; payload: sandbox/TCC/launch facts.
- `credential_source_boundary` — primary target:
  `credential_source_id`; payload: credential health/rotation/
  audience-binding state.
- `git_identity_boundary` — primary target: `surface_id` or
  `workspace_id`; payload: Git config resolution (signing
  identity, author identity, remote-origin-binding).
- `tool_provenance_boundary` — primary target:
  `tool_or_provider_ref`; payload: shim chain, install source,
  version drift state.

These four boundary dimensions overlap with the direct
evidence subtypes above; the choice between
direct-typed-payload (subtype) vs `BoundaryObservation` payload
(envelope) is per use case:
- Direct subtype when the consumer needs the full payload at
  receipt-shape time.
- `BoundaryObservation` payload when the consumer needs cross-
  dimension boundary evidence with a unified discriminator (see
  ADR 0022 §Linked observations multi-dimensional pattern).

Both shapes coexist; consumers choose at composition time.

**Linked-observations pattern.** Per ADR 0022 §Linked
observations: a multi-surface boundary fact (e.g., a TCC
permission observed inside an app sandbox + the parent shell
launch context) is represented as multiple `BoundaryObservation`
records that **share target references**, NOT as a single
envelope with multiple dimensions. This ADR confirms and
applies the pattern to the four composition partners: each is
its own observation/subtype/envelope; consumption-side
operations cite multiple evidence_refs to compose.

### Sub-decision (d) — Boundary-evidence stateness matrix

**Three-state matrix mirroring ADR 0029 v2 anomalous-capture
matrix.** States: `block | approval_required | warn`. Cells per
operation class (six classes from ADR 0029 v2). Three new
boundary-evidence anomaly classes (rows of the matrix):

- **`stale`** — `BoundaryObservation.valid_until` < now
  (freshness window expired).
- **`missing`** — required `boundary_dimension` evidence_ref
  absent from operation's evidence chain.
- **`contradictory`** — linked `BoundaryObservation` records
  diverge on structural facts (per ADR 0022 §Linked
  observations).

**Boundary-evidence stateness matrix (posture):**

| Anomaly ↓ \ Class → | read_only_diagnostic | agent_internal_state | destructive_git | external_control_plane_mutation | worktree_mutation | merge_or_push |
|---|---|---|---|---|---|---|
| **stale** | warn | warn | approval_required | approval_required | approval_required | approval_required |
| **missing** | warn | warn | block | block | block | block |
| **contradictory** | warn | warn | block | block | block | block |

Cell semantics inherit ADR 0029 v2 §Cell semantics:
- `warn` — operation proceeds; typed `Decision` records the
  anomaly; participates in audit hash chain.
- `approval_required` — operation requires matching
  `ApprovalGrant` whose scope binds the boundary-evidence
  anomaly term.
- `block` — operation rejects unconditionally; non-escalable
  per inv. 6.

**Cross-context enforcement layers (registry v0.3.0 §Cross-context
enforcement layer).** The matrix applies at all three Ring 1
layers:
- Layer 1 (mint API): rejects observations that fail structural
  consistency at mint time.
- Layer 2 (broker FSM re-check): re-evaluates freshness and
  contradiction at operation-execution time; produces NEW
  `BoundaryObservation` records when the broker re-runs the
  underlying probe.
- Layer 3 (gateway re-derive): authoritative non-escalable layer
  per inv. 6.

**`stale` vs `valid_until` distinction.** ADR 0022's seven-state
enum (`proven | denied | pending | stale | contradictory |
inapplicable | unknown`) gives the *evidence source state*. The
matrix above triggers on the evidence's `valid_until` window
expiry as observed by the consuming operation, NOT on the
producer's `observation_state` field. A `proven` observation
with expired `valid_until` matches `stale` matrix row.
Producer-asserted `observation_state == stale` informs the
producer; the matrix informs the gateway.

**`unknown` evidence handling.** ADR 0022 leaves `unknown` as a
valid `observation_state` to avoid false-negatives. For the
matrix above, an `unknown` observation that the consuming
operation requires evaluates as `missing` (the required
dimension's evidence is not affirmatively present).
`unknown` is NOT a fourth matrix row.

### `Decision.reason_kind` reservations

Three new rejection-class names reserved (posture-only; schema
enum lands per `.agents/skills/hcs-schema-change`):

- `boundary_evidence_stale` — operation cited a
  `BoundaryObservation` whose `valid_until` window has expired
  at Layer 2/3 re-check.
- `boundary_evidence_missing` — operation requires a specific
  `boundary_dimension` evidence_ref but the consuming evidence
  chain does not provide it.
- `boundary_evidence_contradictory` — linked
  `BoundaryObservation` records diverge on structural facts;
  the consuming operation cannot determine the canonical
  boundary state.

Per ADR 0029 v2 §`block` vs forbidden-tier framing, all three
are *Decision-level* (this-invocation rejects); none promotes
the operation to forbidden tier.

### `Decision.required_grant_kind` reservations

Three new grant-kind names reserved (posture-only):

- `boundary_evidence_freshness_override` — typed grant binding
  acknowledgment that operations may proceed with a stale
  observation (matching `stale` × `approval_required` cells in
  matrix above).
- `boundary_evidence_contradiction_acknowledgment` — typed
  grant binding acknowledgment of contradictory observations
  for the specific operation.
- `boundary_evidence_absence_acceptance` — typed grant binding
  acknowledgment of missing required boundary evidence for the
  specific operation.

`ApprovalGrant.scope` per-class extension for boundary-evidence-
gating operations: scope binds the specific
`boundary_observation_evidence_refs` array (the stale or
contradictory or related observations being acknowledged) +
`execution_context_id`. Scope-key disjointness preserved per
ADR 0019 v3 / ADR 0031 v1: boundary-evidence grants do NOT
overlap with `worktree_mutation`, `destructive_git`,
`merge_or_push`, `external_control_plane_mutation`,
`runner_registration` / `runner_deregistration` per-class
extensions.

### Sub-decision (e) — Dashboard views

**Six views named in view-shape commitment** (posture-only;
React implementation deferred to separate dashboard ADR per
ADR 0019 v3 precedent):

#### `/quality-gates`

Gate inventory view (when QualityGate ADR lands).
- Primary subject: `QualityGate` records.
- Columns: `gate_id`, `gate_kind`, `last_observed_at`,
  `gate_state` (per QualityGate's state enum, to be committed
  in Q-007(g) ADR), evidence-count, action-available
  (approve/review).
- Display vocabulary uses ADR 0022's seven-state enum where
  applicable (`proven | denied | pending | stale |
  contradictory | inapplicable | unknown`).

#### `/boundary-observations`

Raw boundary-evidence surface.
- Primary subject: `BoundaryObservation` records (envelope +
  payloads).
- Columns: `boundary_dimension`, `execution_context_id`,
  `surface_id`, `observation_state`, `observed_at`,
  `valid_until`, `discrepancy_class` (if any).
- Freshness marker: red if `valid_until` < now; yellow if
  within 10% of expiry window.
- Drill-down: per-dimension payload display (TCC facts, Git
  config, credential status, runner isolation, etc.).

#### `/quality-decisions`

Gate-consuming operation history.
- Primary subject: `Decision` records binding to
  `BoundaryObservation` evidence_refs.
- Columns: `operation_id`, `operation_class`, decision outcome
  (approved | blocked | warned), consuming evidence (linked
  evidence_refs), timestamp.
- Display: aggregate stale/missing/contradictory evidence
  counts per operation.

#### `/credential-sources`

Credential health and binding.
- Primary subject: `CredentialSource` records linked to
  `BoundaryObservation` via `credential_source_id`.
- Columns: `credential_source_id`, credential_kind, rotation
  status, `last_health_check_at`, bound surfaces (count).
- Drill-down: per-surface Git identity bindings, GitHub
  account, signing-key bindings.

#### `/tool-provenance`

Shim chain and tool health.
- Primary subject: `ToolProvenance` observations linked via
  `tool_or_provider_ref`.
- Columns: tool_name, version, `installed_path`, `shim_depth`
  (0 = native, >0 = shimmed), `provider_verified_at`.
- Drill-down: full shim chain, install source, version/build
  drift warnings.

#### `/mutation-queue`

Operations awaiting approval or blocked by boundary evidence.
- Primary subject: `Decision` records with `decision_outcome` =
  `approval_required` or `block`.
- Columns: `operation_id`, `operation_class`, `reason_kind`
  (boundary_evidence_* or anomalous_capture_*),
  `required_grant_kind`, human-action-needed.
- Freshness marker: highlight decisions > 1h old with no
  progress.

**View-shape commitment scope.** This ADR commits view names,
primary subject bindings, column shape (high-level), display
vocabulary (e.g., ADR 0022's seven-state enum), and freshness-
marker conventions. React component props, layout, theming,
and MCP adapter wiring are out of scope; the separate dashboard
ADR commits implementation specifics.

### Sub-decision (f) — Charter inv. 19 candidate

**Recommendation: promote to charter v1.4.0 invariant 19 in a
separate amendment PR after this ADR lands.** ADR 0034 does NOT
modify the charter; charter amendments follow change-policy with
a separate PR (per ADR 0021 / ADR 0024 wave-1/2/3 precedent).

**Proposed invariant 19 text (candidate):**

> **Inv. 19** (candidate, v1.4.0). **Boundary claims are
> freshness-bound and execution-context-bound.** Every
> `BoundaryObservation` and related evidence subtype must carry
> `valid_until` and an execution-context binding
> (`execution_context_id`, `surface_id`, `workspace_id`, or
> `credential_source_id`). HCS must model contradictory,
> missing, and stale boundary evidence as distinct states, not
> promote them to false negatives or unknown-as-false. Boundary
> inference cannot cross macOS app, shell, package-manager,
> Git/GitHub, or MCP surfaces without a matching observed
> context record. Linked `BoundaryObservation` records sharing
> target references may represent multi-surface facts; lateral
> context reuse (borrowing evidence from an unrelated context)
> requires fresh observation, not substitution.

**Composition with existing invariants:**

- **inv. 6** (forbidden tier non-escalable): boundary-evidence-
  stale/missing/contradictory operations map to `block` for
  destructive classes per the matrix above; consistent.
- **inv. 7** (execution lane full stack): approval/audit/
  dashboard/lease all required before boundary evidence gates
  destructive operations; consistent.
- **inv. 8** (sandbox no promotion): boundary observations from
  sandbox sources carry `authority: sandbox-observation` and
  cannot clear `approval_required` cells per ADR 0029 v2 +
  ADR 0019 v3; consistent.
- **inv. 17** (execution context declared): boundary evidence
  must bind execution context explicitly; this rule generalizes
  inv. 17 to all boundary observations, not just
  `ExecutionContext` records.
- **inv. 18 candidate** (Q-003 RAG/typed-evidence rule):
  boundary evidence is typed (discriminator:
  `boundary_dimension`); consistent with the evidence-first
  posture.

**Charter amendment timing.** The amendment PR is sequenced
after this ADR's acceptance (so the rule's load-bearing role in
ADR 0022 + ADR 0034 is documented before the charter codifies
it). Target charter version: v1.4.0 (the next planned
amendment wave after v1.3.0/1/2 wave-1/2/3 already landed).
Inv. 19 may land alongside inv. 18 (Q-003 candidate from ADR
0019 v3) in a single charter v1.4.0 wave PR, OR as
inv. 19-only with inv. 18 deferred to a later wave; that
sequencing decision belongs to the charter amendment author.

### Cross-cutting rules

#### Authority discipline

Per registry v0.3.2 §Producer-vs-kernel-set:

- **Kernel-set** on the two new evidence subtypes:
  `provider_observed_via`, `provider_verified_at`,
  `last_health_check_at` (CredentialSource compositions); FK
  resolution for `workspace_id`, `surface_id`,
  `execution_context_id`, `credential_source_id`,
  `tool_or_provider_ref`.
- **Producer-asserted, kernel-verifiable**: domain-specific
  payload fields (Git config values, shim chain, version
  observed, install source, signing key identifier).

`provider_observed_via` follows the three-way naming convention
from ADR 0030 v2 (state observations; query observations would
use `query_observed_via` per ADR 0033 v2 N7 closure).

#### Cross-context binding rules per Ring 1 layer

Per registry v0.3.0 §Cross-context enforcement layer requirement:

- **`GitIdentityBinding`**: Layer 1 enforces `(workspace_id,
  surface_id)` consistency with `ExecutionContext`; rejects
  cross-context reuse per registry v0.3.0 strict default.
  Layer 2 re-checks Git config state freshness via
  `git config --get` re-execution at operation time. Layer 3
  re-derives at decision time.
- **`ToolProvenance`**: Layer 1 enforces
  `(tool_or_provider_ref, execution_context_id)` consistency.
  Layer 2 re-checks resolved path + version state via
  `which` / package-manager-query re-execution. Layer 3
  re-derives.

#### Sandbox-promotion rejection (charter inv. 8)

Both new evidence subtypes inherit the inv. 8 rejection rule:
records with `Evidence.authority` in `{sandbox-observation,
self-asserted}` cannot be promoted to host-authoritative gate
evidence. Broker FSM Layer 2 / gateway Layer 3 re-check enforces
this discipline.

### Out of scope

This ADR does not authorize:

- Zod schema source for `GitIdentityBinding` or `ToolProvenance`.
  Schema lands per `.agents/skills/hcs-schema-change` after
  acceptance.
- `evidenceSubjectKindSchema` enum extension for the two new
  subject-kind values (`git_identity_binding`,
  `tool_provenance`).
- `boundary_dimension` registry entries for the four new
  candidates (`execution_context_boundary`,
  `credential_source_boundary`, `git_identity_boundary`,
  `tool_provenance_boundary`). Registry update PR follows after
  acceptance.
- `Decision.reason_kind` / `Decision.required_grant_kind` enum
  extensions for the six new reservations.
- `QualityGate` standalone Ring 0 entity. Reserved for
  Q-007(g) follow-up ADR.
- Six dashboard view React component implementations. Reserved
  for separate dashboard ADR.
- Charter inv. 19 amendment text. Charter amendments follow
  change-policy in a separate PR after this ADR's acceptance.
- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`.
  Boundary-evidence stateness matrix entries, per-`boundary_dimension`
  freshness windows, ApprovalGrant.scope per-class extension
  for boundary-evidence operations, and verifier-class
  privileges for `boundary_evidence_*_acknowledgment` grants
  all land in `tiers.yaml` once HCS Milestone 2 ships.
- ADR 0026 substrate hook architecture (gated on stage-1
  `BranchProtectionObservation` schema landing; not gated on
  this ADR).
- Q-007(g) QualityGate ADR (next candidate Q-row after this
  ADR lands).
- Q-009, Q-010 sub-decisions (separate Q-rows).

## Consequences

### Accepts

- Q-007 (b)-(f) settled at the design layer with two new
  evidence subtypes (`GitIdentityBinding`, `ToolProvenance`),
  four new `boundary_dimension` registry candidates, three new
  `Decision.reason_kind` reservations, three new
  `Decision.required_grant_kind` reservations, six dashboard
  views named in view-shape commitment, and a charter inv. 19
  candidate prepared for separate amendment PR.
- `QualityGate` standalone Ring 0 entity deferred to follow-up
  Q-007(g) ADR. ADR 0022 §Future amendments deferral satisfied:
  Q-005 (ADR 0032 v2) + Q-006 (ADR 0033 v2) settled today;
  QualityGate is now structurally unblocked but warrants its
  own ADR for clean review.
- `GitIdentityBinding` evidence subtype committed (Q-011 bucket
  1; `evidenceSchema`-direct typed payload). Per-(workspace_id,
  surface_id) grain; payload includes Git user.name,
  user.email, signing-key identifier, signing format kind. One
  of the five load-bearing Q-006 names per dedupe-plan.
- `ToolProvenance` evidence subtype committed (Q-011 bucket 1;
  `evidenceSchema`-direct typed payload). Per-(`tool_or_provider_ref`,
  `execution_context_id`) grain; payload subsumes shim chain
  resolution + install source + version drift state in one
  shape.
- Linked-observations composition pattern (per ADR 0022 §Linked
  observations) confirmed as the binding pattern for boundary
  evidence: each composition partner is its own observation/
  subtype/envelope; consumption-side operations cite multiple
  evidence_refs to compose.
- Three-state matrix (block | approval_required | warn) for
  boundary-evidence stateness committed (posture). Mirrors
  ADR 0029 v2 anomalous-capture matrix; reuses three-layer
  Ring 1 enforcement architecture (mint API + broker FSM +
  gateway). `stale` × destructive classes = approval_required;
  `missing`/`contradictory` × destructive classes = block.
- `unknown` evidence_state evaluates as `missing` for matrix
  purposes (NOT a fourth matrix row); ADR 0022's seven-state
  observer-side enum and the three-row gateway-side matrix
  remain distinct.
- Three new `Decision.reason_kind` rejection classes reserved
  (posture-only; Decision-level per ADR 0029 v2):
  `boundary_evidence_stale`, `boundary_evidence_missing`,
  `boundary_evidence_contradictory`.
- Three new `Decision.required_grant_kind` reservations
  (posture-only): `boundary_evidence_freshness_override`,
  `boundary_evidence_contradiction_acknowledgment`,
  `boundary_evidence_absence_acceptance`. ApprovalGrant.scope
  per-class extension binds `boundary_observation_evidence_refs`
  + `execution_context_id`. Scope-key disjointness preserved
  per ADR 0019 v3 / ADR 0031 v1.
- Four new `boundary_dimension` registry candidates queued for
  registry update PR: `execution_context_boundary`,
  `credential_source_boundary`, `git_identity_boundary`,
  `tool_provenance_boundary`. Both direct-typed-payload (the
  two new evidence subtypes) and `BoundaryObservation` envelope
  shapes coexist; consumers choose at composition time.
- Six dashboard views named in view-shape commitment:
  `/quality-gates`, `/boundary-observations`,
  `/quality-decisions`, `/credential-sources`,
  `/tool-provenance`, `/mutation-queue`. View-shape
  commitment includes view names, primary subject bindings,
  column shape (high-level), display vocabulary, and freshness-
  marker conventions. React component implementation deferred
  to separate dashboard ADR.
- Charter inv. 19 candidate text drafted and queued for
  separate charter amendment PR after this ADR's acceptance.
  Target version: charter v1.4.0. May land alongside inv. 18
  (Q-003 candidate) in a single wave or stand alone.
- Authority discipline follows registry v0.3.2: identity and
  freshness fields kernel-set; domain-specific payload fields
  producer-asserted but kernel-verifiable.
- Sandbox-promotion rejection rule (charter inv. 8) inherited
  by both new evidence subtypes: records with
  `Evidence.authority` in `{sandbox-observation,
  self-asserted}` cannot be promoted to host-authoritative gate
  evidence.
- Cross-context binding rules per Ring 1 layer explicit per
  registry v0.3.0 requirement.
- Q-007(g) QualityGate ADR is now the next candidate Q-row at
  the posture layer (Q-007 b-f settled).

### Rejects

- Embedding `QualityGate` definition in this ADR. Violates
  ADR 0022 §Future amendments deferral and "one coherent
  change per ADR" discipline.
- Nested-field composition for boundary evidence (collapsing
  ExecutionContext / CredentialSource / GitIdentityBinding /
  ToolProvenance fields into BoundaryObservation envelope
  payload). Violates charter inv. 1 (no policy decision in
  adapter-side composition logic) and breaks per-entity
  freshness-management.
- Embedding charter invariant 19 text in this ADR. Charter
  amendments follow change-policy in separate PR.
- Embedding React component implementation for the six
  dashboard views in this ADR. View-shape commitment is
  posture; React implementation is Ring 2 dashboard ADR
  territory.
- Treating `unknown` evidence_state as a fourth matrix row.
  ADR 0022's seven-state enum is observer-side; the matrix is
  gateway-side. `unknown` evaluates as `missing` for matrix
  purposes; this avoids permissive interpretation of unknown
  state for destructive operations.
- Allowing sandbox-derived evidence to promote across surfaces.
  Charter inv. 8 inherited; rejection rule applies to both
  new evidence subtypes.
- Cross-context evidence reuse without fresh observation. The
  inv. 19 candidate text codifies "lateral context reuse
  requires fresh observation, not substitution"; this ADR's
  composition pattern enforces it via Layer 1/2/3 re-check.

### Future amendments

- Q-007(g) ADR commits `QualityGate` standalone Ring 0 entity
  (Q-011 bucket 2): gate identity, gate_kind discriminator
  (candidate values: `identity_binding`, `credential_shadow`,
  `signing_identity`, `filesystem_trust`, `tool_provenance`,
  `mutation_class`), gate state lifecycle, evidence_refs to
  BoundaryObservation + Q-005 + Q-006 receipts.
- Schema PR per `.agents/skills/hcs-schema-change` for
  `GitIdentityBinding` and `ToolProvenance` evidence subtypes
  + the six new `Decision.reason_kind` /
  `Decision.required_grant_kind` reservations +
  `ApprovalGrant.scope` per-class extension for boundary-
  evidence-gating operations.
- Registry update PR adding the four new `boundary_dimension`
  candidates + the two new `evidence_subject_kind` enum values.
- Separate dashboard ADR commits React component
  implementations for the six views (component props, layout,
  theming, MCP adapter wiring).
- Charter v1.4.0 amendment PR commits invariant 19 text per
  the candidate above. May land alongside inv. 18 (Q-003) in
  a single wave or stand alone.
- Canonical policy YAML at Milestone 2: per-`boundary_dimension`
  freshness windows, per-class ApprovalGrant.scope binding for
  boundary-evidence-acknowledgment grants, verifier-class
  privileges for the three new `*_acknowledgment` grant kinds,
  matrix entries for `system-config` policy paths (similar to
  ADR 0033 v2 dual-authority rule).
- Q-009 (HCS diagnostic surface), Q-010 (cross-agent isolation
  taxonomy) are the next candidate Q-rows after Q-007(g) lands.
- Reopen if a future incident shows the linked-observations
  pattern misses a composition class, or the three-state matrix
  needs additional anomaly classes.

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md`
  v1.3.2 (especially inv. 1, 4, 5, 6, 7, 8, 16, 17; inv. 19
  candidate prepared for v1.4.0 amendment).
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
  (Authority discipline, Cross-context enforcement layer,
  Naming suffix discipline, Field-level scrubber rule, four
  new `boundary_dimension` candidates queued).
- Decision ledger: `DECISIONS.md` Q-007.
- ADR 0018:
  `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
  (CredentialSource entity; charter inv. 15).
- ADR 0019:
  `docs/host-capability-substrate/adr/0019-knowledge-and-coordination-store.md`
  (Q-003 v3 final; CoordinationFact composition pattern;
  scope-key disjointness rule; dashboard ADR deferral
  precedent).
- ADR 0021:
  `docs/host-capability-substrate/adr/0021-charter-v1-3-wave-1.md`
  (charter amendment workflow precedent: separate PR per
  change-policy).
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (Q-007(a) accepted; envelope shape; linked-observations
  pattern; QualityGate deferral; charter inv. 19 candidate
  origin).
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract; payload-versioned envelope pattern).
- ADR 0024:
  `docs/host-capability-substrate/adr/0024-charter-v1-3-wave-2-and-3.md`
  (charter amendment wave precedent).
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (Q-006 stage-1 receipts; first-commit-SHA `repository_id`
  resolution; `provider_observed_via` authority discipline).
- ADR 0029:
  `docs/host-capability-substrate/adr/0029-q-008-b-anomalous-capture-blocking-thresholds.md`
  (Q-008(b) v2 final; three-state matrix precedent that this
  ADR's boundary-evidence matrix mirrors; `block` vs forbidden-
  tier framing).
- ADR 0030:
  `docs/host-capability-substrate/adr/0030-q-006-stage-2-source-control-evidence-subtypes.md`
  (Q-006 stage-2 v2 final; three-way `*_observed_via` naming
  convention pattern).
- ADR 0031:
  `docs/host-capability-substrate/adr/0031-q-008-d-worktree-ownership-composition.md`
  (Q-008(d) v1 final; ApprovalGrant.scope per-class extension
  pattern; scope-key disjointness forward-look).
- ADR 0032:
  `docs/host-capability-substrate/adr/0032-q-005-ci-runner-evidence-model.md`
  (Q-005 v2 final; runner/check evidence model; load-bearing
  prerequisite for Q-007 unblock).
- ADR 0033:
  `docs/host-capability-substrate/adr/0033-q-006-b-g-github-authority-and-identity.md`
  (Q-006 (b)-(g) v2 final; GitHub authority + identity
  reconciliation; load-bearing prerequisite for Q-007 unblock;
  `RepositoryIdentityReconciliation` composes with this ADR's
  `GitIdentityBinding`).
- 2026-04-29 quality-management synthesis:
  `docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md`
  (primary research source).
- 2026-05-01 ontology promotion + receipt dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
  (Q-011 review-grammar bucket guidance; QualityGate deferral
  recommendation at line 142).
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`.

### External

- macOS TCC framework (system-level boundary observations
  consumed by `boundary_dimension: tcc`):
  <https://developer.apple.com/documentation/security/transparency_consent_and_control>
- `git-config(1)` resolution chain (consumed by
  `GitIdentityBinding`):
  <https://git-scm.com/docs/git-config>
- mise / asdf / homebrew (tool resolution providers consumed
  by `ToolProvenance`):
  - <https://mise.jdx.dev/>
  - <https://asdf-vm.com/>
  - <https://brew.sh/>
- 1Password CLI (`op`) for credential-source introspection:
  <https://developer.1password.com/docs/cli/>
