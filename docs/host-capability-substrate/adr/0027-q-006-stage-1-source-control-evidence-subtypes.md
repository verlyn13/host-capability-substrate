---
adr_number: 0027
title: Q-006 stage-1 source-control evidence subtypes (Repository, Remote, BranchProtection)
status: proposed
date: 2026-05-02
revision: 2
charter_version: 1.3.2
tags: [git, github, evidence-subtype, branch-protection, q-006, q-008, phase-1]
---

# ADR 0027: Q-006 stage-1 source-control evidence subtypes

## Status

proposed (revision 2)

## Date

Drafted 2026-05-02; revision 2 same day after the post-merge subagent
review on revision 1 returned 10 blocking findings (4 architect, 0
ontology, 6 security). Revision 2 closes them. Cross-cutting design
rules surfaced during the review (authority field placement,
cross-context enforcement layer) are codified in
`docs/host-capability-substrate/ontology-registry.md` v0.3.0; this ADR
cites that registry rather than re-litigating.

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.0 (codified
suffix discipline, version-field naming, authority discipline,
cross-context enforcement layer, redaction posture).

## Context

ADR 0020 (accepted 2026-05-01) committed Q-006's limited posture: five
near-term review names plus a deferred broader inventory of fourteen
candidate Q-006 receipts pending Q-011-guided ontology review. Q-011
was approved 2026-05-01 and the registry codification landed in
registry v0.2.0 (suffix discipline), v0.2.1 (version-field naming),
and v0.3.0 (authority + cross-context + redaction discipline).

This ADR is the first **stage-1 expansion** of the broader Q-006
inventory. It commits posture for three foundational receipts:

- `GitRepositoryObservation`
- `GitRemoteObservation`
- `BranchProtectionObservation`

Selection rationale (load-bearing minimum):

- `GitRepositoryObservation` is foundational. ADR 0025 v2's
  `repository_id` provenance ("set by the minting service from
  `WorkspaceContext` resolution") needs a typed observation behind it.
  Without it, every other Q-006 receipt has a forgeable repository
  binding.
- `GitRemoteObservation` directly closes the 2026-04-30 ScopeCam
  exchange motivating failure: "remote-gone" becomes a typed
  observation about one specific ref on one remote at one
  observed_at, not an agent assertion.
- `BranchProtectionObservation` unblocks the architecturally
  interesting half of ADR 0026 (substrate hook architecture for
  non-literal protected refs); without it, ADR 0026 reduces to a
  documentation refinement of the existing literal-protected-list.

The remaining five Q-006 receipts named as ADR 0025 v2 schema gating —
`GitWorktreeObservation`, `GitWorktreeInventoryObservation`,
`GitBranchAncestryObservation`, `GitDirtyStateObservation`,
`PullRequestReceipt`, `PullRequestAbsenceReceipt` — are stage-2 work.
A separate stage-2 ADR will follow.

This ADR does not implement schemas, generated JSON Schema, policy
tiers, hooks, adapters, dashboard routes, runtime probes, or mutation
operations. It is doc-only and posture-only, mirroring ADR 0020's
limited-posture pattern.

## Options considered

### Option A: All three as standalone Evidence subtype envelopes (own envelope shapes)

**Pros:**
- Parallel structure to `BoundaryObservation`.
- Type-system clarity at the envelope level.

**Cons:**
- Multiplies envelope shapes when most receipts can use ADR 0023's
  `Evidence` base directly with a typed `payload_schema_version` and
  `payload`.
- Couples Q-006 receipts more tightly than they need to be.

### Option B: All three as `BoundaryObservation` payloads

**Pros:**
- Reuses one canonical envelope.
- Cross-context binding discipline already enforced.

**Cons:**
- Pollutes the `boundary_dimension` registry with non-boundary
  identification facts (a repository's existence and a remote's
  last-fetch state are not contextual boundary claims).
- Conflates two distinct mental models.

### Option C: Mixed — `evidenceSchema` direct for Repository and Remote; `BoundaryObservation` payload for BranchProtection (chosen)

**Pros:**
- `GitRepositoryObservation` and `GitRemoteObservation` are factual
  state observations that fit ADR 0023's `Evidence` base contract with
  a typed payload directly. `evidence_kind: "observation"` already
  exists; `subject_refs` already supports `git_repository` and
  `git_ref` subject kinds.
- `BranchProtectionObservation` is a contextual classification that
  fits the `BoundaryObservation` mental model.
- Avoids both pitfalls: no envelope-multiplication; no
  registry-pollution.

**Cons:**
- Requires the `boundary_dimension` registry to gain a new dimension
  (`branch_protection`) when schema implementation lands. Registration
  flow is established.

## Decision

Choose Option C. Revision 2 adds explicit authoring discipline,
freshness rules, redaction posture, and cross-context enforcement
binding for each of the three receipts.

### Authoring discipline (Ring 1 mint API)

All three receipts are **minted by Ring 1 services**; producers
supply observation data, not authority claims. Per registry v0.3.0
§Authority discipline, fields whose value determines or strongly
implies the evidence record's authority class are kernel-set, never
producer-supplied.

For these three receipts:

- The mint API resolves the `Evidence.authority` class from the
  producer's `ExecutionContext` (sandbox vs host vs installed-runtime
  GitHub API client).
