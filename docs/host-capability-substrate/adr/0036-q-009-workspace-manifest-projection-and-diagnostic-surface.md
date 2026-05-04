---
adr_number: 0036
title: Q-009 HCS workspace manifest projection and diagnostic surface
status: proposed
date: 2026-05-04
charter_version: 1.3.2
tags: [workspace-manifest, diagnostic-surface, audit-profile, q-009, phase-1]
---

# ADR 0036: Q-009 HCS workspace manifest projection and diagnostic surface

## Status

proposed (v1)

## Date

2026-05-04

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Context

Q-009 settles the HCS diagnostic surface and the workspace manifest
model. The 2026-04-30 HCS evidence/planning synthesis
(`docs/host-capability-substrate/research/local/2026-04-30-hcs-evidence-planning-synthesis.md`)
proposed seven candidate diagnostic operations
(`system.runtime.diagnose.v1`, `system.git.diagnose.v1`,
`system.workspace.diagnose.v1`, `system.process.inspect_safe.v1`,
`system.docs.diagnose.v1`, `system.cleanup.plan.v1`,
`system.claims.reconcile.v1`) plus an 11-field workspace manifest.

The 2026-05-01 ontology-promotion-receipt-dedupe-plan
(`docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`)
recommended (line 142) that the workspace manifest land as a
"generated view candidate" with explicit "avoid second source of
truth" guidance.

**Key reframe.** During Q-009 deliberation, the human owner
recognized that the existing audit framework's
`profile/<date>/project_profile.yaml` is structurally HCS-shaped
already:

- dated snapshot with `repository_revision` → maps to HCS freshness
  anchors;
- claims-vs-confirmations invariant → maps to HCS authority ladder
  (`self-asserted` / `derived` / `host-observation`);
- `status: claimed` for bounded contexts → maps to `CoordinationFact`
  with `allowed_for_gate: false`;
- profile-diff drift detection → maps to ADR 0019 v3
  `KnowledgeSource.content_hash` re-indexing rule;
- `audit_attention_flags` routing → maps to typed `Decision` records
  with `reason_kind`;
- `cycle-history.md` operator-ratified conventions → maps to promoted
  `CoordinationFact`s.

