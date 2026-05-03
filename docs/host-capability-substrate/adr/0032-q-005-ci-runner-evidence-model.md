---
adr_number: 0032
title: Q-005 CI runner compatibility boundary and evidence model
status: proposed
date: 2026-05-03
charter_version: 1.3.2
tags: [ci-runner, evidence-subtypes, citadel-opa, forbidden-families, status-check-source, q-005, q-006, phase-1]
---

# ADR 0032: Q-005 CI runner compatibility boundary and evidence model

## Status

proposed (v1)

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Context

Q-005 asks four sub-decisions about the CI runner compatibility
boundary and evidence model:
- (a) Should runner/check facts land as `Evidence` subtypes or
  standalone Ring 0 entities?
- (b) Which policy rules live in Citadel OPA versus HCS
  policy/gateway?
- (c) Should public-fork → self-hosted, generic
  `runs-on: self-hosted`, MacBook always-on CI, runner tokens in
  OpenTofu state, and Docker socket exposure become HCS forbidden
  families or remain Citadel PaC-only?
- (d) Should HCS model GitHub status source / app identity as
  gate evidence before consuming self-hosted check results?

The 2026-04-26 proposed runner architecture brief
(`docs/host-capability-substrate/research/external/2026-04-26-proposed-runner-architecture.md`,
589 lines) recommends Proxmox-first / Linux-first /
GitHub-orchestrated self-hosted runners, hosted smoke sentinels,
Citadel-owned OpenTofu/PaC, manual-only MacBook runner use, and
HCS as a typed evidence consumer rather than CI control plane.

The 2026-05-01 ontology-promotion-receipt-dedupe plan provides
Q-011-resolved guidance for the six Q-005 entity candidates
(lines 116–121, 133, 188, 193, 251). The 2026-05-01 version-control
authority consult synthesis confirms shared check-source-identity
vocabulary between Q-005 and Q-006 (lines 61–64, 167). The local-
first CI runner design doc enumerates the six receipts at lines
240, 243, 247, 251, 255.

Pre-draft sub-decisions approved by user (2026-05-03):
- (a) All six candidates land as `Evidence` subtypes (Q-011
  bucket 1), with `RunnerIsolationObservation` using
  `BoundaryObservation` envelope for the existing
  `runner_isolation` boundary dimension.
- (b) Two-side boundary: Citadel OPA owns infrastructure;
  HCS policy/gateway owns per-operation evidence consumption.
- (c) All five forbidden patterns become HCS forbidden families
  enforced at the operation boundary.
- (d) `StatusCheckSourceObservation` (or similar typed source-
  identity evidence) required before HCS consumes self-hosted
  check results as gate evidence.

This ADR is doc-only and posture-only, mirroring ADR 0019 v3 /
ADR 0029 v2 / ADR 0030 v2 / ADR 0031 v1 acceptance pattern. It
does not author Zod schema source, canonical policy YAML, runtime
probes, dashboard routes, MCP adapter contracts, or charter
invariant text. Schema implementation lands per
`.agents/skills/hcs-schema-change` after acceptance.

## Options considered

### Option A: All six Evidence subtypes; Citadel-HCS split; HCS forbidden families; source-identity required (chosen)

**Pros:**
- Matches ADR 0027 v2 / ADR 0030 v2 stage-1+2 pattern: typed
  `Evidence` subtypes with payload-versioned envelopes; minimum
  ontology surface; reuses existing boundary-dimension and
  Evidence base contract.
- Promotes the `runner_isolation` boundary dimension from
  proposed (gated by Q-005) to accepted; resolves the registry
  dimension's gating dependency.
- Two-side Citadel-HCS boundary preserves charter inv. 1 (no
  policy duplication) and inv. 16 (external-control-plane
  evidence-first) without making HCS a parallel CI control
  plane.
- HCS forbidden families enforce at the operation boundary;
  closes the gap where Citadel PaC blocks workflow YAML but
  HCS would otherwise consume green checks from forbidden
  configurations.
- `StatusCheckSourceObservation` requirement closes the check-
  name-only attack surface (an attacker registering a GitHub App
  publishing the same check name).

**Cons:**
- Six new evidence subtypes expand the canonical entity list
  surface area.
- Q-006(g) (check-result gateability) overlaps with sub-decision
  (d); careful sequencing required between Q-005 (this ADR) and
  Q-006 stage-2/stage-3 (commit `StatusCheckSourceObservation`
  shape).
- HCS-forbidden families require coordination with canonical
  policy YAML at Milestone 2.

