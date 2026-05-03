---
adr_number: 0028
title: Q-008(a) execution-mode receipts (ToolInvocation, CommandCapture, ExecutionMode)
status: proposed
date: 2026-05-02
revision: 4
charter_version: 1.3.2
tags: [execution-mode, tool-invocation, command-capture, evidence-subtype, q-008, phase-1]
---

# ADR 0028: Q-008(a) execution-mode receipts

## Status

proposed (revision 4)

## Date

Drafted 2026-05-02; revision 2 same day closed 11 blocking findings
from the v1 review. Revision 3 same day closed five additional v2
re-review gaps (B-S2 producer-crash watchdog, B-S3 audit-chain
coverage of mint-rejected Decisions, B-S4 excerpt upper bound, `mode:
unknown` gateway behavior, `ContextInheritanceReceipt` naming) plus
two cosmetic improvements. Revision 4 same day after the v3 re-review
surfaced five further gaps:

- O-B1: `_mode` was not a codified suffix (closed in registry v0.3.2
  §Sub-rule 8 — orthogonal-layer discriminators).
- O-B2: `ContextInheritanceObservation` was a wrong-suffix name —
  the inheritance is a positive-existence claim, not a freshness-
  bound observation. Renamed to `ContextInheritanceReceipt`.
- O-B3: missing §Scrubber coverage declaration — added.
- S-B5: `Evidence.producer` was producer-settable in schema, allowing
  synthetic-receipt forgery via self-asserted `producer:
  "kernel_broker"` (closed in registry v0.3.2 §Producer-vs-kernel-set
  amendment enumerating `Evidence.producer` as kernel-set when its
  value names a kernel-trusted producer class).
- S-B6: watchdog process-exit observation source unspecified — v4
  names `kqueue` `EVFILT_PROC` (macOS) as the kernel facility.

Plus four non-blocking refinements folded:

- watchdog exec-path coverage scope (broker-mediated vs agent-side
  execs);
- `mode: unknown` mode-agnostic operations clause;
- broker FSM re-check rule for `ContextInheritanceReceipt`;
- §References citation drift (residual v0.3.0 path-style citations
  bumped to v0.3.2).

Cross-cutting design rules surfaced during the four review passes
(authority field placement including `Evidence.producer`,
self-assertion authority class, cross-context enforcement layer with
layer-disagreement tiebreaker and rejection-audit coverage, redaction
posture with field-level scrubber rule and capture-status ×
redaction-mode matrix, `_kind` and `_mode` discriminator suffix
discipline) are codified in
`docs/host-capability-substrate/ontology-registry.md` v0.3.2; this
ADR cites that registry rather than re-litigating.

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.2 (codified
suffix discipline, version-field naming, authority discipline,
cross-context enforcement layer with layer-disagreement tiebreaker
and rejection-audit coverage, redaction posture with field-level
scrubber rule and capture-status × redaction-mode matrix).

## Context

Q-008(a) asks whether `ToolInvocationReceipt`, `CommandCaptureReceipt`,
and `ExecutionModeObservation` should become Ring-0 entities or
`Evidence` / `Run` / `Artifact` subtypes.

The 2026-04-30 ScopeCam exchange synthesis surfaced the motivating
failure family: an agent treated tool-runtime symptoms (no-output,
empty-stdout, silent-exit) as environment evidence and authored
downstream destructive Git cleanup. The substrate-side fix is typed
receipts that distinguish "tool ran" from "capture happened" from
"what mode applies."

Revision 2 incorporates the post-merge findings and cross-cutting rules
codified in registry v0.3.2:

- `self-asserted` is now a registered authority class below
  `sandbox-observation` (registry v0.3.2 §Self-assertion authority
  class). Self-assertion observations no longer alias to `derived`,
  closing the kind/authority semantic overload.
- Authority-class fields (`captured_by`, `observed_via`) are
  kernel-set, not producer-supplied (registry v0.3.2
  §Producer-vs-kernel-set authority fields).
- Cross-context binding rejection lives at the three Ring 1 layers
  named in registry v0.3.2 §Cross-context enforcement layer (mint
  API + broker FSM re-check + gateway re-derive), not the schema
  layer.