- `repository_id` is resolved by the mint API from the requesting
  session's `WorkspaceContext`; agent-supplied `repository_id` is
  rejected.
- Cross-context binding rejection lives in the three Ring 1 layers
  named in registry v0.3.0 §Cross-context enforcement layer (mint
  API + broker FSM re-check + gateway re-derive).

### `GitRepositoryObservation`

A typed `Evidence` record using `evidenceSchema` from ADR 0023
directly, with:

- `evidence_kind: "observation"`
- `subject_refs` includes
  `{subject_kind: "git_repository", subject_id: <repository_id>}`.
- `payload_schema_version: "git_repository_observation:v1"` (canonical
  exact value to be set when schema implementation lands).
- `payload` shape (candidate field block):

```text
repository_id
git_dir_path                                           // redacted_to canonical form per redaction_mode
work_tree_path optional                                 // redacted_to canonical form per redaction_mode
default_branch optional
remote_observation_evidence_refs   array (min(1) when remotes exist)
detected_at
```

Note: `detected_by` (kernel_probe / host_telemetry / sandbox_marker)
is **not** in the producer payload. Per registry v0.3.0 §Authority
discipline, the producer-context source is a kernel-set field on
`Evidence` itself (`producer` field), populated by the mint API from
the requesting session's `ExecutionContext`.

**`repository_id` resolution rule.** The Ring 1 mint API resolves
`repository_id` from the **first-commit SHA** of the worktree's HEAD
ancestry (`git log --reverse --max-parents=0 --format=%H -n 1` or
equivalent). Rationale: filesystem path is mutable via `.git/` writes;
remote URL is mutable via `.git/config` writes; the first-commit SHA
cannot be forged without rewriting history (which produces a
different SHA). Multi-root repositories (octopus merges with multiple
historical roots) resolve to the lexicographically smallest
first-commit SHA. Empty repositories (no commits) have undefined
`repository_id`; the mint API rejects observations from empty repos
until the first commit lands. The audit trail for the resolution is
the `Evidence.workspace_id` reference plus the first-commit-SHA chain
recorded by the mint API.

**Freshness invalidation triggers.** A `GitRepositoryObservation`
record's freshness is bounded by:

- The Evidence base `valid_until` window (canonical-policy-driven
  numeric value).
- `.git/config` change events (remote URL or remote inventory change
  invalidates).
- Worktree HEAD change events (branch state shift may invalidate
  `default_branch`).
- Repository identity does not change while `valid_until` holds; new
  freshness is required after invalidation.

**Redaction posture.** Per registry v0.3.0 §Redaction posture, the
canonical persistence-redaction field is `Evidence.redaction_mode`.
For `GitRepositoryObservation` payloads, the default
`redaction_mode` is `redacted`: `git_dir_path` and `work_tree_path`
are normalized to canonical form (user-home replaced with `~`,
container-mount paths normalized) before persistence. Raw paths
containing user-identifying material are not committed to the audit
chain.

**Cross-context binding rules.**

- `repository_id` matches across producer's `ExecutionContext` and
  the mint-API-resolved value (mint-API rejection on mismatch).
- `remote_observation_evidence_refs` references `GitRemoteObservation`
  records consistent with the same `repository_id` and the same
  resolution session (mint-API rejection on mismatch).

### `GitRemoteObservation`

A typed `Evidence` record using `evidenceSchema` directly, with
**per-(repository, remote_name, ref) grain**:

- `evidence_kind: "observation"`
- `subject_refs` includes
  `{subject_kind: "git_ref", subject_id: "<repository_id>/<remote_name>/<ref_name>"}`.
