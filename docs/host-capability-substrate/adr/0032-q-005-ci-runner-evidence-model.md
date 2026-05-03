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

proposed (v2)

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Revision history

- **v1** (2026-05-03, commit `4056b8d`): initial draft. Reviewers
  surfaced 6 blocking findings (2 ontology, 4 security) plus
  ~16 non-blocking concerns.
- **v2** (2026-05-03, this revision): closes all 6 blockers and
  folds 16 consolidated non-blocking observations.
  - **Ontology O-B1.** Flattened forbidden-family names from
    dotted notation (`forbidden_runner_public_fork_to_self_hosted`)
    to `lower_snake_case` per registry §Sub-rule 9
    (`forbidden_runner_public_fork_to_self_hosted`,
    `forbidden_runner_generic_self_hosted_label`,
    `forbidden_runner_macbook_always_on_ci`,
    `forbidden_runner_tokens_in_state`,
    `forbidden_runner_docker_socket_to_untrusted`).
  - **Ontology O-B2.** Replaced bare `docker_socket_exposure: bool`
    with discriminator `docker_socket_exposure_kind: "none" |
    "host_workflow_only" | "all_workflows" | "unknown"` per
    registry §Sub-rule 6 (matches ADR 0030 v2 `lock_state` 3-state
    precedent for security-sensitive multi-state fields).
  - **Security S-B1.** Added §`PolicyPlanReceipt` secret-bearing
    content rule. `opentofu_plan_hash` is computed over the
    *redacted* plan output; raw plan content never enters HCS
    evidence storage. `redaction_mode` discipline + registry
    v0.3.0 §Field-level scrubber rule applies to all string-typed
    payload fields including `policy_ids` and `workflow_path`.
  - **Security S-B2.** Declared `RunnerHostObservation.labels`
    scrubber-eligible per registry v0.3.0 §Field-level scrubber
    rule. Producer-supplied labels matching secret-shaped patterns
    rejected at Layer 1 mint API. Same posture for
    `WorkflowRunReceipt.workflow_path`.
  - **Security S-B3.** Moved `runner_host_id` from kernel-set list
    to **producer-asserted, kernel-verifiable** list. Citadel
    mints `runner_host_id` (per Citadel-vs-HCS boundary); HCS
    consumes it as producer-asserted, kernel-verifiable against
    Citadel-emitted `PolicyPlanReceipt` and runner-registration
    state. This avoids the ADR 0028 producer-class authority
    confusion that registry v0.3.2 §Producer-vs-kernel-set was
    written to prevent.
  - **Security S-B4.** Added `registration_epoch` field on
    `RunnerHostObservation` and a typed `runner_deregistration`
    event/Decision class. Citadel-signaled runner-token rotation
    or force-deregistration emits a `runner_deregistration`
    Decision; HCS Layer 2/3 re-checks reject `RunnerHostObservation`
    records whose `registration_epoch` no longer matches
    Citadel state. Mirrors ADR 0019 v3 §Secret-referenced
    sources label-upgrade chunk-invalidation pattern.
  - **Ontology N3.** Renamed `repo_access_class` →
    `repo_access_kind` and `network_egress_class` →
    `network_egress_kind` per registry §Sub-rule 6 (`_class`
    forbidden as a non-discriminator suffix; `_kind` is
    canonical). `host_filesystem_access` retains no-suffix form
    (it's a categorization, not a discriminator selecting
    siblings).
  - **Ontology N7.** Added explicit §`RunnerIsolationObservation`
    flat-field composition framing: all five payload fields
    (`job_environment_kind`, `workspace_cleanup_kind`,
    `docker_socket_exposure_kind`, `network_egress_kind`,
    `host_filesystem_access`) are independent dimensions of
    isolation posture; no top-level discriminator selects which
    subset is required. Matches `BoundaryObservation.observed_payload`
    flat-fact pattern.
  - **Architect F-1, F-2.** Acceptance forward-look explicitly
    cites: (a) `runner_isolation` boundary-dimension promotion
    proposed → accepted as a registry update PR gated on this
    ADR's acceptance; (b) Q-006 stage-2/3 dependency on
    `StatusCheckSourceObservation` receipt shape.
  - **Policy (A).** Added one-line clarification distinguishing
    forbidden-family rejection layer (registration / operation-shape
    layer) from Decision-level `block` matrix layer (receipt-
    consumption layer per ADR 0029 v2).
  - **Policy (B).** Explained `forbidden_runner_tokens_in_state`
    enforcement-layer asymmetry: token-at-rest is a structural
    inv. 5 violation surfaced at policy-lint / capability-
    registration time, not per-invocation.
  - **Policy (C).** Tightened `runner_substrate_forbidden`
    framing: forbidden-family rejections produce audit-chain
    rejection-class entries (per registry v0.3.1 §Audit-chain
    coverage of rejections), not ADR 0029 v2-style Decision-level
    matrix states. The reason_kind is the audit-chain
    discriminator at the rejecting layer, not a matrix cell.
  - **Policy (D).** Added §`StatusCheckSourceObservation`
    interim total-block rule: until Q-006 stage-2/3 ADR commits
    the receipt shape, all self-hosted check-result consumption
    rejects with `status_check_source_required`.
  - **Policy (E).** Added §`ApprovalGrant.scope` per-class
    extension sketch for runner operations:
    `runner_registration` and `runner_deregistration` operation
    classes bind `target_ref: { runner_host_id }` +
    `execution_context_id`. Matches ADR 0031 v1 per-class
    extension pattern.
  - **Security N-1.** ResourceBudgetObservation side-channel
    acknowledgment for future multi-tenant runner deployment.
  - **Security N-2.** MacBook always-on cross-context binding
    rule: even with `workflow_dispatch`, the dispatching
    session's `ExecutionContext` must be human-driven, not
    agent-driven; otherwise an agent rehydrates the same ambient-
    credential exposure.
  - **Security N-3.** StatusCheckSourceObservation App-permission-
    surface drift bypass note: a legitimate App with bound
    `expected_github_app_id` could publish a different check name
    post-binding. Q-006 stage-2/3 commits the freshness re-check
    rule that compares current App permission set against the
    observation's.
  - **Security N-4.** `WorkflowRunReceipt.runner_host_evidence_ref`
    linked-observation inv. 8 discipline: cited
    `RunnerHostObservation` with `Evidence.authority:
    sandbox-observation` cannot promote `WorkflowRunReceipt` to
    host-authoritative gating evidence.
  - **Security N-5.** `PolicyPlanReceipt.repository_id`
    clarification: IaC repo, NOT project repo. Remote OpenTofu
    state backend may live in Citadel-managed remote storage;
    HCS *evidence* of plan execution stays single-host per
    inv. 10.
  - **Security N-6.** Audit-chain inheritance restated for the
    new Citadel-adjacent surface; runner-state Decision events
    participate in audit hash chain per registry v0.3.1.

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
- Payload (illustrative): `runner_host_id` (Citadel-minted; see
  Authority discipline below), `registration_epoch` (Citadel-
  signaled; see §`runner_deregistration` event below),
  `substrate_kind: "github_hosted" | "self_hosted_proxmox" |
  "self_hosted_macbook" | "self_hosted_other"`, `os`, `arch`,
  `labels` (array; scrubber-eligible — see §Scrubber-eligibility
  below), `repo_access_kind: "public" | "private" |
  "fork_isolated"`, `last_seen_at` (kernel-set freshness anchor).

