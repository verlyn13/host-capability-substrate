---
adr_number: 0028
title: Q-008(a) execution-mode receipts (ToolInvocation, CommandCapture, ExecutionMode)
status: proposed
date: 2026-05-02
charter_version: 1.3.2
tags: [execution-mode, tool-invocation, command-capture, evidence-subtype, q-008, phase-1]
---

# ADR 0028: Q-008(a) execution-mode receipts

## Status

proposed

## Date

2026-05-02

## Charter version

Written against charter v1.3.2 and `docs/host-capability-substrate/ontology-registry.md`
v0.2.1.

## Context

Q-008(a) asks whether `ToolInvocationReceipt`, `CommandCaptureReceipt`,
and `ExecutionModeObservation` should become Ring-0 concepts or
`Evidence` / `Run` / `Artifact` subtypes.

The 2026-04-30 ScopeCam exchange synthesis surfaces the motivating
failure family: an agent treated a tool's no-output / empty-stdout /
non-zero-exit-without-stderr as authoritative environment evidence (e.g.
"the worktree is corrupt", "the remote is gone", "the branch is
unreachable") rather than as a tool-runtime symptom. The agent then
authored downstream destructive Git cleanup (covered separately by
ADR 0025). The substrate-side fix is to give every tool invocation a
typed receipt that distinguishes "the tool ran and reported X" from
"the tool failed to capture / produce evidence" from "the runtime is
in mode Y".

This ADR commits posture for three execution-mode receipts. It is
doc-only and posture-only, mirroring ADR 0020's and ADR 0027's
limited-posture pattern. Schema implementation is gated on this ADR's
acceptance plus Q-008(b) blocking thresholds (still pending) and
Q-008(d) worktree-ownership (gated on Q-003).

This ADR does not implement schemas, generated JSON Schema, policy
tiers, hooks, adapters, dashboard routes, runtime probes, or mutation
operations.

## Options considered

### Option A: All three as standalone Ring-0 entities (Q-011 bucket 2)

**Pros:**
- Durable identity per concept (a tool invocation is a thing in the
  world; a capture is a record; a mode is a posture).
- Clean parallel structure to existing Ring-0 entities like
  `Run` and `Artifact`.

**Cons:**
- Duplicates `Run` for `ToolInvocationReceipt` (a `Run` is the kernel-
  brokered execution of an approved operation; a tool invocation
  inside an agent session is a similar concept at a different
  granularity).
- Multiplies entity count without commensurate lifecycle differences.
- Forces the schema slice to add three new entities before any
  observation can be recorded.

### Option B: All three as `evidenceSchema` direct subtypes (Q-011 bucket 1) (chosen)

**Pros:**
- Reuses ADR 0023's `Evidence` base contract. Each receipt becomes a
  typed payload with `payload_schema_version` discriminating the
  subtype family.
- `evidence_kind` enum already supports `receipt` and `observation`,
  which directly match the three subtypes.
- `subject_refs` already supports an `execution_context` subject
  kind; new subject kinds for `tool_invocation` can be added with one
  evidence-subject enum extension when schema implementation lands.
- Composes cleanly with ADR 0023's sandbox-authority constraints
  (charter inv. 8): a sandbox-observed capture cannot self-promote to
  a host-authoritative receipt.
- Avoids the Q-011 bucket-2 commitment that would imply per-receipt
  durable identity beyond what's needed.

**Cons:**
- Three distinct payload schema families to maintain when
  implementation lands.
- Cross-receipt composition (linking a `CommandCaptureReceipt` to its
  parent `ToolInvocationReceipt`) happens via `subject_refs` rather
  than a typed parent-child entity relationship.

### Option C: Subtype `Run` for `ToolInvocationReceipt`; `Artifact` for `CommandCaptureReceipt`; `Evidence` for `ExecutionModeObservation`

**Pros:**
- Reuses three existing Ring-0 entities.
- Aligns "tool invocation" with `Run` semantically.

**Cons:**
- `Run` per ADR 0023's planning is "one execution of an approved
  operation through the broker"; agent-side tool invocations occur
  outside that approval lane and would conflate broker-execution
  semantics with agent-internal invocation tracking.
- `Artifact` is for "a run's structured output (diff, log chunks,
  exit code, signed summary)"; a capture receipt is more about
  capture-process integrity than artifact persistence.