### Option B: Promote runner facts to standalone Ring 0 entities now

**Pros:**
- Independent lifecycle for runner state.
- Could carry per-runner approval grants directly.

**Cons:**
- Most runner observations are freshness-bound (host state,
  last-seen, pressure readings), not independently owned
  lifecycles. Charter inv. 16 frames runner/check receipts as
  control-plane *evidence*, not first-class entities.
- Violates Q-011 dedupe rule: `ResourceBudgetObservation` would
  duplicate the accepted `ResourceBudget` entity.
- Inflates the canonical entity list without ontological gain.

### Option C: HCS as parallel CI control plane (own infrastructure policy)

**Pros:**
- Single-system policy authority.

**Cons:**
- Citadel already owns OpenTofu provider ecosystem and state
  backend; duplication violates charter inv. 1.
- Runner infrastructure is external control-plane state, not
  local host capability.
- Local-first CI runner design explicitly delegates
  infrastructure to Citadel; rejecting that posture would
  require re-deciding the broader system architecture.

## Decision

Choose Option A. Q-005 commits four posture decisions: typed
Evidence subtypes for six runner/check candidates; Citadel-vs-HCS
two-side policy boundary; five HCS forbidden families; required
typed source-identity evidence before consuming self-hosted check
results.

### Six runner/check Evidence subtypes

All six entities land as `Evidence` subtypes (Q-011 bucket 1)
matching ADR 0027 v2 / ADR 0030 v2 stage-1+2 pattern. Schema
implementation lands per `.agents/skills/hcs-schema-change` after
acceptance.

#### `RunnerHostObservation`

Freshness-bound observation of a CI runner host's identity,
substrate, and access posture.

**Evidence shape (illustrative; schema PR commits final):**
- `evidence_kind: "observation"`
- `evidence_subject_kind: "runner_host"` (NEW enum value;
  schema PR adds to `evidenceSubjectKindSchema`).
- Standard `Evidence` base fields per ADR 0023 (including
  `payload_schema_version` and `payload`).
- Payload (illustrative): `runner_host_id`, `substrate_kind:
  "github_hosted" | "self_hosted_proxmox" | "self_hosted_macbook"
  | "self_hosted_other"`, `os`, `arch`, `labels` (array),
  `repo_access_class: "public" | "private" | "fork_isolated"`,
  `last_seen_at` (kernel-set freshness anchor).

**Grain:** per-`runner_host_id`. A single host may produce many
observations over time; freshness is determined by `last_seen_at`
and the consuming operation's freshness window.

**Authority discipline (registry v0.3.2):**
- Kernel-set: `last_seen_at`, `runner_host_id` resolution.
- Producer-asserted, kernel-verifiable: `substrate_kind`, `os`,
  `arch`, `labels`, `repo_access_class`.

**Cross-context binding (registry v0.3.0 §Cross-context
enforcement layer):** Layer 1 enforces `runner_host_id`
consistency with the requesting session's `ExecutionContext`;
Layer 2 re-checks `last_seen_at` freshness; Layer 3 re-derives.

#### `RunnerIsolationObservation`

`BoundaryObservation` payload for the `runner_isolation`
boundary dimension already registered (proposed/gated-by-Q-005).
This ADR promotes the dimension to accepted.

**Evidence shape:**
- `BoundaryObservation` envelope per ADR 0022.
- `boundary_dimension: "runner_isolation"`.
- Payload (illustrative): `job_environment_kind: "host" |
  "container" | "disposable_vm"`, `workspace_cleanup_kind:
  "always_clean" | "checkout_clean_only" | "persistent"`,
  `docker_socket_exposure: bool`, `network_egress_class:
  "internet_full" | "internet_restricted" | "vpn_only" |
  "egress_blocked"`, `host_filesystem_access:
  "isolated" | "shared_workspace" | "shared_host"`.

**Grain:** per-runner-lifecycle (the isolation posture for a
single job execution context, not the host-level static config).

**Authority discipline:** observation-class fields kernel-set;
posture-class fields producer-asserted but kernel-verifiable.
`docker_socket_exposure: true` is itself an HCS forbidden-family
trigger when paired with untrusted code (see §Five HCS forbidden
families below).

**Boundary-dimension acceptance:** `runner_isolation` boundary
dimension promotes from proposed → accepted with this ADR's
acceptance. The registry update PR amends the dimension's
`source` field to cite this ADR.

#### `WorkflowRunReceipt`