**Grain:** per-`runner_host_id`. A single host may produce many
observations over time; freshness is determined by `last_seen_at`
and the consuming operation's freshness window.

**Authority discipline (registry v0.3.2):**
- **Kernel-set**: `last_seen_at` (HCS-kernel freshness anchor).
- **Producer-asserted, kernel-verifiable**: `runner_host_id`
  (Citadel mints the identifier per the Citadel-vs-HCS
  boundary; HCS consumes it as producer-asserted, kernel-
  verifiable against Citadel-emitted `PolicyPlanReceipt` and
  runner-registration state. HCS does NOT mint identifiers in
  Citadel's authority domain. This avoids the ADR 0028 producer-
  class authority confusion that registry v0.3.2 §Producer-vs-
  kernel-set was written to prevent), `registration_epoch`
  (Citadel-emitted; HCS verifies against current Citadel state
  at Layer 2/3 re-check), `substrate_kind`, `os`, `arch`,
  `labels`, `repo_access_kind`.

**Scrubber-eligibility (charter inv. 5):** `labels` is
declared scrubber-eligible per registry v0.3.0 §Field-level
scrubber rule. GitHub Actions runner labels are operator-
controlled strings that may encode environment hints or
credential material (`prod-aws-account-12345`,
`vault-token-rotation-enabled`). Producer-supplied labels
matching secret-shaped patterns reject at Layer 1 mint API.

