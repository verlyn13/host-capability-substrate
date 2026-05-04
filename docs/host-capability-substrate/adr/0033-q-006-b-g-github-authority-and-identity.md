---
adr_number: 0033
title: Q-006 (b)–(g) GitHub authority, identity reconciliation, and check-source binding
status: accepted
date: 2026-05-03
charter_version: 1.3.2
tags: [github-authority, identity-reconciliation, mcp-credential-split, ruleset-baseline, status-check-source, q-006, phase-1]
---

# ADR 0033: Q-006 (b)–(g) GitHub authority, identity reconciliation, and check-source binding

## Status

accepted (v2 final)

## Date

2026-05-03 (accepted)

## Acceptance note

All four reviewer subagents (`hcs-architect`, `hcs-ontology-reviewer`,
`hcs-policy-reviewer`, `hcs-security-reviewer`) returned READY-FOR-
ACCEPTANCE on v2 (commit `774c5c4`) — except for three documentation-
hygiene fixes (caused by v1→v2 `replace_all` of `mcp_server_name` →
`mcp_server_kind` catching narrative text in the revision history,
plus a stale "Q-011 bucket 2" reference in §Accepts that contradicted
the v2 reclassification of `GitHubMutationAuthority` as an inline
value type). Three mechanical tweaks applied at acceptance:

1. **Self-referential rename in revision history (Architect / Ontology).**
   The Policy P-B3 entry "renamed from v1's `mcp_server_kind`" now
   correctly reads `mcp_server_name`.
2. **Self-referential rename in revision history (Architect / Ontology).**
   The Ontology borderline B1 entry "Renamed `mcp_server_kind` →
   `mcp_server_kind`" now correctly reads `mcp_server_name` →
   `mcp_server_kind`.
3. **§Accepts stale Q-011 bucket citation (Architect / Ontology).**
   The line "`GitHubMutationAuthority` value type committed (Q-011
   bucket 2)" now correctly reads "inline structured field — NOT a
   Q-011 review-grammar bucket member; carried on operation-shape
   evidence and `ApprovalGrant.scope`" matching the v2
   reclassification.

The two-revision review cycle closed:
- 8 v1 blockers (1 architect, 3 policy, 4 security)
- 1 v1 borderline ontology (`mcp_server_name` rename)
- 11 v1 non-blocking observations folded
- 3 v2 documentation-hygiene fixes at acceptance

Eight forward-looking concerns deferred to schema PR / Milestone 2 /
follow-up ADRs (no further ADR-level mechanical tweaks):

- Schema PR per `.agents/skills/hcs-schema-change` for the five new
  evidence subtypes + the `GitHubMutationAuthority` inline value type
  + the six new `Decision.reason_kind` reservations + the
  `ApprovalGrant.scope` per-class extension.
- `evidenceSubjectKindSchema` enum extension for the four new
  subject-kind values (`ruleset`,
  `repository_identity_reconciliation`, `mcp_credential_audience`,
  `status_check_source`).
- Canonical policy YAML at Milestone 2 commits per-`mcp_server_kind`
  audience-class enforcement; per-`repository_id` freshness windows
  for `StatusCheckSourceObservation`; specific GitHub App
  installation identifiers for system-config agentic operations;
  ruleset baseline ID references for HCS / system-config; mutation-
  class × authority-class matrix entries.