Typed receipt of a GitHub Actions workflow run's lifecycle.

**Evidence shape:**
- `evidence_kind: "receipt"`
- `evidence_subject_kind: "workflow_run"` (NEW).
- Payload (illustrative): `repository_id` (typed FK per
  ADR 0027 v2 first-commit-SHA-rooted resolution),
  `workflow_run_id`, `commit_sha`, `actor_login`,
  `workflow_path`, `conclusion_kind: "success" | "failure" |
  "cancelled" | "skipped" | "neutral" | "timed_out" |
  "action_required"`, `started_at`, `completed_at`,
  `runner_host_evidence_ref` (per `evidenceRefSchema` to a
  `RunnerHostObservation` if self-hosted).

**Grain:** per-(`repository_id`, `workflow_run_id`).

**Run-vs-check distinction:** `WorkflowRunReceipt` records the
*run* (the entire workflow execution). `CheckRunReceipt` (Q-006
candidate, deferred to stage-2/stage-3) records individual
*checks* within a run. Q-011 dedupe rule preserves the
distinction.

#### `CleanRoomSmokeReceipt`

Typed receipt of a clean-room smoke test against a hosted-runner
configuration. The Q-011 dedupe plan flags this as a candidate
proof composite (bucket 3) IF used to gate a mutation; otherwise
it is a receipt (bucket 1).

**This ADR commits bucket 1 (Evidence receipt).** Promotion to
proof composite is reserved for a follow-up ADR if a future
operation class consumes it as gating evidence (e.g., gating a
production deploy on a fresh smoke pass).

**Evidence shape:**
- `evidence_kind: "receipt"`
- `evidence_subject_kind: "clean_room_smoke"` (NEW).
- Payload (illustrative): `repository_id`,
  `hosted_runner_workflow_run_id`, `script_invoked`,
  `dependency_install_outcome_kind: "success" | "failure"`,
  `artifact_hash`, `started_at`, `completed_at`,
  `runner_isolation_evidence_ref` (per `evidenceRefSchema` to
  the `RunnerIsolationObservation` for the runner that
  executed the smoke).

**Grain:** per-(`repository_id`, `hosted_runner_workflow_run_id`).

#### `ResourceBudgetObservation`

Freshness-bound observation that **feeds the accepted
`ResourceBudget` entity**, not a duplicate standalone entity. Per
the Q-011 dedupe rule (line 102 of the plan): "should feed
accepted `ResourceBudget`; avoid standalone duplicate."

**Evidence shape:**
- `evidence_kind: "observation"`
- `evidence_subject_kind: "resource_budget"` (NEW).
- Payload (illustrative): `runner_host_id`,
  `observation_window: { window_start_at, window_end_at }`,
  `cpu_pressure_pct`, `memory_pressure_pct`,
  `disk_pressure_pct`, `active_jobs_count`,
  `cache_size_bytes`.

**Grain:** per-host per-time-window.

**Composition with `ResourceBudget`:** `ResourceBudget` (existing
accepted entity) consumes `ResourceBudgetObservation` records as
component evidence; this ADR does NOT modify `ResourceBudget`'s
schema or lifecycle. The observation is the freshness-bound
fact; the entity is the durable budget claim.

#### `PolicyPlanReceipt`

Typed receipt of an OpenTofu (Terraform) plan execution against
infrastructure or policy state. Q-011 dedupe plan flags this as a
candidate proof composite (bucket 3) IF consumed by operation
approval; otherwise receipt (bucket 1).

**This ADR commits bucket 1 (Evidence receipt).** Promotion to
proof composite reserved for a follow-up ADR when an HCS
operation consumes it as gating evidence (e.g., gating runner
infrastructure changes on a fresh plan-and-policy pass).

**Evidence shape:**
- `evidence_kind: "receipt"`
- `evidence_subject_kind: "policy_plan"` (NEW).
- Payload (illustrative): `repository_id` (the IaC repo, NOT
  the project repo using the runner),
  `opentofu_plan_hash`, `conftest_outcome_kind: "pass" |
  "fail" | "warn"`, `policy_ids` (array of policy bundle
  identifiers asserted to apply), `workspace_id_ref`,
  `provider_versions` (map: provider name → version).

**Grain:** per-(`repository_id`, `opentofu_plan_hash`).

### Citadel-vs-HCS policy boundary

This ADR commits a two-side boundary preserving charter inv. 1
(no policy duplication) and inv. 16 (external-control-plane
evidence-first):

#### Citadel OPA owns