- The mismatch creates downstream confusion when policy/dashboard code
  has to distinguish broker-Run from invocation-receipt-Run.

## Decision

Choose Option B. All three subtypes use `evidenceSchema` from ADR 0023
directly, with typed payloads discriminated by `payload_schema_version`.

### `ToolInvocationReceipt`

- `evidence_kind: "receipt"` (positive existence of an invocation
  event).
- `subject_refs` includes:
  - `{subject_kind: "tool_invocation", subject_id: <invocation_id>}`
    (subject kind to be added to the evidence-subject enum at schema
    implementation time);
  - `{subject_kind: "execution_context", subject_id: <ctx_id>,
    relation: "ran_in"}`;
  - `{subject_kind: "resolved_tool", subject_id: <tool_id>,
    relation: "invoked"}`.
- `payload_schema_version: "tool_invocation_receipt:v1"` (canonical
  exact value to be set when schema implementation lands).
- `payload` shape (candidate field block):

```text
invocation_id
resolved_tool_id
execution_context_id
argv_redaction_mode    enum: none | redacted | classified | reference_only
argv                   optional   // present only when argv_redaction_mode = none
argv_redacted          optional   // present when argv_redaction_mode = redacted
argv_summary           optional   // free-form classification when argv_redaction_mode = classified
start_time
end_time               nullable   // null if invocation interrupted before completion
exit_code              nullable   // null if no exit observed
termination_reason     enum: normal | interrupted | timeout | killed | unknown
parent_invocation_id   optional   // for nested invocations (subagent spawn, mcp tool call)
```

Producer authority:
- Agent-internal invocations: `host-observation` if observed by the
  agent harness on the host; `sandbox-observation` if observed inside
  a sandboxed agent context. Charter inv. 8 prevents promotion.
- Kernel-brokered invocations (future, gated on broker landing): the
  receipt may carry `installed-runtime` authority because the broker
  is a verified producer; this is anticipated future authority and
  not a current posture.

### `CommandCaptureReceipt`

- `evidence_kind: "receipt"` (positive existence of a capture event,
  including positive-empty captures).
- `subject_refs` includes:
  - `{subject_kind: "tool_invocation", subject_id: <invocation_id>,
    relation: "capture_for"}`;
  - `{subject_kind: "execution_context", subject_id: <ctx_id>}`.
- `payload_schema_version: "command_capture_receipt:v1"`.
- `payload` shape (candidate field block):

```text
invocation_id
capture_status         enum: full | partial | empty | redacted | truncated | failed
stdout_byte_count      optional
stderr_byte_count      optional
stdout_redacted_excerpt optional   // present when capture_status in {redacted, partial}
stderr_redacted_excerpt optional
truncation_reason      optional   // present when capture_status = truncated
capture_failure_reason optional   // present when capture_status = failed
                                  // values: pty_unavailable | redirection_failed |
                                  //         streaming_disconnected | sandbox_blocked |
                                  //         observer_crash | unknown
captured_at
captured_by            enum: agent_harness | kernel_broker | sandbox_marker
```

Critical design point: `capture_status: empty` is a **positive
empty-capture receipt**, not a missing field. An invocation whose
capture status is unknown produces no `CommandCaptureReceipt`; an
invocation that produced literally zero bytes of output produces a
`CommandCaptureReceipt` with `capture_status: empty`. Per
ontology-registry §Naming suffix discipline §Sub-rule 2 (positive-
absence is an explicit `*Receipt`).