- ADR 0032 v2 §StatusCheckSourceObservation interim total-block
  lifts on schema PR landing (NOT on this ADR's acceptance).
- `Decision.reason_kind` accumulating-cohort registry update PR
  (~25 reservations across ADRs 0029 v2 / 0030 v2 / 0032 v2 / 0033
  v2 — consolidation per Architect N5).
- `ExecutionContext.actor_kind` field commitment (separate Q-*; gates
  ADR 0032 v2 MacBook always-on cross-context human-driven binding
  rule).
- ADR 0026 substrate hook architecture (gated on stage-1
  `BranchProtectionObservation` schema landing; not gated on this
  ADR).
- Q-007 (b)-(f) sub-decisions — `QualityGate` deferral cadence,
  composition with ExecutionContext / CredentialSource /
  GitIdentityBinding / ToolProvenance, dashboard views, charter
  v1.4 candidate. Q-007 is now FULLY UNBLOCKED at the posture layer
  with Q-005 + Q-006 (b)-(g) settled.

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Revision history

- **v1** (2026-05-03, commit `c2a2d63`): initial draft. Reviewers
  surfaced 8 blocking findings (1 architect, 3 policy, 4 security)
  + 1 borderline ontology + ~15 non-blocking observations.
- **v2** (2026-05-03, this revision): closes all 8 blockers + the
  ontology borderline + folds 11 non-blocking observations.
  - **Architect A-B1.** Reclassified `GitHubMutationAuthority`.
    It is NOT a Q-011 review-grammar bucket member (the registry
    defines exactly three buckets: evidence subtype, standalone
    Ring 0 entity, proof composite). It is an **inline value
    type** carried as a structured field on operation-shape
    evidence and on `ApprovalGrant.scope`. The ADR no longer
    cites a Q-011 bucket for this value type.
  - **Policy P-B1 + Security S-B3 (combined).** Made
    `ApprovalGrant.scope.expected_authority_kind` **kernel-set**
    at grant-mint time (derived from the consuming operation's
    matrix-cell minimum). Added separate
    `observed_authority_kind` field **kernel-set** at Layer 3
    gateway re-derive from the actual invocation's
    `GitHubMutationAuthority` evidence. Mismatch rejects with
    `github_mutation_authority_unverified`. Producer-supplied
    values for either field rejected at Layer 1 mint API.
  - **Policy P-B2.** Closed system-config admin escalation hole.
    Mutations against `system-config` policy paths
    (`policies/host-capability-substrate/**`) require BOTH
    `github_app`/`oidc` authority AND a typed `ApprovalGrant`
    with `operation_class: external_control_plane_mutation`,
    regardless of GitHub-side ruleset state. The ApprovalGrant
    covers HCS Decision-level human authority; the ruleset
    covers GitHub-side enforcement; both required.
  - **Policy P-B3.** MCP read/mutation split interim grant
    scope now binds `mcp_server_kind` (renamed from v1's
    `mcp_server_name` per ontology borderline B1). A grant for
    `github` provider PR mutation is NOT consumable by a
    different MCP server instance claiming `github` provider;
    grant scope binds the specific MCP server kind whose
    credential audience was observed at mint time.
  - **Security S-B1.** Declared
    `GitHubMutationAuthority.pat_keyring_account` scrubber-
    eligible per registry v0.3.0 §Field-level scrubber rule.
    `gh` keyring account names commonly encode org/host
    fingerprints (`github.com-nash-group`); audit-chain
    co-recording would otherwise create a stable cross-session
    correlator.
  - **Security S-B2.** Constrained
    `MCPCredentialAudienceObservation.credential_scope_summary`
    from free-form text to a parsed `array<scope_token>` shape
    where `scope_token` is a closed enum. Free-form summary
    rejected at Layer 1 mint API. Closes the secret-shaped-
    string paste vector.
  - **Security S-B4.** Added inv. 8 sandbox-promotion rejection
    rule on `RepositoryIdentityReconciliation`: a record whose
    `Evidence.authority` is `sandbox-observation` or
    `self-asserted` cannot be promoted to host-authoritative
    gate evidence (mirrors ADR 0032 v2 Security N-4 pattern for
    `WorkflowRunReceipt.runner_host_evidence_ref`).
  - **Ontology borderline B1.** Renamed `mcp_server_name` →
    `mcp_server_kind` throughout. The field is a closed enum
    discriminator per registry §Sub-rule 6, NOT a typed FK to a
    Ring 0 entity (MCP servers are not standalone Ring 0
    entities at this stage). Future schema work may introduce a
    standalone `MCPServer` entity with `mcp_server_id` typed FK;
    until then, `mcp_server_kind` is canonical.
  - **Architect N1.** RulesetObservation + BranchProtectionObservation
    conflict resolution clarified: each rule axis evaluates
    independently and the **union of restrictions** applies.
    Replaces v1's "more restrictive of the two" envelope-pick
    framing (which was ambiguous for orthogonal axes).
  - **Architect N2.** §RepositoryIdentityReconciliation Layer 2
    broker FSM re-check now explicitly produces a NEW
    reconciliation evidence record bound to the execution-time
    `execution_context_id`, not a re-validated mint-time record.
    Avoids cross-context evidence reuse risk per charter v1.3.2
    wave-3.
  - **Architect N3.** Clarified that ADR 0032 v2's
    §StatusCheckSourceObservation interim total-block lifts on
    **schema PR landing**, not on this ADR's acceptance.
  - **Ontology N1.** `StatusCheckSourceObservation` mutually-
    inclusive constraint (`expected_github_app_id` OR
    `expected_workflow_path`) noted as Zod `.refine()` pattern;
    schema PR applies the refine, not a discriminated union.
  - **Ontology N7.** Renamed
    `MCPCredentialAudienceObservation.query_observed_via`
    → `query_observed_via` per ADR 0030 v2 three-way
    authority-class signal naming convention. Field captures
    query-side authority (`gh_token_list`, GitHub API
    permissions probe, MCP introspection); query-shape signal
    matches `query_observed_via` slot exactly.
  - **Ontology N8.** Aligned `last_verified_at`
    (MCPCredentialAudienceObservation) → `provider_verified_at`
    matching `StatusCheckSourceObservation` naming. Both fields
    are kernel-set freshness anchors for provider re-query;
    same name simplifies audit-chain queries.
  - **Security: valid_until interim cap.**
    `StatusCheckSourceObservation.valid_until` interim hard cap
    of 24 hours at Layer 1 mint API until Milestone 2 canonical
    policy commits per-`repository_id` maxima. Mirrors ADR
    0031 v1 Lease `valid_until` interim cap pattern.
  - **Security: plane_disagreement audit attribution.** §Audit-
    chain coverage for `RepositoryIdentityReconciliation`
    rejections records `plane_disagreements` array,
    `agent_client_id`, `session_id`, rejecting layer. Audit-
    event reconstruction is deterministic.
  - **Security: App uninstall case.** §App-permission-surface
    drift handling explicitly covers App uninstallation: 404 on
    provider re-query rejects with
    `status_check_source_app_drift` (not silent success on
    cached state).
  - **Security: cross-org reconciliation.** §Cross-context
    binding rules add: a `RepositoryIdentityReconciliation`
    whose `remote_url_canonical` resolves to a different
    organization than `WorkspaceContext.org_id` rejects at
    Layer 1 mint API. Closes the cross-org bypass gap. Single-
    org per `WorkspaceContext` remains the Phase 1 default.
  - **Architect N5.** Added §`Decision.reason_kind`
    accumulating-cohort note: ADRs 0029 v2 / 0030 v2 / 0032 v2 /
    0033 v2 collectively reserve ~25 rejection-class names
    (posture-only); a registry-side enum-cohort document will
    consolidate these in a follow-up registry update PR.

## Context

Q-006 settles the GitHub / version-control authority model. Prior
sub-decisions:

- **Q-006(a)** (entity shape): accepted in limited posture via ADR
  0020 (evidence-subtype-first); stage-1 expansion via ADR 0027 v2
  (`GitRepositoryObservation`, `GitRemoteObservation`,
  `BranchProtectionObservation`); stage-2 expansion via ADR 0030 v2
  (`GitWorktreeObservation`, `GitWorktreeInventoryObservation`,
  `GitBranchAncestryObservation`, `GitDirtyStateObservation`,
  `PullRequestReceipt`, `PullRequestAbsenceReceipt`).

ADR 0033 settles the remaining six sub-decisions:

- **(b)** GitHub mutation authority — which mutations may use
  human PAT/`gh` versus requiring GitHub App/OIDC or brokered
  credentials?
- **(c)** Branch / ruleset baseline — what minimum protection
  state for HCS and `system-config` repos before agentic push /
  merge becomes normal?
- **(d)** Identity reconciliation — how does HCS reconcile local
  path, remote owner, SSH alias, signing principal, and MCP/`gh`
  credential identity?
- **(e)** GitHub MCP read vs mutation auth split — should HCS
  observe two distinct credentials/toolsets?
- **(f)** Minimum `BranchDeletionProof` requirements (likely
  satisfied by Q-008(c) / ADR 0025 v2 — confirmation row).
- **(g)** Check-result gateability — when is a check result
  gateable as evidence (commits the `StatusCheckSourceObservation`
  receipt shape; closes the ADR 0032 v2 §StatusCheckSourceObservation
  interim total-block rule).

Source materials:

- 2026-04-29 GitHub agentic surface investigation
  (`docs/host-capability-substrate/research/local/2026-04-29-github-version-control-agentic-surface.md`)
  — primary source identifying ambient `gh` authority risk,
  five identity planes, GitHub MCP credential exposure, ruleset
  baseline gaps.
- 2026-05-01 version-control authority consult synthesis
  (`docs/host-capability-substrate/research/local/2026-05-01-version-control-authority-consult-synthesis.md`)
  — adds source-control continuity, expected-source identity for
  required checks, split-credential recommendation.
- ADR 0018 (durable credential preference) — credential-source
  ordering: tool-native OAuth + OS credential storage preferred;
  scoped over ambient.
- ADR 0015 (external control plane automation) — frames GitHub
  as external control plane HCS consumes via typed evidence.
- ADR 0020 (version-control authority, limited posture) — names
  Q-006 sub-decisions; commits evidence-subtype-first path.
- ADR 0027 v2 (stage-1 receipts) — `GitRemoteObservation`'s
  `provider_observed_via` authority discipline; first-commit-SHA
  `repository_id` resolution rule.
- ADR 0030 v2 (stage-2 receipts) — `provider_observed_via` /
  `query_observed_via` authority three-way naming convention
  pattern that ADR 0033 inherits.
- ADR 0032 v2 (Q-005, just accepted 2026-05-03) — names the
  `StatusCheckSourceObservation` requirement and applies an
  interim total-block on self-hosted check-result consumption
  until this ADR commits the receipt shape.

This ADR is doc-only and posture-only, mirroring ADR 0029 v2 /
ADR 0030 v2 / ADR 0031 v1 / ADR 0032 v2 acceptance pattern. It
does not author Zod schema source, canonical policy YAML, runtime
probes, dashboard routes, MCP adapter contracts, GitHub App
provisioning automation, or charter invariant text. Schema
implementation lands per `.agents/skills/hcs-schema-change` after
acceptance.

Pre-draft sub-decisions approved by user (2026-05-03) per
research-grounded recommendations:
- (b) Split mutation authority by credential class.
- (c) Minimum baseline for HCS + system-config.
- (d) Five-plane `RepositoryIdentityReconciliation` evidence
  subtype with Layer 2 broker FSM re-check.
- (e) MCP read vs mutation split with
  `MCPCredentialAudienceObservation`.
- (f) Confirm ADR 0025 v2 sufficient.
- (g) Commit `StatusCheckSourceObservation` receipt shape.

## Decision

### Sub-decision (b) — GitHub mutation authority class

**Authority class taxonomy.** Agentic GitHub mutations require
typed evidence of the credential class authorizing the operation.
Authority classes (closed enum, lower_snake_case per registry
§Sub-rule 9):

- `human_pat` — human-interactive Personal Access Token (typically
  via `gh` keyring session). Acceptable for exploratory / manual
  operations only; agentic operations require gateway approval
  per inv. 7.
- `github_app` — GitHub App installation token. Server-to-server
  authority; preferred for agentic mutations per ADR 0018
  durable-credential ordering.
- `oidc` — OIDC-issued token (e.g., GitHub Actions workflow
  identity, third-party OIDC issuer). Verifiable via provider
  API; preferred for workflow-internal operations.
- `actions_token` — GitHub Actions `GITHUB_TOKEN`. Workflow-
  scoped; cannot escape workflow context.
- `unknown` — authority class undetermined (gates close-list
  fail-mode applies; see §Closed-list fail-mode below).

**`GitHubMutationAuthority` inline value type.** This is **not**
a Q-011 review-grammar bucket member; the registry defines
exactly three buckets (evidence subtype, standalone Ring 0
entity, proof composite) and `GitHubMutationAuthority` lacks the
durable lifecycle that defines bucket 2 (standalone Ring 0
entity). It is an **inline structured field** carried on
operation-shape evidence consuming GitHub mutation receipts and
on `ApprovalGrant.scope`. Field shape (illustrative; schema PR
commits):

- `authority_kind` (discriminator from the closed enum above).
- `github_app_id` — present iff `authority_kind == "github_app"`;
  GitHub App installation identifier.
- `oidc_issuer` — present iff `authority_kind == "oidc"`; OIDC
  issuer identifier.
- `actions_workflow_path` — present iff `authority_kind ==
  "actions_token"`; the workflow file that minted the token.
- `pat_keyring_account` — present iff `authority_kind ==
  "human_pat"`; the `gh` keyring account identifier.
  **Scrubber-eligible per registry v0.3.0 §Field-level scrubber
  rule** (charter inv. 5). `gh` keyring account names commonly
  encode org/host fingerprints (e.g., `github.com-nash-group`);
  audit-chain co-recording with `repository_id` +
  `execution_context_id` would otherwise create a stable
  cross-session correlator. Receipts carrying this field SHOULD
  set `Evidence.redaction_mode != none` at mint time; producers
  emitting `pat_keyring_account` without redaction posture face
  Layer 1 mint API rejection.

**Mutation-class × authority-class matrix (posture):**

Each operation class names the minimum acceptable authority
class for agentic invocation. Canonical policy at Milestone 2
commits the matrix; this ADR commits the binding shape.

| Mutation class | Acceptable authority for agentic invocation |
|---|---|
| Repository metadata read | any (incl. `human_pat` read-only scope) |
| Content read | any (incl. `human_pat` read-only scope) |
| Content write (commits, PRs) | `github_app` OR `oidc` (NOT `human_pat`) |
| Admin (ruleset edit, branch protection, settings) | `github_app` with admin permission OR `oidc` with admin claim (NOT `human_pat`) |
| Workflow dispatch | `github_app` with `actions: write` OR `actions_token` |
| Branch / ref deletion | `github_app` with admin OR human-only break-glass per ADR 0025 v2 |

**Forbidden authority shapes** (charter inv. 16 evidence-first):

- Agentic content-write operations citing `authority_kind:
  "human_pat"` reject at gateway with
  `Decision.reason_kind: github_mutation_authority_unverified`.
- Agentic operations against `system-config` (canonical policy
  authority repo) require `github_app` OR human break-glass;
  `human_pat` rejected regardless of class.

### Sub-decision (c) — Branch / ruleset baseline

**Minimum ruleset baseline.** Before agentic push / merge
operations become routine, the following minimum protection
state must be observable as `BranchProtectionObservation` /
`RulesetObservation` evidence:

**For HCS repo (`host-capability-substrate`):**
1. Required signed commits (GitHub-side enforcement).
2. Required linear history (currently observed; confirm
   GitHub enforcement state).
3. Force pushes blocked for non-admin.
4. Ref deletions blocked for non-admin.
5. Admin bypass reserved for human-only break-glass (no
   `github_app` admin tokens for routine operations).

**For `system-config` repo (canonical policy authority — higher
sensitivity):** all five HCS-baseline rules above, PLUS:

6. At least one approval-required review before merge.
7. Dismiss stale reviews on force push.
8. CODEOWNERS coverage for policy files
   (`policies/host-capability-substrate/**`).

**`RulesetObservation` evidence subtype (Q-011 bucket 1).**
Distinct from `BranchProtectionObservation` (ADR 0027 v2):
classic branch protection is the legacy GitHub protection model;
GitHub Rulesets API is the modern superset. The two coexist on
GitHub and HCS observes both.

**Evidence shape (illustrative):**

- `evidence_kind: "observation"`
- `evidence_subject_kind: "ruleset"` (NEW; schema PR commits)
- Standard `Evidence` base fields per ADR 0023.
- Payload (illustrative):
  - `repository_id` — typed FK per ADR 0027 v2 first-commit-SHA-
    rooted resolution.
  - `ruleset_id` — GitHub-side ruleset identifier.
  - `ruleset_kind: "branch" | "tag" | "push"` discriminator.
  - `target_pattern` — e.g., `"refs/heads/main"` or
    `"refs/heads/*"`.
  - `enforcement_kind: "active" | "evaluate" | "disabled"`
    discriminator.
  - `rule_summary` — structured rule list (require_signed,
    require_linear_history, restrict_pushes, restrict_deletions,
    required_review_count, dismiss_stale_reviews, codeowners_required).
  - `bypass_actor_count` — number of actors with bypass
    privileges (audit trail concern).
  - `provider_observed_via: "github_api_v3_rulesets" |
    "github_api_v4_rulesets" | "gh_cli" | "github_mcp"` —
    kernel-set per registry v0.3.2 (authority-class signal).

**Grain:** per-(`repository_id`, `ruleset_id`).

**Composition with `BranchProtectionObservation`.** Both
evidence subtypes can coexist for the same `(repository_id,
target_pattern)` pair when GitHub configuration uses both classic
branch protection and the modern Rulesets API. **Conflict
resolution: union of restrictions.** Each rule axis evaluates
independently, and the union of restrictions across the two
shapes applies — not an envelope-pick of "more restrictive."
Examples:
- Classic protection requires linear history; Ruleset does not
  → linear history required.
- Ruleset adds CODEOWNERS coverage; classic protection does not
  → CODEOWNERS coverage required.
- Classic protection requires 1 review; Ruleset requires 2
  reviews → 2 reviews required (per-axis maximum).

Gateway re-derive at Layer 3 evaluates the union; consuming
operations cite whichever shape's evidence_refs cover the
relevant axes.

### Sub-decision (d) — Repository identity reconciliation

**Five-plane reconciliation.** A repository's effective identity
spans five planes that may drift independently:

1. **Local filesystem path** — canonical worktree path.
2. **Remote URL** — `.git/config` `remote.origin.url` (resolves
   to `repository_id` via ADR 0027 v2 first-commit-SHA rule).
3. **SSH alias** — `~/.ssh/config` host alias used by the remote
   URL.
4. **Signing principal** — GPG key, sigstore identity, or other
   signing authority configured for commits.
5. **Credential account identity** — active `gh` account or MCP
   credential username.

A drift on any plane invalidates implicit operation-authority
assumptions. The 2026-04-29 investigation surfaced concrete
divergence cases (`github-work` remote without matching SSH
alias; `github.com` remotes for org-specific repos; signing
identity selecting business identity while remotes auth via
`github.com-nash-group`).

**`RepositoryIdentityReconciliation` evidence subtype (Q-011
bucket 1).**

**Evidence shape (illustrative):**

- `evidence_kind: "observation"`
- `evidence_subject_kind: "repository_identity_reconciliation"`
  (NEW)
- Standard `Evidence` base fields per ADR 0023.
- Payload (illustrative):
  - `repository_id` — typed FK per ADR 0027 v2.
  - `local_path_canonical` — redacted canonical path; scrubber-
    eligible per registry v0.3.0 §Field-level scrubber rule.
  - `remote_url_canonical` — redacted remote URL (token-form,
    NOT resolved-secret-form).
  - `ssh_host_alias` — alias from `~/.ssh/config` matching the
    remote URL host portion (null when remote uses HTTPS).
  - `signing_principal_evidence_ref` — typed `evidenceRefSchema`
    to a `CredentialSource` record naming the signing key /
    sigstore identity.
  - `credential_account_identity` — active `gh` username OR MCP
    credential account identifier (kernel-verifiable via
    `gh auth status` / MCP introspection).
  - `reconciliation_verdict_kind: "all_planes_consistent" |
    "plane_disagreement"` discriminator.
  - `plane_disagreements` — present iff
    `reconciliation_verdict_kind == "plane_disagreement"`;
    array naming which planes diverge (e.g.,
    `["ssh_alias_missing", "signing_principal_unmapped"]`).
  - `provider_observed_via: "gh_auth_status" | "git_config_read"
    | "ssh_config_resolution" | "mcp_introspection"` — kernel-
    set per registry v0.3.2.

**Grain:** per-`repository_id`.

**Reconciliation timing (charter inv. 17 execution-context
declared, not inferred).** Reconciliation evidence is **re-
checked at operation-execution time** (Layer 2 broker FSM re-
check per registry v0.3.2 §Cross-context enforcement layer),
NOT only at mint time. Local state (SSH config edits, `gh auth
switch`, credential rotation) can drift between mint and
execution; the broker FSM re-runs the cross-plane check before
Layer 3 gateway re-derive. The Layer 2 re-check **produces a
NEW `RepositoryIdentityReconciliation` evidence record** bound
to the execution-time `execution_context_id` (NOT a re-validated
mint-time record), avoiding cross-context evidence reuse risk
per charter v1.3.2 wave-3. Stale reconciliation evidence
rejects with `Decision.reason_kind: repository_identity_mismatch`.

**Sandbox-promotion rejection (charter inv. 8).** A
`RepositoryIdentityReconciliation` whose `Evidence.authority`
is `sandbox-observation` or `self-asserted` cannot be promoted
to host-authoritative gate evidence. Broker FSM Layer 2 /
gateway Layer 3 re-check enforces this discipline, mirroring
ADR 0032 v2 Security N-4 pattern for
`WorkflowRunReceipt.runner_host_evidence_ref`. A sandbox-
execution session producing `all_planes_consistent` does not
satisfy operation gates for sensitive-mutation classes; the
broker FSM rejects with `repository_identity_mismatch` augmented
by the sandbox-authority signal. Closes Security S-B4.

**Composition with operation gates.** Operations against
sensitive-mutation classes (`destructive_git`, `merge_or_push`,
`external_control_plane_mutation` per ADR 0029 v2) require a
fresh `RepositoryIdentityReconciliation` evidence_ref with
`reconciliation_verdict_kind: "all_planes_consistent"` AND
`Evidence.authority` NOT in {`sandbox-observation`,
`self-asserted`}. `plane_disagreement` outcomes block these
classes regardless of matrix cell state — `plane_disagreement`
is a **gate-level rejection prior to matrix-cell evaluation**;
it does not introduce new combinations into the ADR 0029 v2
closed taxonomy.

**Audit-chain attribution on plane_disagreement.** Per registry
v0.3.1 §Audit-chain coverage of rejections,
`repository_identity_mismatch` rejection events emitted on
`plane_disagreement` records carry: `agent_client_id`,
`session_id`, the rejecting Ring 1 layer, AND the
`plane_disagreements` array naming which planes diverged.
Audit-event reconstruction is deterministic.

### Sub-decision (e) — GitHub MCP read vs mutation auth split

**Split credential architecture.** GitHub MCP currently uses a
single token; this ADR commits the posture that read and
mutation authority MUST be split into distinct credentials with
distinct scopes:

- **Read-only credential**: fine-grained PAT or GitHub App
  installation scoped to `contents: read` + `pull_requests:
  read` + `metadata: read` (and similar read-only scopes as
  needed). Used by read-class MCP tools (search, list, get).
- **Mutation-bearing credential**: separate GitHub App
  installation token OR separate fine-grained PAT scoped to
  the specific mutation class needed. Used by mutation-class
  MCP tools (create PR, update PR, merge, branch / ref edits).

**Interim posture (until split is implemented).** Until the
split-credential architecture is deployed, all mutating GitHub
MCP calls require a typed `ApprovalGrant` per ADR 0029 v2
shape sketch + `external_control_plane_mutation` per-class
extension. Read-only MCP calls proceed under existing single-
credential posture (audited but not gateway-blocked).

**`MCPCredentialAudienceObservation` evidence subtype (Q-011
bucket 1).**

**Evidence shape (illustrative):**

- `evidence_kind: "observation"`
- `evidence_subject_kind: "mcp_credential_audience"` (NEW)
- Standard `Evidence` base fields per ADR 0023.
- Payload (illustrative):
  - `mcp_server_kind: "github_mcp"` — discriminator (canonical
    enum landing per `.agents/skills/hcs-schema-change`).
  - `credential_audience_kind: "read_only" | "mutation" |
    "unscoped"` discriminator.
  - `credential_scope_tokens` — array of closed-enum scope
    tokens (e.g., `["contents:read", "pull_requests:read",
    "metadata:read"]`). Each token is a closed enum value
    (canonical token list lands per `.agents/skills/hcs-schema-change`).
    Free-form text rejected at Layer 1 mint API. Renamed from
    v1's free-form `credential_scope_summary` per Security
    S-B2 closure: free-form text was a paste vector for
    resolved token bytes / `op://` values.
  - `credential_source_evidence_ref` — typed `evidenceRefSchema`
    to a `CredentialSource` record naming the underlying
    credential.
  - `provider_verified_at` — kernel-set freshness anchor; produced
    by `gh auth status` / GitHub API permissions probe.
  - `query_observed_via: "gh_token_list" |
    "github_api_permissions" | "mcp_introspection" | "unknown"`
    — kernel-set per registry v0.3.2 (authority-class signal).

**Grain:** per-(`mcp_server_kind`, `credential_audience_kind`).

**Authority discipline.** `provider_verified_at` and
`query_observed_via` kernel-set;
`credential_audience_kind` and `credential_scope_tokens`
producer-asserted but kernel-verifiable.

**Composition with operation gates.** Operations dispatching to
GitHub MCP must cite a `MCPCredentialAudienceObservation`
evidence_ref whose `credential_audience_kind` matches the
operation's required audience. Mismatch rejects with
`Decision.reason_kind: mcp_credential_audience_mismatch`.

### Sub-decision (f) — Minimum BranchDeletionProof (confirmation)

**Confirmed: ADR 0025 v2 sufficient.** Q-008(c) was settled via
ADR 0025 v2 (accepted 2026-05-02). The composite already
distinguishes:

- **Local branch deletion**: requires `worktree_attachment_evidence_refs`,
  `dirty_state_evidence_refs`, `lease_evidence_refs`.
- **Remote branch deletion**: requires
  `remote_state_evidence_refs` (fresh fetch with
  `last_fetch_outcome: ok` per ADR 0027 v2 `GitRemoteObservation`
  gateway rules; stale `gone` observations rejected).
- **Multi-worktree branches**: requires
  `worktree_inventory_evidence_refs` (per ADR 0030 v2
  `GitWorktreeInventoryObservation`).
- **Merge proof**: `merge_proof_kind: "ancestry" |
  "patch_equivalence" | "vacuous"` discriminator with sibling
  evidence arrays.
- **PR state proof**: `pr_state_kind: "absent" | "open" |
  "closed_unmerged" | "merged"` discriminator with
  `PullRequestReceipt` (ADR 0030 v2) or
  `PullRequestAbsenceReceipt` (ADR 0030 v2).

**No additional schema or posture additions** are introduced
by Q-006(f). Force-deletion is non-escalable per ADR 0025 v2
five-layer defense-in-depth. The `hcs-hook` literal-protected-
list (layer 4) is the substrate-side enforcement boundary;
ADR 0026 will commit the broader hook architecture once
`BranchProtectionObservation` schema lands.

### Sub-decision (g) — `StatusCheckSourceObservation` receipt shape

**Closes ADR 0032 v2 §StatusCheckSourceObservation interim
total-block rule.** Until this ADR's acceptance, all self-
hosted check-result consumption rejects unconditionally per
inv. 16 (external-control-plane evidence-first). This ADR
commits the receipt shape; ADR 0032 v2's gateway rule lifts
once schema implementation lands.

**`StatusCheckSourceObservation` evidence subtype (Q-011 bucket
1; `evidenceSchema`-direct typed payload, NOT
`BoundaryObservation` envelope).**

Rationale for `evidenceSchema`-direct shape: a check-source
binding is an *observation* of provider state (the GitHub
Checks API entry for a specific commit + check name), not a
*boundary fact* about a surface context. The
`BoundaryObservation` envelope is reserved for context claims
(sandbox kind, runner isolation, credential routing audience);
check-source is observational and matches the ADR 0027/0030
stage-1+2 pattern.

**Evidence shape (illustrative):**

- `evidence_kind: "observation"`
- `evidence_subject_kind: "status_check_source"` (NEW)
- Standard `Evidence` base fields per ADR 0023.
- Payload (illustrative):
  - `repository_id` — typed FK per ADR 0027 v2.
  - `commit_sha` — required; the commit whose check is being
    bound.
  - `check_name` — required; the check identifier (e.g.,
    `"build"`, `"ci/test"`).
  - `expected_github_app_id` — optional; GitHub App
    installation identifier expected to publish the check.
  - `expected_workflow_path` — optional; workflow file path
    (e.g., `".github/workflows/ci.yml"`) expected to produce
    the check. At least one of `expected_github_app_id` OR
    `expected_workflow_path` MUST be present (mutually
    inclusive of source identity).
  - `conclusion_kind: "success" | "failure" | "skipped" |
    "cancelled" | "neutral" | "timed_out" | "action_required"`
    discriminator (matches GitHub Checks API conclusion enum).
  - `concluded_at` — required; freshness anchor.
  - `valid_until` — required; consumer-side freshness window.
    Producer-asserted at mint; canonical policy at Milestone 2
    may impose a per-`repository_id` maximum window.
    **Phase 1 interim hard cap of 24 hours at Layer 1 mint API**
    (mirrors ADR 0031 v1 Lease `valid_until` interim cap
    pattern); producers asserting `valid_until` more than 24
    hours past `concluded_at` rejected at mint.
  - `source_kind: "actions_workflow" | "github_app" |
    "third_party_service" | "native"` discriminator (matches
    ADR 0032 v2 `StatusCheckSourceObservation` requirement).
  - `provider_observed_via: "github_api_v3_checks" |
    "github_api_v4_checkruns" | "gh_cli" | "github_mcp"` —
    kernel-set per registry v0.3.2.
  - `provider_verified_at` — kernel-set; the most recent time
    the provider was queried to verify the binding (Layer 2/3
    re-check).

**Grain:** per-(`repository_id`, `commit_sha`, `check_name`).

**Scrubber-eligibility (charter inv. 5).** `workflow_path` is
declared scrubber-eligible per registry v0.3.0 §Field-level
scrubber rule. Producer-asserted paths matching secret-shaped
patterns reject at Layer 1 mint API.

**Composition with `WorkflowRunReceipt` (ADR 0032 v2).** A
`StatusCheckSourceObservation` for a self-hosted check pairs
with a `WorkflowRunReceipt` evidence_ref naming the workflow
run that produced the check. The pair binds: the check's
expected source (this receipt) + the runner that executed the
workflow (the `runner_host_evidence_ref` on
`WorkflowRunReceipt`).

**App-permission-surface drift handling (ADR 0032 v2 Security
N-3).** A legitimate GitHub App with bound `expected_github_app_id`
could publish a different `check_name` post-binding (App
permission scopes typically allow publishing arbitrary check
names). The Layer 2/3 re-check rule enforces:

- `provider_verified_at` MUST be within `valid_until` window;
  stale verifications reject.
- The provider re-query MUST confirm: (a) the check still
  exists at `(commit_sha, check_name)`; (b) the check was
  published by `expected_github_app_id` OR via
  `expected_workflow_path`; (c) the App's current permission
  set still allows publishing checks (not revoked).
- Drift on (c) rejects with
  `Decision.reason_kind: status_check_source_app_drift`.
- **App uninstall case**: when the App is uninstalled, the
  provider re-query returns 404 on the App-installation
  endpoint. This rejects with `status_check_source_app_drift`,
  not silent success on cached state. The receipt's stored
  state is invalidated at Layer 2 and rejected at Layer 3.

This closes the App-permission-surface drift bypass ADR 0032
v2 Security N-3 named.

**ADR 0032 v2 interim total-block lift trigger.** ADR 0032 v2
applies an interim total-block on self-hosted check-result
consumption until the `StatusCheckSourceObservation` receipt
shape lands. The interim block lifts on **schema PR landing**
(per `.agents/skills/hcs-schema-change`), NOT on this ADR's
acceptance. ADR 0033 acceptance commits the receipt shape
(posture); the schema PR commits the receipt's Zod source.
Until the schema PR lands, the interim total-block remains in
effect.

### Cross-cutting rules

#### Authority discipline

Authority-class signals across the five new evidence subtypes
follow registry v0.3.2 §Producer-vs-kernel-set discipline:

- **Kernel-set**: `provider_observed_via` /
  `provider_verified_at` /
  `query_observed_via` (all `*_observed_via`-shape
  authority-class signals); `repository_id` resolution per
  ADR 0027 v2; freshness anchors and timestamps.
- **Producer-asserted, kernel-verifiable**: ruleset state,
  reconciliation verdict fields, MCP credential audience
  classification, check conclusion, expected source identity.
- **Three-way `*_observed_via` naming convention** per ADR
  0030 v2 §Cross-cutting authority discipline: local-Git uses
  bare `observed_via`; provider-side state uses
  `provider_observed_via`; provider-side query uses
  `query_observed_via`. ADR 0033's five new subtypes use
  `provider_observed_via` (state observations) consistently.

#### Cross-context binding rules per Ring 1 layer

Per registry v0.3.0 §Cross-context enforcement layer
requirement, each new evidence subtype names enforcement
layers:

- **`RulesetObservation`**: Layer 1 enforces
  `repository_id` + `ruleset_id` consistency with
  `ExecutionContext`; Layer 2 re-checks ruleset state freshness
  via provider re-query; Layer 3 re-derives. Bypass-actor-count
  changes rejected at Layer 3 if they exceed the consuming
  operation's tolerance.
- **`RepositoryIdentityReconciliation`**: Layer 1 enforces
  `repository_id` consistency. Layer 1 ALSO enforces
  cross-organization rejection: a record whose
  `remote_url_canonical` resolves to a different organization
  than `WorkspaceContext.org_id` rejects at Layer 1 mint API
  with `Decision.reason_kind: repository_identity_mismatch`
  (single-org per `WorkspaceContext` is the Phase 1 default).
  Layer 1 ALSO enforces `Evidence.authority` rejection for
  `sandbox-observation` and `self-asserted` per the §Sandbox-
  promotion rejection rule above. Layer 2 re-runs the cross-
  plane check at operation-execution time (the layer that
  closes the drift gap per inv. 17); produces a NEW
  reconciliation record bound to the execution-time
  `execution_context_id` (not a re-validated mint-time record);
  rejects with `repository_identity_mismatch` if any plane
  disagrees. Layer 3 re-derives at decision time.
- **`MCPCredentialAudienceObservation`**: Layer 1 enforces
  `mcp_server_kind` registration + `credential_source_evidence_ref`
  resolution; Layer 2 re-checks `credential_audience_kind`
  against current MCP server token introspection; Layer 3
  rejects mismatched-audience operation invocations.
- **`StatusCheckSourceObservation`**: Layer 1 enforces
  `repository_id` resolution + `commit_sha` + `check_name`
  uniqueness within freshness window; Layer 2 re-checks
  provider state per the App-permission-drift handling rule
  above; Layer 3 re-derives.

#### `Decision.reason_kind` reservations

Six new rejection-class names reserved (posture-only; schema
enum lands per `.agents/skills/hcs-schema-change`):

- `github_mutation_authority_unverified` — agentic GitHub
  mutation cited a non-`github_app` / non-`oidc` authority
  class for an operation requiring server-to-server identity
  (sub-decision (b)).
- `ruleset_baseline_unmet` — observed `BranchProtectionObservation`
  / `RulesetObservation` state below the minimum baseline for
  the consuming repository's sensitivity tier (sub-decision (c)).
- `repository_identity_mismatch` — five-plane reconciliation
  surfaced divergence at Layer 2 / Layer 3 re-check (sub-
  decision (d)).
- `mcp_credential_audience_mismatch` — operation cited a
  `credential_audience_kind` that does not match the consuming
  MCP tool class (sub-decision (e)).
- `status_check_source_unverified` — `StatusCheckSourceObservation`'s
  `provider_verified_at` outside `valid_until` window OR
  provider re-query failed at Layer 2/3 (sub-decision (g)).
- `status_check_source_app_drift` — bound `expected_github_app_id`
  no longer has check-publishing permission at Layer 2/3
  re-check (sub-decision (g); closes ADR 0032 v2 Security
  N-3).

Per ADR 0029 v2 §`block` vs forbidden-tier framing, all six
rejection classes are *Decision-level* (this-invocation
rejects); none promotes the operation to forbidden tier.

#### `ApprovalGrant.scope` per-class extension for GitHub
mutations

Per ADR 0019 v3 §Scope-key disjointness rule and ADR 0031 v1
forward-look, GitHub-mutation operations bind:

- `operation_class: "external_control_plane_mutation"` (per
  ADR 0029 v2 §`ApprovalGrant.scope` per-class extensions).
- `target_ref: { provider_id, provider_target_id }` —
  per-(provider, target) grain; for GitHub, `provider_id =
  "github"` and `provider_target_id` names the repository, PR,
  or branch being mutated.
- `expected_authority_kind` — **kernel-set** at grant-mint
  time per registry v0.3.2 §Producer-vs-kernel-set authority
  fields. The kernel derives the value from the consuming
  operation's matrix-cell minimum (sub-decision (b) matrix).
  Producer-supplied values rejected at Layer 1 mint API.
  This closes the v1 escalation surface where a producer
  could claim `"github_app"` while presenting a `human_pat`.
- `observed_authority_kind` — **kernel-set** at Layer 3
  gateway re-derive time. Derived from the actual
  invocation's `GitHubMutationAuthority` evidence (the
  introspected credential class via `gh auth status` token-
  class probe, GitHub API permissions probe, or App
  installation token introspection). Mismatch with
  `expected_authority_kind` rejects with `Decision.reason_kind:
  github_mutation_authority_unverified`.