- `payload_schema_version: "git_remote_observation:v1"`.
- `payload` shape (candidate field block):

```text
repository_id
remote_name
remote_url                                             // redacted per redaction_mode (URL credentials stripped)
ref_class            enum: branch | tag | other | unknown
ref_name
observed_commit_sha   nullable    // null when ref_state in {gone, ambiguous, unknown}
last_fetch_at
last_fetch_outcome   enum: ok | network_error | auth_error | rejected
ref_state            enum: present | gone | ambiguous | unknown
```

**`ref_class` discriminator.** The audit-finding-driven addition;
distinguishes branch refs from tag refs (and other ref classes) so
downstream proof composites (e.g., ADR 0025 v2's
`BranchDeletionProof`) can bind only to `ref_class: branch`
observations. A `GitRemoteObservation` with `ref_class: tag` cannot
be passed off as a branch-ref observation; the mint API enforces the
discriminator from the underlying ref-name format
(`refs/heads/...` vs `refs/tags/...` vs other).

**`last_fetch_outcome` verifiability rule.** Per registry v0.3.0
§Authority discipline, operational claims are producer-asserted but
must be kernel-verifiable. The producer asserts `last_fetch_outcome`
based on transport result; the kernel re-verifies via separate
evidence (`ToolInvocationReceipt` from ADR 0028 plus
`CommandCaptureReceipt` for the producing `git fetch` invocation).
Mismatch between producer claim and kernel-verified transport result
fails composition at the broker FSM re-check (registry v0.3.0
§Cross-context enforcement layer layer 2).

**`ref_state` gateway behavior.** The gateway's interpretation of
`ref_state` values (registry v0.3.0 §Cross-context enforcement layer
layer 3 territory; canonical-policy-driven specifics):

- `present`: deletion-relevant evidence is fresh; gateway proceeds.
- `gone`: deletion-relevant evidence requires fresh fetch (within
  freshness window) AND `last_fetch_outcome: ok`. Stale `gone`
  observations are rejected.
- `ambiguous`: gateway BLOCKS deletion. The ref state cannot be
  proven either present or gone; deletion is not gateable.
- `unknown`: gateway BLOCKS deletion. No observation backing.

These rules close the ScopeCam motivating failure at the gateway
layer: an agent that observed `ref_state: gone` from a stale fetch
cannot use that observation as deletion authority because the
gateway re-verifies freshness at decision time.

**Redaction posture.** Default `redaction_mode` is `redacted`:
`remote_url` is normalized to strip embedded credentials (e.g.,
`https://user:token@host/path` → `https://host/path`) before
persistence. Per charter inv. 5, raw secret material in URL
user-info or query-string parameters is never committed to the
audit chain.

**Cross-context binding rules.**

- `repository_id` must match the parent `GitRepositoryObservation`'s
  `repository_id` (mint-API rejection on mismatch).
- A "remote-as-a-whole" question (e.g., does `origin` exist as a
  remote? what is its current URL?) is captured in
  `GitRepositoryObservation.payload.remote_observation_evidence_refs`
  plus per-remote-per-ref `GitRemoteObservation` records. A separate
  `GitRemoteInventoryObservation` is queued only if a future incident
  shows the per-(remote, ref) shape leaves a gap.

### `BranchProtectionObservation`

