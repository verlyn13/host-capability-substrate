---
adr_number: 0029
title: Q-008(b) anomalous-command-capture blocking thresholds
status: proposed
date: 2026-05-03
charter_version: 1.3.2
tags: [anomalous-capture, blocking-thresholds, policy-shape, gateway, q-008, phase-1]
---

# ADR 0029: Q-008(b) anomalous-command-capture blocking thresholds

## Status

proposed (v2)

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Revision history

- **v1** (2026-05-03, commit `e197c48`): initial draft. Reviewers
  surfaced 16 blocking findings (4 architect, 4 ontology, 4 policy, 4
  security).
- **v2** (2026-05-03, this revision): addresses all 16 blockers.
  Cross-cutting registry codifications (enum-value casing,
  `_code`/`_class` rejection on Decision/ApprovalGrant fields) landed
  in ontology-registry v0.3.3. ADR-side changes: §Anomalous-capture
  taxonomy adds combination H (`cross_receipt_inconsistency`); §Combination
  G and §Combination E reframed as defense-in-depth confirmations of
  rules already in registry v0.3.2 / ADR 0028 v4 with explicit Layer
  2/3 re-check rules; §Operation classes annotates `worktree_mutation`
  with Q-008(d) deferral; new §Operation-class classification authority,
  §Closed-list fail-mode, §`block` vs forbidden-tier framing,
  §Approval × self-asserted authority composition, §`ApprovalGrant.scope`
  shape sketch sections; field renames per registry v0.3.3 Sub-rule 6
  (`reason_code` → `reason_kind`, `required_grant_class` →
  `required_grant_kind`).

## Context

Q-008(b) asks: when does anomalous command capture block implementation,
cleanup, merge, push, or worktree mutation?

The 2026-04-30 ScopeCam exchange synthesis surfaced the motivating failure:
an agent received receipt-level signals consistent with anomalous capture
(empty stdout, silent exit, capture-failure reason) and treated those
signals as positive evidence about the world (the worktree is corrupt,
the remote is gone, the branch is unreachable). Downstream destructive
Git cleanup followed.

Q-008(a) was settled in ADR 0028 v4 (accepted 2026-05-03): three typed
receipts (`ToolInvocationReceipt`, `CommandCaptureReceipt`,
`ExecutionModeObservation`) make the capture-state and execution-mode
facts first-class. ADR 0029 takes the next step: name *which*
combinations of receipt-fields constitute anomalous capture, and *which*
downstream operations block when those combinations are observed.

Q-008(c) (BranchDeletionProof composite) was settled in ADR 0025 v2.
The composite already names component-evidence requirements and
gateway-side enforcement; ADR 0029 commits the blocking-threshold
shape that proof composites consume from Q-008(a) receipts.

Q-008(d) (worktree-ownership composition) remains gated on Q-003. ADR
0029 names worktree-mutation operations as one of the affected
operation classes but does not commit worktree-ownership composition
rules — that work continues under Q-008(d) once Q-003 settles.

This ADR is doc-only and posture-only, mirroring ADR 0027 / ADR 0028
acceptance pattern. It does not author canonical policy YAML, schema
source, hook bodies, or runtime probes. The blocking-threshold matrix
is a posture commitment that Ring 1 policy/gateway services consume;
the actual numeric thresholds and per-operation policy entries land in
canonical policy at `system-config/policies/host-capability-substrate/`
once HCS Milestone 2 ships.

## Options considered

### Option A: Single binary block-or-allow rule per receipt combination

**Pros:**
- Simple to express in policy YAML.
- Easy for Ring 1 services to evaluate.

**Cons:**
- Loses the operation-class distinction: read-only diagnostics versus
  destructive Git versus external-control-plane mutations need different
  thresholds for the same receipt combination.
- Forces over-blocking (every operation blocks on every anomaly) or
  over-permitting (no operation blocks on any anomaly).