- `mcp_server_kind` — required when the mutation is
  dispatched through a GitHub MCP server (per sub-decision
  (e)). Binds the grant to a specific MCP server kind so a
  grant minted for `github_mcp` cannot be consumed by a
  different MCP server claiming `github` provider. Closes
  Policy P-B3.
- `execution_context_id` — per registry v0.3.0 §Cross-context
  enforcement layer.

**`system-config` policy-path mutation rule (closes Policy
P-B2 escalation hole):** mutations targeting
`system-config` policy paths (`policies/host-capability-substrate/**`)
require BOTH the matrix-minimum authority class AND a typed
`ApprovalGrant` of this per-class extension shape, regardless
of GitHub-side ruleset state. The ApprovalGrant covers HCS
Decision-level human authority; the ruleset (sub-decision (c)
baseline rows 6–8) covers GitHub-side enforcement; both are
required. A `github_app` with admin permission token alone
cannot mutate canonical policy YAML — the ApprovalGrant is
the HCS Decision authority and is independent of GitHub-side
review approval.

Scope-key disjointness preserved per ADR 0019 v3: GitHub-
mutation grants do not overlap with `worktree_mutation`,
`destructive_git`, `merge_or_push`, or `runner_registration` /
`runner_deregistration` per-class extensions.

### Out of scope