- Runner provisioning (OpenTofu plans + state lifecycle).
- Runner group assignments by repo trust class
  (`public_only`, `private_trusted`, `restricted`).
- Network egress policy at the runner host level (firewall
  rules, VPN gateways, allowed destinations).
- Runner-registration-token lifecycle (ephemeral; no state
  storage; tokens minted just-in-time and consumed once).
- Workflow-YAML required-check shapes (which checks must run
  on which paths/branches at the GitHub Actions level).
- Action version pinning policy (which marketplace actions are
  allowed at which SHA-pinned versions).
- Repo-trust-class assignments and the workflow-YAML
  enforcement (`pull_request_target` restrictions, etc.).

#### HCS policy/gateway owns

- Per-operation evidence consumption: gate `scm.push.v1`,
  `github.workflow.dispatch.v1`, `scm.pull_request.create.v1`,
  and similar operations based on `RunnerHostObservation` +
  `RunnerIsolationObservation` + `WorkflowRunReceipt` +
  `StatusCheckSourceObservation` evidence.
- `mutation_scope` enforcement per charter inv. 7 (full
  approval/audit/dashboard/lease stack required for
  destructive operations consuming runner-produced evidence).
- Approval-grant binding for runner registration / deregistration
  / force-deregistration operations (typed `ApprovalGrant`
  scope binding to `runner_host_id`).
- Audit trail of runner credential consumption (typed Decision
  records in audit hash chain per charter inv. 4).
- Gate consumption of self-hosted check results (per
  sub-decision (d); see §`StatusCheckSourceObservation`
  requirement below).
- Forbidden-family enforcement at the operation boundary (see
  §Five HCS forbidden families below).

#### Boundary

Citadel PaC writes *desired infrastructure state*; HCS reads
*evidence from observed state* and gates *local operations*. The
two systems do NOT share policy YAML; canonical HCS policy at
`system-config/policies/host-capability-substrate/` is disjoint
from Citadel OPA bundles. HCS consumes Citadel's evidence (e.g.,
`PolicyPlanReceipt` carrying conftest outcomes) as input to HCS
operation gates.

### Five HCS forbidden families

Per sub-decision (c), all five candidate forbidden patterns
become HCS forbidden families enforced at the operation boundary
(in addition to any Citadel PaC workflow-level blocks). HCS must
refuse to *consume* a green check from a forbidden runner
configuration; Citadel can block bad workflow YAML, but HCS owns
the operation/approval boundary.

#### `forbidden.runner.public_fork_to_self_hosted`

Public-fork pull requests targeting self-hosted runners.

**HCS enforcement (gateway):** rejects any
`github.workflow.dispatch.v1`, `scm.pull_request.create.v1`, or
similar operation whose source is a fork PR AND target runner is
not GitHub-hosted (per `RunnerHostObservation.substrate_kind !=
"github_hosted"`).

**Authority:** charter inv. 8 (sandbox-observation non-promotion
— untrusted PR code on self-hosted = host compromise) + inv. 16
(evidence-first — block before rendering any GitHub mutation).

#### `forbidden.runner.generic_self_hosted_label`

Workflow YAML or operation citing a runner with `runs-on:
self-hosted` only (no explicit group + label).

**HCS enforcement (gateway):** rejects operations citing a runner
without explicit group + label in the consuming evidence
(`RunnerHostObservation.labels` array empty or single-`self-hosted`).

**Authority:** charter inv. 17 (execution-context declared, not
inferred) — cannot audit which host/capability was intended
without explicit labels.

#### `forbidden.runner.macbook_always_on_ci`

MacBook self-hosted runner used outside `workflow_dispatch` /
manual gate.

**HCS enforcement (gateway):** rejects MacBook-runner operations
(`RunnerHostObservation.substrate_kind:
"self_hosted_macbook"`) outside `workflow_dispatch` triggers.

**Authority:** charter inv. 15 (ambient-credentials risk —
MacBook hosts carry SSH keys, 1Password sessions, personal
credentials) + ScopeCam motivating-failure family.

#### `forbidden.runner.tokens_in_state`

Runner registration tokens stored in OpenTofu state.

**HCS enforcement (policy):** rejects any operation that would
materialize runner registration tokens at rest in state.

**Authority:** charter inv. 5 (secrets never at rest in Ring 0/1)
+ inv. 13 (deletion authority is not gitignore — state lifecycle
≠ token lifecycle).

#### `forbidden.runner.docker_socket_to_untrusted`

Docker socket exposed to untrusted code execution targets.