### Option B: Three-state matrix (block / approval-required / warn) crossed with operation classes (chosen)

**Pros:**
- Each receipt-combination × operation-class cell carries a typed
  decision (block, approval-required, warn).
- Composes with charter inv. 6 (forbidden tier non-escalable) by
  reserving "block" for non-escalable cases and "approval-required" for
  cases that can clear via `ApprovalGrant`.
- Matches ADR 0025 v2's BranchDeletionProof-style escalation
  discipline (force-protected non-escalable; force-non-protected
  approval-only; non-force-without-merge approval-only).
- Lets read-only diagnostics flow even when destructive operations
  block on the same anomaly.

**Cons:**
- More entries in policy YAML.
- Producer-side reasoning needs to bind operations to operation
  classes consistently; misclassification is a policy gap.

### Option C: Continuous risk score per receipt combination, threshold per operation

**Pros:**
- Maximally flexible.
- Could express subtle gradations.

**Cons:**
- Numeric scoring is canonical-policy-driven and brittle; small
  threshold changes cascade across operations.
- Hard to audit: a `Decision` record citing a "risk score 0.42" is
  less inspectable than one citing "block per Q-008(b) row 3".
- Charter inv. 6 is already discrete (forbidden vs not); a continuous
  score conflicts with the discrete authority ladder.

## Decision

Choose Option B. Q-008(b) commits a three-state × operation-class
blocking-threshold matrix.

### `block` vs forbidden-tier framing

