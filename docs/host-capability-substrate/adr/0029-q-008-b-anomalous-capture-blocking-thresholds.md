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

proposed

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.2.

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

### Anomalous-capture taxonomy (receipt combinations)

The taxonomy is a closed list of named combinations over Q-008(a)
receipt fields. Each combination has a stable name; canonical policy
references combinations by name, not by re-deriving the field
predicates.

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
unpromotable per inv. 8; the entry exists for matrix completeness.

**E. `mode_unknown`** — `ExecutionModeObservation.mode: unknown`. The
execution mode could not be determined. Already named as a
gateway-BLOCK rule in ADR 0028 v4; the entry exists for matrix
completeness.

**F. `capture_truncated_at_cap`** — `CommandCaptureReceipt.capture_status:
truncated` with `truncation_reason: byte_cap_reached`. The producer hit
the 1024-byte excerpt cap (per ADR 0028 v4). May indicate legitimate
long output or attempted overflow exfiltration; flag for gateway
inspection.

**G. `producer_class_forgery_attempt`** — receipt arrives at the mint
API with a producer-supplied `Evidence.producer` value naming a
kernel-trusted producer class (per registry v0.3.2 §Producer-vs-kernel-set
authority fields allowlist: `kernel_broker`, `kernel_telemetry`,
`mint_api`). Already rejected at the mint API per registry v0.3.2; the
entry exists so the rejection emits an audit event (per registry v0.3.1
§Audit-chain coverage of rejections) named in the matrix.

The list is closed for stage-1 acceptance. New combinations require an
ontology/policy review pass before policy YAML adopts them.

### Operation classes

Operations the matrix gates fall into six classes. Each class has a
stable name; canonical policy references classes by name, not by
re-deriving the operation list.

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
operations. Q-008(d) will commit the composition rules with
`WorkspaceContext` / `Lease` / Q-003 coordination facts; Q-008(b)
commits the blocking-threshold rule shape.

**6. `merge_or_push`** — branch merge into a protected ancestor or
push to a protected remote. Distinct from `destructive_git` because
merge/push do not destroy state but do propagate it across protection
boundaries.

### Blocking-threshold matrix

The matrix maps each anomalous-capture combination to a state
(`block` | `approval_required` | `warn`) per operation class. Per
inv. 6, `block` is non-escalable; `approval_required` consumes a
matching `ApprovalGrant`; `warn` produces a typed `Decision` that
allows the operation but records the anomaly in the audit chain.

| Combination ↓ \ Class → | read_only_diagnostic | agent_internal_state | destructive_git | external_control_plane_mutation | worktree_mutation | merge_or_push |
|---|---|---|---|---|---|---|
| **A. empty_apparent_success** | warn | warn | block | block | warn | approval_required |
| **B. capture_failure** | warn | warn | block | block | block | block |
| **C. abnormal_termination** | warn | warn | block | block | block | approval_required |
| **D. authority_self_asserted** | warn | warn | block | block | block | block |
| **E. mode_unknown** | block | block | block | block | block | block |
| **F. capture_truncated_at_cap** | warn | warn | warn | approval_required | warn | warn |
| **G. producer_class_forgery_attempt** | block | block | block | block | block | block |

Cell semantics:

- **`warn`**: the operation proceeds; a typed `Decision` records the
  anomaly with the named combination as `decision.reason_code`. The
  `Decision` participates in the audit hash chain per registry v0.3.1
  §Audit-chain coverage of rejections (warn is not a rejection; the
  rule extends by inheritance).
- **`approval_required`**: the operation requires a matching
  `ApprovalGrant` whose scope binds the named combination as a
  permitted-anomaly term. Without the grant, the operation rejects;
  the rejection is a typed `Decision` with `reason_code` and
  `required_grant_class` per registry v0.3.1 §Audit-chain coverage of
  rejections.
- **`block`**: the operation rejects unconditionally; no
  `ApprovalGrant` can clear the rejection. Per inv. 6, `block` is
  non-escalable. The `Decision` records the rejection in the audit
  chain.

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
layer layer 2).

### Threshold-application layer

Per registry v0.3.2 §Cross-context enforcement layer, the
blocking-threshold matrix is applied at all three Ring 1 layers:

- **Layer 1 (mint API)**: rejects receipts whose payload is
  structurally inconsistent with their authority claims (e.g.,
  combination G: producer_class_forgery_attempt). Layer 1 enforcement
  is binding-time.