This ADR does not authorize:

- Zod schema source for any of the five new evidence subtypes
  (`RulesetObservation`, `RepositoryIdentityReconciliation`,
  `MCPCredentialAudienceObservation`,
  `StatusCheckSourceObservation`). Plus the
  `GitHubMutationAuthority` value type and the six
  `Decision.reason_kind` reservations. Schema lands per
  `.agents/skills/hcs-schema-change` after acceptance.
- `evidenceSubjectKindSchema` enum extension for the new
  subject-kind values (`ruleset`,
  `repository_identity_reconciliation`,
  `mcp_credential_audience`, `status_check_source`).
- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. The
  mutation-class × authority-class matrix is posture; canonical
  rule entries land in `tiers.yaml` once HCS Milestone 2 ships.
- Specific GitHub Ruleset IDs, ruleset versions, or canonical
  GitHub App identifiers. Those belong to a separate GitHub
  governance / hardening task outside HCS mutation lanes.
- GitHub App provisioning automation or installation
  workflows. Citadel OPA / OpenTofu owns external control-
  plane provisioning per ADR 0015 + ADR 0032 v2 Citadel-vs-HCS
  boundary.
- Workspace-context ↔ repository_id cross-binding (separate
  Q-009 / Q-008(d) territory).
- Multi-organization workspace routing. Organizational identity
  mapping is a `WorkspaceContext` concern, not identity
  reconciliation. Single-org per `WorkspaceContext` is the
  Phase 1 default.