- `argv_redaction_mode` was a collision with the base `redaction_mode`;
  per registry v0.3.2 §Redaction posture, the field is renamed to
  `argv_capture_mode` (capture-time discipline; orthogonal to base
  persistence-redaction).

This ADR commits posture for the three execution-mode receipts. It is
doc-only and posture-only.

## Options considered

### Option A: All three as standalone Ring-0 entities (Q-011 bucket 2)

**Pros:**
- Durable identity per concept.
- Clean parallel structure to existing entities like `Run` and
  `Artifact`.

**Cons:**
- Duplicates `Run` for `ToolInvocationReceipt` (broker-executed Run
  vs agent-side invocation receipt).
- Multiplies entity count without commensurate lifecycle differences.
- Forces three new Ring-0 entities before any observation can be
  recorded.

### Option B: All three as `evidenceSchema` direct subtypes (Q-011 bucket 1) (chosen)

**Pros:**
- Reuses ADR 0023's `Evidence` base contract. Each receipt becomes a
  typed payload with `payload_schema_version` discriminating the
  subtype family.
- `evidence_kind` enum already supports `receipt` and `observation`,
  matching the three subtypes.
- Composes cleanly with ADR 0023's sandbox-authority constraints
  (charter inv. 8) and the new `self-asserted` authority class
  (registry v0.3.2).
- Avoids Q-011 bucket-2 commitments that would imply per-receipt
  durable identity beyond what's needed.

**Cons:**
- Three distinct payload schema families to maintain when
  implementation lands.
- Cross-receipt composition (linking a `CommandCaptureReceipt` to its
  parent `ToolInvocationReceipt`) happens via `subject_refs` rather
  than typed parent-child entity relationship.

### Option C: Subtype `Run` for `ToolInvocationReceipt`; `Artifact` for `CommandCaptureReceipt`; `Evidence` for `ExecutionModeObservation`

**Pros:**
- Reuses three existing Ring-0 entities.

**Cons:**
- `Run` per ADR 0023 planning is "one execution of an approved
  operation through the broker"; agent-side tool invocations occur
  outside the broker approval lane.
- `Artifact` is for output products, not capture-process records.
- Mismatch creates downstream confusion.

## Decision

Choose Option B. Revision 2 adds explicit authoring discipline,
self-assertion authority handling, capture-status × redaction matrix,
cross-context enforcement layer binding, and audit-integrity posture
for failed invocations.

### Authoring discipline (Ring 1 mint API)

All three receipts are minted by Ring 1 services; producers supply
observation data, not authority claims. Per registry v0.3.2
§Authority discipline:

- `Evidence.authority` is set by the kernel/mint API based on the
  producer's `ExecutionContext`.
- Authority-class fields (`captured_by`, `observed_via`) are
  removed from producer payloads. Kernel-set only.
- Operational claims that are not authority-class
  (`termination_reason`, `capture_status`, `mode`) may remain
  producer-asserted but must be kernel-verifiable via separate
  evidence.

Cross-context binding rejection lives at the three Ring 1 layers
named in registry v0.3.2 §Cross-context enforcement layer (mint API
+ broker FSM re-check + gateway re-derive); schema validation is
not an enforcement layer.

**Mint-rejected `Decision` records participate in the audit hash
chain** per registry v0.3.2 §Audit-chain coverage of rejections.
When the mint API, broker FSM, or gateway rejects a payload
submission for any of the three receipts, the rejection produces a
typed `Decision` that is committed to the audit hash chain with
`rejecting_layer` and `rejection_class` discriminators. Audit-chain
coverage of rejections is a Ring 1 invariant inherited from the
registry; this ADR does not opt out and does not need to re-name
the requirement per-receipt.

### `ToolInvocationReceipt`

A typed `Evidence` record using `evidenceSchema` from ADR 0023
directly, with:

- `evidence_kind: "receipt"` (positive existence of an invocation
  event).
- `subject_refs` includes:
  - `{subject_kind: "tool_invocation", subject_id: <invocation_id>}`
    (subject kind to be added to the evidence-subject enum at
    schema implementation time);
  - `{subject_kind: "execution_context", subject_id: <ctx_id>,
    relation: "ran_in"}`;
  - `{subject_kind: "resolved_tool", subject_id: <tool_id>,
    relation: "invoked"}`;
  - `{subject_kind: "tool_invocation", subject_id: <parent_id>,
    relation: "parent"}` (optional; present when this invocation
    is nested under another).
