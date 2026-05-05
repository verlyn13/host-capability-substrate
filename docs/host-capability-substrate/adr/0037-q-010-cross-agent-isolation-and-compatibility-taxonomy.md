---
adr_number: 0037
title: Q-010 cross-agent isolation and compatibility taxonomy
status: proposed
date: 2026-05-04
charter_version: 1.3.2
tags: [agent-client, containment, remote-agent, compatibility-taxonomy, q-010, phase-1]
---

# ADR 0037: Q-010 cross-agent isolation and compatibility taxonomy

## Status

proposed (v2)

## Date

2026-05-04 (v1); 2026-05-04 (v2 — closes 5 reviewer blockers
across architect / ontology; folds 9 mechanical tweaks)

## Revision history

- **v1 (2026-05-04)**: initial draft per user-approved A3 + B3 +
  C2 + D2 + E-ratify recommendation with all precision
  commitments folded.
- **v2 (2026-05-04)**: closes architect B1 (off-by-one count
  "Five new" vs six listed reason_kinds) + B2 (`kernel_sandbox_kind`
  cache cannot distinguish "uncontained" from "non-kernel-
  contained" — renamed to `kernel_sandbox_kind`); ontology B-5
  (`containment_runtime_capability_exceeded` verb-form renamed
  to `containment_runtime_capability_exceeded`) + B-7 (cross-
  enum value collision `terminal_no_isolation` /
  `ide_host_isolation` between `containment_kind` runtime-class
  and `containment_mechanism` capability-class — capability
  enum normalized to all-`_capable` form, closing B-6
  heterogeneity simultaneously) + B-1 (absence-naming
  `none_required` rationale documented in §Authority
  discipline). Folded mechanical tweaks: polymorphic FK
  clarification on `*_evidence_ref` fields; AgentClient audit-
  chain participation field; ±5 min binder secure-default
  rationale; regression trap candidates #32-#36 added to
  §Future amendments (fixture-numbering deferred to fixture-
  landing PR per policy NB-5). Zero policy blockers, zero
  security blockers in v1; the 5 v1 blockers were ontology /
  architect naming-discipline + cache-field-ambiguity items.

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Context

Q-010 settles cross-agent isolation and compatibility taxonomy.
The 2026-05-01 agentic coding tool isolation synthesis
(`docs/host-capability-substrate/research/local/2026-05-01-agentic-tool-isolation-synthesis.md`)
ingested a broad survey of agentic coding products (Claude Code
CLI/Desktop/IDE, Codex CLI/app/IDE, Cursor, Copilot incl. cloud
agent, Devin, Windsurf, Augment/Auggie, Amp, OpenCode, Warp incl.
Oz, VS Code local agents). The brief's core lesson: permission
gating, worktree/file isolation, local kernel sandboxing, container
isolation, VM isolation, remote cloud execution, terminal
inheritance, and app-managed bundles are **separate evidence
dimensions**. Collapsing them into one "sandbox profile" string
loses the discrimination HCS needs.

The brief explicitly **rejects** as canonical HCS shape:
- vendor `SharedAgentPolicySchema` and per-vendor adapter schemas
  (adapters must not own policy facts);
- cross-tool false equivalence collapsed into one object;
- treating permission modes / worktrees / app settings as proof of
  OS containment.

Only the brief's containment vocabulary is queued for Ring 0
evidence reconciliation; nothing else is canonical until this ADR.

**Composition with prior precedent.** Most of Q-010 composes via
existing entities and rules — the primary novel work concentrates
on `AgentClient` as a Ring 0 entity (which today exists only as an
FK on `ExecutionContext` and as a `subject_kind` value).

- ADR 0022 commits `BoundaryObservation` as the envelope for all
  containment evidence; `containment_class` is reserved as the
  umbrella `boundary_dimension`. This ADR's Sub-decision (a)
  closes the Q-011(i) deferral inside that envelope (no ADR 0022
  amendment required).
- ADR 0027 v2 / ADR 0030 v2 commit Git observation receipts;
  remote-agent receipts compose via `evidence_ref` to those
  records (no commit_sha duplication).
- ADR 0028 v4 commits `Evidence.producer` kernel-trusted producer
  allowlist; this ADR adds a new producer class for the agent-
  client capability resolver.
- ADR 0029 v2 commits operation-class enumeration + closed-list
  fail-mode tightening rule + three-state matrix pattern.
- ADR 0031 v1 commits `(session, repository_id, worktree_path)`
  Lease grain pattern; `AgentClient` follows the same identity-
  grain discipline.
- ADR 0032 commits Q-005 runner evidence subtypes (six receipts);
  this ADR mirrors the multi-subtype split for remote-agent
  receipts.
- ADR 0033 v2 commits `StatusCheckSourceObservation` for source-
  app identity; PR-mediated cloud-agent runs compose via that
  record.
- ADR 0034 v2 commits `ToolProvenance` (kernel-set fields like
  `provider_observed_via`, `provider_verified_at`); `AgentClient`
  inherits the producer-vs-kernel-set authority discipline.
- ADR 0036 v2 commits closed-list fail-mode tightening rule
  comprehensive restatement and the `kernel_workspace_diagnose`
  producer class precedent for narrower kernel-trusted producers.

This ADR is doc-only and posture-only, mirroring ADR 0029 v2 / ADR
0030 v2 / ADR 0031 v1 / ADR 0032 v2 / ADR 0033 v2 / ADR 0034 v2 /
ADR 0035 v2 / ADR 0036 v2 acceptance pattern. It does not author
Zod schema source, canonical policy YAML, runtime probes, dashboard
route React components, MCP adapter contracts, or charter invariant
text.

Pre-draft sub-decisions approved by user (2026-05-04) per
research-grounded recommendations + precision commitments:

- (a) `ExecutionContext.sandbox` becomes a denormalized cache (A3-
  pointer): pointer-form `latest_containment_evidence_ref`
  (`evidenceRefSchema`) plus cached `kernel_sandbox_kind` for fast
  gateway lookup; authority class flips from producer-asserted to
  kernel-set; tiebreaker rule = latest-by-kernel-mint-time among
  non-stale observations sharing `boundary_dimension:
  containment_class`; new `Decision.reason_kind:
  containment_evidence_absent` for gate consumption when no
  observation exists; inv. 17 compliance argument committed
  inline (this is intentional typed inheritance, not inference).
- (b) `AgentClient` becomes a Ring 0 entity (B3-reference) with
  six axes; identity grain per-(`product_family`, `surface`,
  `app_build`) per D-029 baseline discipline; lifecycle
  `agent_client_state: active | retired`; per-axis authority
  matrix committed; composition with `ExecutionContext.sandbox`
  via narrower-wins rule (capability-class ↔ runtime-class).
- (c) Remote-agent environment evidence splits into three typed
  subtypes (C2-split): `RemoteAgentBaseImageObservation`,
  `RemoteAgentSetupReceipt` (carries `secret_injection_kind`
  discriminator), `RemoteAgentNetworkPostureObservation`. Source-
  app identity composes via existing `StatusCheckSourceObservation`
  (ADR 0033 v2); checkout commit composes via `evidence_ref` to
  `GitRepositoryObservation` (ADR 0027 v2); non-PR-mediated cloud-
  agent binding via `(execution_context_id, observed_at window)`
  for Phase 1 with `RemoteAgentInvocationReceipt` aggregator
  flagged for future amendment.
- (d) Surface enum gains ONE new value: `remote_cloud_agent`
  (D2). Specific cloud-agent products stay matrix-only entries in
  `tooling-surface-matrix.md`. inv. 17 cares about the local-vs-
  cloud structural divide; per-product specificity churns too
  fast for schema migration.
- (e) Re-baseline trigger ratifies existing precedent: containment
  evidence carries `valid_until`; re-baseline on observed_runtime
  change OR matching_changelog material change per D-026
  authority hierarchy + ADR 0022 registry rule 5; NO new
  `boundary_dimension: version_drift`. Canonical policy at
  Milestone 2 commits the per-dimension freshness windows
  (containment dimension needs hours-to-day window).

## Decision

### Sub-decision (a) — `ExecutionContext.sandbox` as denormalized cache (A3-pointer)

**Closes Q-011(i) deferral.** ADR 0022 reserved
`boundary_dimension: containment_class` as the umbrella for all
containment evidence; this ADR commits the payload shape and
binds `ExecutionContext` to it via a pointer + cached value.

**Field shape on `ExecutionContext`** (replaces the current shipped
`sandbox` block; preserves shipped enum for the cache):

- `latest_containment_evidence_ref` — `evidenceRefSchema` reference
  to the most recent `BoundaryObservation` of `boundary_dimension:
  containment_class` for this `execution_context_id` in `proven`
  state with non-expired `valid_until`. **Kernel-set; cannot be
  producer-supplied.**
- `kernel_sandbox_kind` — denormalized cached value from the resolved
  observation's payload; uses the existing shipped
  `sandboxProfileSchema` enum (`none | seatbelt | sandbox_exec |
  workspace_write | read_only | full_access | ide_host |
  unknown`) for kernel-sandbox-class observations only. The field
  is renamed from v1's `sandbox_kind` to `kernel_sandbox_kind` to
  disambiguate "no kernel sandbox in use" (the cache value `none`)
  from the broader containment classification (closes architect
  B2 from v1 review). For observations whose `containment_kind`
  is non-kernel-class (`container | vm | remote_cloud_sandbox |
  ide_host_isolation | terminal_no_isolation`),
  `kernel_sandbox_kind` reads `none` because no kernel-sandbox is
  in effect — but consumers MUST NOT interpret this as
  "uncontained." Consumers needing the broader containment
  classification dereference the pointer's resolved payload and
  read `containment_kind` directly. **Gateway re-derive consumers
  reading `kernel_sandbox_kind` only to make a kernel-sandbox-
  specific decision; consumers needing container/VM/remote-cloud
  containment dimension MUST read the resolved
  `BoundaryObservation` payload's `containment_kind` field.**
  **Kernel-set; populated at mint time from the pointer's
  resolved payload.**
- The pre-substrate flat `sandbox` block (profile + fs/network/
  keychain capability statuses) is retained for legacy reads
  during migration but is **read-only** post-A3 and is itself
  derived from `latest_containment_evidence_ref`.

**Authority class change.** Today `ExecutionContext.sandbox` is
producer-asserted (per v1.3.2 forbidden-pattern wording). Under
A3 it becomes **kernel-set** per registry v0.3.2 §Producer-vs-
kernel-set authority fields. The kernel reads from the latest
accepted `BoundaryObservation`. Producer-supplied sandbox values
are rejected at Layer 1 mint API with NEW `Decision.reason_kind:
containment_evidence_producer_supplied`.

**Tiebreaker rule.** Multiple `BoundaryObservation` records can
exist for one `execution_context_id` with different `observed_at`
and different mint times (out-of-order arrival, retry,
contradictory producers). The kernel resolves the active
observation by **latest-by-kernel-mint-time** among non-stale
observations (`valid_until` not yet passed) sharing
`boundary_dimension: containment_class`. Latest-by-`observed_at` is
**rejected** because producers can backdate. Mint-time ordering is
the kernel-controlled timestamp.

**Default state when no observation exists.** Gates consuming
`ExecutionContext.sandbox` (or equivalently
`latest_containment_evidence_ref`) when no `BoundaryObservation`
exists in `proven` state for the execution context reject with
NEW `Decision.reason_kind: containment_evidence_absent`. The
absence is treated as missing evidence (per ADR 0034 v2 boundary-
evidence stateness matrix); operations gated on containment
proceed only when typed evidence is present.

**`ContainmentObservation` payload shape on `BoundaryObservation`.**
Closes ADR 0022's open Q-010 dependency. Payload (illustrative;
schema PR commits):