**HCS enforcement (gateway):** rejects operations combining
`RunnerIsolationObservation.docker_socket_exposure: true` with
untrusted code execution target (e.g., fork PR or
unverified-actor workflow dispatch).

**Authority:** charter inv. 17 (execution context declared, not
inferred — Docker socket = host root equivalent).

#### Forbidden-family discipline

All five families are non-escalable per charter inv. 6;
`ApprovalGrant` cannot upgrade a forbidden-family rejection. The
families are tier-orthogonal to ADR 0029 v2 §`block` vs forbidden-
tier framing: a `worktree_mutation` operation invocation hitting
a forbidden-runner cell rejects unconditionally regardless of the
operation's tier.

### `StatusCheckSourceObservation` requirement

Per sub-decision (d), HCS rejects consumption of self-hosted
check results as gate evidence unless the consuming operation
also references a typed `StatusCheckSourceObservation` evidence
record carrying:
- `commit_sha` matching the target branch tip / PR head commit.
- `check_name` + (`expected_github_app_id` OR
  `expected_workflow_path`) binding.
- `conclusion_kind` (success / failure / etc.) + `concluded_at`
  timestamp + `valid_until` freshness window.
- `source_kind: "actions_workflow" | "github_app" |
  "third_party_service" | "native"` discriminator.
- Pair with `WorkflowPolicyObservation` evidence_ref for runner
  class + permissions binding.

**Schema commitment scope.** This ADR REQUIRES the typed
observation as a precondition for consumption; it does NOT
commit the receipt's full Zod shape. The shape is committed
under Q-006 stage-2 / stage-3 (a follow-up Q-006 ADR) to keep
the source-identity evidence in the source-control authority
model alongside `BranchProtectionObservation` and
`PullRequestReceipt`. Q-005 names the requirement; Q-006 owns
the receipt.

**Rejection class.** Operations that consume a self-hosted check
result without a paired `StatusCheckSourceObservation` reject at
gateway (Layer 3 re-derive) with `Decision.reason_kind:
status_check_source_required`. Check-name-only consumption is
explicitly forbidden; an attacker registering a GitHub App
publishing the same check name is the failure mode this rule
closes.

### Cross-context binding rules per Ring 1 layer

Per registry v0.3.0 §Cross-context enforcement layer
requirement, each Q-005 evidence subtype names its enforcement
layers:

- **`RunnerHostObservation`**: Layer 1 enforces
  `runner_host_id` consistency with `ExecutionContext`; Layer 2
  re-checks `last_seen_at` freshness; Layer 3 re-derives.
- **`RunnerIsolationObservation`**: Layer 1 enforces
  `boundary_dimension: "runner_isolation"` payload structure
  per `BoundaryObservation` envelope rules; Layer 2 re-checks
  isolation posture freshness; Layer 3 re-derives. Forbidden-
  family triggers (e.g., `docker_socket_exposure: true` with
  untrusted target) fire at Layer 3 per inv. 6.
- **`WorkflowRunReceipt`**: Layer 1 enforces `repository_id`
  resolution + `workflow_run_id` uniqueness; Layer 2 re-checks
  `conclusion_kind` against current GitHub state if the
  consumer demands fresh state; Layer 3 re-derives.
- **`CleanRoomSmokeReceipt`**: same Layer 1/2/3 pattern as
  `WorkflowRunReceipt` plus runtime composition with
  `RunnerIsolationObservation` (the cited isolation evidence
  must share `execution_context_id` per registry v0.3.0
  strict-default).
- **`ResourceBudgetObservation`**: Layer 1 enforces
  `runner_host_id` consistency; Layer 2 re-checks pressure
  freshness; Layer 3 re-derives. Composition with
  `ResourceBudget` entity at runtime uses
  `evidenceRefSchema`-typed binding; the entity is consumer,
  the observation is producer.
- **`PolicyPlanReceipt`**: Layer 1 enforces `repository_id` (IaC
  repo, NOT project repo) + `opentofu_plan_hash` uniqueness;
  Layer 2 re-checks `conftest_outcome_kind` if the consumer
  demands fresh policy; Layer 3 re-derives.

### Authority discipline

Authority-class signals across the six entities follow registry
v0.3.2 §Producer-vs-kernel-set discipline:

- **Kernel-set**: `last_seen_at` (RunnerHostObservation);
  `runner_host_id`, `workflow_run_id`, `repository_id` resolution
  on all six entities; `payload_schema_version` (ADR 0027 v2
  pattern); freshness anchors and timestamps generally.