The audit spec's Prime Directive 3 ("Claims are not confirmations") is
structurally identical to the charter inv. 18 candidate ("Derived
retrieval results are never decision authority"; ADR 0019 v3).

Therefore: the workspace manifest is **not a new HCS-specific
artifact**. It is a Layer 3 retrieval projection composing existing
operational truth with the audit framework's claims snapshot — using
mechanisms already accepted across ADR 0019 v3 / 0027 v2 / 0030 v2 /
0031 v1 / 0034 v2 / 0035 v2.

This ADR is doc-only and posture-only, mirroring ADR 0029 v2 / ADR
0030 v2 / ADR 0031 v1 / ADR 0032 v2 / ADR 0033 v2 / ADR 0034 v2 / ADR
0035 v2 acceptance pattern. It does not author Zod schema source,
canonical policy YAML, runtime probes, dashboard route React
components, MCP adapter contracts, or charter invariant text.

Pre-draft sub-decisions approved by user (2026-05-04) per
research-grounded recommendations + structural reframe + three
refinements:

- (a) ONLY `system.workspace.diagnose.v1` Ring 1 operation lands in
  Phase 1; four other diagnostic operations defer until Q-008 typed
  inputs / Q-006 stage-2/3 receipts settle. Diagnose op outputs a
  `DerivedSummary` (per ADR 0019 v3), NOT a new typed Receipt;
  service mints via `mint_api` (existing kernel-trusted producer
  allowlist per ADR 0028 v4 §Producer-vs-kernel-set authority
  fields).
- (b) Workspace manifest is a **generated view**, NOT a source of
  truth. Three explicit input layers: Layer 1 operational truth
  (existing entities); Layer 2 claims snapshot (audit framework
  `project_profile.yaml` registered as `KnowledgeSource` with NEW
  `source_kind: "audit_profile"`); Layer 3 derived retrieval
  projection (per ADR 0019 v3).
- (c) Five governance elements compose via existing entities + one
  new `boundary_dimension` + one new no-suffix Ring 0 entity (NOT
  five orthogonal new entities): protected paths via promoted
  `boundary_dimension: filesystem_authority` (with `claim_kind`
  sibling-discriminator); search/lint exclusions producer-asserted
  on `WorkspaceContext`; canonical MCP config via NEW
  `boundary_dimension: mcp_canonical_source`; verify commands via
  NEW `VerificationCommand` no-suffix Ring 0 entity; docs taxonomy
  via `KnowledgeSource.source_kind` extensions.
- (d) Three regression traps (#26-#28) accepted but staged behind
  evidence dependencies.
- (e) Claim reconciliation is ALREADY settled by ADR 0019 v3. Claims
  become `DerivedSummary` records (default `allowed_for_gate:
  false`); reconciliation is a Layer 3 retrieval projection;
  gateability requires verifier visibility-authority rule. NO new
  `ClaimReconciliationReceipt` entity.

## Decision

### Sub-decision (a) — Diagnostic operations: phase 1 minimum

**Phase 1 commits ONLY `system.workspace.diagnose.v1`.** Four other
candidate operations defer until their evidence dependencies clear.

**`system.workspace.diagnose.v1`** (Ring 1 read-only operation):

- Input: `(workspace_id, include_stale_evidence: bool)`.
- Output: a `DerivedSummary` (per ADR 0019 v3) whose `derived_from`
  array cites Layer 1 operational evidence (e.g.,
  `GitRepositoryObservation`, `WorkspaceContext`, active `Lease`s,
  active `CoordinationFact`s) AND Layer 2 audit-profile content
  (`KnowledgeChunk` records from `KnowledgeSource` records of
  `source_kind: "audit_profile"`).
- `summary_kind: "operational_summary"` (already reserved in ADR
  0019 v3 enum; no new reservation needed).
- `Evidence.authority: "derived"` and `Evidence.confidence:
  "best-effort"` (fixed per ADR 0019 v3 `DerivedSummary`).
- `Evidence.producer: "mint_api"` (existing kernel-trusted producer
  allowlist per ADR 0028 v4 / registry v0.3.2; the workspace-
  diagnose service mints via `mint_api` rather than introducing a
  new producer class). This avoids a registry follow-up dependency
  and matches how other Ring 1 services already mint.
- `mutation_scope: "none"` (read-only diagnostic).

**Chain-promotion blocks gateability automatically.** Per ADR 0019
v3 §Chain promotion rule, a `DerivedSummary` whose `derived_from`
graph contains any `KnowledgeChunk` reference is non-promotable. The
diagnose op's `derived_from` will routinely cite `KnowledgeChunk`s
from the audit-profile `KnowledgeSource`; this **structurally blocks
the diagnostic summary from clearing `approval_required` cells** for
destructive operations, regardless of any operator's intent. The
existing chain-promotion rule does the work; no new gateability
mechanism is needed. A workspace diagnostic can never accidentally
gate a destructive operation as long as it cites audit-profile
content.

**Composition rule (preempts ontology-reviewer non-blocker).** When
a `system.workspace.diagnose.v1` `DerivedSummary` cites audit-
profile `KnowledgeChunk`s in `derived_from`, the resulting summary
is **guaranteed non-promotable** until the audit profile's claims
are independently confirmed through Layer 1 evidence AND a separate
`CoordinationFact` is promoted citing those Layer 1 records. The
diagnostic summary remains display-only by structure; promotion
requires re-derivation through the typed-evidence path, not through
the summary itself. This is not a regression of inv. 18 — it is the
inv. 18 candidate working correctly across the audit-framework
boundary.

**Deferred operations** (NOT committed in Phase 1; reasoning):

| Operation | Defers until |
|---|---|
| `system.runtime.diagnose.v1` | Q-008 typed `ProcessInspectionRequest` input; D-028 host_secret_* compatibility surface stable |
| `system.git.diagnose.v1` | Subsumed today by ADR 0027 v2 + ADR 0030 v2 receipts; no new entity needed; reopen if a future incident motivates an aggregator |
| `system.docs.diagnose.v1` | Q-006 stage-3 (e.g., docs-source receipts, if any) + `KnowledgeSource.content_hash` re-index hook from ADR 0019 v3 schema PR |
| `system.cleanup.plan.v1` | Subsumes into a `CleanupPlanRequest` operation-shape; ADR 0036 commits the deletion-authority field-shape (see Sub-decision (c) below); operation lands when canonical policy YAML at Milestone 2 ships |
| `system.claims.reconcile.v1` | Subsumes into ADR 0019 v3 `DerivedSummary` + Q-003 promotion workflow; NO new reconciliation operation needed (see Sub-decision (e) below) |

**`host_secret_*` compatibility-surface exception** remains the only
pre-substrate compatibility concession per D-028. No new
compatibility surfaces introduced.

### Sub-decision (b) — Workspace manifest as three-layer projection

**The workspace manifest is a Layer 3 retrieval projection, not a
file.** Three explicit input layers compose into the projection:

**Layer 1 — Operational truth** (existing). The host-authoritative
layer:

- `WorkspaceContext` (one-to-one with worktree per ADR 0031 v1).
- `Lease` records with `lease_kind: "worktree"` (ADR 0031 v1).
- `GitRepositoryObservation` / `GitRemoteObservation` /
  `BranchProtectionObservation` (ADR 0027 v2).
- `GitWorktreeObservation` / `GitWorktreeInventoryObservation` /
  `GitDirtyStateObservation` (ADR 0030 v2).
- `BoundaryObservation` for boundary-dimension claims (ADR 0022;
  ADR 0034 v2 four queued; ADR 0036 promotes `filesystem_authority`
  + adds `mcp_canonical_source`).
- `ToolProvenance` (ADR 0034 v2).
- `GitIdentityBinding` (ADR 0034 v2).
- `CredentialSource` (ADR 0018).
- Promoted `CoordinationFact` records (ADR 0019 v3) covering
  workspace-scope assertions.

This is the only host-authoritative layer; gates consume only Layer
1 evidence (or promoted `CoordinationFact`s citing Layer 1) per inv.
18 candidate.

**Layer 2 — Claims snapshot (NEW input class).** The audit
framework's `profile/<date>/project_profile.yaml` is registered as
a `KnowledgeSource` per ADR 0019 v3, with NEW candidate value
`source_kind: "audit_profile"` (and adjacent
`source_kind: "cycle_history"` for `cycle-history.md`).
`security_label` defaults to `"internal"`; profile-diff drift
detection re-indexes via the existing
`KnowledgeSource.content_hash` change rule. Profile chunks become
`KnowledgeChunk` records. **`audit_profile` and `cycle_history`
profiles starting at `internal` may upgrade to `secret_referenced`
on re-index when embedded `op://` references appear in cited
content — this is the rule working correctly per ADR 0019 v3
§Secret-referenced sources, not a regression.**

**Layer 3 — Derived retrieval projection** (existing per ADR 0019
v3). Composes Layer 1 + Layer 2 into the workspace view consumed
by `system.workspace.diagnose.v1`. Per inv. 18 candidate, results
are display-only; gates consume only Layer 1 evidence or promoted
`CoordinationFact`s citing both layers via `evidence_refs`. Chain-
promotion rule from ADR 0019 v3 enforces non-promotability when
`KnowledgeChunk` references are present in `derived_from`.

**`system.workspace.manifest.v1`** (Ring 2 read-only view
operation; the manifest as a query). Input: `(workspace_id,
filter_kind: "full" | "leases_only" | "protected_paths_only" |
"mcp_config_only")`. Output: a projection record (NOT a Ring 0
entity). Generated on read from authoritative Ring 0 state;
idempotent re-generation. The manifest is NOT a file; there is no
`workspace.yaml` committed to the repo.

**WorkspaceContext field additions** (posture; schema PR commits):

- `manifest_valid_until` — derived from `min(Evidence.valid_until)`
  across linked records; Layer 2 broker re-check invalidates the
  manifest on expiry.
- `verify_operations` — array of `evidenceRefSchema` references to
  `OperationShape` records of operation_class `workspace_verify`
  (see Sub-decision (c)).
- `search_exclusions` / `lint_exclusions` / `docs_exclusions` —
  producer-asserted, kernel-verifiable arrays of
  `{patterns: [glob|regex], applied_tool_kind: enum,
  exclusion_authority_kind: enum}`.
- `docs_taxonomy_evidence_refs` — array of `evidenceRefSchema`
  references to `KnowledgeSource` records of
  `source_kind: "audit_profile" | "cycle_history" | "charter" |
  "adr" | "decision_ledger" | "runbook"` covering the workspace's
  docs taxonomy.

**Rejected alternatives:**

- `workspace.yaml` committed in repo as source of truth — rejected
  per Q-011 dedupe plan ("avoid second source of truth"); creates
  synchronization hazard between manifest and authoritative Ring 0
  state; violates inv. 13 deletion-authority rule if manifest lists
  protected paths.
- Host-level workspace registry as Ring 0 entity — rejected per
  Q-011 dedupe plan; mutations should flow through existing Ring 0
  entities (`WorkspaceContext`, `CoordinationFact`, `Lease`,
  `BoundaryObservation`), not a parallel registry.

### Sub-decision (c) — Five governance elements composition

Each manifest field gets a typed home in **existing** entity space
plus minimal additions:

#### Protected paths → `boundary_dimension: filesystem_authority`

Promote `filesystem_authority` from charter-prose-token (currently
referenced in v1.3.2 invariant 17 forbidden-pattern entry) to a
**registry-committed `boundary_dimension`** with payload shape.
ADR 0022 §`boundary_dimension` registry already lists
`filesystem_authority` as a candidate; this ADR commits the payload
shape.

**`claim_kind` sibling-discriminator (Sub-rule 5 pattern, mirrors
ADR 0034 v2 `git_signing_format_kind`):** `filesystem_authority`
boundary observations carry a `claim_kind` discriminator
distinguishing the question being answered:

- **`claim_kind: "inheritance_assertion"`** — answers "does child
  execution context inherit filesystem authority from parent?"
  Per-context, per-launch. Default false; non-default requires
  linked-observation chain. Closes the v1.3.2 inv. 17 forbidden-
  pattern entry at evidence shape (not just charter rule). Payload
  (illustrative): `{inheritance_held: bool,
  inheritance_evidence_refs: array<evidenceRefSchema>}`.
- **`claim_kind: "protected_paths_registry"`** — answers "what
  paths in this workspace are under D-025 authority and what is
  their authority source?" Per-workspace, per-snapshot. Cleanup
  capability gates on this. Payload (illustrative):
  `{protected_paths: array<{path, path_authority_kind,
  path_authority_source_evidence_ref}>}`. Path_authority_kind
  candidate values: `"rule_binding" | "lease_scope" |
  "tcc_authorization" | "human_dashboard_grant"`.
- **`claim_kind: "path_authority_check"`** — answers "for this
  specific operation × path, what is the authority?" Per-operation,
  per-path. **Reserved for stage-2; mentioned but not committed by
  this ADR.** Stage-2 Q-* row commits the payload shape if and when
  per-operation per-path lookups become a Ring 1 service.

This three-claim_kind structure is registry Sub-rule 5 sibling-
discriminator territory: each `claim_kind` value selects which
sibling payload-block applies. The schema PR commits the discriminated
union; ADR 0036 commits the discriminator + the three reserved
values.

#### Search / lint / docs exclusions → producer-asserted on WorkspaceContext

Modeled directly on `WorkspaceContext` as producer-asserted,
kernel-verifiable arrays. Layer 1 mint API validates structure;
Layer 2/3 re-check exclusion-pattern validity at operation-execution
time against repo state.

Field shape (illustrative): each exclusion array entry is
`{patterns: array<glob|regex>, applied_tool_kind:
"git" | "ripgrep" | "shellcheck" | "biome" | "eslint" | "ruff" |
"docs_indexer", exclusion_authority_kind:
"rule_binding" | "tool_config_read" | "audit_profile_claim"}`.

#### Canonical MCP config → NEW `boundary_dimension: mcp_canonical_source`

A new `boundary_dimension` registered via `BoundaryObservation`
envelope. Closes the duplicate-MCP-config canonicality concern
surfaced in the 2026-04-30 Budget Triage planning evidence.

Payload (illustrative): `{mcp_server_kind: enum (per ADR 0033 v2),
canonical_install_source_kind: enum (per ADR 0034 v2 ToolProvenance),
canonical_credential_source_evidence_ref: evidenceRefSchema (to
`CredentialSource` per ADR 0018), shim_chain_evidence_ref:
evidenceRefSchema (to `ToolProvenance`), canonical_authority_kind:
enum (e.g., "system_install" | "user_install" | "homebrew" |
"mise" | "direnv_provided")}`.

Layer 1 unique constraint: at most one `BoundaryObservation` of
`boundary_dimension: mcp_canonical_source` per `(execution_context_id,
mcp_server_kind)` triple in `proven` state. Producers minting a
duplicate-target observation reject with new
`Decision.reason_kind: duplicate_mcp_config_detected` (see
§`Decision.reason_kind` reservations below).

#### Verify commands → NEW `VerificationCommand` (Q-011 bucket 2 entity)

A new no-suffix Ring 0 entity (Q-011 bucket 2: standalone Ring 0
entity with durable identity and lifecycle) bound to `OperationShape`.
Free-form CLI strings rejected at Layer 1 mint API per inv. 2 (no
shell-string canonical form).

Field shape (illustrative; schema PR commits final):

- `verification_command_id` — primary key.
- `workspace_context_id` — typed FK.
- `command_shape` — typed `OperationShape` payload (per inv. 2; no
  shell-string).
- `expected_exit_codes` — `{success_codes: array<int>,
  allowed_failure_codes: array<int>}`.
- `output_evidence_kind: "verification_receipt" | "diagnostic_report"`
  — discriminator per registry Sub-rule 6.
- `verification_command_state: "active" | "deprecated" | "retired"`
  — bare-noun central-concept discriminator per Sub-rule 8 (mirrors
  ADR 0031 v1 `lease_state` precedent).

NEW operation_class on `OperationShape`: **`workspace_verify`** with
`mutation_scope: "verify_workspace"`. CommandShape payloads carry
typed argv arrays (no shell-string per inv. 2).

#### Docs taxonomy → `KnowledgeSource.source_kind` extensions

Two new `source_kind` values: `"audit_profile"` (for
`profile/<date>/project_profile.yaml`), `"cycle_history"` (for
`cycle-history.md` and `cycle-history-notes.md`). The existing five
values from ADR 0019 v3 (`charter`, `adr`, `decision_ledger`,
`runbook`, `vendor_doc`) cover the rest. `KnowledgeSource.content_hash`
re-indexing rule + label-recheck rule from ADR 0019 v3 §Secret-
referenced sources apply uniformly.

#### Cleanup rules → `OperationShape.deletion_authority_source_ref` field-shape

Per D-025 (deletion authority is not gitignore), cleanup operations
must cite a typed authority source. ADR 0036 commits the field-
shape, NOT a new entity. The user reframe explicitly rejected
introducing a `CleanupAuthoritySource` no-suffix entity (would risk
ontology-reviewer pushback because `Source` looks like an entity-
name root precedent: `KnowledgeSource`, `CredentialSource`).

NEW field on `OperationShape`:

- `deletion_authority_source_ref` — polymorphic FK per ADR 0019 v3
  `subject_ref` precedent (`<thing>_ref` polymorphic single-FK).
  Resolves to one of the authority-kind targets enumerated below.
- `deletion_authority_kind` — closed-enum discriminator with reserved
  values:
  - `"protected_paths_registry"` — references a
    `BoundaryObservation` of `boundary_dimension:
    filesystem_authority` with `claim_kind: protected_paths_registry`.
  - `"coordination_fact"` — references a promoted
    `CoordinationFact` of `subject_kind: workspace` with relevant
    `predicate_kind` (e.g., `claimed_to_contain` /
    `confirmed_to_contain`).
  - `"human_dashboard_grant"` — references an `ApprovalGrant`
    minted via dashboard-only break-glass (per ADR 0035 v2 +
    canonical policy at Milestone 2).
  - `"runtime_state_classification"` — references a typed
    classification of runtime state (e.g., per-charter inv. 10
    deployment-boundary observations under
    `~/Library/Application Support/host-capability-substrate/`).

Cleanup operations citing `deletion_authority_kind: "gitignore"` or
similar non-typed authority reject at Layer 1 mint API per D-025 +
inv. 13.

### Sub-decision (d) — Three regression traps staged behind dependencies

All three traps accepted as design intent; **fixtures land when their
evidence dependencies clear**. Trap entries reserved in
`packages/evals/traps/` registry NOW (with stage-blocked status),
fixtures filled when underlying schemas land:

#### Trap #26 — `nested-worktree-search-contamination`

- **What it tests**: `GitWorktreeInventoryObservation`
  (ADR 0030 v2) correctly excludes worktrees nested under parent
  worktree paths. (E.g., a primary repo at
  `/ws/repo/.git/worktrees/branch-a` with a child Lease at
  `/ws/repo/.git/worktrees/branch-a/linked-work/` — inventory for
  `branch-a` MUST NOT list `linked-work` as a separate worktree.)
- **Rejection class on failure**: existing `worktree_inventory_partial`
  reason_kind from ADR 0030 v2 OR Layer 1 mint rejection if path
  containment check fails.
- **Stage-blocked on**: `GitWorktreeInventoryObservation` schema PR
  (ADR 0030 v2 schema-implementation pending).

#### Trap #27 — `duplicate-mcp-config-canonicality`

- **What it tests**: Layer 1 unique constraint on `boundary_dimension:
  mcp_canonical_source` rejects duplicate-target mints; Layer 2
  broker re-check catches stale entries.
- **Rejection class on failure**: NEW `Decision.reason_kind:
  duplicate_mcp_config_detected` (committed in §`Decision.reason_kind`
  reservations below).
- **Stage-blocked on**: `boundary_dimension: mcp_canonical_source`
  schema commitment + ADR 0036 acceptance.

#### Trap #28 — `docs-planning-index-projection-drift`

- **What it tests**: When a `KnowledgeSource` of `source_kind:
  "audit_profile"` or `"cycle_history"` has its `content_hash`
  change, ADR 0019 v3 §Re-indexing label-recheck triggers chunk
  invalidation; Layer 3 gateway re-derive serves fresh projection.
- **Rejection class on failure**: existing
  `knowledge_source_content_drift` reason_kind from ADR 0019 v3.
- **Stage-blocked on**: `KnowledgeSource.content_hash` re-index hook
  from ADR 0019 v3 schema PR.

### Sub-decision (e) — Claim reconciliation already settled by ADR 0019 v3

**No new entity.** Claim reconciliation does NOT introduce a new
`ClaimReconciliationReceipt` Ring 0 evidence subtype. ADR 0019 v3
already covers it:

- **Claims become `DerivedSummary` records** (default
  `allowed_for_gate: false` per ADR 0019 v3 chain-promotion rule).
- **Reconciliation is a Layer 3 retrieval projection** composing
  Layer 1 evidence + Layer 2 audit-profile claims; the projection
  IS the reconciliation result.
- **Gateability requires verifier visibility-authority rule** (ADR
  0019 v3 v3 §Verifier visibility-authority rule). The audit
  framework's "smoke-test before shipping" (Phase 10.5 of the audit
  spec) maps to verifier-class privilege at promotion time.
- **No new reconciliation operation.** `system.claims.reconcile.v1`
  is subsumed: any consumer wanting a reconciliation queries
  Layer 3 retrieval directly.

This avoids re-litigating Q-003's promotion workflow for workspace
claims specifically and avoids minting a parallel reconciliation
entity that would compete with `DerivedSummary`.

### Two structural commitments

#### Subject-kind reservations: `workspace`, `audit_profile`

Per ADR 0019 v3 §Predicate-kind registry reservation, the
follow-up registry update PR reserves NEW `subject_kind` values for
`CoordinationFact`:

- **`subject_kind: "workspace"`** — `subject_ref` resolves to a
  `(workspace_context_id)` reference (or
  `(workspace_id, repository_id)` pair for multi-repo workspaces;
  Phase 1 default is single-repo per ADR 0031 v1 cardinality).
- **`subject_kind: "audit_profile"`** — `subject_ref` resolves to
  `(workspace_context_id, audit_profile_revision_date)` pair
  binding a specific profile snapshot.

#### Predicate-kind reservations: `claimed_to_contain`, `confirmed_to_contain`, `superseded_by`

Three NEW `predicate_kind` values for the audit framework's
claim/confirmation/halt vocabulary:

- **`predicate_kind: "claimed_to_contain"`** — the audit profile
  claims the workspace contains a specific bounded context. Default
  `allowed_for_gate: false` until promoted via Q-003 verifier
  workflow.
- **`predicate_kind: "confirmed_to_contain"`** — the audit
  framework's smoke-test (Phase 10.5) confirmed the claim through
  Layer 1 evidence. Composes with the verifier visibility-authority
  rule.
- **`predicate_kind: "superseded_by"`** — a prior audit profile's
  claim is superseded by a fresher snapshot. Maps to ADR 0019 v3
  §Re-indexing label-recheck pattern at the CoordinationFact layer.

#### `cycle-history.md` ↔ CoordinationFact lifecycle binding

The audit framework's `cycle-history.md` (operator-ratified) +
`cycle-history-notes.md` (audit-proposed) workflow is **structurally
identical to Q-003's "agent proposes / verifier promotes" pattern**.
ADR 0036 commits the binding:

- **Audit framework proposes** via `cycle-history-notes.md` →
  produces unpromoted `CoordinationFact` records of
  `subject_kind: "audit_profile"` with
  `predicate_kind: "claimed_to_contain"` (or similar) and
  `allowed_for_gate: false`.
- **Operator approves** via `cycle-history.md` ratification →
  triggers Q-003 promotion-grant workflow → fact transitions to
  `allowed_for_gate: true` (via the existing promotion path,
  including verifier visibility-authority rule + chain-promotion
  rule per ADR 0019 v3).
- **Audit-chain participation** — promotion events emit typed
  `Decision` records per registry v0.3.1 §Audit-chain coverage of
  rejections (extended to promotions per ADR 0019 v3 §Promotion
  audit-record completeness). The audit framework gets HCS's
  audit-chain participation and force-protected non-escalable
  enforcement for free.

This binding gives HCS a real-world claim-promotion exemplar that
is not synthetic, and gives the audit framework HCS-grade audit-
chain integrity.

### Cross-cutting rules

#### Authority discipline

Per registry v0.3.2 §Producer-vs-kernel-set:

- **Kernel-set**: workspace-diagnose service mints via
  `mint_api` (existing allowlist; no new producer class);
  `manifest_valid_until` derived from min(Evidence.valid_until)
  across linked records.
- **Producer-asserted, kernel-verifiable**: `verify_operations`
  array on `WorkspaceContext`; `search_exclusions` / `lint_exclusions`
  / `docs_exclusions` arrays; `docs_taxonomy_evidence_refs` array.
- **Audit-profile content-hash re-classification**: when
  `KnowledgeSource.security_label` upgrades from `"internal"` to
  `"secret_referenced"` (because `op://` references appear in
  re-indexed content), the chunk-invalidation purge rule from ADR
  0019 v3 §Secret-referenced sources fires. **This is the rule
  working correctly; the security reviewer should not flag it as
  a regression.** Audit profiles are designed to be human-readable
  and may quote source files containing `op://` references in
  `audit_attention_flags` and citation blocks; the re-classification
  path is expected, not exceptional.

#### Cross-context binding rules per Ring 1 layer

Per registry v0.3.0:

- **`boundary_dimension: filesystem_authority`**: Layer 1 enforces
  `claim_kind` discriminator + sibling-payload validity; Layer 2/3
  re-checks per per-`claim_kind` rules.
- **`boundary_dimension: mcp_canonical_source`**: Layer 1 enforces
  `(execution_context_id, mcp_server_kind)` uniqueness; Layer 2/3
  re-checks shim-chain freshness via `ToolProvenance` re-derivation.
- **`VerificationCommand`**: Layer 1 enforces
  `(workspace_context_id, command_shape)` consistency; Layer 2 re-
  evaluates verification at operation-execution time per
  registry v0.3.0 §Cross-context enforcement layer.
- **`KnowledgeSource` of `source_kind: "audit_profile" |
  "cycle_history"`**: standard ADR 0019 v3 cross-context binding
  rules apply; cross-workspace audit-profile reuse rejected at
  Layer 1.

#### Sandbox-promotion rejection (charter inv. 8)

Inherited from ADR 0019 v3 / ADR 0034 v2 / ADR 0035 v2:

- `boundary_dimension: filesystem_authority` and
  `boundary_dimension: mcp_canonical_source` observations with
  `Evidence.authority` in `{sandbox-observation, self-asserted}`
  cannot be promoted to host-authoritative gate evidence.
- `VerificationCommand` records cited in operations cannot launder
  sandbox-derived authority.
- `system.workspace.diagnose.v1` `DerivedSummary` outputs cannot
  promote across the sandbox/host boundary; per ADR 0019 v3 chain-
  promotion rule, `KnowledgeChunk` references in `derived_from`
  block promotion regardless of authority class.

### `Decision.reason_kind` reservations

Two new rejection-class names reserved (posture-only; schema enum
lands per `.agents/skills/hcs-schema-change`):

- **`duplicate_mcp_config_detected`** — Layer 1 mint API rejects
  duplicate-target `BoundaryObservation` of `boundary_dimension:
  mcp_canonical_source` for the same `(execution_context_id,
  mcp_server_kind)` triple where an existing observation is in
  `proven` state. Decision-level per ADR 0029 v2 framing; not
  forbidden-tier.
- **`workspace_verify_command_failed`** — Layer 2 broker FSM
  re-runs a `VerificationCommand` at operation-execution time and
  the command's exit code is not in
  `expected_exit_codes.success_codes`. Operations gating on
  workspace verification reject with this reason_kind.

The existing reason_kinds cover the other failure modes:

- `worktree_inventory_partial` (ADR 0030 v2) — Trap #26 rejection.
- `knowledge_source_content_drift` (ADR 0019 v3) — Trap #28
  rejection.
- `derived_summary_unpromoted_dependency` (ADR 0019 v3) — Chain-
  promotion rule rejection for workspace-diagnose summaries citing
  `KnowledgeChunk` refs.

### Out of scope

This ADR does not authorize:

- Zod schema source for `VerificationCommand`,
  `boundary_dimension: filesystem_authority` / `mcp_canonical_source`
  payload schemas, or `OperationShape` field additions
  (`deletion_authority_source_ref`, `deletion_authority_kind`).
  Schema lands per `.agents/skills/hcs-schema-change`.
- `evidenceSubjectKindSchema` enum extension for `verification_command`
  (NEW subject-kind value). Schema PR commits.
- Registry update PR for: 2 new `KnowledgeSource.source_kind` values
  (`audit_profile`, `cycle_history`); 2 new `CoordinationFact.subject_kind`
  values (`workspace`, `audit_profile`); 3 new `predicate_kind` values
  (`claimed_to_contain`, `confirmed_to_contain`, `superseded_by`);
  2 new `boundary_dimension` values (`filesystem_authority` payload
  promotion, `mcp_canonical_source` new); 1 new operation_class
  (`workspace_verify`); 4 new `deletion_authority_kind` enum values
  (`protected_paths_registry`, `coordination_fact`, `human_dashboard_grant`,
  `runtime_state_classification`); 3 new `claim_kind` values for
  `filesystem_authority` (`inheritance_assertion`,
  `protected_paths_registry`, `path_authority_check` reserved-only).
- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. Per-
  `boundary_dimension` freshness windows; per-operation_class
  composition rules; verifier-class privileges for audit-framework
  promotion grants; canonical exclusion-pattern conflict resolution.
- Four deferred diagnostic operations (`system.runtime.diagnose.v1`,
  `system.git.diagnose.v1`, `system.docs.diagnose.v1`,
  `system.cleanup.plan.v1`); each defers until evidence dependencies
  clear (Q-006 stage-3, Q-008 typed inputs, Milestone 2 canonical
  policy).
- `system.claims.reconcile.v1` operation. Subsumed into ADR 0019 v3
  `DerivedSummary` + Q-003 promotion workflow per Sub-decision (e).
- ADR 0026 substrate hook architecture (still gated on stage-1
  `BranchProtectionObservation` schema landing).
- Charter inv. 19 amendment text (separate charter PR per change-
  policy, per ADR 0034 v2).
- Q-010 sub-decisions (separate Q-row).
- `path_authority_check` `claim_kind` payload commitment (stage-2
  Q-* row).

## Consequences

### Accepts

- Q-009 settled at the design layer with a three-layer projection
  model, one new Ring 1 operation, one new Ring 0 entity
  (`VerificationCommand`), one new `boundary_dimension`
  (`mcp_canonical_source`), one promoted `boundary_dimension`
  (`filesystem_authority` from charter prose to registry payload),
  three new `claim_kind` discriminator values, two new
  `KnowledgeSource.source_kind` values, two new
  `CoordinationFact.subject_kind` values, three new `predicate_kind`
  values, four new `deletion_authority_kind` enum values, one new
  `operation_class` (`workspace_verify`), and three regression traps
  staged behind evidence dependencies.
- The workspace manifest is a Layer 3 retrieval projection (NOT a
  Ring 0 entity, NOT a file). Three explicit input layers compose
  via existing entities + minimal additions.
- The audit framework's `project_profile.yaml` is registered as a
  typed Layer 2 input (`KnowledgeSource` of `source_kind:
  "audit_profile"`) rather than a parallel HCS-specific manifest
  artifact. Profile-diff drift detection inherits ADR 0019 v3 §Re-
  indexing label-recheck rule.
- `system.workspace.diagnose.v1` outputs a `DerivedSummary` whose
  `derived_from` cites Layer 1 + Layer 2 evidence. ADR 0019 v3
  chain-promotion rule structurally blocks gate-promotion when
  `KnowledgeChunk` refs are present (display-only by structure;
  no new gateability mechanism needed). Service mints via existing
  `mint_api` kernel-trusted producer (no new producer class).
- Claim reconciliation is settled by ADR 0019 v3 (`DerivedSummary`
  + Q-003 promotion workflow); NO new `ClaimReconciliationReceipt`
  entity.
- `cycle-history.md` ↔ CoordinationFact lifecycle binding
  committed: audit-framework's audit-proposes/operator-promotes
  workflow maps directly to Q-003's verifier promotion pattern.
- D-025 deletion-authority-source field-shape committed on
  `OperationShape` as polymorphic `deletion_authority_source_ref`
  + `deletion_authority_kind` closed-enum discriminator. NO new
  no-suffix `CleanupAuthoritySource` entity.

### Rejects

- `workspace.yaml` committed in repo as source of truth (Q-011
  dedupe plan rejection; second-source-of-truth failure mode).
- Host-level workspace registry as Ring 0 entity (Q-011 dedupe plan
  rejection).
- Five orthogonal new Ring 0 entities for protected paths /
  exclusions / MCP config / verify commands / docs taxonomy
  (overlaps with existing entities; user reframe).
- New `ClaimReconciliationReceipt` entity (subsumed into ADR 0019
  v3 `DerivedSummary`).
- New `WorkspaceDiagnosticReceipt` entity (subsumed into
  `DerivedSummary` via `system.workspace.diagnose.v1` output shape).
- New `DocsProjectionReceipt` entity (subsumed into
  `KnowledgeSource.source_kind` extensions).
- New `kernel_workspace_service` producer class (avoided; existing
  `mint_api` allowlist is sufficient).
- New no-suffix `CleanupAuthoritySource` entity (entity-name root
  ambiguity with `KnowledgeSource` / `CredentialSource`; replaced
  by typed field-shape on `OperationShape`).
- Free-form CLI strings as canonical verify commands (per inv. 2;
  `VerificationCommand.command_shape` carries typed
  `OperationShape`).
- Cleanup operations citing `gitignore` as deletion authority
  (per D-025 + inv. 13).
- Re-litigating Q-003's promotion workflow for workspace claims
  specifically (already accepted in ADR 0019 v3).

### Future amendments

- Schema PR per `.agents/skills/hcs-schema-change` for:
  `VerificationCommand` Ring 0 entity; `boundary_dimension:
  filesystem_authority` payload (3 `claim_kind` values committed
  here, stage-2 commits `path_authority_check` payload);
  `boundary_dimension: mcp_canonical_source` payload;
  `OperationShape.deletion_authority_source_ref` polymorphic FK +
  `deletion_authority_kind` closed enum; 2 new
  `Decision.reason_kind` reservations; new `operation_class:
  "workspace_verify"`.
- Registry update PR for the 2 new `KnowledgeSource.source_kind`
  values, 2 new `subject_kind` values, 3 new `predicate_kind`
  values, 1 new `boundary_dimension` (`mcp_canonical_source`),
  payload-shape commitment for promoted
  `boundary_dimension: filesystem_authority` with 3 `claim_kind`
  values, 4 new `deletion_authority_kind` values, 1 new
  `operation_class`.
- Trap fixtures land when their evidence dependencies clear
  (Trap #26: `GitWorktreeInventoryObservation` schema PR; Trap
  #27: `boundary_dimension: mcp_canonical_source` schema; Trap
  #28: `KnowledgeSource.content_hash` re-index hook).
- Stage-2 Q-* row commits `path_authority_check` `claim_kind`
  payload shape if and when per-operation per-path lookups become
  a Ring 1 service.
- Four deferred diagnostic operations land as evidence dependencies
  clear (`system.runtime.diagnose.v1`, `system.git.diagnose.v1`,
  `system.docs.diagnose.v1`, `system.cleanup.plan.v1`).
- Charter v1.4.0 amendment PR for inv. 19 text (per ADR 0034 v2
  candidate).
- Q-010 sub-decisions (separate Q-row).
- Reopen if the audit framework's `project_profile.yaml` schema
  evolves in ways that strain the `KnowledgeSource` model (e.g.,
  multi-document profiles, federated profiles across repos).

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md`
  v1.3.2 (especially inv. 1, 2, 5, 6, 7, 8, 10, 13, 16, 17;
  inv. 18 candidate per ADR 0019 v3; inv. 19 candidate per ADR
  0034 v2).
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
  (Authority discipline, Cross-context enforcement layer,
  Naming suffix discipline, Field-level scrubber rule, Secret-
  referenced sources rules).
- Decision ledger: `DECISIONS.md` Q-009 (this row); D-025
  (deletion authority is not gitignore); D-028 (host_secret_*
  compatibility contract).
- ADR 0018:
  `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
  (CredentialSource consumed by `mcp_canonical_source` payload).
- ADR 0019:
  `docs/host-capability-substrate/adr/0019-knowledge-and-coordination-store.md`
  (Q-003 v3 final; CoordinationFact composition pattern;
  KnowledgeSource / KnowledgeChunk / DerivedSummary; chain-promotion
  rule; verifier visibility-authority rule; promotion workflow;
  naming-discipline-never-memory; Predicate-kind registry
  reservation).
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (BoundaryObservation envelope; `filesystem_authority`
  candidate boundary_dimension; QualityGate deferral origin).
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract).
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (Q-006 stage-1 receipts; first-commit-SHA repository_id
  resolution).
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (Producer-vs-kernel-set authority fields; `mint_api` kernel-
  trusted producer allowlist).
- ADR 0030:
  `docs/host-capability-substrate/adr/0030-q-006-stage-2-source-control-evidence-subtypes.md`
  (Q-006 stage-2 receipts; `worktree_inventory_partial`
  reason_kind for Trap #26).
- ADR 0031:
  `docs/host-capability-substrate/adr/0031-q-008-d-worktree-ownership-composition.md`
  (Q-008(d) v1 final; WorkspaceContext one-to-one with worktree
  cardinality; Lease lifecycle).
- ADR 0034:
  `docs/host-capability-substrate/adr/0034-q-007-b-f-boundary-evidence-composition-quality-gate-posture.md`
  (Q-007 (b)-(f) v2 final; ToolProvenance / GitIdentityBinding;
  flat-payload composition pattern reference for
  `mcp_canonical_source`).
- ADR 0035:
  `docs/host-capability-substrate/adr/0035-q-007-g-quality-gate-standalone-entity.md`
  (Q-007(g) v2 final; gate identity triple pattern reference).
- 2026-04-30 HCS evidence/planning synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-hcs-evidence-planning-synthesis.md`
  (primary research source; seven candidate diagnostic operations;
  workspace manifest 11-field sketch).
- 2026-05-01 ontology promotion + receipt dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
  (line 142 workspace manifest "generated view candidate"
  guidance).
- Tooling-surface matrix:
  `docs/host-capability-substrate/tooling-surface-matrix.md`
  (MCP config canonicality + tooling-surface integration).
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`.

### External

- Audit framework `project_profile.yaml` format (referenced via the
  human owner's reframe; specific repo location is workspace-local
  and registered as a `KnowledgeSource` per Sub-decision (b) Layer
  2).
- XDG Base Directory Specification (referenced by §Path
  canonicalization rule from ADR 0034 v2 inherited):
  <https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html>
- macOS Application Support / Logs convention (charter inv. 10
  deployment boundary; runtime state under `~/Library/Application
  Support/host-capability-substrate/`):
  <https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFileSystem/Articles/MacOSXDirectories.html>