- **Layer 2 (broker FSM re-check)**: re-evaluates the matrix at
  operation-execution time, since execution-mode and capture-status
  facts can change between mint and execution. Specifically, a
  `BranchDeletionProof` whose constituent receipts cleared layer 1 may
  fail layer 2 if a fresh `ExecutionModeObservation` shows
  `mode: unknown` was observed in the meantime.
- **Layer 3 (gateway re-derive)**: applies the matrix at decision
  time. The gateway is the authoritative non-escalable layer per inv.
  6; layer-3 `block` is binding regardless of layer-1/layer-2
  outcomes.

### Out of scope

This ADR does not authorize:

- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. The matrix is
  posture; the policy entries are system-config work, gated on HCS
  Milestone 2 (`tiers.yaml` schema + `Decision`/`ApprovalRequest`
  schemas).
- Schema source for `Decision` or `ApprovalGrant` extensions
  (`reason_code` enum, `required_grant_class` enum). Schema
  implementation lands per `.agents/skills/hcs-schema-change` after
  this ADR's acceptance.
- Hook bodies that enforce the matrix at Ring 2. Hooks call HCS;
  policy decisions live at Ring 1.
- Adapter behavior. Per charter inv. 1, adapters translate; they do
  not classify.
- Q-008(d) worktree-ownership composition rules. The matrix names
  `worktree_mutation` as a class; the composition with
  `WorkspaceContext` / `Lease` / Q-003 coordination facts continues
  under Q-008(d).
- Numeric thresholds for stage-2 anomalous-capture combinations (e.g.,
  rate of `empty_apparent_success` per session window). Such
  combinations require their own ADR if and when an incident
  motivates them.

## Consequences

### Accepts

- Q-008(b) is settled at the design layer. The seven-combination
  taxonomy and six-class operation list are the canonical vocabulary
  for the matrix.
- The three-state cell (`block` | `approval_required` | `warn`)
  composes cleanly with charter inv. 6 (forbidden tier non-escalable)
  and with ADR 0025 v2's escalation discipline.
- Proof composites consume Q-008(b) thresholds at composition time;
  ADR 0025 v2's BranchDeletionProof inherits the rule by reference.
- The matrix applies at all three Ring 1 layers (mint API + broker FSM
  + gateway) per registry v0.3.2 §Cross-context enforcement layer.
- `block` cells are non-escalable per inv. 6; `approval_required`
  cells consume `ApprovalGrant`; `warn` cells produce typed `Decision`
  records that participate in the audit chain.
- The matrix is the binding shape; canonical numeric thresholds (rate
  windows, session caps, freshness deadlines) land in
  `system-config/policies/host-capability-substrate/tiers.yaml` once
  HCS Milestone 2 ships.

### Rejects

- Single binary block-or-allow per receipt combination (Option A).
- Continuous risk score per combination (Option C).
- Treating `capture_status: empty` + `exit_code: 0` as positive
  evidence-of-success for any operation class beyond
  `read_only_diagnostic` and `agent_internal_state` (closes the
  ScopeCam motivating failure at the policy-shape layer).
- Allowing producer-supplied `Evidence.producer` values naming
  kernel-trusted classes; combination G is unconditionally `block`
  across all operation classes (per registry v0.3.2 §Producer-vs-
  kernel-set authority fields, this is already enforced at the mint
  API).
- Mode-unknown observations clearing any operation class; combination
  E is unconditionally `block` (per ADR 0028 v4 gateway behavior).
- Applying the matrix at Ring 0 (schema validation). The matrix is a
  Ring 1 policy concern; schema validates structure, not policy.

### Future amendments

- Stage-2 anomalous-capture combinations (e.g., `repeated_empty_run`
  for a series of empty captures across a session window;
  `cross_invocation_drift` for inconsistent execution-mode
  observations within one session). These require their own ADRs
  motivated by observed incidents.
- Q-008(d) worktree-ownership composition: the matrix names
  `worktree_mutation` as a class; the actual composition rules with
  `WorkspaceContext` / `Lease` / Q-003 coordination facts continue
  under Q-008(d) once Q-003 settles.
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
  `docs/host-capability-substrate/ontology-registry.md` v0.3.2
  (Authority discipline, Cross-context enforcement layer with
  layer-disagreement tiebreaker and audit-chain coverage of
  rejections, Redaction posture, Naming suffix discipline)
- Decision ledger: `DECISIONS.md` Q-003, Q-008
- ADR 0025:
  `docs/host-capability-substrate/adr/0025-branch-deletion-proof.md`
  (BranchDeletionProof composite consumes Q-008(b) thresholds at
  composition time)
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (Q-006 stage-1 receipts; cross-cutting authority discipline)
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (Q-008(a) execution-mode receipts; the matrix's input vocabulary)
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