- `payload_schema_version: "tool_invocation_receipt:v1"` (canonical
  exact value to be set when schema implementation lands).
- `payload` shape (candidate field block):

```text
invocation_id
resolved_tool_id
execution_context_id
argv_capture_mode      enum: none | redacted | classified | reference_only | mixed
argv                   optional   // present only when argv_capture_mode = none
                                  // AND the resolved_tool's argv contract is
                                  // declared secret-free at the producer-attestation layer
argv_redacted          optional   // present when argv_capture_mode = redacted
argv_summary           optional   // free-form classification when argv_capture_mode = classified
start_time
end_time               nullable   // null if invocation interrupted before completion
exit_code              nullable   // null if no exit observed
termination_reason     enum: normal | interrupted | timeout | killed | unknown
```

Note: `parent_invocation_id` was a flat payload field in revision 1.
Per registry v0.2.1 §Field-name suffixes and ontology-reviewer B2,
parent linkage now lives in `subject_refs`
(`subject_kind: "tool_invocation", relation: "parent"`).

**`argv_capture_mode` rename.** Renamed from revision 1's
`argv_redaction_mode` per registry v0.3.2 §Redaction posture (capture
mode is orthogonal to persistence redaction; the base
`Evidence.redaction_mode` remains canonical for persisted-payload
sanitization).

**`argv_capture_mode = none` producer attestation.** Per security
review B1, `argv_capture_mode = none` is permitted only when the
producer attests that the resolved tool's argv contract is
secret-free. Tool-resolution evidence (a `ResolvedTool` reference
with a declared "argv contract: secret-free" classification) is
required for the mint API to accept `argv_capture_mode = none`.
Tools known to accept secret-bearing argv (`gh auth login --with-token`,
`curl -H "Authorization: Bearer ..."`, `op signin --raw`,
`mysql -p<password>`, etc.) must default to `redacted` or
`classified`. The `ResolvedTool`-side declaration of argv-contract
class is queued for stage-2 ontology work.

**Audit-integrity posture for failed/interrupted invocations.** Per
security review B5, every initiated invocation produces a
`ToolInvocationReceipt`, including failed and interrupted
invocations. `end_time: null` and `termination_reason: interrupted |
killed | unknown` are valid receipt shapes; absence of a receipt is
itself an audit-integrity violation, not silent acceptable behavior.
The mint API requires producers to emit a closing receipt before
session-end; broker FSM enforces.

**Producer-crash kernel watchdog** (per security review B-S2 / B-S6;
v4 names the kernel facility). When the producer process exits
without emitting a closing `ToolInvocationReceipt` (e.g., SIGKILL,
OOM, segfault), the broker FSM emits a synthetic
`ToolInvocationReceipt` on the producer's behalf. The synthetic
receipt carries:

- `end_time: <process_exit_observed_at>` (kernel-observed),
- `exit_code: <observed_or_null>`,
- `termination_reason: killed` (when signal-terminated by the
  kernel) or `unknown` (when the kernel cannot classify),
- `Evidence.authority: host-observation` (the broker is
  host-trusted),
- `Evidence.producer: kernel_broker` (kernel-set per registry v0.3.2
  §Producer-vs-kernel-set authority fields; producer-supplied
  `producer: "kernel_broker"` values are rejected at the mint API).

**Kernel facility for exit observation.** On macOS, the broker FSM's
process-exit observation source is `kqueue` `EVFILT_PROC` with the
`NOTE_EXIT` flag (returns the exit status when the watched pid
terminates). This is the canonical macOS kernel facility for
process-exit events; it produces `host-observation` authority because
the kernel is the trusted source. Producer-asserted exit (a wrapper
script claiming "the child crashed") is not acceptable as a
watchdog source; that path produces `self-asserted` authority and
cannot satisfy the synthetic receipt's `host-observation`
requirement. Linux and Windows host ports (post-Phase-1) use
the equivalent kernel facilities; the binding rule is "kernel-trusted
exit telemetry," not the macOS-specific API name.