- **Producer-asserted, kernel-verifiable**: substrate, isolation,
  outcome, conclusion, label, plan-hash, policy-id payload
  fields. Mint API validates structure only; broker FSM and
  gateway re-check via Ring 1 telemetry / external-API queries
  per registry v0.3.2 §Cross-context enforcement layer.

### `Decision.reason_kind` reservations

Five new rejection-class names reserved (posture-only; schema
enum lands per `.agents/skills/hcs-schema-change`):

- `runner_isolation_unverified` — operation cited a runner
  without paired `RunnerIsolationObservation`.
- `runner_substrate_forbidden` — operation matched one of the
  five HCS forbidden runner families above.
- `status_check_source_required` — operation consumed a self-
  hosted check result without paired
  `StatusCheckSourceObservation` (sub-decision (d)).
- `workflow_run_evidence_drift` — `WorkflowRunReceipt`'s
  `conclusion_kind` differs from current GitHub state at
  Layer 2/3 re-check.
- `policy_plan_outcome_failed` — operation consumed a
  `PolicyPlanReceipt` with `conftest_outcome_kind: "fail"` for
  a `worktree_mutation` or `external_control_plane_mutation`
  class operation.

Per ADR 0029 v2 §`block` vs forbidden-tier framing, all five
rejection classes are *Decision-level* (this-invocation rejects);
none promotes the operation to forbidden tier. The five
forbidden-runner *families* (above §Five HCS forbidden families)
are tier-level forbidden, distinct from Decision-level rejection
classes.

### Out of scope

This ADR does not authorize:

- Zod schema source for any of the six entities. Schema lands
  per `.agents/skills/hcs-schema-change` after acceptance.
- `evidenceSubjectKindSchema` enum extension for the six new
  subject-kind values (`runner_host`, `runner_isolation`,
  `workflow_run`, `clean_room_smoke`, `resource_budget`,
  `policy_plan`). Schema PR commits.
- `Decision.reason_kind` enum extension for the five new
  reservations. Schema PR commits.
- Promotion of `CleanRoomSmokeReceipt` or `PolicyPlanReceipt`
  to proof composite (Q-011 bucket 3). Reserved for follow-up
  ADRs if and when a future operation class consumes them as
  gating evidence.
- `StatusCheckSourceObservation` Zod schema or full receipt
  shape. Q-005 names the requirement; Q-006 stage-2 / stage-3
  owns the receipt shape.
- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. The five
  forbidden-runner families are posture-only here; canonical
  rule entries land in `tiers.yaml` once HCS Milestone 2 ships.
- Citadel OPA policy bundle definitions. Citadel's
  infrastructure rules (runner provisioning, network egress,
  OpenTofu state schema) are out of HCS scope per the
  Citadel-vs-HCS boundary above.
- Charter invariant text. The Citadel-HCS boundary and the five
  forbidden families compose with existing inv. 1 / 5 / 7 / 8 /
  13 / 15 / 16 / 17 without requiring new invariants. Future
  charter v1.4.0 may codify "HCS does not own external CI
  control-plane policy" as an explicit invariant; that
  amendment lands per change-policy in a separate PR.
- Q-007 (b)–(f) sub-decisions. Q-007's `QualityGate` deferral
  cadence depends on Q-005 + Q-006 settling; Q-005 settles
  here, but Q-007 (b) acceptance requires Q-006 (b)–(g)
  closure, which is a separate Q-row.
- Stage-2 runner/check receipts (e.g.,
  `WorkflowPolicyObservation`, `RemoteAgentEnvironmentReceipt`).
  Reserved for follow-up Q-005 stage-2 or Q-010 when remote-
  agent execution evidence work begins.
- Multi-runner-host coordination facts. A
  `CoordinationFact.subject_kind: "runner_host"` is a future
  candidate for the §Predicate-kind vocabulary registry update;
  not committed by this ADR.

## Consequences

### Accepts

- Q-005 is settled at the design layer with six runner/check
  evidence subtypes, a two-side Citadel-HCS policy boundary,
  five HCS forbidden runner families, and a typed source-
  identity requirement before consuming self-hosted check
  results.
- All six runner/check entities are `Evidence` subtypes
  (Q-011 bucket 1) matching ADR 0027 v2 / ADR 0030 v2 stage-1+2
  pattern.
- `RunnerIsolationObservation` is a `BoundaryObservation`
  payload for the `runner_isolation` boundary dimension; the
  dimension promotes from proposed → accepted with this ADR.