- Tag deletion, release-branch classification, submodule
  observation. Reserved for follow-up Q-006 stage-3 ADRs if
  needed.
- ADR 0026 substrate hook architecture (still gated on
  stage-1 `BranchProtectionObservation` schema; not gated on
  this ADR).
- GitHub Copilot cloud-agent remote-environment receipt (Q-010
  territory; tooling-surface-matrix routes Copilot through
  Q-005/Q-006 evidence).
- `ExecutionContext.actor_kind` field commitment (referenced by
  ADR 0032 v2's MacBook always-on cross-context rule; remains
  follow-up Q-* candidate).
- Q-007 (b)-(f) sub-decisions. Q-007(b) `QualityGate` deferral
  cadence is now fully unblocked at the posture layer (Q-005
  + Q-006(g) settled); Q-007 (b)-(f) remains a separate
  Q-row.

## Consequences

### Accepts

- Q-006 (b)-(g) settled at the design layer with five new
  evidence subtypes, one value type, and one confirmation row.
- `GitHubMutationAuthority` value type committed (inline
  structured field — NOT a Q-011 review-grammar bucket member;
  carried on operation-shape evidence and `ApprovalGrant.scope`):
  `authority_kind` discriminator + per-kind expected-source
  fields; agentic GitHub mutations require `github_app` /
  `oidc` authority class for content-write / admin / merge /
  ref-deletion operations. `human_pat` reserved for
  exploratory / manual operations.