**Cross-context binding (registry v0.3.0 §Cross-context
enforcement layer):** Layer 1 enforces `runner_host_id`
consistency with the requesting session's `ExecutionContext`;
Layer 2 re-checks `last_seen_at` freshness AND
`registration_epoch` against current Citadel-signaled state;
Layer 3 re-derives.

**`runner_deregistration` event (closes audit-integrity gap):**
Citadel-signaled runner-token rotation, force-deregistration,
or runner removal emits a typed `runner_deregistration` event
recorded as a typed Decision in the audit hash chain per
registry v0.3.1 §Audit-chain coverage of rejections (extended
to lifecycle events by inheritance). The Decision carries:
- `agent_client_id` + `session_id` of the requesting principal
  (typically a Citadel agent);
- `runner_host_id` of the deregistered runner;
- `prior_registration_epoch` and `new_registration_epoch` (or
  `null` for terminal deregistration);
- `deregistration_kind: "rotation" | "force_deregistration" |
  "runner_removal"` discriminator per registry Sub-rule 6.

After a `runner_deregistration` Decision is emitted, all stale
`RunnerHostObservation` records whose `registration_epoch`
matches the prior epoch are invalidated at Layer 2/3 re-check.
Operations consuming such records reject with
`Decision.reason_kind: runner_observation_stale_post_deregistration`
(NEW reservation; see §`Decision.reason_kind` reservations below).
This mirrors ADR 0019 v3 §Secret-referenced sources label-upgrade
chunk-invalidation pattern: when the upstream authority signals
a state change, derived evidence is invalidated atomically at
the kernel boundary.

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
  `docker_socket_exposure_kind: "none" | "host_workflow_only"
  | "all_workflows" | "unknown"`, `network_egress_kind:
  "internet_full" | "internet_restricted" | "vpn_only" |
  "egress_blocked"`, `host_filesystem_access: "isolated" |
  "shared_workspace" | "shared_host"`.

**Flat-field composition.** All five payload fields are
independent dimensions of isolation posture; no top-level
discriminator selects which subset is required. Matches
`BoundaryObservation.observed_payload` flat-fact pattern. Each
field is observed and reported per runner-lifecycle; the
forbidden-family decisions compose across fields rather than
selecting siblings.

**Grain:** per-runner-lifecycle (the isolation posture for a
single job execution context, not the host-level static config).

**Authority discipline:** observation-class fields kernel-set;
posture-class fields producer-asserted but kernel-verifiable.
`docker_socket_exposure_kind in {"host_workflow_only",
"all_workflows"}` paired with untrusted code is itself an HCS
forbidden-family trigger (see §Five HCS forbidden families
below).

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

**Scrubber-eligibility:** `workflow_path` is declared scrubber-
eligible per registry v0.3.0 §Field-level scrubber rule. A
producer-asserted path matching secret-shaped patterns (e.g.,
embedded credential references) rejects at Layer 1 mint API.