- `ResourceBudgetObservation` feeds the existing accepted
  `ResourceBudget` entity (Q-011 dedupe rule); does NOT
  duplicate as a standalone entity.
- `CleanRoomSmokeReceipt` and `PolicyPlanReceipt` land as
  Evidence receipts (bucket 1); promotion to proof composite
  reserved for follow-up ADRs if a future operation class
  consumes them as gating evidence.
- `WorkflowRunReceipt` preserves the run-vs-check distinction
  from Q-006 candidate `CheckRunReceipt`; both names reserved.
- Citadel OPA owns infrastructure (provisioning, network egress,
  OpenTofu state, runner-token lifecycle, workflow-YAML
  required-check shapes, action version pinning). HCS owns
  per-operation evidence consumption + mutation_scope + audit +
  approval grants + forbidden-family enforcement. The two
  systems do not duplicate policy YAML.
- Five HCS forbidden runner families committed (posture-only):
  `forbidden.runner.public_fork_to_self_hosted`,
  `forbidden.runner.generic_self_hosted_label`,
  `forbidden.runner.macbook_always_on_ci`,
  `forbidden.runner.tokens_in_state`,
  `forbidden.runner.docker_socket_to_untrusted`. All five
  non-escalable per charter inv. 6.
- HCS gates self-hosted check results on a paired typed
  `StatusCheckSourceObservation` evidence record (commit_sha +
  check_name + expected source app/workflow + conclusion +
  freshness window + source_kind + WorkflowPolicyObservation
  pair). Check-name-only consumption rejected with
  `Decision.reason_kind: status_check_source_required`. The
  receipt shape lands under Q-006 stage-2 / stage-3.
- Five new `Decision.reason_kind` rejection-class names
  reserved (posture-only): `runner_isolation_unverified`,
  `runner_substrate_forbidden`, `status_check_source_required`,
  `workflow_run_evidence_drift`, `policy_plan_outcome_failed`.
- Six new `evidence_subject_kind` enum values reserved:
  `runner_host`, `runner_isolation`, `workflow_run`,
  `clean_room_smoke`, `resource_budget`, `policy_plan`.
- Cross-context binding rules per Ring 1 layer explicit per
  registry v0.3.0 requirement.
- Authority discipline follows registry v0.3.2; identity and
  freshness fields kernel-set; substrate/isolation/outcome
  fields producer-asserted but kernel-verifiable.
- Q-007(b) (`QualityGate` deferral cadence) is partially
  unblocked: Q-005 settles; Q-006(g) check-result gateability
  remains.

### Rejects

- Promoting runner facts to standalone Ring 0 entities now
  (Option B). Most observations are freshness-bound;
  `ResourceBudgetObservation` would duplicate the accepted
  `ResourceBudget` entity per Q-011 dedupe rule.
- HCS as parallel CI control plane (Option C). Citadel owns
  OpenTofu provider ecosystem and state backend; duplication
  violates charter inv. 1.
- Citadel-PaC-only enforcement of the five forbidden runner
  families. HCS must refuse to consume green checks from
  forbidden configurations at the operation boundary; Citadel
  blocks bad workflow YAML at the source.
- Check-name-only consumption of self-hosted check results.
  An attacker registering a GitHub App publishing the same
  check name is the failure mode the
  `StatusCheckSourceObservation` requirement closes.
- HCS storage of runner registration tokens (charter inv. 5).
- HCS-scope OpenTofu plan / state authoring. Citadel owns the
  IaC ecosystem.
- Proof-composite promotion of `CleanRoomSmokeReceipt` /
  `PolicyPlanReceipt` in this ADR. Reserved for follow-up.

### Future amendments

- Schema PR per `.agents/skills/hcs-schema-change` for the six
  evidence subtypes + five `Decision.reason_kind` reservations.
- Q-006 stage-2 / stage-3 ADR commits
  `StatusCheckSourceObservation` receipt shape (precondition
  for HCS gateway implementation of sub-decision (d)
  enforcement).