This is the substrate-side answer to the ScopeCam motivating failure:
empty stdout is a typed positive observation about capture, not an
implicit signal about the world.

### `ExecutionModeObservation`

- `evidence_kind: "observation"` (freshness-bound observation of mode).
- `subject_refs` includes:
  - `{subject_kind: "execution_context", subject_id: <ctx_id>}`;
  - `{subject_kind: "tool_invocation", subject_id: <invocation_id>,
    relation: "mode_for"}` (optional; present when the observation is
    bound to a specific invocation).
- `payload_schema_version: "execution_mode_observation:v1"`.
- `payload` shape (candidate field block):

```text
execution_context_id
invocation_id          optional
mode                   enum: normal | sandbox_observation | escalated |
                              isolated_clean_room | unknown
escalation_kind        optional   // present when mode = escalated
                                  // values: privileged_user | broker_grant |
                                  //         capability_marker | unknown
privileged_capabilities array     // optional list, when mode = escalated
isolated_image_ref     optional   // present when mode = isolated_clean_room
observed_via           enum: kernel_observation | sandbox_marker | host_telemetry |
                              self_assertion
```

Authority handling:

- `observed_via: kernel_observation` produces `host-observation`
  authority (kernel telemetry is host-trusted).
- `observed_via: sandbox_marker` produces `sandbox-observation`
  authority. The mode itself can name `sandbox_observation`, but the
  evidence carrying that observation must follow inv. 8.
- `observed_via: host_telemetry` produces `host-observation` if the
  telemetry source is a verified host installation;
  `sandbox-observation` if observed inside a sandbox.
- `observed_via: self_assertion` produces `derived` authority at most.
  An agent claiming "I am running in normal mode" without kernel /
  sandbox / host telemetry backing is the lowest-trust observation
  class; charter v1.3.2 wave-3's fabricated-evidence-envelope
  forbidden pattern blocks promotion of self-assertion to
  `host-observation`.

### Cross-receipt composition rules

- A `CommandCaptureReceipt` references its parent invocation via
  `subject_refs[subject_kind="tool_invocation",
  relation="capture_for"]`. The referenced `invocation_id` must
  resolve to a `ToolInvocationReceipt` with the same
  `execution_context_id`. Cross-context capture references
  (capture from invocation in context A applied to context B) fail
  per charter v1.3.2 wave-3 cross-context evidence reuse forbidden
  pattern.
- An `ExecutionModeObservation` may reference a specific invocation
  via `subject_refs[subject_kind="tool_invocation",
  relation="mode_for"]`. When present, its `execution_context_id`
  must match the `ToolInvocationReceipt`'s.
- A `ToolInvocationReceipt`'s `parent_invocation_id` references
  another `ToolInvocationReceipt` for nested invocations (subagent
  spawn, MCP tool call). Same-execution-context binding required.

### Out of scope

This ADR does not authorize:

- Schema source (Zod, generated JSON Schema, tests, fixtures). Schema
  implementation uses `.agents/skills/hcs-schema-change` after this
  ADR's acceptance.
- Q-008(b) anomalous-command-capture blocking thresholds (separate
  sub-decision; pending). When any operation should *block*
  implementation/cleanup/merge/push on observed capture anomalies is
  policy work, not receipt-shape work.
- Q-008(d) worktree-ownership composition (gated on Q-003).
- Adding `tool_invocation` to the evidence-subject enum in
  `packages/schemas/src/entities/evidence.ts`. That schema enum
  update lands with the schema implementation PR.
- Kernel broker semantics for `installed-runtime` authority on
  `ToolInvocationReceipt`. Anticipated future authority but not
  current posture; broker lands later.
- Mutating execution endpoints. Inv. 7 still gates these.
- MCP / Codex / Claude protocol-specific receipt shapes; the three
  receipts here are protocol-agnostic.

## Consequences

### Accepts

- All three subtypes are committed by name and shape. Q-008(a) is
  settled at the design layer.