**Watchdog exec-path coverage scope** (per architect review N2). The
broker FSM's watchdog covers exec paths the broker spawned or
supervises:

- broker-spawned children (broker is the parent process);
- broker-supervised processes via launchd handle (the broker holds
  the launchd job reference);
- MCP-server-spawned children whose lifecycle the broker proxies (the
  broker is the parent of the MCP transport process and observes
  child exit through it).

Exec paths the broker FSM cannot observe directly:

- agent-harness-spawned tool calls (the agent is the parent; the
  broker doesn't see exit). These rely on the agent harness emitting
  the closing `ToolInvocationReceipt` before session-end; the mint
  API's session-close enforcement is the binding mechanism (every
  initiated invocation must close, OR the session itself fails to
  close cleanly and the close-time pairing check rejects the
  session).
- daemon-spawned children that escape the agent's process tree (rare;
  out of scope for Phase 1 broker work; future ADR if a class of
  failure surfaces).

The watchdog mechanism + agent-harness session-close pairing +
daemon-out-of-scope deferral together cover the audit-integrity
surface for Phase 1.

The synthetic receipt is composed at the Ring 1 broker FSM, not at
the agent harness. An attacker that crashes a broker-mediated
producer cannot suppress receipt emission; the kernel watchdog
ensures every broker-mediated invocation produces a receipt, even
when the producer is not in a position to emit one.

### Scrubber coverage

Per registry v0.3.2 §Field-level scrubber rule, every string-typed
payload field on this ADR's three receipts passes the secret-shape
scrubber when `Evidence.redaction_mode != none`. The covered fields
are:

- **`ToolInvocationReceipt`**: `argv` (scrubbed), `argv_redacted`
  (scrubbed; double-redaction is intentional — capture-time redaction
  may have missed something the persistence-time scrubber catches),
  `argv_summary` (scrubbed). Enum-typed fields (`argv_capture_mode`,
  `termination_reason`) are exempt.
- **`CommandCaptureReceipt`**: `stdout_redacted_excerpt` (scrubbed),
  `stderr_redacted_excerpt` (scrubbed). Enum-typed and count-typed
  fields (`capture_status`, `truncation_reason`,
  `capture_failure_reason`, `stdout_byte_count`, `stderr_byte_count`)
  are exempt.
- **`ExecutionModeObservation`**: no string-typed scrubber-covered
  fields; `escalation_kind` is enum-typed; `privileged_capabilities`
  is an array of classified or hashed identifiers (already
  pre-classified per security review N2); `isolated_image_ref` is a
  classification value (`internal | external | unknown`) per
  security review N3.

The scrubber implementation itself (regex / entropy-shape /
known-secret-format heuristics) is canonical-policy-driven and lands
with the schema implementation PR; the field-list declaration above
is binding from this ADR's acceptance.

**Cross-context binding rules** (per registry v0.3.2
§Cross-context enforcement layer):

- The receipt's `execution_context_id` must match the producer's
  resolved `ExecutionContext` (mint-API rejection on mismatch).
- The `parent_invocation_id` in `subject_refs`, if present, must
  resolve to a `ToolInvocationReceipt` whose `execution_context_id`
  matches OR has typed inheritance evidence per charter v1.3.2 wave-3
  parent-context-inheritance forbidden pattern. Same-execution-context
  is the default; cross-context parent linkage requires typed
  evidence.

### `CommandCaptureReceipt`

A typed `Evidence` record using `evidenceSchema` directly, with:

- `evidence_kind: "receipt"` (positive existence of a capture event,
  including positive-empty captures per registry §Naming suffix
  discipline §Sub-rule 2).
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
stderr_redacted_excerpt optional   // same
truncation_reason      optional   // present when capture_status = truncated
capture_failure_reason optional   // present when capture_status = failed
                                  // values: pty_unavailable | redirection_failed |
                                  //         streaming_disconnected | sandbox_blocked |
                                  //         observer_crash | unknown