**Linked-observation authority discipline (charter inv. 8):**
when `runner_host_evidence_ref` cites a `RunnerHostObservation`,
the cited observation's `Evidence.authority` cannot be
`sandbox-observation` or `self-asserted` for the consuming
`WorkflowRunReceipt` to be host-authoritative gating evidence.
A receipt whose linked runner observation carries
sandbox-observation authority cannot be promoted to gate
authority per inv. 8 (sandbox-observation non-promotion). The
broker FSM Layer 2 / gateway Layer 3 re-check enforces this
inheritance.

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
  the project repo using the runner; remote OpenTofu state
  backend may live in Citadel-managed remote storage, but HCS
  *evidence* of plan execution stays single-host per charter
  inv. 10),
  `opentofu_plan_hash`, `conftest_outcome_kind: "pass" |
  "fail" | "warn"`, `policy_ids` (array of policy bundle
  identifiers asserted to apply; scrubber-eligible),
  `workspace_id_ref`,
  `provider_versions` (map: provider name → version).

**Grain:** per-(`repository_id`, `opentofu_plan_hash`).

**Secret-bearing content rule (charter inv. 5):** OpenTofu plans
routinely include resolved secret material (provider credentials
interpolated into resource arguments, sensitive variables,
base64-encoded user_data). The following rules apply at all
three Ring 1 layers to prevent plan content from leaking into
HCS evidence storage:

- **`opentofu_plan_hash` provenance.** The hash is computed over
  the *redacted* plan output. The producer's plan-redaction
  step strips secret-shaped content before hashing; raw plan
  content (with resolved secrets) never enters HCS evidence
  storage. Producers that submit a hash computed over raw plan
  content reject at Layer 1 mint API with
  `Decision.reason_kind: secret_resolution_in_chunk` (mirrors
  ADR 0019 v3 §Secret-referenced sources rule, applied to
  PolicyPlanReceipt).
- **`redaction_mode` discipline (registry v0.3.0).** Every
  `PolicyPlanReceipt` carries `Evidence.redaction_mode != none`
  when the source plan contains any secret-shaped content; the
  registry v0.3.0 §Field-level scrubber rule applies to all
  string-typed payload fields including `policy_ids`.
- **Scrubber-eligibility.** `policy_ids` (array of policy bundle
  identifiers, may encode environment hints) and any
  `workflow_path` reference are declared scrubber-eligible.
  Producer-supplied values matching secret-shaped patterns
  reject at Layer 1 mint API.
- **No raw plan content.** Producers may carry summary
  identifiers (plan_hash, conftest_outcome_kind, policy_ids,
  workspace_id_ref, provider_versions) but MUST NOT carry raw
  plan output, plan-side stdout/stderr captures with secret
  references, or any field that materializes resolved secret
  values. The receipt's role is identification + outcome, not
  reproduction of plan content.

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

#### `forbidden_runner_public_fork_to_self_hosted`

Public-fork pull requests targeting self-hosted runners.

**HCS enforcement (gateway):** rejects any
`github.workflow.dispatch.v1`, `scm.pull_request.create.v1`, or
similar operation whose source is a fork PR AND target runner is
not GitHub-hosted (per `RunnerHostObservation.substrate_kind !=
"github_hosted"`).

**Authority:** charter inv. 8 (sandbox-observation non-promotion
— untrusted PR code on self-hosted = host compromise) + inv. 16
(evidence-first — block before rendering any GitHub mutation).

#### `forbidden_runner_generic_self_hosted_label`

Workflow YAML or operation citing a runner with `runs-on:
self-hosted` only (no explicit group + label).

**HCS enforcement (gateway):** rejects operations citing a runner
without explicit group + label in the consuming evidence
(`RunnerHostObservation.labels` array empty or single-`self-hosted`).

**Authority:** charter inv. 17 (execution-context declared, not
inferred) — cannot audit which host/capability was intended
without explicit labels.

#### `forbidden_runner_macbook_always_on_ci`

MacBook self-hosted runner used outside `workflow_dispatch` /
manual gate.

**HCS enforcement (gateway):** rejects MacBook-runner operations
(`RunnerHostObservation.substrate_kind:
"self_hosted_macbook"`) outside `workflow_dispatch` triggers.