- `containment_kind` — closed-enum discriminator: `none |
  kernel_sandbox | container | vm | remote_cloud_sandbox |
  ide_host_isolation | terminal_no_isolation`.
- `kernel_sandbox_profile` — applicable when `containment_kind:
  kernel_sandbox`; matches shipped `sandboxProfileSchema` enum.
- `container_runtime_kind` — applicable when `containment_kind:
  container`; closed enum (e.g., `docker | podman | nerdctl |
  orbstack | colima | unknown`).
- `vm_kind` — applicable when `containment_kind: vm`; closed enum.
- `remote_cloud_kind` — applicable when `containment_kind:
  remote_cloud_sandbox`; closed enum (e.g., `vendor_managed_vm |
  vendor_managed_container | self_hosted_runner_class |
  unknown`).
- `network_egress_posture` — closed enum: `none | restricted |
  open | unknown`.
- `filesystem_write_scope` — closed enum: `none |
  workspace_write | full_access | unknown`.
- `keychain_access` — closed enum: `none | tcc_scoped |
  app_managed_bundle | unknown`.

The `containment_kind` discriminator drives which sub-field
applies; flat-payload composition per ADR 0034 v2 / ADR 0036 v2
(no sibling-payload-block selection).

**inv. 17 compliance argument** (preempts ontology / security
reviewer). Charter v1.3.0 invariant 17 requires every operation
to declare its execution context; subprocesses do not inherit
parent sandbox / capability / env / credential scope without
typed evidence bound to the target context. A reviewer might
read auto-population from `BoundaryObservation` evidence as
inference (forbidden by inv. 17). It is not. A3-pointer is
**projection from typed evidence bound to the same
`execution_context_id`** — the `BoundaryObservation`'s primary
target ref is the same execution context the cache field reads
on. This is exactly the "intentional typed inheritance evidence
bound to the target execution context" pattern inv. 17
envisions; the cache is structurally identical to evaluating the
BoundaryObservation at read time, just with the lookup
materialized for fast gateway dispatch. The Layer 3 gateway re-
derive checks the pointer's freshness on every gate consumption;
stale pointers (where `valid_until` has passed) read as
`containment_evidence_absent` regardless of cached value.

**Cache invalidation rule.** A new `BoundaryObservation` of
`boundary_dimension: containment_class` minted for an
`execution_context_id` triggers an atomic update of
`latest_containment_evidence_ref` and `kernel_sandbox_kind` on the
execution context record. The update is kernel-driven; agents
cannot direct-write the cache. Concurrent mints serialize per
the existing Ring 1 atomic-insert TOCTOU pattern (per ADR 0031
v1 Lease pattern).

### Sub-decision (b) — `AgentClient` Ring 0 entity (B3-reference)

**Per Q-011 bucket 2** (no-suffix standalone Ring 0 entity with
durable identity and lifecycle, mirroring `WorkspaceContext` /
`HostProfile` / `ExecutionContext` / `Lease` precedents).

`AgentClient` exists today as an `agent_client_id` FK on
`ExecutionContext` and as an `agent_client` value in
`evidenceSubjectKindSchema`. This ADR commits the entity shape.

**Identity grain (per D-029 baseline discipline).** Identity tuple
is `(product_family, surface, app_build)`. A new `app_build` mints
a NEW `AgentClient` record; `agent_client_id` **never mutates in
place**. Old `AgentClient` records remain queryable for audit-
chain reconstruction; mutation-in-place would break audit-chain
hash continuity.

**Lifecycle.** `agent_client_state: "active" | "retired"` (bare-
noun central-concept discriminator per registry Sub-rule 8;
mirrors ADR 0031 v1 `lease_state` precedent). State transitions:

- `active` → `retired` when the AgentClient's `app_build` no
  longer matches observed runtime per D-026 authority hierarchy.
- Retired AgentClients stay queryable for audit-chain
  reconstruction; gates do not consume retired AgentClient
  evidence (per ADR 0034 v2 stale-evidence rule).

**Six axes with per-axis authority matrix:**

| Axis | Authority class | Source |
|---|---|---|
| `product_family` | kernel-set | resolved from launchd / process-tree observation |
| `surface` | kernel-set | matches the existing `surface` enum on `ExecutionContext` |
| `app_build` | kernel-set | observed runtime per D-026 authority hierarchy |
| `dep_bundle_version` | kernel-set | observed at launch time |
| `permission_mode` | producer-asserted, kernel-verifiable | the agent surface declares; kernel verifies against observed config |
| `containment_mechanism` | kernel-set | observed runtime; cannot be self-asserted per inv. 8 |

Producer attempts to mint an `AgentClient` with kernel-set fields
self-asserted reject at Layer 1 mint API with NEW
`Decision.reason_kind: agent_client_axis_self_asserted`.

**Field shape** (illustrative; schema PR commits):

- `agent_client_id` — primary key.
- `product_family` — closed enum: `claude_code | codex | cursor |
  copilot | devin | windsurf | augment | amp | opencode | warp |
  vscode_native | unknown`. Closed-list fail-mode tightens per
  ADR 0029 v2.
- `surface` — closed enum, shares values with
  `ExecutionContext.surface` (post-D2: 13 values including
  `remote_cloud_agent`).
- `app_build` — opaque string; `^[A-Za-z0-9._+-]+$` shape.
- `dep_bundle_version` — opaque string; `^[A-Za-z0-9._+-]+$` shape.
- `permission_mode` — closed enum: `default | yolo |
  approve_all | read_only | unknown`. Bound to product-family-
  specific verifier rules at Layer 1 mint (Codex `--yolo` differs
  from Claude Code `--dangerously-skip-permissions` differs from
  Cursor cloud auto-mode).
- `containment_mechanism` — closed enum, capability-class:
  `terminal_no_isolation_capable | ide_host_isolation_capable |
  app_managed_bundle_capable | kernel_sandbox_capable |
  container_capable | vm_capable | remote_cloud_managed_capable
  | unknown`. Names what containment the product *can* provide,
  not what a specific launch *currently has*. **All seven
  substantive values share the `_capable` suffix to disambiguate
  from `containment_kind` runtime-class values per registry
  cross-enum value-collision discipline (closes ontology B-7 +
  B-6 from v1 review).** The `unknown` sentinel value remains
  un-suffixed per registry convention.
- `agent_client_state` — `"active" | "retired"`.
- `kernel_observed_at` — kernel-set `observed_at` for the
  AgentClient observation (D-026 anchor).
- `valid_until` — derived from observation freshness window per
  canonical policy at Milestone 2 (containment dimension needs
  tighter window).
- `audit_chain_link_hash` — kernel-set hash linking the
  `AgentClient` record into the audit chain per charter inv. 4.
  Mirrors `Lease.audit_chain_link_hash` from ADR 0031 v1.
  Required for lifecycle entities so retirement transitions
  preserve audit-chain hash continuity. Retired AgentClients
  remain queryable via `agent_client_id` FK on Decision /
  Evidence / DerivedSummary records (per Sub-decision (b)
  §Lifecycle).

**Composition with `ExecutionContext.sandbox` via narrower-wins
rule.** The two records carry structurally different evidence:

- `AgentClient.containment_mechanism` is **capability-class
  evidence** — what containment this product *can* provide per
  its build / dep_bundle (e.g., "Codex CLI is `kernel_sandbox_capable`
  via Apple Sandbox; Claude Code with no flag is
  `terminal_no_isolation_capable`; Devin is
  `remote_cloud_managed_capable`").
- `ExecutionContext.sandbox` (now via
  `latest_containment_evidence_ref`) is **runtime-class
  evidence** — what containment this specific launch *is
  currently observed as having* (e.g., "Codex CLI launched with
  `--no-sandbox` reads as `containment_kind: none`; Codex CLI
  launched in default mode reads as `containment_kind:
  kernel_sandbox` with `kernel_sandbox_profile:
  workspace_write`").

**Composition rule (narrower-wins, closes the structural
attack-surface concern).** An operation's actual containment is
**whichever is narrower (more restrictive)**. A capable-of-
sandbox product launched with sandbox-disabled flags reads as
`none`, NOT as the product's default capability. Layer 3 gateway
re-derive at gate consumption MUST check both:

- the AgentClient.containment_mechanism (capability-class), and
- the latest BoundaryObservation of `boundary_dimension:
  containment_class` for the active execution_context_id
  (runtime-class, via `latest_containment_evidence_ref`).

The gate consumes the narrower of the two. Producers attempting
to gate on capability-class evidence alone (without runtime
observation) reject with `containment_evidence_absent`. Producers
attempting to claim runtime containment that exceeds the
AgentClient's capability-class (e.g., a `terminal_no_isolation_capable`-
capable product producing a runtime observation of
`containment_kind: kernel_sandbox`) reject at Layer 1 mint with
NEW `Decision.reason_kind:
containment_runtime_capability_exceeded`. Charter inv. 8
(sandbox-observation cannot be promoted) provides the structural
backstop; this rule is the explicit ontological enforcement.

**Audit-chain integration.** The kernel-set
`canonical_attribution_agent_client_id` field on Decision /
Evidence / DerivedSummary records per ADR 0019 v3 / ADR 0028 v4 /
ADR 0031 references the active `AgentClient` at mint time. A new
AgentClient mint for the same product/surface/build identity is
exceptional; mints occur at observed-runtime change.

**New kernel-trusted producer class:
`kernel_agent_client_resolver`** — resolves AgentClient axes from
launchd / process-tree / installed-binary observation. Registry
follow-up dependency; enumerated in §Out of scope.

### Sub-decision (c) — Remote-agent environment receipt split (C2-split)

Three typed `Evidence` subtypes mirror Q-005's six-receipt split
pattern (ADR 0032). Each subtype carries independent freshness
and composes via existing receipts where appropriate.

#### `RemoteAgentBaseImageObservation`

- **Subject**: the base image / runtime image of the remote
  cloud agent's execution environment.
- **Authority**: `derived` (per the cross-cutting Composition
  rule below — remote-agent-produced evidence cannot promote
  beyond `derived` against the host-authority ladder without a
  linked-observation chain through host-observation evidence).
- **Field shape** (illustrative): `base_image_kind: enum`,
  `base_image_digest: sha256-string`, `base_image_provenance:
  enum (vendor_managed | user_specified | unknown)`,
  `image_published_at: timestamp`,
  `vendor_observed_via_evidence_ref` (polymorphic FK per
  registry §Field-name suffixes Sub-rule 4 — resolves to one
  of: `StatusCheckSourceObservation` (ADR 0033 v2),
  `RemoteAgentEnvironmentControlPlaneReceipt` (future Q-row),
  or vendor-API observation kinds queued for stage-2; schema PR
  commits the closed polymorphic-target set).
- **Checkout commit** is NOT a payload field. It composes via
  `evidence_ref` to a `GitRepositoryObservation` (ADR 0027 v2);
  cross-receipt commit_sha duplication creates the drift class
  ADR 0030 v2 closed for source-control receipts.

#### `RemoteAgentSetupReceipt`

- **Subject**: the setup-script execution that prepared the
  remote agent's working environment.
- **Authority**: `derived` (same rationale).
- **Field shape** (illustrative): `setup_script_evidence_ref:
  evidenceRefSchema` (polymorphic FK per Sub-rule 4 — resolves
  to one of: a setup-script content observation,
  `GitRepositoryObservation` (ADR 0027 v2) when the script is
  repo-tracked, `ArtifactReceipt` (ADR 0028 v4) when the script
  is published, or `RawScriptObservation` (future Q-row);
  schema PR commits the closed polymorphic-target set),
  `setup_exit_code: int`, `setup_observed_at: timestamp`,
  `secret_injection_kind: enum`, `setup_duration_ms: int`,
  `setup_log_evidence_ref: evidenceRefSchema` (polymorphic FK
  per Sub-rule 4 — resolves to a separate Evidence record
  carrying log content with appropriate `redaction_mode`;
  field is by-construction a reference, not inline content).
- **`secret_injection_kind` discriminator** (closed enum):
  `env_at_setup | env_at_runtime | mounted_secret_volume |
  brokered_at_request | none_required`. Names the mechanism
  by which secrets reach the remote agent's runtime.
- **Secret-shape protection**: existing
  `Decision.reason_kind: secret_resolution_in_chunk` (ADR
  0019 v3) applies if `setup_log_evidence_ref` content
  contains resolved `op://` values or other resolved-secret
  shapes. Re-use, do not duplicate.

#### `RemoteAgentNetworkPostureObservation`

- **Subject**: the network egress / firewall posture of the
  remote cloud agent's execution environment.
- **Authority**: `derived` (same rationale).
- **Field shape** (illustrative): `egress_kind: enum (none |
  allowlist_only | proxy_mediated | open | unknown)`,
  `firewall_kind: enum`, `egress_observed_via_evidence_ref`
  (polymorphic FK per Sub-rule 4 — resolves to a vendor API
  observation or status receipt; schema PR commits the closed
  polymorphic-target set), `network_posture_observed_at:
  timestamp`.

**Source-app identity composition.** PR-mediated cloud-agent
runs (Copilot cloud when PR-driven, Codex cloud when PR-driven,
Devin via PR) compose with `StatusCheckSourceObservation` (ADR
0033 v2) via `evidence_ref`. The three remote-agent subtypes
above describe environment evidence; `StatusCheckSourceObservation`
describes who-ran-the-check identity. Both are required for full
PR-mediated remote-agent provenance.

**Non-PR-mediated cloud-agent binding rule** (closes the brief's
gap for Devin chat sessions, Cursor cloud agents in self-hosted
no-PR mode, Codex cloud tasks invoked via the Codex app outside
PR flow, Claude Code on the Web automation when not PR-driven).
For Phase 1, the three subtypes bind to a specific cloud-agent
invocation via `(execution_context_id, observed_at_window)`:

- All three subtypes share the same `execution_context_id` (the
  ExecutionContext record corresponding to the remote-agent
  invocation, per Sub-decision (d)'s `remote_cloud_agent`
  surface enum value).
- Their `observed_at` timestamps fall within a kernel-defined
  window (canonical policy at Milestone 2 commits the window
  duration; default Phase 1 posture: ±5 minutes from the
  earliest observation in the binding set). **Defense-in-depth
  rationale**: the binding window is bounded by TWO independent
  dimensions, not by the window duration alone — (i) all three
  subtypes must share the same kernel-resolved
  `execution_context_id` (the `kernel_agent_client_resolver`-
  resolved value cannot be self-asserted by producers), AND
  (ii) all three `observed_at` values must fall within the
  freshness window. A racing producer cannot bypass the binding
  by clustering subtype mints because the
  `execution_context_id` constraint forces them onto the same
  kernel-resolved invocation; producers cannot fork the
  invocation. The ±5 minute Phase 1 default is the canonical-
  policy-deferred number; security adequacy is documented at
  the canonical policy commit per security NB-1.
- Layer 3 gateway re-derive treats partial bindings (only one or
  two of the three subtypes present) as missing evidence; gate
  consumption rejects with NEW `Decision.reason_kind:
  non_pr_remote_agent_binding_partial` until all three are
  present in the binding window.

**Future amendment**: if a future incident shows
`(execution_context_id, observed_at_window)` binding fails
(e.g., long-running cloud agents with environment changes
mid-invocation, or cloud-agent invocations that don't naturally
share a single ExecutionContext), reopen with a
`RemoteAgentInvocationReceipt` aggregator entity (mirroring
Q-005's `WorkflowRunReceipt` aggregator pattern) that ties the
three subtypes via explicit `evidence_refs`. This is queued in
§Future amendments.

### Sub-decision (d) — Surface enum: `remote_cloud_agent` (D2)

The `surface` enum on `ExecutionContext` (currently 12 shipped
values: `codex_cli | codex_app_sandboxed | codex_ide_ext |
claude_code_cli | claude_desktop | claude_code_ide_ext |
zed_external_agent | warp_terminal | mcp_server | setup_script |
app_integrated_terminal | unknown`) gains ONE new value:

- **`remote_cloud_agent`** — umbrella value for all remote
  cloud-agent execution contexts (Copilot cloud agent, Codex
  cloud, Devin, Cursor cloud, Claude Code on the Web, Augment
  cloud, etc.). Specific cloud-agent products are
  distinguished via `AgentClient.product_family` (per Sub-
  decision (b)) and `AgentClient.surface` (which carries the
  same `remote_cloud_agent` value), not via per-product surface
  enum entries.

**Closed enum extension**: 12 → 13 values. Registry update PR
is precondition for the schema PR; standard sequencing per the
Predicate-kind reservation precedent from ADR 0019 v3. No new
field; the enum is extended in place.

**inv. 17 rationale.** The enum addition reflects what inv. 17
actually cares about: the local-vs-cloud structural divide,
because execution-context inheritance is fundamentally different
across that boundary (host has direct kernel observation locally;
remote-cloud is observed only via vendor-provider APIs and
returns `derived` authority). Per-product specificity churns too
fast for schema migration (a new agentic coding product appearing
quarterly is a typical baseline).

**Specific products stay matrix-only.** Cursor (CLI + cloud),
Copilot (CLI + cloud agent), Devin, Windsurf, Augment / Auggie,
Amp, OpenCode, Warp Oz, VS Code local agents — none gets a per-
product surface enum entry from this ADR. They are tracked as
entries in `tooling-surface-matrix.md` until first-party
engagement proves out a need for per-product schema typing.
First-class addition criteria for a future ADR: HCS has at
least one accepted Receipt subtype that distinguishes the
specific product, and the matrix entry has accumulated material
incident history that schema-typing would close.

### Sub-decision (e) — Re-baseline trigger (E-ratify)

Pure ratification of existing precedent.

- **Containment evidence carries `valid_until`** per ADR 0022
  envelope.
- **Re-baseline trigger** = observed_runtime version change OR
  matching_changelog material change per D-026 authority
  hierarchy. New `BoundaryObservation` mints when re-baseline
  fires; the cache pointer (Sub-decision (a)) updates atomically.
- **NO new `boundary_dimension: version_drift`**. Per ADR 0022
  registry rule 5: version / build / dependency drift is freshness
  signal, NOT a `boundary_dimension`. Existing dimensions
  (`containment_class`, `bundle_identity`, `tcc`,
  `mcp_authorization`) carry their own freshness windows.
- **Canonical policy at Milestone 2 dependency**: per-
  `boundary_dimension` maximum freshness windows commit at that
  layer. The containment dimension needs a **tighter window**
  (hours-to-day order) than most boundary dimensions because the
  brief's "daily tool updates invalidate sandbox/containment
  evidence" claim is empirically grounded in observed agentic-
  tool release cadence. This ADR does not commit the number;
  it flags the dependency.

### Cross-cutting rules

#### Authority discipline

Per registry v0.3.2 §Producer-vs-kernel-set:

- **Kernel-set fields**:
  - `ExecutionContext.latest_containment_evidence_ref`,
    `ExecutionContext.sandbox_kind` (Sub-decision (a)).
  - All `AgentClient` axes EXCEPT `permission_mode`
    (Sub-decision (b) — `product_family`, `surface`, `app_build`,
    `dep_bundle_version`, `containment_mechanism`,
    `kernel_observed_at`, `agent_client_state`).
- **Producer-asserted, kernel-verifiable**:
  - `AgentClient.permission_mode` (the agent surface declares;
    kernel verifies against observed configuration).
- **Producer-asserted (derived authority)**:
  - All three remote-agent subtypes
    (`RemoteAgentBaseImageObservation`,
    `RemoteAgentSetupReceipt`,
    `RemoteAgentNetworkPostureObservation`) carry
    `Evidence.authority: "derived"`. Remote-agent producers
    cannot self-claim host-observation authority.

#### Absence-naming convention (`none` vs `none_required`)

(Closes ontology B-1 v1 review.) The `secret_injection_kind`
enum on `RemoteAgentSetupReceipt` uses `none_required` while
six other absence-state enum values across this ADR
(`containment_kind: none`, `network_egress_posture: none`,
`filesystem_write_scope: none`, `keychain_access: none`,
`egress_kind: none`, etc.) use bare `none`. The distinction is
intentional and load-bearing:

- **`none`** is used when the enum value answers **what is
  observed** ("no egress was observed", "no kernel sandbox is
  in effect", "no filesystem-write scope is granted"). The
  predicate is observation-state.
- **`none_required`** is used when the enum value answers
  **why no mechanism applies** ("no secret-injection mechanism
  is required by the agent's design"; e.g., a stateless agent
  that resolves secrets at every request via a cloud
  metadata service does not need any of the four other
  injection mechanisms). The predicate is requirement-state.

The two predicates are ontologically distinct: an observation
of "no egress" is a runtime fact about a specific launch; a
classification of "no secret injection required" is a
capability-class fact about the agent's design. Conflating
them by renaming `none_required` → `none` would lose the
distinction between "no secrets observed in injection" (a
runtime claim that may be wrong if observation missed them)
and "this agent design does not use injected secrets" (a
capability-class claim about the agent's secret-resolution
model). The schema PR enforces the predicate distinction via
the field's parent context (`secret_injection_kind` lives on
`RemoteAgentSetupReceipt` capability/design metadata, whereas
the bare `none` values live on per-launch runtime
observations).

#### Remote-agent-produced evidence default authority class (NEW)

**Pre-empts security-reviewer escalation concern; closes a real
authority surface.** Remote-agent-produced evidence (any
`Evidence` record whose `producer` resolves to a `remote_cloud_agent`-
surface AgentClient) carries `authority: "derived"` against the
host-authority ladder when consumed by HCS gates. Promotion to
stronger authority (`provider-asserted-kernel-verifiable` or
`host-observation`) requires a **linked-observation chain**
through evidence carrying that stronger authority. Concretely:

- A Devin-produced `RemoteAgentSetupReceipt` cannot be cited as
  authority for a host gate; it must be linked to a
  `StatusCheckSourceObservation` (ADR 0033 v2) and a
  `GitRepositoryObservation` (ADR 0027 v2) carrying their own
  authority chain.
- An `AgentClient.permission_mode = "approve_all"` claim on a
  Devin session reads as `derived` evidence about the remote
  agent's claimed permission mode; it does NOT authorize a
  host operation just because the remote agent declares
  itself permissive.
- Layer 3 gateway re-derive applies the chain-promotion rule
  (ADR 0019 v3 §Chain promotion rule) extended to remote-agent
  authority chains: any record citing `derived`-only authority
  in its `evidence_refs` cannot promote.

Producers attempting to mint a remote-agent record with
`authority: "host-observation"` reject at Layer 1 mint API with
NEW `Decision.reason_kind:
remote_agent_evidence_authority_overreach`.

This composes with charter inv. 8 (sandbox-observation cannot
promote) and inv. 16 (external-control-plane evidence-first):
remote-agent evidence is a specific case of external-control-
plane observation under inv. 16, and the `derived`-default rule
is its explicit binding to the host-authority ladder.

#### Cross-context binding rules per Ring 1 layer

Per registry v0.3.0:

- **`boundary_dimension: containment_class`**: Layer 1 enforces
  payload validity per the discriminated-union (Sub-decision
  (a)); Layer 2 broker FSM re-checks freshness at operation-
  execution time; Layer 3 gateway re-derives narrower-wins
  composition (Sub-decision (b)) at gate consumption.
- **`AgentClient`**: Layer 1 enforces `(product_family, surface,
  app_build)` identity-tuple uniqueness for `agent_client_state:
  "active"` records; Layer 2 re-checks observed-runtime drift;
  Layer 3 gateway resolves via `agent_client_id` FK on
  `ExecutionContext`.
- **Three remote-agent subtypes**: Layer 1 enforces
  `(execution_context_id, observed_at)` per-subtype binding;
  Layer 2 broker FSM re-checks freshness; Layer 3 gateway re-
  derives the non-PR binding window per Sub-decision (c).
- **Cross-workspace AgentClient reuse** rejected at Layer 1
  (an AgentClient minted for one workspace cannot be cited as
  authority by another workspace; mirrors ADR 0019 v3
  cross-workspace rule).

#### Sandbox-promotion rejection (charter inv. 8)

Inherited from ADR 0019 v3 / ADR 0034 v2 / ADR 0035 v2 / ADR
0036 v2:

- `BoundaryObservation` of `boundary_dimension:
  containment_class` with `Evidence.authority` in
  `{sandbox-observation, self-asserted}` cannot be promoted to
  host-authoritative gate evidence.
- `AgentClient` records with self-asserted kernel-set axes
  reject at Layer 1 mint per the `agent_client_axis_self_asserted`
  reason_kind (Sub-decision (b)).
- Remote-agent `Evidence` records cannot promote beyond
  `derived` per the cross-cutting rule above.

### `Decision.reason_kind` reservations

Six new rejection-class names reserved (posture-only; schema
enum lands per `.agents/skills/hcs-schema-change`). All match
`<subject>_<state>` form per the precedent codified in ADR 0036
v2:

- **`containment_evidence_absent`** — Layer 3 gateway rejects a
  gate consumption that requires containment evidence when no
  `BoundaryObservation` of `boundary_dimension: containment_class`
  exists in `proven` state for the operation's
  `execution_context_id` (or all such observations have expired
  `valid_until`). Closes Sub-decision (a) default-state surface.
- **`containment_evidence_producer_supplied`** — Layer 1 mint API
  rejects a producer-supplied value on the kernel-set
  `ExecutionContext.sandbox_kind` or
  `ExecutionContext.latest_containment_evidence_ref` fields.
  Closes Sub-decision (a) authority-class change.
- **`containment_runtime_capability_exceeded`** — Layer 1 mint API
  rejects a runtime `BoundaryObservation` of `boundary_dimension:
  containment_class` whose `containment_kind` exceeds the
  capability-class committed by the active AgentClient's
  `containment_mechanism` (e.g., a `terminal_no_isolation_capable`-
  capable product producing a runtime observation of
  `containment_kind: kernel_sandbox`). Closes Sub-decision (b)
  narrower-wins attack surface.
- **`agent_client_axis_self_asserted`** — Layer 1 mint API
  rejects a producer-supplied value on any kernel-set `AgentClient`
  axis (`product_family`, `surface`, `app_build`,
  `dep_bundle_version`, `containment_mechanism`,
  `kernel_observed_at`, `agent_client_state`). Closes
  Sub-decision (b) authority discipline.
- **`remote_agent_evidence_authority_overreach`** — Layer 1
  mint API rejects a remote-agent-produced `Evidence` record
  whose `Evidence.authority` claims `host-observation` or
  `provider-asserted-kernel-verifiable` without a linked-
  observation chain to a host-observation Evidence record.
  Closes the cross-cutting Composition rule.
- **`non_pr_remote_agent_binding_partial`** — Layer 3 gateway
  rejects a non-PR-mediated remote-agent gate consumption when
  one or two of the three remote-agent subtypes
  (`RemoteAgentBaseImageObservation`,
  `RemoteAgentSetupReceipt`,
  `RemoteAgentNetworkPostureObservation`) are missing in the
  `(execution_context_id, observed_at_window)` binding set.
  Closes Sub-decision (c) non-PR binder.

The existing reason_kinds cover other failure modes:
- `boundary_evidence_stale` (ADR 0034 v2) — applies to expired
  containment observations on read.
- `boundary_evidence_contradictory` (ADR 0034 v2) — applies to
  contradictory containment observations.
- `secret_resolution_in_chunk` (ADR 0019 v3) — applies to
  `RemoteAgentSetupReceipt.setup_log_evidence_ref` content.

**Closed-list fail-mode tightening rule.** All new closed enums
introduced by this ADR (one new `surface` value, six new
`Decision.reason_kind` values, new `AgentClient.product_family`
enum, new `AgentClient.permission_mode` enum, new
`AgentClient.containment_mechanism` enum, new
`agent_client_state` enum, new `containment_kind` discriminator
on the `containment_class` payload, new `secret_injection_kind`
discriminator on `RemoteAgentSetupReceipt`, etc.) inherit the
ADR 0029 v2 §Closed-list fail-mode tightening rule (canonical
restatement per ADR 0036 v2): unrecognized values default to
`block` for destructive operations or `warn` for read-only.

### Three regression traps staged behind dependencies

All three traps accepted as design intent; **fixtures land when
their evidence dependencies clear**. Trap entries reserved in
`packages/evals/traps/` registry NOW (with stage-blocked
status), fixtures filled when underlying schemas land:

#### Trap #29 — `containment-narrower-wins-composition`

- **What it tests**: an operation cited against an AgentClient
  with `containment_mechanism: kernel_sandbox_capable` AND a
  runtime `BoundaryObservation` of `containment_kind: none`
  (sandbox-disabled flag in effect). Layer 3 gateway re-derive
  reads the operation as `none` (narrower wins), NOT as
  `kernel_sandbox`.
- **Rejection class on failure**: gate proceeds when it should
  not (operation gated on kernel-sandbox containment
  succeeding); Layer 3 must reject with
  `containment_evidence_absent` or analogous.
- **Stage-blocked on**: `AgentClient` schema PR + `BoundaryObservation`
  of `containment_class` payload schema + Layer 3 gateway re-
  derive implementation.

#### Trap #30 — `agent-client-axis-self-asserted-rejection`

- **What it tests**: producer attempts to mint an `AgentClient`
  with `product_family`, `surface`, `app_build`, or
  `containment_mechanism` self-asserted (kernel-set axis with
  producer-supplied value).
- **Rejection class on failure**: NEW
  `agent_client_axis_self_asserted` reason_kind.
- **Stage-blocked on**: `AgentClient` schema PR.

#### Trap #31 — `remote-agent-authority-overreach`

- **What it tests**: producer attempts to mint a
  `RemoteAgentSetupReceipt` with `Evidence.authority:
  host-observation` (claiming the remote agent's setup is
  host-grade evidence).
- **Rejection class on failure**: NEW
  `remote_agent_evidence_authority_overreach` reason_kind.
- **Stage-blocked on**: three remote-agent subtype schemas.

### Out of scope

This ADR does not authorize:

- Zod schema source for `AgentClient` Ring 0 entity, the three
  remote-agent subtype envelopes, the `containment_class`
  payload shape, or `ExecutionContext` field changes
  (`latest_containment_evidence_ref`, `kernel_sandbox_kind` cache
  semantics). Schema lands per `.agents/skills/hcs-schema-change`.
- Registry update PR for:
  - `ExecutionContext.surface` enum extension: 1 new value
    (`remote_cloud_agent`).
  - `boundary_dimension: containment_class` payload commitment
    (closes ADR 0022 open dependency).
  - `AgentClient` Ring 0 entity registration with six axes +
    lifecycle.
  - Three new `Evidence` subtypes
    (`RemoteAgentBaseImageObservation`,
    `RemoteAgentSetupReceipt`,
    `RemoteAgentNetworkPostureObservation`).
  - Producer-class allowlist extension: new
    `kernel_agent_client_resolver` value.
  - `Decision.reason_kind` reservations: 6 new values.
  - `secret_injection_kind` discriminator on
    `RemoteAgentSetupReceipt` (5 values).
  - `containment_kind` discriminator on `containment_class`
    payload (7 values).
  - `AgentClient.product_family` enum (12 values).
  - `AgentClient.permission_mode` enum (5 values).
  - `AgentClient.containment_mechanism` enum (8 values).
  - `agent_client_state` enum (2 values).
- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. Per-
  `boundary_dimension` freshness windows (containment dimension
  needs a tighter window per Sub-decision (e)); non-PR remote-
  agent binding window duration (Phase 1 default ±5 min, but
  canonical policy commits the number); per-product-family
  permission-mode verifier rules.
- Per-product surface enum entries for Cursor, Copilot, Devin,
  Windsurf, Augment / Auggie, Amp, OpenCode, Warp Oz, VS Code
  local agents (matrix-only per Sub-decision (d) until future
  ADR with explicit Receipt subtype).
- `RemoteAgentInvocationReceipt` aggregator entity (Phase 1
  uses `(execution_context_id, observed_at_window)` binding;
  aggregator queued for future amendment if non-PR binder fails
  per Sub-decision (c)).
- ADR 0022 amendment (Sub-decision (a) keeps containment posture
  inside the BoundaryObservation envelope; ADR 0022 as accepted
  remains correct).
- A2A facade (deferred per D-013).
- Codex profile cross-surface inheritance (rejected per D-031).
- Charter inv. 17 amendment text (already at v1.3.0; no change
  needed — A3 explicitly composes with inv. 17).
- Charter inv. 19 amendment text (separate charter PR per
  change-policy, per ADR 0034 v2).
- Future Q-row for first-class per-product surface enum entries
  if matrix-only entries accumulate material incident history.
- Future ADR for cross-cutting AgentClient × WorkspaceContext
  cardinality if a single workspace's operations span multiple
  AgentClients with conflicting capability-class evidence
  (architectural deferral; current Phase 1 assumption is single
  active AgentClient per ExecutionContext).

## Consequences

### Accepts

- Q-010 settled at the design layer with: one new Ring 0 entity
  (`AgentClient`); three new `Evidence` subtypes (one
  observation, one receipt, one observation); one new kernel-
  trusted producer class (`kernel_agent_client_resolver`); one
  new `surface` enum value (`remote_cloud_agent`); six new
  `Decision.reason_kind` reservations; commitment of the
  `containment_class` boundary_dimension payload shape (closes
  ADR 0022 open dependency); refactor of `ExecutionContext.sandbox`
  from producer-asserted flat field to kernel-set denormalized
  cache (pointer + cached value form); closure of Q-011(i)
  deferred question; three regression traps staged behind
  evidence dependencies.
- `ExecutionContext.sandbox` becomes kernel-set per registry
  v0.3.2 §Producer-vs-kernel-set authority fields; producer-
  supplied values reject at Layer 1 mint with new typed
  reason_kind. The pre-substrate flat `sandbox` block is read-
  only post-A3 and itself derived from the new pointer field.
  inv. 17 compliance preserved: cache is projection from typed
  evidence bound to the same execution_context_id, not
  inference.
- `AgentClient` identity grain per-(`product_family`, `surface`,
  `app_build`); `agent_client_id` never mutates in place; new
  `app_build` mints a NEW AgentClient; retired AgentClients
  stay queryable for audit-chain reconstruction. Six axes with
  per-axis authority matrix (5 kernel-set + 1 producer-asserted-
  kernel-verifiable). Lifecycle `agent_client_state: active |
  retired` per registry Sub-rule 8 bare-noun central-concept
  pattern.
- Composition rule between `AgentClient.containment_mechanism`
  (capability-class evidence — what product CAN provide) and
  `ExecutionContext.latest_containment_evidence_ref` (runtime-
  class evidence — what current launch IS) committed as
  narrower-wins at Layer 3 gateway re-derive. Charter inv. 8
  provides the structural backstop; this ADR provides the
  explicit ontological enforcement.
- Three remote-agent subtypes split per Q-005 multi-receipt
  pattern. `RemoteAgentSetupReceipt` carries
  `secret_injection_kind` discriminator (5 values); secret-
  shape protection inherited from ADR 0019 v3 (no
  duplication). Checkout commit composes via `evidence_ref`
  to `GitRepositoryObservation` (ADR 0027 v2), not as payload
  field. PR-mediated binding via `StatusCheckSourceObservation`
  (ADR 0033 v2). Non-PR binding via `(execution_context_id,
  observed_at_window)` for Phase 1; aggregator entity flagged
  for future amendment.
- `surface` enum gains ONE new value (`remote_cloud_agent`)
  reflecting the inv. 17 local-vs-cloud structural divide.
  Specific cloud-agent products distinguished via
  `AgentClient.product_family`, not surface enum entries.
  Per-product surface entries stay matrix-only.
- Re-baseline ratifies existing precedent: `valid_until`-based
  per ADR 0022 registry rule 5; observed_runtime change OR
  matching_changelog material change per D-026; NO
  `boundary_dimension: version_drift`. Canonical policy at
  Milestone 2 commits per-dimension freshness windows
  (containment dimension needs hours-to-day order).
- Cross-cutting Composition rule: remote-agent-produced
  evidence carries `Evidence.authority: "derived"` against the
  host-authority ladder by default; promotion to stronger
  authority requires linked-observation chain through host-
  observation evidence. Pre-empts AgentClient.permission_mode
  escalation surface; closes the inv. 16 external-control-
  plane evidence-first binding for remote-agent observations.
- ADR 0022 envelope confirmed correct as accepted; A3 keeps
  containment posture inside the envelope, closing the open
  dependency the ADR 0022 Acceptance section flagged.

### Rejects

- Adding per-product surface enum entries for Cursor / Copilot
  / Devin / Windsurf / Augment / Amp / OpenCode / Warp Oz /
  VS Code local agents (D-013 conservative posture preserved;
  matrix-only by default).
- Vendor `SharedAgentPolicySchema` and per-vendor adapter
  schemas as canonical HCS shape (rejected by source brief;
  reaffirmed here).
- Cross-tool false equivalence collapsed into one object
  (rejected by source brief; reaffirmed here).
- Treating permission modes / worktrees / app settings as
  proof of OS containment (rejected by source brief; reaffirmed
  here — kernel-class containment requires runtime
  `BoundaryObservation` evidence, not declarative claims).
- Producer-asserted `ExecutionContext.sandbox` (the v1 shipped
  shape; A3 flips authority to kernel-set per registry
  Producer-vs-kernel-set discipline).
- A1 (deprecate `ExecutionContext.sandbox` field entirely;
  breaks shipped schema).
- A2 (coexist as two sources of truth — exactly the failure
  mode HCS exists to prevent).
- B1 (supersede `ExecutionContext.surface` enum from
  AgentClient; breaks shipped schema unnecessarily).
- B2 (complement with both surface enum AND AgentClient
  carrying surface independently; redundant).
- C1 (single composite `RemoteAgentEnvironmentReceipt` with
  multiple fields; loses independent freshness per piece;
  rejected per Q-005 multi-receipt precedent).
- D1 (status quo no enum additions; doesn't capture the inv.
  17 local-vs-cloud divide HCS needs to bind).
- D3 (per-product surface enum additions; churns too fast for
  schema migration and creates per-quarter ADR overhead for
  every new agentic product).
- New `boundary_dimension: version_drift` (rejected by ADR
  0022 registry rule 5; version drift is freshness signal,
  not a dimension).
- A separate `containment_mechanism` field on `ExecutionContext`
  duplicating `AgentClient.containment_mechanism`
  (capability-class evidence belongs on AgentClient;
  ExecutionContext binds the runtime-class evidence via
  pointer to BoundaryObservation).
- Devin / Cursor / Copilot cloud-specific Receipt subtypes for
  Phase 1 (the three umbrella subtypes
  `RemoteAgentBaseImageObservation`,
  `RemoteAgentSetupReceipt`,
  `RemoteAgentNetworkPostureObservation` cover the cross-
  product evidence shape; per-product specificity stays
  matrix-only).
- A2A facade or cross-agent coordination at this ADR (deferred
  per D-013; Q-010 scope is per-agent-client typed evidence,
  not cross-agent delegation).
- Codex profile cross-surface inheritance (rejected per D-031;
  AgentClient identity is per-surface so Codex CLI profile
  evidence does not lend authority to Codex app or Codex IDE
  contexts).

### Future amendments

- Schema PR per `.agents/skills/hcs-schema-change` for:
  `AgentClient` Ring 0 entity (six axes + lifecycle); three
  remote-agent `Evidence` subtypes; `boundary_dimension:
  containment_class` payload; `ExecutionContext` field
  refactor (`latest_containment_evidence_ref`, `kernel_sandbox_kind`
  cache, deprecation of pre-substrate flat `sandbox` block to
  read-only); six new `Decision.reason_kind` reservations.
- Registry update PR for:
  - `surface` enum extension: 1 new value
    (`remote_cloud_agent`).
  - Producer-class allowlist extension:
    `kernel_agent_client_resolver`.
  - `containment_class` boundary_dimension payload commitment.
  - `AgentClient` Ring 0 entity registration.
  - Three Evidence subtype names + naming-discipline
    conformance.
  - 6 new `Decision.reason_kind` values.
  - 5 closed enums (product_family, permission_mode,
    containment_mechanism, agent_client_state,
    secret_injection_kind, containment_kind).
- Trap fixtures land when their evidence dependencies clear
  (Trap #29: AgentClient schema + containment_class payload
  + Layer 3 gateway re-derive; Trap #30: AgentClient schema;
  Trap #31: three remote-agent subtype schemas). **Final trap
  numbering deferred to fixture-landing PR per policy NB-5
  v1 review** — the coordination-store brief
  (`MEMORY.md`) reserves trap candidates #31–#35; the
  fixture-landing PR deconflicts the actual numbers.
- **Additional regression trap candidates** (per security
  reviewer recommendation in v1 review; staged on the same
  evidence-dependency discipline as Traps #29–#31; final
  numbering at fixture-landing PR):
  - **Non-PR-binding-partial rejection trap** — exercises
    Layer 3 gateway rejection of partial
    `(execution_context_id, observed_at_window)` bindings with
    `non_pr_remote_agent_binding_partial` reason_kind.
  - **Remote-agent permission-mode host-gate rejection trap** —
    exercises Layer 3 chain-promotion rejection when a
    `remote_cloud_agent`-surface AgentClient's
    `permission_mode: approve_all` is cited as authority for
    a host-gate operation.
  - **Containment-cache stale-pointer rejection trap** —
    exercises `containment_evidence_absent` when
    `latest_containment_evidence_ref` resolves to an expired
    `BoundaryObservation` regardless of cached
    `kernel_sandbox_kind` value.
  - **Setup-log secret-resolution rejection trap** —
    exercises the existing `secret_resolution_in_chunk`
    rejection on `RemoteAgentSetupReceipt.setup_log_evidence_ref`
    content matching resolved-secret shape.
  - **Cross-workspace AgentClient reuse rejection trap** —
    exercises Layer 1 mint rejection when an `AgentClient`
    minted in workspace A is cited as authority for a
    Decision in workspace B.
- Canonical policy YAML at Milestone 2 commits: per-
  `boundary_dimension` freshness windows (containment
  dimension hours-to-day order); non-PR remote-agent binding
  window duration (Phase 1 default ±5 min); per-product-
  family permission-mode verifier rules.
- Future Q-row for first-class per-product surface enum
  entries if matrix-only entries accumulate material incident
  history that schema-typing would close.
- Future ADR for `RemoteAgentInvocationReceipt` aggregator
  entity if non-PR binding via `(execution_context_id,
  observed_at_window)` fails empirically (e.g., long-running
  cloud agents with environment changes mid-invocation).
- Future ADR for cross-cutting AgentClient × WorkspaceContext
  cardinality if a single workspace's operations span multiple
  AgentClients with conflicting capability-class evidence.
- Charter v1.4.0 amendment PR for inv. 19 text (per ADR 0034
  v2 candidate; inv. 19 freshness-bound principle composes
  with this ADR's containment cache invalidation rule).

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md`
  v1.3.2 (especially inv. 7 execute-lane, inv. 8 sandbox-
  promotion-rejection, inv. 16 external-control-plane
  evidence-first, inv. 17 execution-context declared not
  inferred; inv. 18 candidate per ADR 0019 v3; inv. 19
  candidate per ADR 0034 v2).
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
  (Producer-vs-kernel-set authority fields, Cross-context
  enforcement layer, Naming suffix discipline including
  Sub-rule 8 bare-noun central-concept lifecycle pattern,
  Field-level scrubber rule, Audit-chain coverage of
  rejections; `agent_client` subject_kind value;
  containment-related boundary_dimension candidates).
- Decision ledger: `DECISIONS.md` Q-010 (this row); D-013
  (A2A deferred); D-022 / D-029 (tool baseline by public
  semver, app build IDs tracked separately); D-026 (config-
  spec authority hierarchy); D-031 (Codex profiles CLI-only,
  no cross-surface identity/auth/policy inheritance);
  D-032 / ADR 0015 (external APIs as typed evidence-producing
  control planes).
- ADR 0015:
  `docs/host-capability-substrate/adr/0015-external-control-plane-evidence-first.md`
  (external-control-plane typed evidence pattern referenced
  by Sub-decision (c)).
- ADR 0018:
  `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
  (CredentialSource referenced by `secret_injection_kind`
  discriminator on `RemoteAgentSetupReceipt`).
- ADR 0019:
  `docs/host-capability-substrate/adr/0019-knowledge-and-coordination-store.md`
  (chain-promotion rule extended to remote-agent authority
  chains; `secret_resolution_in_chunk` reason_kind reused
  for `RemoteAgentSetupReceipt.setup_log_evidence_ref`;
  canonical_attribution_agent_client_id field).
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (BoundaryObservation envelope; `containment_class`
  candidate boundary_dimension whose payload Sub-decision
  (a) commits; envelope confirmed correct — no amendment
  needed).
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract; `evidenceSubjectKindSchema`
  including `agent_client` value).
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (`GitRepositoryObservation` referenced by
  `RemoteAgentBaseImageObservation` checkout-commit
  composition).
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (Producer-vs-kernel-set authority fields; kernel-trusted
  producer allowlist extended here with
  `kernel_agent_client_resolver`; canonical_attribution_*
  field discipline).
- ADR 0029:
  `docs/host-capability-substrate/adr/0029-q-008-b-c-broker-fsm-and-cross-tool-authority.md`
  (operation_class enumeration; closed-list fail-mode
  tightening rule; three-state matrix pattern).
- ADR 0030:
  `docs/host-capability-substrate/adr/0030-q-006-stage-2-source-control-evidence-subtypes.md`
  (cross-receipt commit_sha duplication drift class closed —
  Sub-decision (c) inherits the no-duplication rule).
- ADR 0031:
  `docs/host-capability-substrate/adr/0031-q-008-d-worktree-ownership-composition.md`
  (Lease identity-grain pattern; `agent_client_id`
  canonical-attribution field; `lease_state` bare-noun
  central-concept discriminator pattern referenced for
  `agent_client_state`).
- ADR 0032:
  `docs/host-capability-substrate/adr/0032-q-005-ci-runner-evidence-model.md`
  (Q-005 multi-receipt split pattern; six runner/check
  evidence subtypes; precedent for Sub-decision (c)
  three-subtype split).
- ADR 0033:
  `docs/host-capability-substrate/adr/0033-q-006-b-g-github-authority-and-identity.md`
  (Q-006 (b)-(g) v2 final; `StatusCheckSourceObservation`
  for source-app identity composing with PR-mediated cloud-
  agent runs in Sub-decision (c)).
- ADR 0034:
  `docs/host-capability-substrate/adr/0034-q-007-b-f-boundary-evidence-composition-quality-gate-posture.md`
  (Q-007 (b)-(f) v2 final; ToolProvenance kernel-set
  fields; flat-payload composition pattern; boundary-
  evidence stateness matrix; charter inv. 19 candidate).
- ADR 0035:
  `docs/host-capability-substrate/adr/0035-q-007-g-quality-gate-standalone-entity.md`
  (Q-007(g) v2 final; gate identity triple pattern).
- ADR 0036:
  `docs/host-capability-substrate/adr/0036-q-009-workspace-manifest-projection-and-diagnostic-surface.md`
  (Q-009 v2 final; closed-list fail-mode tightening rule
  comprehensive restatement; `kernel_workspace_diagnose`
  narrower-kernel-trusted-producer precedent for
  `kernel_agent_client_resolver`; reason_kind
  `<subject>_<state>` form precedent).
- 2026-05-01 agentic coding tool isolation synthesis:
  `docs/host-capability-substrate/research/local/2026-05-01-agentic-tool-isolation-synthesis.md`
  (primary research source; 11 products; 9-dimension
  containment taxonomy; explicit rejection of vendor
  SharedAgentPolicySchema; brief leaves Q-010 sub-decisions
  open for HCS-side resolution).
- Tooling-surface matrix:
  `docs/host-capability-substrate/tooling-surface-matrix.md`
  (matrix-only entries for per-product cloud agents per
  Sub-decision (d)).
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`.
- Existing schema:
  `packages/schemas/src/entities/execution-context.ts`
  (current `ExecutionContext` shape; `surface` enum 12
  values; pre-substrate `sandbox` block;
  `agent_client_id` FK already present).
- Existing schema:
  `packages/schemas/src/entities/evidence.ts`
  (`evidenceSubjectKindSchema` including `agent_client`
  value).

### External

- Apple Sandbox / Seatbelt
  (`sandbox-exec`-class containment referenced by
  `kernel_sandbox_profile` enum):
  <https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/AboutAppSandbox/AboutAppSandbox.html>
- Codex CLI sandbox flags (per the brief; referenced by
  `permission_mode` and runtime `containment_kind`
  observation):
  <https://github.com/openai/codex>
- Devin / Cursor / Copilot cloud-agent vendor APIs
  (referenced via the matrix; specific URLs tracked in
  `tooling-surface-matrix.md`).