captured_at
```

Note: `captured_by` (kernel_broker / agent_harness / sandbox_marker)
was a flat payload field in revision 1. Per registry v0.3.2
§Producer-vs-kernel-set authority fields, the producer-context
source is kernel-set at the Evidence base via `Evidence.producer`,
not in payload.

**`capture_status: empty` semantics** (unchanged from v1, but worth
restating). A positive empty-capture receipt: the invocation
produced literally zero bytes of output. An invocation whose capture
status is unknown produces no `CommandCaptureReceipt`; an invocation
that produced empty output produces a `CommandCaptureReceipt` with
`capture_status: empty`. Per registry §Naming suffix discipline
§Sub-rule 2, this is the canonical positive-absence pattern. Closes
the ScopeCam motivating failure at the receipt-shape layer.

**Capture-status × redaction-mode matrix** (per architect review B2).
The Evidence base `redaction_mode` field is canonical for persisted-
payload sanitization. Permitted combinations:

| `capture_status` | Permitted `redaction_mode` values | Notes |
|---|---|---|
| `full` | `none`, `redacted`, `classified`, `hash_only`, `reference_only`, `mixed` | Captured payload available for any persistence treatment |
| `partial` | `none`, `redacted`, `classified`, `hash_only`, `reference_only`, `mixed` | Excerpts present in payload; redaction at persistence layer |
| `empty` | `none` only | Empty capture has no content to redact; `redaction_mode: redacted` would be misleading |
| `redacted` | `redacted`, `classified`, `hash_only`, `reference_only`, `mixed` | Capture-time redaction already applied; persistence layer may further redact |
| `truncated` | `none`, `redacted`, `classified`, `hash_only`, `reference_only`, `mixed` | Truncation orthogonal to redaction |
| `failed` | `none` only | No content captured; `redaction_mode: redacted` would be misleading |

Producer payloads with mismatched `capture_status` × `redaction_mode`
combinations are rejected at the mint API.

**Excerpt length bounds** (per security review B-S4 + v1 N1).
`stdout_redacted_excerpt` and `stderr_redacted_excerpt` are bounded
at the ADR-acceptance layer at **`<= 1024 bytes` per excerpt**.
Producers MUST truncate at this boundary at capture time; mint API
rejects payloads with longer excerpts. The 1024-byte cap is large
enough to give debugging context (a few lines of output) and small
enough that a high-entropy needle has limited room to hide. The
entropy-shape post-filter (which scans the truncated excerpt for
secret-shaped content even after the producer's redactor ran) is
canonical-policy-driven and lands with the schema implementation
PR; the byte cap is binding from this ADR's acceptance.

**Cross-context binding rules.** A `CommandCaptureReceipt` whose
parent `tool_invocation` reference resolves to an invocation in a
different `execution_context_id` fails composition at the mint API
(registry v0.3.2 §Cross-context enforcement layer layer 1).

### `ExecutionModeObservation`

A typed `Evidence` record using `evidenceSchema` directly. Per
ontology review B3, `evidence_kind` selection depends on whether the
mode is observed via real telemetry or self-asserted:

- `evidence_kind: "observation"` when the mode is observed via
  kernel telemetry, sandbox marker, or host telemetry.
- `evidence_kind: "derived"` when the mode is computed from other
  evidence records (e.g., derived from a `CommandCaptureReceipt` plus
  an `ExecutionContext` reference).

`subject_refs` includes:

- `{subject_kind: "execution_context", subject_id: <ctx_id>}`;
- `{subject_kind: "tool_invocation", subject_id: <invocation_id>,
  relation: "mode_for"}` (optional).

`payload_schema_version: "execution_mode_observation:v1"`.

`payload` shape (candidate field block):

```text
execution_context_id
invocation_id          optional
mode                   enum: normal | sandboxed | escalated |
                              isolated_clean_room | unknown
escalation_kind        optional   // present when mode = escalated
                                  // values: privileged_user | broker_grant |
                                  //         capability_marker | unknown
privileged_capabilities array     // optional, classified or hashed (not raw names)
isolated_image_ref     optional   // classification: internal | external | unknown
                                  // raw ref omitted to avoid deployment-topology leak