- Promotion of `runner_isolation` boundary dimension from
  proposed → accepted in `ontology-registry.md` (registry
  update PR after this ADR's acceptance).
- Q-005 stage-2 ADR if a future incident motivates additional
  receipts (e.g., `WorkflowPolicyObservation`,
  `RemoteAgentEnvironmentReceipt`).
- Promotion of `CleanRoomSmokeReceipt` / `PolicyPlanReceipt`
  from Evidence receipt to proof composite if a future
  operation class consumes them as gating evidence.
- Canonical policy YAML at Milestone 2 commits the five
  forbidden-runner family rule entries; the
  `Decision.reason_kind` enum extension; the
  `StatusCheckSourceObservation` consumption rule; and any
  per-substrate-kind freshness windows.
- Charter v1.4.0 candidate codifying "HCS does not own external
  CI control-plane policy" as a forbidden-pattern amendment.
- Citadel-HCS coordination ADR covering shared vocabulary
  (runner-host identity, workflow-run identity, policy-plan
  identity) if cross-system schema drift becomes a friction
  point.
- `CoordinationFact.subject_kind: "runner_host"` for cross-
  session runner-state coordination, gated on a motivating
  incident.

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md` v1.3.2,
  invariants 1, 4, 5, 6, 7, 8, 13, 15, 16, 17.
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
  (boundary dimensions including `runner_isolation` proposed-
  to-accepted promotion; Naming suffix discipline; Authority
  discipline; Cross-context enforcement layer).
- Decision ledger: `DECISIONS.md` Q-005, Q-006, Q-007.
- ADR 0015:
  `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
  (frames GitHub, Citadel, Proxmox as external control planes
  HCS consumes via typed evidence; charter inv. 16 origin).
- ADR 0019:
  `docs/host-capability-substrate/adr/0019-knowledge-and-coordination-store.md`
  (Q-003 v3 final; CoordinationFact composition pattern; future
  `subject_kind: "runner_host"` candidate).
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (BoundaryObservation envelope used by
  `RunnerIsolationObservation`; `runner_isolation` boundary
  dimension origin).
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract; payload-versioned envelope pattern).
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (Q-006 stage-1 v2 final; `evidenceSchema`-direct typed payload
  pattern Q-005 mirrors; first-commit-SHA-rooted `repository_id`
  resolution).
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (Q-008(a) v4 final; receipt vs observation distinction;
  three-receipt pattern).
- ADR 0029:
  `docs/host-capability-substrate/adr/0029-q-008-b-anomalous-capture-blocking-thresholds.md`
  (Q-008(b) v2 final; `block` vs forbidden-tier framing;
  Decision-level rejection classes pattern Q-005 mirrors).
- ADR 0030:
  `docs/host-capability-substrate/adr/0030-q-006-stage-2-source-control-evidence-subtypes.md`
  (Q-006 stage-2 v2 final; six-receipt acceptance pattern Q-005
  mirrors; precondition for `StatusCheckSourceObservation`
  receipt shape under Q-006 stage-2/stage-3).
- ADR 0031:
  `docs/host-capability-substrate/adr/0031-q-008-d-worktree-ownership-composition.md`
  (Q-008(d) v1 final; ApprovalGrant.scope per-class extension
  pattern Q-005 mirrors for runner-host approval grants).
- Q-005 source brief:
  `docs/host-capability-substrate/research/external/2026-04-26-proposed-runner-architecture.md`
  (589 lines; primary research source).
- Local-first CI design:
  `docs/host-capability-substrate/local-first-ci-opentofu-runner-design.md`
  (six-receipt enumeration at lines 240, 243, 247, 251, 255).
- Q-011 dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
  (Q-011 entity guidance for Q-005 candidates at lines 116–121).
- Version-control authority consult:
  `docs/host-capability-substrate/research/local/2026-05-01-version-control-authority-consult-synthesis.md`
  (Q-005 + Q-006 shared check-source vocabulary at lines 61–64,
  167).
- Quality-management synthesis:
  `docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md`
  (Q-005 scope guidance at line 212).
- GitHub agentic surface:
  `docs/host-capability-substrate/research/local/2026-04-29-github-version-control-agentic-surface.md`
  (Q-005 / Q-006 interlock at lines 29, 340).
- Agentic-tool isolation synthesis:
  `docs/host-capability-substrate/research/local/2026-05-01-agentic-tool-isolation-synthesis.md`
  (Q-010 cross-references at lines 151, 239, 271–273).
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`.

### External

- GitHub Actions self-hosted runners:
  <https://docs.github.com/en/actions/hosting-your-own-runners>
- GitHub status checks API:
  <https://docs.github.com/en/rest/checks>
- GitHub branch protection rules / required status checks:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches>
- OpenTofu (Terraform) plan / apply lifecycle:
  <https://opentofu.org/docs/cli/run/>
- Conftest (OPA-based testing for IaC):
  <https://www.conftest.dev/>