The cell state `block` in this matrix is a *Decision-level* state
("this instance of the operation rejects unconditionally given these
receipt facts") and is **tier-orthogonal**. It does not promote the
operation to forbidden tier in canonical policy.

- *Forbidden tier* (canonical policy at
  `system-config/policies/host-capability-substrate/`): the operation
  itself is unrunnable in the substrate; no `ApprovalGrant` exists,
  no Decision is produced, the gateway never invokes the operation.
- *Decision-level `block`* (this matrix): the operation is registered
  and runnable in principle, but a specific invocation is rejected
  because the consuming receipt combination is structurally
  inconsistent with the operation class. A different invocation of
  the same operation against different receipt facts may not block.

`block` cells are non-escalable per inv. 6 (no `ApprovalGrant`
upgrades them) but tier-orthogonal: an `allowed_with_approval` tier
operation whose invocation hits a `block` cell still rejects without
moving the operation to forbidden tier.

### Anomalous-capture taxonomy (receipt combinations)

The taxonomy is a closed list of named combinations over Q-008(a)
receipt fields. Each combination has a stable name in `lower_snake_case`
per registry v0.3.3 Sub-rule 9; canonical policy references combinations
by name, not by re-deriving the field predicates.

**A. `empty_apparent_success`** — `CommandCaptureReceipt.capture_status:
empty` AND `ToolInvocationReceipt.exit_code: 0` AND
`ToolInvocationReceipt.termination_reason: normal`. The ScopeCam
motivating failure: tool ran "successfully" but produced literally zero
bytes of output. Legitimate cases exist (a tool that intentionally
produces no output on success); anomalous cases dominate downstream
gateway use.

**B. `capture_failure`** — `CommandCaptureReceipt.capture_status:
failed`, with any `capture_failure_reason` value. The capture mechanism
itself failed; the actual tool may or may not have run. The receipt
proves "capture failed" but does not prove "tool did or did not
complete its intended work."

**C. `abnormal_termination`** — `ToolInvocationReceipt.termination_reason
in {killed, interrupted, timeout, unknown}`. The tool did not complete
normally. The receipt is a typed record of termination but does not
carry the tool's intended-completion evidence.

**D. `authority_self_asserted`** — `Evidence.authority: self-asserted`
(per registry v0.3.0 §Self-assertion authority class). The producer's
claims have no kernel/sandbox/host telemetry backing. Already
unpromotable per inv. 8; the entry exists for matrix completeness and
to bind composition rules with `approval_required` cells (see
§Approval × self-asserted authority composition below).

**E. `mode_unknown`** — `ExecutionModeObservation.mode: unknown`.

This combination *inherits* the gateway-BLOCK rule already committed
in ADR 0028 v4. The matrix entry below does not introduce a new
enforcement; it confirms inheritance and codifies that all three
Ring 1 layers re-enforce the rule:

- **Layer 1 (mint API)**: rejects mint of any composite or
  evidence-consuming Decision whose component evidence carries
  `mode: unknown` for any operation class other than read-only
  diagnostics already covered by ADR 0028 v4's `mode_unknown ⇒
  shape_only` rule for read-only operations. (`shape_only` is
  ADR 0028 v4 vocabulary; in this matrix's vocabulary it maps to
  the read-only cell behavior, not a separate state.)
- **Layer 2 (broker FSM re-check)**: re-evaluates the rule at
  operation-execution time per registry v0.3.2 §Cross-context
  enforcement layer.
- **Layer 3 (gateway re-derive)**: applies the rule at decision
  time. Per ADR 0028 v4, the gateway is the authoritative non-
  escalable layer.

The matrix row for E below is binding for non-read-only operation
classes; for `read_only_diagnostic`, the cell carries `block` because
ADR 0028 v4's `shape_only` outcome is itself the read-only
allowance and `mode_unknown` does not extend further. Diagnostic
operations that need to inspect host state under unknown execution
mode use ADR 0028 v4's explicit shape-only path, not this matrix.

**F. `capture_truncated_at_cap`** — `CommandCaptureReceipt.capture_status:
truncated` with `truncation_reason: byte_cap_reached`. The producer hit
the 1024-byte excerpt cap (per ADR 0028 v4). May indicate legitimate
long output or attempted overflow exfiltration; flag for gateway
inspection.

**G. `producer_class_forgery_attempt`** — receipt arrives at any of the
three Ring 1 layers with a producer-supplied `Evidence.producer` value
naming a kernel-trusted producer class (per registry v0.3.2
§Producer-vs-kernel-set authority fields allowlist: `kernel_broker`,
`kernel_telemetry`, `mint_api`).

This combination *inherits* the mint-API rejection rule already
committed in registry v0.3.2. The matrix entry below does not
introduce a new enforcement at Layer 1; it confirms inheritance and
codifies that Layers 2 and 3 also re-check, providing defense in
depth against bypass attempts:

- **Layer 1 (mint API)**: rejects per registry v0.3.2 §Producer-vs-
  kernel-set authority fields. This is the primary enforcement layer.
- **Layer 2 (broker FSM re-check)**: when a broker FSM consumes a
  proof composite or evidence envelope at operation-execution time,
  it re-validates `Evidence.producer` against the kernel-only
  allowlist. A record that bypassed Layer 1 (e.g., via an internal
  call path) still fails at Layer 2 if its `Evidence.producer` is
  on the allowlist but was not kernel-set.
- **Layer 3 (gateway re-derive)**: at decision time the gateway
  re-derives whether `Evidence.producer` is on the allowlist for
  any component evidence; allowlist values that the gateway cannot
  bind to a kernel-set provenance fail per inv. 6.

The audit-chain coverage of rejections rule (registry v0.3.1
§Audit-chain coverage of rejections) applies at all three layers; G
rejections emit audit events with rejection-class
`producer_class_forgery_attempt` per Sub-rule 6 (registry v0.3.3),
identifying the rejecting layer.

**H. `cross_receipt_inconsistency`** — `ToolInvocationReceipt` and
`CommandCaptureReceipt` for the same operation diverge on a structural
fact:

- different `op_id` values for receipts claiming to refer to the same
  invocation;
- timestamps on the two receipts that fall outside the consistency
  window declared in ADR 0028 v4;
- contradictory exit/capture status (e.g., `termination_reason:
  normal` + `exit_code: 0` on one receipt and `capture_status: failed`
  with a `capture_failure_reason` that names a tool-side fault on the
  other);
- producer fields that name different `Evidence.producer` allowlist
  values across the receipt pair without kernel-set provenance for
  both.

The receipts together no longer corroborate a single invocation; the
combination is anomalous regardless of which receipt is "correct."
Combination H surfaces during the broker FSM re-check (Layer 2) and
gateway re-derive (Layer 3), which are the layers that see receipt
pairs together; the mint API (Layer 1) accepts each receipt
individually but the FSM rejects the *consuming* operation when the
pair is inconsistent.

The list is closed for stage-1 acceptance. New combinations require an
ontology/policy review pass before policy YAML adopts them. The
closed-list discipline is binding; see §Closed-list fail-mode below
for the default behavior when an unregistered combination is observed.

### Operation classes

Operations the matrix gates fall into six classes. Each class has a
stable name in `lower_snake_case` per registry v0.3.3 Sub-rule 9;
canonical policy references classes by name, not by re-deriving the
operation list.

**1. `read_only_diagnostic`** — operations that observe host state
without mutating it. Examples: `system.host.profile.v1`,
`system.session.current.v1`, `system.tool.resolve.v1`. Per inv. 7,
read-only operations do not require the full approval/audit/dashboard
stack; they remain available even when other classes block.

**2. `agent_internal_state`** — operations that mutate agent-side
context (memory, session-scoped artifacts) without touching host or
external state. Examples: agent memory writes, `evidence_cache`
writes (when the cache is agent-scoped and not Ring 1 audit chain).

**3. `destructive_git`** — Git operations that destroy local or
remote state. Examples: branch deletion (gated by `BranchDeletionProof`
per ADR 0025 v2), force-push, ref deletion, worktree pruning. Per
inv. 7, these require the full approval/audit/dashboard stack; per
ADR 0025 v2, branch deletion specifically requires the proof composite.

**4. `external_control_plane_mutation`** — operations against remote
control planes (Cloudflare, GitHub Actions, 1Password, DNS providers).
Per inv. 16 (charter v1.3.0+), these require typed evidence before
provider-side mutation.

**5. `worktree_mutation`** — Git worktree add/remove/move/lock
operations. **The matrix row below carries default thresholds; the
final composition with `WorkspaceContext` / `Lease` / Q-003
coordination facts is gated on Q-008(d) and may revise individual
cells.** Q-008(b) commits the *shape* (a row exists in the matrix
and uses the same three-state vocabulary); Q-008(d) commits the
*content* of the row once Q-003 settles. Until Q-008(d), the row's
defaults apply.

**6. `merge_or_push`** — branch merge into a protected ancestor or
push to a protected remote. Distinct from `destructive_git` because
merge/push do not destroy state but do propagate it across protection
boundaries.

### Operation-class classification authority

Each Ring 1 operation registers its operation class at registration
time. The classification authority is:

- **Producer of the operation declaration**: the Ring 1 service that
  owns the operation (`system.host.profile.v1` is owned by the
  host-state service; `git.branch.delete.v1` is owned by the
  destructive-Git service). The owning service is the
  classification authority for its operations.
- **Broker FSM enforcement**: when an operation is invoked, the
  broker FSM looks up the operation's registered class from the
  Ring 1 operation registry. Operations without a registered class
  are rejected at the mint API per §Closed-list fail-mode below.
- **Cross-class promotion is forbidden**: an operation registered as
  `read_only_diagnostic` cannot be re-classified at invocation time
  as `agent_internal_state` to relax thresholds. Re-classification
  requires re-registration, which is itself a typed Decision
  recording the change.

This classification authority is independent of canonical policy
tier; an operation in `allowed_with_approval` tier may be classified
as `destructive_git` or `merge_or_push` per its receipt-consumption
shape.

### Closed-list fail-mode

When a receipt combination not present in §Anomalous-capture taxonomy
is observed (a combination that emerges from a future receipt-shape
extension or a producer bug), the gateway applies a tightening default
per operation class:

- `read_only_diagnostic`: **`warn`** — the diagnostic value of the
  observation is preserved; the unrecognized combination is recorded
  in audit chain for ontology review.
- `agent_internal_state`: **`warn`** — same rationale.
- `destructive_git`: **`block`** — the operation rejects until a
  matching combination is registered. Rationale: destructive Git
  operations against unrecognized anomaly shapes risk the ScopeCam
  motivating failure (treating unfamiliar receipts as positive
  evidence).
- `external_control_plane_mutation`: **`block`** — same rationale.
- `worktree_mutation`: **`block`** (subject to Q-008(d) refinement).
- `merge_or_push`: **`block`** — same rationale.

When an operation registered without an operation class is invoked
(missing-class case rather than missing-combination case), the
gateway rejects with `Decision.reason_kind:
operation_class_unregistered` regardless of receipt facts. Tightening
the class registry is a separate policy workflow.

The fail-mode is intentionally tightening; loosening defaults
requires a registry/ADR pass.

### Blocking-threshold matrix

The matrix maps each anomalous-capture combination to a state
(`block` | `approval_required` | `warn`) per operation class. Per
inv. 6, `block` is non-escalable; `approval_required` consumes a
matching `ApprovalGrant`; `warn` produces a typed `Decision` that
allows the operation but records the anomaly in the audit chain.

| Combination ↓ \ Class → | read_only_diagnostic | agent_internal_state | destructive_git | external_control_plane_mutation | worktree_mutation (Q-008(d)) | merge_or_push |
|---|---|---|---|---|---|---|
| **A. empty_apparent_success** | warn | warn | block | block | warn | approval_required |
| **B. capture_failure** | warn | warn | block | block | block | block |
| **C. abnormal_termination** | warn | warn | block | block | block | approval_required |
| **D. authority_self_asserted** | warn | warn | block | block | block | block |
| **E. mode_unknown** | block | block | block | block | block | block |
| **F. capture_truncated_at_cap** | warn | warn | warn | approval_required | warn | warn |
| **G. producer_class_forgery_attempt** | block | block | block | block | block | block |
| **H. cross_receipt_inconsistency** | warn | warn | block | block | block | block |

Cell semantics:

- **`warn`**: the operation proceeds; a typed `Decision` records the
  anomaly with the named combination as `Decision.reason_kind` (per
  registry v0.3.3 Sub-rule 6). The `Decision` participates in the
  audit hash chain per registry v0.3.1 §Audit-chain coverage of
  rejections (warn is not a rejection; the rule extends by
  inheritance because audit chain coverage is by Decision shape, not
  by outcome class).
- **`approval_required`**: the operation requires a matching
  `ApprovalGrant` whose scope binds the named combination as a
  permitted-anomaly term (see §`ApprovalGrant.scope` shape sketch
  below). Without the grant, the operation rejects; the rejection is
  a typed `Decision` with `reason_kind` and `required_grant_kind`
  per registry v0.3.3 Sub-rule 6 and v0.3.1 §Audit-chain coverage of
  rejections.
- **`block`**: the operation rejects unconditionally; no
  `ApprovalGrant` can clear the rejection. Per inv. 6, `block` is
  non-escalable. The `Decision` records the rejection in the audit
  chain. `block` is *Decision-level* and tier-orthogonal per
  §`block` vs forbidden-tier framing above.

### Approval × self-asserted authority composition

When the matrix cell is `approval_required` and the consuming
evidence carries `Evidence.authority: self-asserted` (combination D
in the matrix and any composition that brings self-asserted evidence
into an `approval_required` cell):

- **A standard `ApprovalGrant` does NOT clear the rejection.**
  Self-asserted authority is below `sandbox-observation` in the
  authority ladder per registry v0.3.0; it cannot satisfy
  `approval_required` automatically.
- **A typed self-assertion-acknowledgment grant is required.** The
  grant's scope must include `acknowledges_self_asserted_authority:
  true` and bind to the specific `Evidence` record(s) being relied
  upon. The grant is itself a typed Decision recording explicit
  human authority over the self-assertion.
- **The gateway re-derives the self-assertion at decision time** per
  registry v0.3.2 §Cross-context enforcement layer Layer 3. The
  self-assertion-acknowledgment grant binds the exact evidence
  record set; if a different evidence record (with the same kind
  but different `evidence_id`) reaches the gateway, the grant does
  not transfer.

This rule prevents the failure mode where an agent self-asserts
favorable execution context, requests an `ApprovalGrant` for the
downstream operation, and the grant is satisfied without the human
acknowledging that the execution context is self-asserted.

In the matrix above, combination D is `block` for all classes other
than read-only/internal because `approval_required` would invoke this
composition; the `block` cells codify that even with explicit
acknowledgment, the operation does not proceed under self-asserted
authority for destructive/external-plane/merge-push classes. The
self-assertion-acknowledgment grant pattern applies when an operation
class is `approval_required` for combinations *other* than D and the
consuming evidence happens to be self-asserted (e.g., a combination
A `approval_required` cell on `merge_or_push` with self-asserted
component evidence).

### `ApprovalGrant.scope` shape sketch

ADR 0025 v2 bound `BranchDeletionProof`-consuming grants to commit
SHA + worktree. ADR 0029 generalizes the grant scope shape per
operation class. The scope shape sketch below is *posture only*; the
schema source for `ApprovalGrant.scope` lands per
`.agents/skills/hcs-schema-change` after this ADR's acceptance.

A grant's scope must bind at least:

- **`operation_class`** — one of the six classes from §Operation
  classes.
- **`anomalous_capture_combinations`** — the closed list of
  combinations whose `approval_required` cells the grant satisfies.
- **`execution_context_id`** — the `ExecutionContext` the grant is
  scoped to, per registry v0.3.0 §Cross-context enforcement layer.
- **`target_ref`** — the operation's primary target reference
  (`workspace_id`, `surface_id`, `tool_or_provider_ref`, or
  per-class equivalent).

Per-class extensions:

- `destructive_git` grants additionally bind to **commit SHA + first-
  commit SHA repository_id** (matches ADR 0025 v2 BranchDeletionProof
  scope).
- `merge_or_push` grants additionally bind to **source ref + target
  ref + commit SHA** (matches the merge/push semantics).
- `external_control_plane_mutation` grants additionally bind to
  **provider_id + provider-side target_id** (matches inv. 16
  typed-evidence-before-provider-mutation).
- `worktree_mutation` grants are deferred to Q-008(d) per
  §Operation classes class 5.

A grant whose scope is broader than these constraints (e.g., an
operation-class-only grant without execution_context binding) is
rejected at the mint API per registry v0.3.0 §Cross-context
enforcement layer. A grant whose scope is narrower (binding to a
specific receipt-pair op_id) is permitted; the gateway honors the
narrowest grant satisfying the operation's facts.

### Composition with proof composites

Proof composites (per ADR 0025 v2's BranchDeletionProof; future
composites for force-push, ruleset edits, etc.) consume Q-008(b)
thresholds at composition time. A `BranchDeletionProof` whose
component evidence includes a `CommandCaptureReceipt` with
`capture_status: failed` (combination B) cannot clear `destructive_git`
class; the proof's mint API rejects the composition. This composes
cleanly with ADR 0025 v2's existing component-evidence binding rules.

The general pattern: proof composites reference component evidence by
`evidenceRefSchema`; the broker FSM re-checks each component's
anomalous-capture combination against the consuming operation's class
at execution time (per registry v0.3.2 §Cross-context enforcement
layer layer 2). Combination H (`cross_receipt_inconsistency`) is
specifically detected at this re-check stage, since the FSM is the
first layer that sees component evidence as a corroborating set.

### Threshold-application layer

Per registry v0.3.2 §Cross-context enforcement layer, the
blocking-threshold matrix is applied at all three Ring 1 layers:

- **Layer 1 (mint API)**: applies combinations B, C, D, E, F, G to
  the receipt or composite being minted. Combinations A and H
  require receipt-pair or per-invocation context that the mint API
  does not have; they are surfaced at Layer 2.
- **Layer 2 (broker FSM re-check)**: re-evaluates all combinations
  at operation-execution time, since execution-mode and
  capture-status facts can change between mint and execution.
  Specifically:
  - Combination A: detected when the FSM correlates the
    `ToolInvocationReceipt` and `CommandCaptureReceipt` for the
    same `op_id` and finds the empty-success conjunction.
  - Combination H: detected at the FSM because it is the first
    layer with both receipts in hand.
  - Combinations G: re-checked per §Combination G above; bypass-
    Layer-1 records still fail here.
- **Layer 3 (gateway re-derive)**: applies the matrix at decision
  time. The gateway is the authoritative non-escalable layer per
  inv. 6; layer-3 `block` is binding regardless of layer-1/layer-2
  outcomes (per registry v0.3.1 §Layer-disagreement tiebreaker).

### Out of scope

This ADR does not authorize:

- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. The matrix is
  posture; the policy entries are system-config work, gated on HCS
  Milestone 2 (`tiers.yaml` schema + `Decision`/`ApprovalRequest`
  schemas).
- Schema source for `Decision` or `ApprovalGrant` extensions
  (`reason_kind` enum, `required_grant_kind` enum,
  `ApprovalGrant.scope` shape). Schema implementation lands per
  `.agents/skills/hcs-schema-change` after this ADR's acceptance.
- Hook bodies that enforce the matrix at Ring 2. Hooks call HCS;
  policy decisions live at Ring 1.
- Adapter behavior. Per charter inv. 1, adapters translate; they do
  not classify.
- Q-008(d) worktree-ownership composition rules. The matrix names
  `worktree_mutation` as a class; the composition with
  `WorkspaceContext` / `Lease` / Q-003 coordination facts continues
  under Q-008(d). The default cell values in the
  `worktree_mutation` row apply until Q-008(d) settles.
- Numeric thresholds for stage-2 anomalous-capture combinations (e.g.,
  rate of `empty_apparent_success` per session window). Such
  combinations require their own ADR if and when an incident
  motivates them.

## Consequences

### Accepts

- Q-008(b) is settled at the design layer. The eight-combination
  taxonomy and six-class operation list are the canonical vocabulary
  for the matrix.
- The three-state cell (`block` | `approval_required` | `warn`)
  composes cleanly with charter inv. 6 (forbidden tier non-escalable)
  and with ADR 0025 v2's escalation discipline. `block` is
  Decision-level and tier-orthogonal; it is not promotion to
  forbidden tier.
- Proof composites consume Q-008(b) thresholds at composition time;
  ADR 0025 v2's BranchDeletionProof inherits the rule by reference.
- The matrix applies at all three Ring 1 layers (mint API + broker FSM
  + gateway) per registry v0.3.2 §Cross-context enforcement layer;
  combination G is specifically re-enforced at Layer 2 and Layer 3
  on top of the Layer 1 mint-API rejection.
- `block` cells are non-escalable per inv. 6; `approval_required`
  cells consume `ApprovalGrant` whose scope shape is sketched in
  §`ApprovalGrant.scope` shape sketch; `warn` cells produce typed
  `Decision` records that participate in the audit chain.
- `Decision.reason_kind` and `Decision.required_grant_kind` are the
  registry-canonical discriminator field names per registry v0.3.3
  Sub-rule 6.
- The matrix is the binding shape; canonical numeric thresholds (rate
  windows, session caps, freshness deadlines) land in
  `system-config/policies/host-capability-substrate/tiers.yaml` once
  HCS Milestone 2 ships.
- Each Ring 1 operation registers its operation class at registration
  time; the broker FSM enforces the registered class at execution
  time per §Operation-class classification authority.
- Unregistered combinations and unregistered operation classes fail
  tightening per §Closed-list fail-mode.

### Rejects

- Single binary block-or-allow per receipt combination (Option A).
- Continuous risk score per combination (Option C).
- Treating `capture_status: empty` + `exit_code: 0` as positive
  evidence-of-success for any operation class beyond
  `read_only_diagnostic` and `agent_internal_state` (closes the
  ScopeCam motivating failure at the policy-shape layer).
- Allowing producer-supplied `Evidence.producer` values naming
  kernel-trusted classes; combination G is unconditionally `block`
  across all operation classes and re-checked at all three Ring 1
  layers (per registry v0.3.2 §Producer-vs-kernel-set authority
  fields, this is enforced at the mint API; Layers 2 and 3 re-enforce
  per §Combination G).
- Mode-unknown observations clearing any operation class beyond
  ADR 0028 v4's explicit `shape_only` allowance for
  `read_only_diagnostic`; combination E is `block` across all classes
  (per ADR 0028 v4 gateway behavior; this matrix confirms inheritance).
- Applying the matrix at Ring 0 (schema validation). The matrix is a
  Ring 1 policy concern; schema validates structure, not policy.
- Re-classifying an operation's class at invocation time to relax
  thresholds. Re-classification is a separate Decision-recording
  workflow per §Operation-class classification authority.
- Standard `ApprovalGrant`s satisfying `approval_required` cells
  when the consuming evidence is `Evidence.authority: self-asserted`;
  a typed self-assertion-acknowledgment grant is required per
  §Approval × self-asserted authority composition.

### Future amendments

- Stage-2 anomalous-capture combinations (e.g., `repeated_empty_run`
  for a series of empty captures across a session window;
  `cross_invocation_drift` for inconsistent execution-mode
  observations within one session). These require their own ADRs
  motivated by observed incidents.
- Q-008(d) worktree-ownership composition: the matrix names
  `worktree_mutation` as a class with default cells; the actual
  composition rules with `WorkspaceContext` / `Lease` / Q-003
  coordination facts continue under Q-008(d) once Q-003 settles.
- Charter v1.3.x or v1.4.0 follow-up may add a forbidden-pattern
  entry covering "treating empty capture as positive evidence-of-
  success for non-diagnostic operations." That charter amendment
  follows the change-policy rule (separate PR, ADR-justified).
- Reopen if a future incident shows the matrix misses a class of
  failure or over-blocks a legitimate flow.

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md` v1.3.2,
  invariants 1, 4, 5, 6, 7, 8, 16, 17 (and v1.3.2 wave-3 forbidden
  patterns)
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
  (Naming suffix discipline including Sub-rule 6 amended for `_code`
  rejection and Sub-rule 9 enum-value casing; Authority discipline;
  Cross-context enforcement layer with layer-disagreement tiebreaker
  and audit-chain coverage of rejections; Redaction posture)
- Decision ledger: `DECISIONS.md` Q-003, Q-008
- ADR 0025:
  `docs/host-capability-substrate/adr/0025-branch-deletion-proof.md`
  (BranchDeletionProof composite consumes Q-008(b) thresholds at
  composition time; `ApprovalGrant.scope` per-class extension for
  `destructive_git` matches ADR 0025 v2 scope shape)
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (Q-006 stage-1 receipts; cross-cutting authority discipline)
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (Q-008(a) execution-mode receipts; the matrix's input vocabulary;
  `mode_unknown ⇒ shape_only` for read-only)
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- 2026-05-02 system-config security audit evidence:
  `docs/host-capability-substrate/research/local/2026-05-02-system-config-security-audit-evidence.md`
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- POSIX `wait` / exit-code semantics:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/wait.html>
- IEEE Std 1003.1 process termination:
  <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html>