- `RulesetObservation` evidence subtype committed (Q-011 bucket
  1): `evidenceSchema`-direct typed payload, per-(`repository_id`,
  `ruleset_id`) grain, ruleset-state observation including
  `enforcement_kind` discriminator and `bypass_actor_count`.
  Coexists with `BranchProtectionObservation` (ADR 0027 v2)
  for repos using both classic protection and modern Rulesets
  API.
- `RepositoryIdentityReconciliation` evidence subtype committed
  (Q-011 bucket 1): five-plane composite (local path, remote
  URL, SSH alias, signing principal, credential account
  identity); `reconciliation_verdict_kind` discriminator;
  Layer 2 broker FSM re-check at operation-execution time per
  inv. 17.
- `MCPCredentialAudienceObservation` evidence subtype committed
  (Q-011 bucket 1): per-(`mcp_server_kind`,
  `credential_audience_kind`) grain; binds MCP server +
  credential audience for split-credential gating.
- Q-006(f) confirmed satisfied by ADR 0025 v2 BranchDeletionProof;
  no additional schema or posture additions required.
- `StatusCheckSourceObservation` evidence subtype committed
  (Q-011 bucket 1): `evidenceSchema`-direct typed payload,
  per-(`repository_id`, `commit_sha`, `check_name`) grain.
  Closes the ADR 0032 v2 §StatusCheckSourceObservation interim
  total-block rule. App-permission-surface drift handling rule
  closes the ADR 0032 v2 Security N-3 bypass surface.