**Cross-context binding requirement.** Even when
`workflow_dispatch` is used, the dispatching session's
`ExecutionContext` must be human-driven, not agent-driven.
Otherwise an agent that can call `github.workflow.dispatch.v1`
rehydrates the same ambient-credential exposure the manual-gate
rule was meant to prevent. The gateway enforces this by checking
that the requesting session's `ExecutionContext.actor_kind ==
"human"` (or equivalent canonical-policy field) for any
`workflow_dispatch` operation against a MacBook substrate; agent-
driven sessions are rejected with
`Decision.reason_kind: runner_substrate_forbidden`.

**Authority:** charter inv. 15 (ambient-credentials risk —
MacBook hosts carry SSH keys, 1Password sessions, personal
credentials) + ScopeCam motivating-failure family.

#### `forbidden_runner_tokens_in_state`

Runner registration tokens stored in OpenTofu state.

**HCS enforcement (policy-lint / capability-registration layer):**
rejects any operation that would materialize runner registration
tokens at rest in state. Note: the enforcement layer here is
*policy-lint / capability-registration*, NOT per-invocation
gateway. Token-at-rest is a structural inv. 5 violation surfaced
when an operation's capability declaration is registered (it
never reaches per-invocation gateway evaluation because the
capability registration itself is rejected). This asymmetry vs
the other four families (which are gateway-layer per-invocation
checks) is intentional: secret material at rest is a registration-
layer violation, while the other four are operation-shape
violations evaluated per-invocation.

**Authority:** charter inv. 5 (secrets never at rest in Ring 0/1)
+ inv. 13 (deletion authority is not gitignore — state lifecycle
≠ token lifecycle).

#### `forbidden_runner_docker_socket_to_untrusted`

Docker socket exposed to untrusted code execution targets.

**HCS enforcement (gateway):** rejects operations combining
`RunnerIsolationObservation.docker_socket_exposure_kind in
{"host_workflow_only", "all_workflows"}` with untrusted code
execution target (e.g., fork PR or unverified-actor workflow
dispatch).

**Authority:** charter inv. 17 (execution context declared, not
inferred — Docker socket = host root equivalent).

#### Forbidden-family discipline

All five families are non-escalable per charter inv. 6;
`ApprovalGrant` cannot upgrade a forbidden-family rejection.

**Forbidden-family layer vs Decision-level matrix layer.**
Forbidden-family rejection happens at the registration /
operation-shape layer (or capability-registration layer for
`forbidden_runner_tokens_in_state` per the asymmetry above);
ADR 0029 v2 §`block` matrix cells happen at the receipt-
consumption layer per-invocation. The two layers are distinct
mechanisms, both non-escalable, but for different structural
reasons:
- **Forbidden-family layer**: the operation's *shape*
  (substrate, isolation, target) violates a forbidden pattern
  before any receipt is consumed.
- **Decision-level matrix layer**: the operation's *consuming
  receipt facts* (anomalous capture combinations × operation
  classes) trigger a `block` cell.

The families are tier-orthogonal to ADR 0029 v2 §`block` vs
forbidden-tier framing: a `worktree_mutation` operation
invocation hitting a forbidden-runner cell rejects
unconditionally regardless of the operation's tier.

**Forbidden-family rejection audit-chain entry.** Forbidden-
family rejections produce typed audit-chain rejection-class
entries per registry v0.3.1 §Audit-chain coverage of rejections;
the `runner_substrate_forbidden` reason_kind is the audit-chain
rejection-class discriminator at the rejecting layer (not an
ADR 0029 v2 matrix Decision-level state). See §`Decision.reason_kind`
reservations below.

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

**Interim total-block rule.** Until Q-006 stage-2/3 ADR commits
the `StatusCheckSourceObservation` receipt's full Zod schema,
all self-hosted check-result consumption rejects unconditionally
with `status_check_source_required`. Producers cannot mint a
conformant `StatusCheckSourceObservation` until the shape is
committed; therefore HCS gateway treats every self-hosted check-
result consumption attempt as missing the required evidence and
rejects. The rejection is not a temporary quality-of-life
concern — it is a structural enforcement of charter inv. 16
(external-control-plane evidence-first). Consumers that need
self-hosted check results before Q-006 stage-2/3 must wait or
use GitHub-hosted check results (which may have their own
source-identity requirements once Q-006 stage-2/3 commits).

**App-permission-surface drift.** A bypass remains for legitimate
GitHub Apps with bound `expected_github_app_id`: post-binding,
an App could publish a different check name than expected (App
permission scopes typically allow publishing arbitrary check
names within the repo). The pin via `expected_github_app_id` is
correct but doesn't cover post-binding permission-surface drift.
Q-006 stage-2/3 commits a freshness re-check rule that compares
the current App permission set against the observation's
expected permission set; this ADR names the gap so Q-006 can
close it.

### `ApprovalGrant.scope` per-class extension for runner operations

ADR 0031 v1 §`ApprovalGrant.scope` per-class extension established
the per-class extension pattern. Q-005 commits the per-class
extension shape for runner operation classes (posture-only;
schema source per `.agents/skills/hcs-schema-change` after
acceptance):

A `runner_registration` or `runner_deregistration` operation-
class grant binds:
- `operation_class: "runner_registration" | "runner_deregistration"`
- `target_ref: { runner_host_id }` — per-runner-host grain
  matching `RunnerHostObservation` grain. `runner_host_id` is
  Citadel-minted (per §RunnerHostObservation Authority
  discipline above); the grant binds the producer-asserted
  identifier kernel-verifiable against current Citadel state.
- `execution_context_id` — per registry v0.3.0 §Cross-context
  enforcement layer.

A grant scoped without `runner_host_id` is rejected at Layer 1
mint API. A grant scoped to a different runner host than the
operation's target rejects at Layer 3 gateway re-derive per
inv. 6.

**Scope-key disjointness.** Per ADR 0019 v3 §Scope-key
disjointness rule and ADR 0031 v1 forward-look, the
`runner_registration` and `runner_deregistration` per-class
extension keys are disjoint from `worktree_mutation`,
`destructive_git`, `merge_or_push`,
`external_control_plane_mutation`, and other ADR 0029 v2 /
ADR 0031 v1 per-class extensions. Canonical policy YAML
rejects overlapping scope keys.

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
  family triggers (e.g., `docker_socket_exposure_kind: "all_workflows"` with
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

Six new rejection-class names reserved (posture-only; schema
enum lands per `.agents/skills/hcs-schema-change`):

- `runner_isolation_unverified` — operation cited a runner
  without paired `RunnerIsolationObservation`.
- `runner_substrate_forbidden` — operation matched one of the
  five HCS forbidden runner families above (audit-chain
  rejection-class discriminator at the rejecting layer per
  §Forbidden-family discipline; not an ADR 0029 v2 matrix
  Decision-level state).
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
- `runner_observation_stale_post_deregistration` — operation
  consumed a `RunnerHostObservation` whose `registration_epoch`
  no longer matches current Citadel-signaled state (after a
  `runner_deregistration` event). Closes the audit-integrity
  gap from ADR 0032 v1 review (Security S-B4).

Per ADR 0029 v2 §`block` vs forbidden-tier framing, the five
non-forbidden-family rejection classes are *Decision-level*
(this-invocation rejects); none promotes the operation to
forbidden tier. The `runner_substrate_forbidden` reason_kind is
a hybrid: it is the *audit-chain* rejection-class discriminator
recorded when a forbidden-family rejection happens, but the
underlying mechanism is forbidden-family rejection at the
registration / operation-shape layer (per §Forbidden-family
discipline above), not a Decision-level matrix state. The five
forbidden-runner *families* are tier-level forbidden, distinct
from Decision-level rejection classes; the `runner_substrate_forbidden`
reason_kind is the typed name those rejections carry in the
audit chain.

Note: the secret-resolution-in-chunk rejection class for
`PolicyPlanReceipt` plan-content provenance violations is
`secret_resolution_in_chunk` — this name is shared with ADR
0019 v3's `KnowledgeChunk` secret-resolution rule, mirroring
the same charter inv. 5 violation across both surfaces.

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
  `forbidden_runner_public_fork_to_self_hosted`,
  `forbidden_runner_generic_self_hosted_label`,
  `forbidden_runner_macbook_always_on_ci`,
  `forbidden_runner_tokens_in_state`,
  `forbidden_runner_docker_socket_to_untrusted`. All five
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