```

Note: `observed_via` (kernel_observation / sandbox_marker /
host_telemetry / self_assertion) was a flat payload field in revision
1. Per registry v0.3.2 §Producer-vs-kernel-set authority fields,
this is **kernel-set** on the `Evidence` base via `Evidence.authority`
and `Evidence.producer`, not in payload.

**Authority handling.** Per registry v0.3.2 §Authority discipline,
the kernel/mint API resolves `Evidence.authority` from the producer's
`ExecutionContext` and the means of mode resolution:

- Kernel telemetry source → `host-observation` authority (kernel is
  host-trusted).
- Sandbox-marker source → `sandbox-observation` authority. The mode
  value `sandboxed` (renamed from v2's `sandbox_observation` to break
  the lexical near-collision with the `sandbox-observation` authority
  class per ontology review) names the runtime posture; the
  authority class is derived independently from `observed_via` and
  `Evidence.producer`, not from `mode`.
- Host telemetry source → `host-observation` if the telemetry source
  is verified; `sandbox-observation` if observed inside a sandbox.
- Producer self-assertion (no telemetry backing) → `self-asserted`
  authority per registry v0.3.2 §Self-assertion authority class.
  Cannot be promoted; the evidence record's authority is below
  `sandbox-observation`.

**Privileged-capability redaction posture.** Per security review N2,
the `privileged_capabilities` array carries classified or hashed
capability identifiers, not raw names. Listing capability names
verbatim would let an audit reader enumerate the producer's
attack-surface metadata. The classification scheme (which
capabilities map to which classes) lands with the schema
implementation PR.

**`isolated_image_ref` redaction.** Per security review N3, the
`isolated_image_ref` field carries a classification value
(`internal | external | unknown`) rather than the raw image
reference. Raw refs (registry hosts, repository paths, tags) are
deployment-topology-leak risks for audit readers; the
classification is sufficient for gateway decisions.

**Cross-context binding rules.** An `ExecutionModeObservation` whose
`subject_refs` parent_invocation reference resolves to an invocation
in a different `execution_context_id` fails composition at the mint
API. Self-assertion observations cannot satisfy a downstream
operation that requires `host-observation` authority for the same
context (per inv. 8 promotion rejection).

**`mode: unknown` gateway behavior** (per security review A4 + v3
analogue to ADR 0027 v2's `ref_state: unknown` BLOCK rule). The
gateway's interpretation of `mode` values:

- `normal`: gateway proceeds for operations whose policy allows
  normal-mode execution.
- `sandboxed`: gateway proceeds only when the operation's
  `mutation_scope` is compatible with sandbox-bounded execution; per
  inv. 8 sandbox observations cannot promote to host-authority for
  forbidden-tier or high-mutation-scope operations.
- `escalated`: gateway requires the matching `ApprovalGrant` for the
  named `escalation_kind`.
- `isolated_clean_room`: gateway proceeds for operations declared
  isolation-acceptable in their capability manifest.
- `unknown`: gateway BLOCKS the operation. Mode cannot be
  proven; observations carrying `mode: unknown` cannot satisfy mode-
  conditioned policy.

For **mode-agnostic operations** (operations whose policy does not
name an expected mode at all): the gateway does not consult mode.
Mode is not a precondition for these operations. Per inv. 6,
forbidden-tier operations remain non-escalable regardless of mode;
mode-agnostic does not relax the forbidden-tier rule.

**Cross-context parent-invocation typed inheritance evidence** (per
security review A5 + charter v1.3.2 wave-3). When a child
invocation's parent_invocation reference resolves to an invocation
in a different `execution_context_id`, the cross-context parent
linkage requires typed evidence: a candidate
`ContextInheritanceReceipt` (queued for stage-2 ontology work)
that asserts the named target context inherits a specific dimension
(env, sandbox scope, credential authority, etc.) from the parent
context, with `Evidence.authority: host-observation` (the kernel is
the only producer that can authoritatively assert cross-context
inheritance). The receipt's name uses the `*Receipt` suffix per
registry v0.3.1 §Sub-rule 7 / §Entity-name suffixes — inheritance
is a positive-existence claim about a typed binding, not a
freshness-bound observation. The kernel's authority source for the
assertion is the same kernel facility that observes `ExecutionContext`
identity (e.g., on macOS, launchd job binding plus process-lineage
telemetry); the binding receipt is queued for stage-2 ontology where
the kernel facility is named explicitly.

Sandbox-context children that reference host-context parents without
a `ContextInheritanceReceipt` covering the asserted dimension fail
composition. Per registry v0.3.2 §Cross-context enforcement layer,
the rejection happens at all three Ring 1 layers: layer 1 (mint API)
rejects at binding time, layer 2 (broker FSM) re-checks at execution
time (since execution-context inheritance can become invalid between
mint and execution if the parent context terminates or its
inheritance binding revokes), and layer 3 (gateway) re-derives at
decision time. The named subtype `ContextInheritanceReceipt` is the
authority anchor for inv. 17's "intentional inheritance" carve-out.

### Cross-receipt composition

- A `CommandCaptureReceipt` references its parent invocation via
  `subject_refs[subject_kind="tool_invocation",
  relation="capture_for"]`. The parent must resolve to a
  `ToolInvocationReceipt` with the same `execution_context_id`.
  Cross-context capture references fail at the mint API.
- An `ExecutionModeObservation` may reference a specific invocation
  via `subject_refs[subject_kind="tool_invocation",
  relation="mode_for"]`. When present, the parent must have a
  matching `execution_context_id`.
- A `ToolInvocationReceipt` may reference a parent invocation via
  `subject_refs[subject_kind="tool_invocation", relation="parent"]`
  (replacing v1's flat `parent_invocation_id` field per ontology
  review B2). Same-execution-context binding required by default;
  cross-context parent linkage requires typed inheritance evidence
  per charter v1.3.2 wave-3.

### Out of scope

This ADR does not authorize:

- Schema source (Zod, generated JSON Schema, tests, fixtures).
- Q-008(b) anomalous-command-capture blocking thresholds (separate
  sub-decision; pending).
- Q-008(d) worktree-ownership composition (gated on Q-003).
- Adding `tool_invocation` to the evidence-subject enum in
  `packages/schemas/src/entities/evidence.ts`. That schema enum
  update lands with the schema implementation PR.
- Adding `self-asserted` to `evidenceAuthoritySchema` (separate
  schema-change PR; registry v0.3.2 records the rule).
- Kernel broker semantics for `installed-runtime` authority on
  `ToolInvocationReceipt`. Anticipated future authority but not
  current posture; broker lands later.
- Mutating execution endpoints. Inv. 7 still gates these.
- Setting canonical excerpt byte caps or capability-name
  classification schemes (canonical-policy-driven; schema
  implementation PR).
- MCP / Codex / Claude protocol-specific receipt shapes; the three
  receipts here are protocol-agnostic.

## Consequences

### Accepts

- All three subtypes are committed by name and shape. Q-008(a) is
  settled at the design layer.
- All three use `evidenceSchema` directly as typed payloads (Q-011
  bucket 1).
- Authority-class fields (`captured_by`, `observed_via`) are removed
  from producer payloads; kernel-set per registry v0.3.2
  §Producer-vs-kernel-set authority fields.
- Self-assertion observations carry `self-asserted` authority per
  registry v0.3.2 §Self-assertion authority class; cannot be
  promoted; cannot satisfy host-observation gateway requirements.
- `evidence_kind` for `ExecutionModeObservation` is `observation`
  for telemetry-backed observations and `derived` for self-asserted
  / computed observations (closes architect B1 and ontology B3 kind/
  authority overload).
- `argv_redaction_mode` renamed to `argv_capture_mode` per registry
  v0.3.2 §Redaction posture (originally v0.3.0); capture-mode is
  orthogonal to persistence-redaction.
- `argv_capture_mode = none` requires producer attestation that the
  resolved tool's argv contract is secret-free; tools accepting
  secret-bearing argv default to `redacted` or `classified`.
- `parent_invocation_id` moved from flat payload field to
  `subject_refs[subject_kind="tool_invocation", relation="parent"]`
  per registry v0.2.1 §Field-name suffixes.
- `CommandCaptureReceipt.capture_status: empty` is the typed positive
  empty-capture receipt closing the ScopeCam motivating failure at
  the receipt-shape layer.
- Capture-status × redaction-mode matrix is explicit; the mint API
  rejects mismatched combinations.
- Excerpt length bounds and privileged-capability classification
  posture are recorded; canonical specifics land with schema
  implementation PR.
- Failed/interrupted invocations are required to emit
  `ToolInvocationReceipt` records; absence is an audit-integrity
  violation enforced by the mint API and broker FSM.
- Cross-context binding rejection lives at registry v0.3.2
  §Cross-context enforcement layer's three Ring 1 layers (mint API
  + broker FSM re-check + gateway re-derive).

### Rejects

- Treating no-output / empty-stdout / silent-exit-zero as evidence
  about the world (the ScopeCam failure mode).
- Subtyping `Run` for `ToolInvocationReceipt` (Option C); `Run` is
  reserved for broker-executed approved operations.
- Subtyping `Artifact` for `CommandCaptureReceipt` (Option C);
  artifacts are output products, not capture-process records.
- Producer-supplied authority-class fields (`captured_by`,
  `observed_via`) in any of the three payloads.
- Mapping `self_assertion` execution-mode observations to `derived`
  authority — `self-asserted` is the correct class per registry
  v0.3.2 §Self-assertion authority class (originally v0.3.0).
- `argv_capture_mode = none` without producer attestation that the
  tool's argv contract is secret-free.
- Cross-context capture / mode references (capture-from-A applied-
  to-B; mode-from-A applied-to-B).
- Cross-context parent_invocation chains without typed inheritance
  evidence.
- Kernel-brokered authority on agent-side receipts before the
  broker lands.
- Empty `pr_state_evidence_refs`-style absence-as-missing-field
  semantics; positive empty-capture is an explicit
  `capture_status: empty` value, not absence of a receipt.
- Silent omission of failed-invocation receipts; absence is an
  audit-integrity violation.
- Raw capability names in `privileged_capabilities`; raw image refs
  in `isolated_image_ref`. Both leak deployment metadata.
- Schema-layer cross-context binding enforcement; binding lives at
  Ring 1 (registry v0.3.2).

### Future amendments

- Schema implementation PR (separate, post-acceptance) adds
  `tool_invocation` to the evidence-subject enum; introduces three
  payload schema families; updates ontology.md; lands tests and
  fixtures.
- Schema-change PR for `evidenceAuthoritySchema` adding
  `self-asserted` (separate from this ADR; landing path noted in
  registry v0.3.2).
- Q-008(b) anomalous-command-capture blocking thresholds: a follow-
  up ADR will name which `capture_status` / `termination_reason` /
  `mode` combinations block which downstream operations.
- Q-008(d) worktree-ownership composition: gated on Q-003 settling.
- Capability-classification scheme for `privileged_capabilities`
  (canonical-policy-driven).
- Excerpt byte cap and entropy-shape post-filter rules
  (canonical-policy-driven).
- ResolvedTool-side argv-contract declaration ("secret-free" vs
  "may-bear-secrets") for `argv_capture_mode = none` attestation
  (stage-2 ontology work).
- Reopen if Q-003 coordination facts reframe
  `ExecutionModeObservation` as a coordination fact rather than
  evidence.
- Reopen if Q-005 runner work introduces remote-runner invocation
  semantics that need a distinct receipt shape.

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md` v1.3.2,
  invariants 1, 4, 5, 7, 8, 16, 17 (and v1.3.2 wave-3 forbidden
  patterns)
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.2
  (codified suffix discipline including `_kind` and `_mode` rules;
  version-field naming; authority discipline including
  self-assertion authority class and `Evidence.producer` kernel-only
  allowlist; cross-context enforcement layer with layer-disagreement
  tiebreaker and rejection-audit coverage; redaction posture with
  field-level scrubber rule and capture-status × redaction-mode
  matrix)
- Decision ledger: `DECISIONS.md` Q-003, Q-008
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract used for all three subtypes;
  evidenceAuthoritySchema; evidenceKindSchema; redaction_mode)
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
  (parallel-track ADR; `GitRemoteObservation.last_fetch_outcome` is
  kernel-verified via the receipts in this ADR)
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- Ontology promotion/dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- 2026-05-02 system-config security audit evidence:
  `docs/host-capability-substrate/research/local/2026-05-02-system-config-security-audit-evidence.md`

### External

- POSIX `wait` / exit-code semantics:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/wait.html>
- IEEE Std 1003.1 process termination:
  <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html>
- macOS Seatbelt / sandbox-exec documentation (Apple Open Source).