- Six new `Decision.reason_kind` rejection-class names reserved
  (posture-only): `github_mutation_authority_unverified`,
  `ruleset_baseline_unmet`, `repository_identity_mismatch`,
  `mcp_credential_audience_mismatch`,
  `status_check_source_unverified`,
  `status_check_source_app_drift`.
- Four new `evidence_subject_kind` enum values reserved:
  `ruleset`, `repository_identity_reconciliation`,
  `mcp_credential_audience`, `status_check_source`.
- `ApprovalGrant.scope` per-class extension for GitHub
  mutations committed: `external_control_plane_mutation` class
  with `target_ref: { provider_id, provider_target_id }` +
  required `expected_authority_kind` field. Scope-key
  disjointness preserved per ADR 0019 v3.
- Mutation-class × authority-class matrix committed as posture;
  canonical numeric thresholds and per-cell refinements land in
  `tiers.yaml` once HCS Milestone 2 ships.
- Authority discipline follows registry v0.3.2: identity and
  freshness fields kernel-set; ruleset / reconciliation /
  audience / check-source fields producer-asserted but
  kernel-verifiable.
- Q-007(b) (`QualityGate` deferral cadence) now fully unblocked
  at the posture layer (Q-005 + Q-006 (b)-(g) settled). Q-007
  (b)-(f) becomes the next candidate Q-row in the synthesis
  window.