A `BoundaryObservation` payload (per ADR 0022's envelope) for a new
`branch_protection` boundary dimension, registered as `proposed` in
`docs/host-capability-substrate/ontology-registry.md` when schema
implementation lands.

- `BoundaryObservation.boundary_dimension: "branch_protection"`
- `BoundaryObservation.tool_or_provider_ref`: the branch / ruleset
  target reference (e.g., `<repository_id>:branch:<remote_name>:<ref_name>`).
- `BoundaryObservation.observed_payload` shape (candidate, payload
  schema family `branch_protection:v1`):

```text
repository_id
remote_name                                            // matches the deletion-target remote
ref_name
protection_kind   enum: classic_protection | ruleset | both | none | unknown
ruleset_id        optional
ruleset_version   optional
required_check_names   array
required_review_count  optional
restrictions_push     enum: blocked | allowed | bypass_only
restrictions_delete   enum: blocked | allowed | bypass_only
restrictions_force_push enum: blocked | allowed | bypass_only
bypass_actor_count    optional       // count, not actor names
linear_history_required optional
last_observed_at
```

**Authoring discipline.** Per registry v0.3.0 §Authority discipline,
producer-supplied authority-class fields are forbidden. The mint API
resolves `Evidence.authority` based on the producer's
`ExecutionContext`:

- GitHub API client (`gh api repos/.../branches/.../protection`)
  invoked from a verified host installation: `installed-runtime`
  authority.
- Local pre-push hook claim or ruleset metadata cached locally:
  `host-observation` (host) or `sandbox-observation` (sandbox) per
  inv. 8.
- Self-asserted producer claim with no telemetry: `self-asserted`
  authority per registry v0.3.0 (cannot satisfy ADR 0025 v2's
  `is_protected` field for the gateway's layer-3 re-check).

**Redaction posture.** Default `redaction_mode` is `redacted`:
`bypass_actor_count` is a count, not actor names (which would risk
PII exposure); `ruleset_id` is a provider object reference (not a
secret); `required_check_names` are typed strings, audit-safe.

**Cross-context binding rules.**

- The `repository_id` in the payload must match the
  `GitRepositoryObservation` for the same surface.
- The `remote_name` in the payload must match the deletion target's
  `remote_name`. **This closes the multi-remote attack surface:** an
  observation from a fork's `main` branch (unprotected in fork)
  cannot be used to authorize deletion of `main` on upstream
  (protected in upstream) because the cross-binding rule rejects
  the mismatch at the mint API.
- The `boundary_dimension: branch_protection` registry entry will
  name `tool_or_provider_ref` as the primary target reference and
  `workspace_id` as an allowed supplemental.

### Authority handling (cross-cutting; per registry v0.3.0)

- Local Git operations (`git remote -v`, `git config --get`, fetched
  state from `.git`) produce `host-observation` authority on host or
  `sandbox-observation` in a sandbox per inv. 8.
- GitHub API responses produce `installed-runtime` authority when
  issued by a verified authoritative tool installation.
- Sandbox-context observations remain `sandbox-observation` and
  cannot be promoted (charter inv. 8).
- Producer claims without backing telemetry produce `self-asserted`
  authority per registry v0.3.0 §Self-assertion authority class.
- Authority-class fields (`detected_by`, equivalent producer-context
  signals) are kernel-set only; not in producer payloads.

### Out of scope

This ADR does not authorize:

- Schema source (Zod, generated JSON Schema, tests, fixtures).
- The remaining five Q-006 stage-2 receipts.
- Adding `branch_protection` to the `boundary_dimension` registry
  or to `boundaryDimensionSchema` enum (deferred to schema
  implementation PR per ontology-registry §Adding or removing a
  dimension and §Registration rules rule 7).
- Adding `self-asserted` to the `evidenceAuthoritySchema` enum
  (deferred to a separate schema-change PR; registry v0.3.0
  §Self-assertion authority class records the rule).
- ADR 0026 substrate hook architecture (separate ADR, gated on
  `BranchProtectionObservation` schema acceptance).
- Q-006 broader receipt inventory beyond the three stage-1 picks.
- GitHub API call shapes, MCP tool definitions, dashboard routes,
  runtime probes.
- Mutating Git operations.
- Setting canonical wall-clock freshness windows.

## Consequences

### Accepts

- The three stage-1 Q-006 receipts are committed by name and shape.
  Future schema work targets these names without re-litigation.
- `evidenceSchema` (ADR 0023) is the canonical envelope for non-
  contextual-boundary Q-006 receipts.
- `GitRemoteObservation` per-(repository, remote_name, ref) grain
  with `ref_class` discriminator is the canonical answer for
  ScopeCam-style "remote-gone" observations and forecloses tag-vs-
  branch confusion.
- `BranchProtectionObservation` is a `BoundaryObservation` payload
  for a future `branch_protection` dimension, with a `remote_name`
  field that closes the multi-remote attack surface.
- The repository identity chain (first-commit-SHA-rooted
  `repository_id` resolved from `WorkspaceContext` →
  `GitRepositoryObservation` → child observations) is the canonical
  cross-context binding for Q-006 work.
- Per registry v0.3.0:
  - Authority-class fields are kernel-set; producer payload contains
    observation data only.
  - Cross-context binding rejection happens at three Ring 1 layers
    (mint API + broker FSM + gateway), not at the schema layer.
  - Persistence redaction follows `Evidence.redaction_mode`; default
    is `redacted` for all three receipts (URL credentials stripped,
    paths normalized, no PII in payloads).
- ADR 0025 v2 component evidence subtypes (`GitRepositoryObservation`,
  `GitRemoteObservation`) are now committed at posture level,
  unblocking the `BranchDeletionProof` schema implementation step.
- ADR 0026 substrate hook architecture has a typed
  `BranchProtectionObservation` to consume for non-literal
  protected-ref classification.

### Rejects

- Embedding repository identity, remote state, and branch protection
  into a single `OperationShape` argument shape.
- Treating "ref not visible in last fetch" as deletion authority
  without a fresh `GitRemoteObservation`.
- Producer-supplied authority-class fields in any of the three
  receipts (per registry v0.3.0 §Authority discipline).
- Filesystem-path-derived or remote-URL-derived `repository_id`
  resolution. First-commit-SHA-rooted is canonical.
- Cross-remote `BranchProtectionObservation` reuse (fork's
  protection observation used to gate upstream deletion).
- Tag-ref `GitRemoteObservation` records passed as branch-ref
  observations (the `ref_class` discriminator forbids).
- Schema-layer cross-context binding enforcement (per registry v0.3.0
  §Cross-context enforcement layer; binding lives at Ring 1).
- Promoting sandbox-observed branch protection to host-authoritative.
- Treating `gh api` response in a sandbox-observation execution
  context as `host-observation` authority.
- Stale `ref_state: gone` observations as deletion authority.
- Raw URL credentials, user-home paths, or actor names in audit-
  chain payloads.

### Future amendments

- Stage-2 ADR (next in sequence) covers `GitWorktreeObservation`,
  `GitWorktreeInventoryObservation`, `GitBranchAncestryObservation`,
  `GitDirtyStateObservation`, `PullRequestReceipt`,
  `PullRequestAbsenceReceipt`. ADR 0025 v2 schema implementation
  gates on stage-2 plus stage-1 landing.
- Schema-change PR for `evidenceAuthoritySchema` adding
  `self-asserted` (separate from this ADR).
- Schema-change PR for `boundaryDimensionSchema` adding
  `branch_protection` (separate, with the BranchProtectionObservation
  payload schema).
- ADR 0026 (substrate hook architecture) follows once
  `BranchProtectionObservation` schema lands.
- Reopen if Q-005 runner work introduces remote-only repository
  facts.
- Reopen if Q-006 sub-decision (e) (split GitHub MCP read/mutation
  authority) changes the authority assignment for these
  observations.
- Reopen if a future incident shows the per-(remote, ref) grain
  misses a class of remote-state failure.
- Reopen if first-commit-SHA-rooted resolution proves inadequate for
  some repository class (e.g., shallow clones with no first-commit
  visibility).

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md` v1.3.2,
  invariants 1, 5, 6, 7, 8, 16, 17 (and v1.3.2 wave-3 forbidden
  patterns)
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.0
  (codified suffix discipline, version-field naming, authority
  discipline, cross-context enforcement layer, redaction posture)
- Decision ledger: `DECISIONS.md` Q-006, Q-008, Q-011
- ADR 0020:
  `docs/host-capability-substrate/adr/0020-version-control-authority.md`
  (originating Q-006 limited posture; deferred receipt list)
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (BoundaryObservation envelope used by `BranchProtectionObservation`)
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract used by all three stage-1 receipts;
  evidenceAuthoritySchema; redaction_mode)
- ADR 0024:
  `docs/host-capability-substrate/adr/0024-charter-v1-3-wave-2-and-3.md`
  (charter enforcement plumbing)
- ADR 0025:
  `docs/host-capability-substrate/adr/0025-branch-deletion-proof.md`
  (consumes stage-1 receipts for BranchDeletionProof composition)
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (parallel-track ADR; ToolInvocationReceipt + CommandCaptureReceipt
  used to verify GitRemoteObservation.last_fetch_outcome)
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- Ontology promotion/dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- 2026-05-02 system-config security audit evidence:
  `docs/host-capability-substrate/research/local/2026-05-02-system-config-security-audit-evidence.md`

### External

- Git `git-remote` documentation:
  <https://git-scm.com/docs/git-remote>
- Git `git-config` documentation:
  <https://git-scm.com/docs/git-config>
- Git `git-log` documentation (first-commit resolution):
  <https://git-scm.com/docs/git-log>
- GitHub branch protection API:
  <https://docs.github.com/en/rest/branches/branch-protection>
- GitHub rulesets API:
  <https://docs.github.com/en/rest/repos/rules>
- GitHub repository settings:
  <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features>