- All three use `evidenceSchema` directly as typed payloads (Q-011
  bucket 1). No new envelopes; no Q-011 bucket 2 commitments.
- `CommandCaptureReceipt.capture_status: empty` is the typed answer
  for "the tool produced zero output." Empty stdout is a positive
  receipt, not a missing field. Closes the ScopeCam motivating
  failure at the receipt-shape layer.
- `ExecutionModeObservation.observed_via` distinguishes kernel /
  sandbox / host / self-assertion authority sources. Self-assertion
  is the lowest-trust class and cannot be promoted under inv. 8 or
  charter v1.3.2 wave-3.
- Cross-context binding (charter v1.3.2 wave-3 forbidden pattern) is
  enforced at composition time: capture-of-A applied-to-B fails;
  invocation-mode-A applied-to-B fails.
- ADR 0025 v2's `dirty_state_evidence_refs` and similar component
  evidence may compose `ToolInvocationReceipt` /
  `CommandCaptureReceipt` records as part of their evidence chain
  when those receipts witness the producing tool invocation (for
  example, the `git status --porcelain` invocation that produced the
  dirty-state observation). The schema PR for those receipts is
  responsible for the binding.

### Rejects

- Treating no-output / empty-stdout / silent-exit-zero as evidence
  about the world (the ScopeCam failure mode).
- Subtyping `Run` for `ToolInvocationReceipt` (Option C); `Run` is
  reserved for broker-executed approved operations.
- Subtyping `Artifact` for `CommandCaptureReceipt` (Option C);
  artifacts are output products, not capture-process records.
- Promoting `self_assertion` execution-mode observations to
  `host-observation` authority.
- Cross-context capture / mode references (capture-from-A
  applied-to-B).
- Kernel-brokered authority on agent-side receipts before the broker
  lands.
- Pre-specifying `Run.execution_context_id` shape; that is broker /
  kernel territory.

### Future amendments

- Schema implementation PR (separate, post-acceptance) adds
  `tool_invocation` to the evidence-subject enum; introduces three
  payload schema families; updates ontology.md; lands tests and
  fixtures.
- Q-008(b) anomalous-command-capture blocking thresholds: a
  follow-up ADR will name which `capture_status` /
  `termination_reason` / `mode` combinations block which
  downstream operations. This ADR's receipt shape exists to make
  those thresholds expressible.
- Q-008(d) worktree-ownership composition: gated on Q-003 settling.
- Reopen if Q-003 coordination facts reframe `ExecutionModeObservation`
  as a coordination fact rather than evidence.
- Reopen if Q-005 runner work introduces remote-runner invocation
  semantics that need a distinct receipt shape.
- Reopen if a future incident shows the three subtypes miss a class
  of execution-mode failure (for example, partial-redirection or
  PTY-loss cases).

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md`
  v1.3.2, invariants 1, 5, 7, 8, 16, 17 (and v1.3.2 wave-3 forbidden
  patterns)
- Ontology registry: `docs/host-capability-substrate/ontology-registry.md`
  v0.2.1
- Decision ledger: `DECISIONS.md` Q-003, Q-008
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract used for all three subtypes)
- ADR 0024:
  `docs/host-capability-substrate/adr/0024-charter-v1-3-wave-2-and-3.md`
  (charter wave-3 cross-context evidence reuse forbidden pattern;
  fabricated-evidence-envelope forbidden pattern)
- ADR 0025:
  `docs/host-capability-substrate/adr/0025-branch-deletion-proof.md`
  (`dirty_state_evidence_refs` consumes `ToolInvocationReceipt` /
  `CommandCaptureReceipt` for the producing tool invocation)
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (parallel-track Q-006 stage-1 expansion; same posture-only pattern)
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- Ontology promotion/dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`

### External

- POSIX `wait` / exit-code semantics:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/wait.html>
- IEEE Std 1003.1 process termination:
  <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html>
- macOS Seatbelt / sandbox-exec documentation (Apple Open Source).