### Rejects

- Treating ambient `gh` PAT as sufficient authority for agentic
  content-write / admin / merge / ref-deletion operations
  (charter inv. 16 violation).
- Observing GitHub MCP credentials as a single audience (sub-
  decision (e) split required).
- Mint-time-only repository identity reconciliation (sub-
  decision (d) requires Layer 2 broker FSM re-check at
  operation-execution time per inv. 17).
- `BoundaryObservation` envelope for `StatusCheckSourceObservation`
  (sub-decision (g) — observational, not boundary fact).
- Additional schema or posture work for Q-006(f) BranchDeletionProof
  beyond what ADR 0025 v2 commits.
- Check-name-only consumption of self-hosted check results
  (closes ADR 0032 v2's interim total-block by committing the
  receipt shape; does NOT relax the consumption rule).
- Cross-organization workspace routing. Phase 1 default is
  single-org per `WorkspaceContext`.
- HCS storage of GitHub App private keys, PATs, or OIDC tokens.
  Charter inv. 5 prohibits secrets at rest in Ring 0/1; HCS
  observes credential identity and audience, not credential
  material.

### Future amendments

- Schema PR per `.agents/skills/hcs-schema-change` for the five
  evidence subtypes + value type + six `Decision.reason_kind`
  reservations + `ApprovalGrant.scope` per-class extension.
- Q-007 (b)-(f) ADR closing `QualityGate` deferral cadence,
  composition with `ExecutionContext` / `CredentialSource` /
  `GitIdentityBinding` / `ToolProvenance`, dashboard views,
  charter v1.4 candidate.
- Canonical policy YAML at Milestone 2: mutation-class ×
  authority-class matrix entries; ruleset baseline ID
  references for HCS / system-config; per-`repository_id`
  freshness window for `StatusCheckSourceObservation`;
  per-`mcp_server_kind` audience-class enforcement; specific
  GitHub App installation identifiers for system-config
  agentic operations.
- ADR 0026 substrate hook architecture (gated on stage-1
  `BranchProtectionObservation` schema landing; not gated on
  this ADR).
- Q-006 stage-3 ADR if remote-tag receipts, submodule
  observations, or tag deletion grain become required.
- `ExecutionContext.actor_kind` field commitment ADR (separate
  Q-*; gates ADR 0032 v2's MacBook always-on cross-context
  human-driven binding rule).
- GitHub App permission-set freshness re-check policy at
  Milestone 2 (canonical thresholds for
  `status_check_source_app_drift` rejection-class enforcement).
- Multi-organization workspace routing ADR if cross-org
  agentic operations become a use case.
- Reopen if a future incident shows the five-plane identity
  reconciliation misses a divergence class, or the
  authority-class matrix needs a new authority kind (e.g.,
  sigstore identities, hardware-attested tokens).

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md`
  v1.3.2 (especially inv. 1, 4, 5, 6, 7, 8, 13, 16, 17).
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
  (Authority discipline, Cross-context enforcement layer,
  Naming suffix discipline, Field-level scrubber rule).
- Decision ledger: `DECISIONS.md` Q-006, Q-008.
- ADR 0015:
  `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
  (frames GitHub as external control plane; charter inv. 16
  origin).
- ADR 0018:
  `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
  (credential-source ordering: tool-native OAuth + OS credential
  storage preferred; scoped over ambient).
- ADR 0019:
  `docs/host-capability-substrate/adr/0019-knowledge-and-coordination-store.md`
  (Q-003 v3 final; scope-key disjointness rule).
- ADR 0020:
  `docs/host-capability-substrate/adr/0020-version-control-authority.md`
  (Q-006 limited posture; named the six sub-decisions ADR 0033
  closes).
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (BoundaryObservation envelope rejected for
  StatusCheckSourceObservation; observational vs boundary fact
  distinction).
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract; payload-versioned envelope pattern).
- ADR 0025:
  `docs/host-capability-substrate/adr/0025-branch-deletion-proof.md`
  (Q-008(c) v2 final; satisfies Q-006(f) per confirmation row
  here).
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (Q-006 stage-1 v2 final; first-commit-SHA `repository_id`
  resolution; provider_observed_via authority discipline).
- ADR 0029:
  `docs/host-capability-substrate/adr/0029-q-008-b-anomalous-capture-blocking-thresholds.md`
  (Q-008(b) v2 final; ApprovalGrant.scope shape sketch;
  `block` vs forbidden-tier framing).
- ADR 0030:
  `docs/host-capability-substrate/adr/0030-q-006-stage-2-source-control-evidence-subtypes.md`
  (Q-006 stage-2 v2 final; three-way authority-class signal
  naming convention pattern this ADR inherits;
  `PullRequestReceipt` / `PullRequestAbsenceReceipt`).
- ADR 0031:
  `docs/host-capability-substrate/adr/0031-q-008-d-worktree-ownership-composition.md`
  (Q-008(d) v1 final; ApprovalGrant.scope per-class extension
  pattern; scope-key disjointness forward-look).
- ADR 0032:
  `docs/host-capability-substrate/adr/0032-q-005-ci-runner-evidence-model.md`
  (Q-005 v2 final; named the StatusCheckSourceObservation
  requirement; interim total-block rule lifted by this ADR;
  Security N-3 App-permission-drift bypass surface closed by
  this ADR's drift handling rule).
- 2026-04-29 GitHub agentic surface investigation:
  `docs/host-capability-substrate/research/local/2026-04-29-github-version-control-agentic-surface.md`
  (primary research source for sub-decisions (b), (c), (d), (e)).
- 2026-05-01 version-control authority consult synthesis:
  `docs/host-capability-substrate/research/local/2026-05-01-version-control-authority-consult-synthesis.md`
  (consult source for sub-decisions (c), (g); source-control
  continuity model).
- 2026-05-01 ontology promotion + receipt dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
  (Q-011 review-grammar bucket guidance).
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`.

### External

- GitHub Apps installation tokens:
  <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/about-authentication-with-a-github-app>
- GitHub Actions OIDC tokens:
  <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>
- GitHub Rulesets API:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>
- GitHub Branch protection (classic):
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches>
- GitHub Checks API:
  <https://docs.github.com/en/rest/checks>
- GitHub fine-grained PATs:
  <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens>
- SLSA source-track requirements (continuity model):
  <https://slsa.dev/spec/v1.0/source-requirements>
