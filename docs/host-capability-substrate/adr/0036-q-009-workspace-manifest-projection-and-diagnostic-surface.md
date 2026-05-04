---
adr_number: 0036
title: Q-009 HCS workspace manifest projection and diagnostic surface
status: accepted
date: 2026-05-04
charter_version: 1.3.2
tags: [workspace-manifest, diagnostic-surface, audit-profile, q-009, phase-1]
---

# ADR 0036: Q-009 HCS workspace manifest projection and diagnostic surface

## Status

accepted (v2)

## Date

2026-05-04 (v1); 2026-05-04 (v2 — closes 19 reviewer blockers across
architect / ontology / security; folds 11 non-blocking items);
2026-05-04 (v2 accepted with 5 mechanical tweaks)

## Revision history

- **v1 (2026-05-04)**: initial draft per user's structural reframe;
  three-layer projection model; five governance elements composing
  via existing entities + minimal additions.
- **v2 (2026-05-04)**: closes architect B1/B2/B3, ontology
  B-1..B-8, security B-1..B-8 (zero policy blockers in v1).
  Major restructurings: (i) split `filesystem_authority` into three
  separate `boundary_dimension` values per registry Sub-rule 1; (ii)
  introduce new `security_label: "secret_pointer"` for `op://`
  literal classification; (iii) `VerificationCommand` reclassified
  as `VerificationCommandSpec` (producer-asserted spec entity, not
  Q-011 bucket-2 standalone entity); (iv) all renames per
  ontology-reviewer cross-enum collision findings; (v) explicit
  Layer 1 host-observation grounding requirements for promotion of
  `subject_kind: workspace_context | audit_profile_snapshot`
  CoordinationFacts and for `deletion_authority_kind:
  filesystem_protected_paths_observation | coordination_fact`
  cleanup operations; (vi) named producer class for diagnose
  service rather than asserting `mint_api` is a producer-class
  enum value.
- **v2 accepted (2026-05-04)**: re-reviewed by architect /
  ontology / policy / security — zero v2 blockers across all four
  reviewers. Five mechanical tweaks folded at acceptance:
  (1) Sub-decision (b) three-state label progression now defers
  to §Authority discipline as canonical normative statement;
  (2) §Authority discipline three-state progression adds
  most-restrictive-label-wins semantics for simultaneous
  pointer + resolved-secret introduction; (3) Sub-decision (c)
  Cleanup rules cross-references the canonical closed-list
  fail-mode tightening rule restatement in §Decision.reason_kind
  reservations; (4) §Rejects `mcp_canonical_source` rationale
  cross-references registry v0.3.3 §Naming suffix discipline;
  (5) §Future amendments adds Layer 1 grounding rule
  extensibility principle (subject_kinds backed by derived/Layer-2
  content require Layer 1 grounding at introduction time).

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
  `DerivedSummary` (per ADR 0019 v3), NOT a new typed Receipt.
- (b) Workspace manifest is a **generated view**, NOT a source of
  truth. Three explicit input layers: Layer 1 operational truth
  (existing entities); Layer 2 claims snapshot (audit framework
  `project_profile.yaml` registered as `KnowledgeSource`); Layer 3
  derived retrieval projection (per ADR 0019 v3).
- (c) Five governance elements compose via existing entities +
  three new `boundary_dimension` values (split of `filesystem_*`)
  + one new `boundary_dimension` (`mcp_canonical_authority`) + one
  new producer-asserted spec entity (NOT five orthogonal new
  entities): protected paths via promoted `boundary_dimension:
  filesystem_protected_paths`; filesystem inheritance via
  `boundary_dimension: filesystem_inheritance`; search/lint
  exclusions producer-asserted on `WorkspaceContext`; canonical
  MCP config via NEW `boundary_dimension: mcp_canonical_authority`;
  verify commands via NEW `VerificationCommandSpec` producer-
  asserted spec entity; docs taxonomy via
  `KnowledgeSource.source_kind` extensions.
- (d) Three regression traps (#26-#28) accepted but staged behind
  evidence dependencies.
- (e) Claim reconciliation is ALREADY settled by ADR 0019 v3. Claims
  become `DerivedSummary` records (default `allowed_for_gate:
  false`); reconciliation is a Layer 3 retrieval projection;
  gateability requires verifier visibility-authority rule + Layer 1
  host-observation grounding rule (committed by this ADR for
  `subject_kind: workspace_context | audit_profile_snapshot`
  promotions). NO new `ClaimReconciliationReceipt` entity.

## Decision

### Sub-decision (a) — Diagnostic operations: phase 1 minimum

**Phase 1 commits ONLY `system.workspace.diagnose.v1`.** Four other
candidate operations defer until their evidence dependencies clear.

**`system.workspace.diagnose.v1`** (Ring 1 read-only operation;
`operation_class: "read_only_diagnostic"` per ADR 0029 v2):

- Input: `(workspace_id, include_stale_evidence: bool)`.
- Output: a `DerivedSummary` (per ADR 0019 v3) whose `derived_from`
  array cites Layer 1 operational evidence (e.g.,
  `GitRepositoryObservation`, `WorkspaceContext`, active `Lease`s,
  active `CoordinationFact`s) AND Layer 2 audit-profile content
  (`KnowledgeChunk` records from `KnowledgeSource` records of
  `source_kind: "audit_profile_yaml"` and `"cycle_history"`).
- `summary_kind: "operational_summary"` (already reserved in ADR
  0019 v3 enum; no new reservation needed).
- `Evidence.authority: "derived"` and `Evidence.confidence:
  "best-effort"` (fixed per ADR 0019 v3 `DerivedSummary`).
- **`Evidence.producer: "kernel_workspace_diagnose"`** — a NEW
  kernel-trusted producer class. The v1 attempt to assert
  `Evidence.producer: "mint_api"` was incorrect: `mint_api` is a
  Ring 1 layer name (per ADR 0019 v3 §Promotion workflow), not a
  producer-class enum value. The kernel-trusted producer allowlist
  is extended with `kernel_workspace_diagnose` as a registry
  follow-up dependency (enumerated in §Out of scope).
- **`summary_text` mint-time scrubber rule** (NEW): the diagnose
  service's `summary_text` field passes through the registry
  v0.3.3 §Field-level scrubber rule before mint commit; on match,
  Layer 1 mint API rejects with NEW `Decision.reason_kind:
  derived_summary_secret_shape_in_text` (committed in §Decision.
  reason_kind reservations below). This composes with ADR 0019 v3
  §Secret-referenced sources but applies regardless of the
  `derived_from` graph's source labels — including derived from
  `internal`-classified sources that nonetheless contain secret-
  shape patterns.
- `mutation_scope: "none"` (read-only diagnostic).

**Composition rule — both `allowed_for_gate: false` default AND
chain-promotion rule do work** (revised per architect B2). Per
ADR 0019 v3 §`DerivedSummary` shape, all `DerivedSummary` records
default to `allowed_for_gate: false` — which structurally prevents
immediate gate consumption regardless of `derived_from` content.
Per ADR 0019 v3 §Chain promotion rule, a `DerivedSummary` whose
`derived_from` graph contains any `KnowledgeChunk` reference (or any
unpromoted record, or any sandbox/self-asserted authority) is
**non-promotable**. Both rules apply to `system.workspace.diagnose.v1`
outputs:

- The default `allowed_for_gate: false` makes the diagnose summary
  display-only at mint.
- The chain-promotion rule blocks any later attempt to promote
  `allowed_for_gate: true` whenever the `derived_from` graph cites
  audit-profile `KnowledgeChunk`s (which is the routine case).
- A workspace diagnostic can never accidentally gate a destructive
  operation — it sits behind both barriers.

This is not a regression of inv. 18 — it is the inv. 18 candidate
working correctly across the audit-framework boundary. Promotion
requires re-derivation through the typed-evidence path and additional
host-observation grounding (see §Layer 1 grounding requirement
below); promotion through the summary itself is structurally
impossible.

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
  ADR 0034 v2 four queued; ADR 0036 promotes
  `filesystem_inheritance` + `filesystem_protected_paths` + adds
  `mcp_canonical_authority`; reserves `filesystem_path_authority_check`
  for stage-2).
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
`source_kind: "audit_profile_yaml"` (and adjacent
`source_kind: "cycle_history"` for `cycle-history.md`).
`security_label` defaults to `"internal"`; profile-diff drift
detection re-indexes via the existing
`KnowledgeSource.content_hash` change rule. Profile chunks become
`KnowledgeChunk` records.

**`security_label: "secret_pointer"` (NEW value, closes security
B-1).** A new `security_label` value distinct from
`"secret_referenced"`. Semantics:

- `"secret_pointer"` applies to sources that legitimately contain
  pointer-shaped strings (e.g., `op://Vault/Item/field`) but not
  resolved secret values. Chunks remain embedding-eligible (unlike
  `"secret_referenced"`, which forces `embedding_ref: null`).
- Layer 1 mint API enforces: a chunk classified `"secret_pointer"`
  must contain only pointer-shaped strings matching the pointer
  vocabulary (`op://...`, `vault:...`, `keyring:...`, `kms:...`).
  If a pointer-classified chunk contains content matching a
  resolved-secret shape (long hex strings, JWT shapes, AWS-key
  shapes, password-keyed YAML lines), the mint rejects with
  existing `Decision.reason_kind: secret_resolution_in_chunk`
  (ADR 0019 v3) — closes security B-2.
- Audit-profile chunks default to `"secret_pointer"` if they
  contain `op://` references; `"internal"` otherwise; `"secret_
  referenced"` only if a resolved-secret pattern is detected
  (which forces purge per ADR 0019 v3 chunk-invalidation rule).
- The label-recheck rule from ADR 0019 v3 §Re-indexing label-recheck
  applies; the canonical three-state progression
  (`"internal"` → `"secret_pointer"` → `"secret_referenced"`,
  including direct upgrade paths and most-restrictive-wins
  semantics) is committed in §Authority discipline below — see
  there for the normative statement.

**Universal scrubber rule (NEW, closes security B-2).** Layer 1 mint
API runs the registry v0.3.3 §Field-level scrubber against
`KnowledgeChunk.content` before persistence **regardless of
`security_label`**. The scrubber matches against the closed
secret-shape pattern set (long hex, JWT shape, AWS-key shape, common
password-keyed YAML lines, etc.). Any match rejects the chunk mint
with existing `Decision.reason_kind: secret_resolution_in_chunk`
(ADR 0019 v3). This guards against an audit profile that is
classified `"internal"` (because no `op://` patterns appear) but
contains a copy-pasted resolved secret value.

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
  manifest on expiry. **Empty-set behavior** (closes security
  NB-5): when no linked records carry `valid_until` (e.g., all are
  derived summaries), `manifest_valid_until` is set to `null` and
  the manifest is treated as immediately stale by Layer 2/3
  re-check; the diagnose op explicitly flags this case in
  `summary_text` with a typed annotation.
- `verify_operations` — array of `evidenceRefSchema` references to
  `VerificationCommandSpec` records (see Sub-decision (c)).
- `search_exclusions` / `lint_exclusions` / `docs_exclusions` —
  producer-asserted, kernel-verifiable arrays. Each entry carries a
  discriminated-union pattern shape (closes ontology N-4):
  `{pattern_kind: "glob" | "regex", pattern: string,
  applied_tool_kind: enum, exclusion_authority_kind: enum}`.
- `docs_taxonomy_evidence_refs` — array of `evidenceRefSchema`
  references to `KnowledgeSource` records of
  `source_kind: "audit_profile_yaml" | "cycle_history" | "charter"
  | "adr" | "decision_ledger" | "runbook"` covering the workspace's
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

#### Filesystem authority → THREE separate boundary_dimensions

(Closes architect B1 + ontology B-6.) Per registry Sub-rule 1
("Singular discriminator. A boundary fact carries one
`boundary_dimension`"), three structurally distinct claim shapes
cannot be collapsed onto a single boundary_dimension via a
sibling-payload `claim_kind` discriminator. The v1 attempt to use
`claim_kind` on a single `filesystem_authority` value violates
Sub-rule 1; v2 splits them.

**`boundary_dimension: "filesystem_inheritance"`** — answers "does
child execution context inherit filesystem authority from parent?"
Per-context, per-launch. Default false; non-default requires
linked-observation chain. Closes the v1.3.2 inv. 17 forbidden-
pattern entry at evidence shape (not just charter rule). Payload
(illustrative): `{inheritance_held: bool,
inheritance_evidence_refs: array<evidenceRefSchema>}`.

**`boundary_dimension: "filesystem_protected_paths"`** — answers
"what paths in this workspace are under D-025 authority and what
is their authority source?" Per-workspace, per-snapshot. Cleanup
capability gates on this. Payload (illustrative):
`{protected_paths: array<{path, path_authority_kind,
path_authority_source_evidence_ref}>}`. **`path_authority_kind`
candidate values** (closes security NB-1 — `tcc_authorization`
renamed to `tcc_scoped` because TCC defines scope, not deletion
authority): `"rule_binding" | "lease_scope" | "tcc_scoped" |
"human_dashboard_grant"`.

**`boundary_dimension: "filesystem_path_authority_check"`** —
answers "for this specific operation × path, what is the
authority?" Per-operation, per-path. **Reserved for stage-2;
mentioned but not committed by this ADR.** Stage-2 Q-* row
commits the payload shape if and when per-operation per-path
lookups become a Ring 1 service (closes security NB-3).

The three boundary_dimensions compose cleanly with ADR 0034 v2's
flat-payload pattern: each has a single uniform payload shape, no
sibling-discriminator collapse. Linked-observation pattern (per
ADR 0022) used when a single workspace assertion needs to bind
across two of the three (e.g., a child execution context that
inherits AND is constrained to a protected-paths subset).

#### Search / lint / docs exclusions → producer-asserted on WorkspaceContext

Modeled directly on `WorkspaceContext` as producer-asserted,
kernel-verifiable arrays. Layer 1 mint API validates structure;
Layer 2/3 re-check exclusion-pattern validity at operation-execution
time against repo state.

Field shape (illustrative; closes ontology N-4 with explicit
discriminated-union):

```
{
  pattern_kind: "glob" | "regex",
  pattern: string,
  applied_tool_kind: "git" | "ripgrep" | "shellcheck" | "biome"
                   | "eslint" | "ruff" | "docs_indexer",
  exclusion_authority_kind: "rule_binding" | "tool_config_read"
                          | "audit_profile_claim"
}
```

Cross-tool conflict resolution (e.g., ripgrep and biome with
overlapping but non-identical exclusion patterns) is a known
stage-2 concern (closes security NB-2) — the manifest projection
flags conflicts in `summary_text` but does not auto-resolve;
canonical policy YAML at Milestone 2 commits the resolution rule.

#### Canonical MCP config → NEW `boundary_dimension: mcp_canonical_authority`

(Closes ontology B-4 — renamed from v1's `mcp_canonical_source`
because the `_source` suffix collides with the `KnowledgeSource` /
`CredentialSource` entity-name-root convention. The boundary
dimension classifies which authority class names the canonical
install, not a source.)

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

**`redaction_mode: "reference_only"`** (closes security B-6). All
`mcp_canonical_authority` BoundaryObservation payloads carry
`redaction_mode: "reference_only"`; resolved credential values are
never stored in the observation payload. The
`canonical_credential_source_evidence_ref` field resolves to a
`CredentialSource` reference, not an inlined value.

Layer 1 unique constraint: at most one `BoundaryObservation` of
`boundary_dimension: mcp_canonical_authority` per
`(execution_context_id, mcp_server_kind)` triple in `proven` state.
Producers minting a duplicate-target observation reject with new
`Decision.reason_kind: mcp_canonical_authority_duplicate` (renamed
per ontology B-7 — see §Decision.reason_kind reservations below).

**Decision body for duplicate detection** (closes security B-6):
the `mcp_canonical_authority_duplicate` Decision body cites both
conflicting observations by `evidenceRefSchema` reference only,
never by resolved credential-source content. The Decision body
passes the §Field-level scrubber before persistence.

#### Verify commands → NEW `VerificationCommandSpec` (producer-asserted spec entity)

(Closes ontology B-5 + security B-4.) **Renamed from v1's
`VerificationCommand`.** The entity holds the *spec/shape* of a
verify command (producer-asserted, kernel-verifiable). Per-execution
verification *results* would be separate `Evidence` records (not
introduced in this ADR). The `Spec` suffix per registry suffix
discipline correctly classifies this as a producer-asserted shape,
not a Q-011 bucket-2 standalone entity with full provenance ladder.

Free-form CLI strings rejected at Layer 1 mint API per inv. 2 (no
shell-string canonical form).

Field shape (illustrative; schema PR commits final):

- `verification_command_spec_id` — primary key.
- `workspace_context_id` — typed FK.
- `command_shape` — typed `OperationShape` payload (per inv. 2; no
  shell-string). **Producer-asserted, kernel-verifiable** (closes
  security B-4): kernel verifier runs argv + env scrubber pass at
  mint time; `command_shape` cannot reference env vars whose names
  match secret-shape patterns (`*_KEY`, `*_TOKEN`, `*_SECRET`,
  `*_PASSWORD`, `*_CREDENTIAL`) without explicit `env_capture_mode:
  "name_only" | "existence_only"`. Closes runpod-incident
  regression class (memory: 2026-04-23).
- `expected_exit_codes` — `{success_codes: array<int>,
  allowed_failure_codes: array<int>}`.
- `output_evidence_kind: "verification_receipt" | "diagnostic_report"`
  — discriminator per registry Sub-rule 6.
- `verification_command_spec_state: "active" | "deprecated" |
  "retired"` — bare-noun central-concept discriminator per
  Sub-rule 8 (mirrors ADR 0031 v1 `lease_state` precedent).
- **`author_session_id`** — kernel-set at mint, not producer-
  asserted (closes security B-4). An agent cannot self-attribute a
  `VerificationCommandSpec` to a verifier identity.
- **`author_agent_client_id`** — kernel-set at mint, not producer-
  asserted (closes security B-4).

NEW operation_class on `OperationShape`: **`workspace_verify`** with
`mutation_scope: "verify_workspace"`. CommandShape payloads carry
typed argv arrays (no shell-string per inv. 2).

**Matrix row commitment** (closes policy non-blocking #3): the
`workspace_verify` operation_class row in the ADR 0034 v2 boundary-
evidence stateness matrix is committed in posture form here:

| operation_class | stale | missing | contradictory |
|---|---|---|---|
| `workspace_verify` | warn | approval_required | block |

Rationale: a verify operation that fires against stale evidence
should still warn rather than block (the verify is itself the
freshness check); against missing evidence, the verify cannot
proceed without operator approval; contradictory evidence at
verify time is a hard block. Canonical policy YAML at Milestone 2
commits per-evidence-class freshness windows.

#### Docs taxonomy → `KnowledgeSource.source_kind` extensions

Two new `source_kind` values: `"audit_profile_yaml"` (closes
ontology B-8 — renamed from v1's `"audit_profile"` to disambiguate
from existing `"audit_summary"` and to avoid value-collision with
the new `subject_kind: "audit_profile_snapshot"`),
`"cycle_history"` (for `cycle-history.md` and
`cycle-history-notes.md`). The existing five values from ADR 0019
v3 (`charter`, `adr`, `decision_ledger`, `runbook`, `vendor_doc`)
cover the rest. `KnowledgeSource.content_hash` re-indexing rule +
label-recheck rule from ADR 0019 v3 §Secret-referenced sources
apply uniformly.

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
  **Per-target-kind validation** (closes security NB-4): Layer 1
  mint API rejects mismatched (kind, ref) pairs with NEW
  `Decision.reason_kind: deletion_authority_kind_ref_mismatch`
  (committed in §Decision.reason_kind reservations below).
- `deletion_authority_kind` — closed-enum discriminator with reserved
  values:
  - **`"filesystem_protected_paths_observation"`** (renamed from
    v1's `"protected_paths_registry"` per ontology B-6 — the FK
    actually resolves to a `BoundaryObservation`, so the kind
    value names the resolved-entity category, not the inner
    payload semantic) — references a `BoundaryObservation` of
    `boundary_dimension: filesystem_protected_paths`.
  - **`"coordination_fact"`** — references a promoted
    `CoordinationFact` of `subject_kind: workspace_context` with
    relevant `predicate_kind` (e.g., `claimed_to_contain` /
    `confirmed_to_contain`). **Layer 1 host-observation grounding
    requirement** (closes security B-5): a `CoordinationFact`
    cited via `deletion_authority_kind: "coordination_fact"` MUST
    have at least one `Evidence` record in its `evidence_refs`
    array with `authority: "host-observation"` (or
    `"provider-asserted-kernel-verifiable"` per inv. 16). Audit-
    framework `derived` Evidence alone is insufficient for
    cleanup authority. Layer 1 mint API rejects with NEW
    `Decision.reason_kind: coordination_fact_insufficient_grounding`
    (committed in §Decision.reason_kind reservations below).
  - **`"human_dashboard_grant"`** — references an `ApprovalGrant`
    minted via dashboard-only break-glass (per ADR 0035 v2 +
    canonical policy at Milestone 2).
  - **`"runtime_state_classification"`** — references a typed
    classification of runtime state (e.g., per-charter inv. 10
    deployment-boundary observations under
    `~/Library/Application Support/host-capability-substrate/`).

Cleanup operations citing `deletion_authority_kind: "gitignore"` or
similar non-typed authority reject at Layer 1 mint API per D-025 +
inv. 13. Unrecognized `deletion_authority_kind` values default per
ADR 0029 v2 §Closed-list fail-mode tightening rule (canonical
restatement covering all v2-introduced enum surfaces is in
§Decision.reason_kind reservations §Closed-list fail-mode
tightening rule below).

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
  mcp_canonical_authority` rejects duplicate-target mints; Layer 2
  broker re-check catches stale entries; **Decision body for
  duplicate detection cites observations by ref, never by resolved
  credential-source content** (closes security NB-6 — fixture
  asserts secret-shape scrubber passes on the
  `mcp_canonical_authority_duplicate` Decision body).
- **Rejection class on failure**: NEW `Decision.reason_kind:
  mcp_canonical_authority_duplicate` (committed in §`Decision.
  reason_kind` reservations below).
- **Stage-blocked on**: `boundary_dimension: mcp_canonical_authority`
  schema commitment + ADR 0036 acceptance.

#### Trap #28 — `docs-planning-index-projection-drift`

- **What it tests**: When a `KnowledgeSource` of `source_kind:
  "audit_profile_yaml"` or `"cycle_history"` has its `content_hash`
  change, ADR 0019 v3 §Re-indexing label-recheck triggers chunk
  invalidation; Layer 3 gateway re-derive serves fresh projection.
  Additional fixture (closes architect F1): assert correct
  `security_label` upgrade path on first appearance of `op://`
  references (`"internal"` → `"secret_pointer"`) and on first
  appearance of resolved-secret patterns (`"secret_pointer"` →
  `"secret_referenced"` with chunk-purge).
- **Rejection class on failure**: existing
  `knowledge_source_content_drift` reason_kind from ADR 0019 v3.
- **Stage-blocked on**: `KnowledgeSource.content_hash` re-index hook
  from ADR 0019 v3 schema PR + `security_label: "secret_pointer"`
  schema commitment.

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
  0019 v3 §Verifier visibility-authority rule) **AND Layer 1
  host-observation grounding** (closes security B-8; see §Layer 1
  grounding requirement below). The audit framework's "smoke-test
  before shipping" (Phase 10.5 of the audit spec) maps to verifier-
  class privilege at promotion time, but not unconditionally — host-
  observation grounding remains required.
- **No new reconciliation operation.** `system.claims.reconcile.v1`
  is subsumed: any consumer wanting a reconciliation queries
  Layer 3 retrieval directly.

This avoids re-litigating Q-003's promotion workflow for workspace
claims specifically and avoids minting a parallel reconciliation
entity that would compete with `DerivedSummary`.

### Two structural commitments

#### Subject-kind reservations: `workspace_context`, `audit_profile_snapshot`

(Closes ontology B-1 + B-2 — renamed from v1's `"workspace"` and
`"audit_profile"` to disambiguate from FK-suffix vocabulary
(`workspace_id`, `workspace_context_id`) and existing `worktree`
subject_kind, and to avoid cross-enum value collision with the new
`KnowledgeSource.source_kind: "audit_profile_yaml"`.)

Per ADR 0019 v3 §Predicate-kind registry reservation, the
follow-up registry update PR reserves NEW `subject_kind` values for
`CoordinationFact`:

- **`subject_kind: "workspace_context"`** — `subject_ref` resolves
  to a `(workspace_context_id)` reference. Single-repo per ADR
  0031 v1 cardinality; multi-repo workspace coordination uses
  `subject_kind: "worktree"` per ADR 0019 v3 + ADR 0031 v1
  composition. Narrower-rule preference: when an assertion is
  worktree-specific, prefer existing `subject_kind: "worktree"`;
  use `"workspace_context"` only for assertions that are
  worktree-superset (e.g., spanning the entire workspace's
  exclusion taxonomy).
- **`subject_kind: "audit_profile_snapshot"`** — `subject_ref`
  resolves to `(workspace_context_id, audit_profile_revision_date)`
  pair binding a specific profile snapshot.

#### Predicate-kind reservations: `claimed_to_contain`, `confirmed_to_contain`, `claim_superseded_by_snapshot`

Three NEW `predicate_kind` values for the audit framework's
claim/confirmation/halt vocabulary:

- **`predicate_kind: "claimed_to_contain"`** — the audit profile
  claims the workspace contains a specific bounded context. Default
  `allowed_for_gate: false` until promoted via Q-003 verifier
  workflow + Layer 1 grounding.
- **`predicate_kind: "confirmed_to_contain"`** — the audit
  framework's smoke-test (Phase 10.5) confirmed the claim through
  Layer 1 evidence. Composes with the verifier visibility-authority
  rule.
- **`predicate_kind: "claim_superseded_by_snapshot"`** (renamed
  from v1's `"superseded_by"` per ontology B-3 — the v1 spelling
  was ambiguous between CoordinationFact lifecycle supersession
  and KnowledgeSource content-hash supersession; the explicit
  spelling commits this predicate to CoordinationFact-claim-level
  supersession only). A prior audit profile's claim is superseded
  by a fresher snapshot. Maps to ADR 0019 v3 §Re-indexing label-
  recheck pattern at the CoordinationFact layer; **does not** apply
  to KnowledgeSource.content_hash drift (which has its own
  mechanism).

#### Layer 1 grounding requirement for promotion (NEW, closes security B-8)

A `CoordinationFact` of `subject_kind: "workspace_context"` or
`"audit_profile_snapshot"` cannot be promoted to
`allowed_for_gate: true` unless its `evidence_refs` array contains
at least one `Evidence` record with `authority: "host-observation"`
(or `"provider-asserted-kernel-verifiable"` for external-control-
plane facts per inv. 16). Audit-framework `derived` Evidence alone
is insufficient for promotion. Layer 1 mint API enforces this
during the promotion-grant minting; on missing host-observation
grounding, mint rejects with NEW `Decision.reason_kind:
coordination_promotion_no_layer1_grounding`.

This rule closes the inv. 8 escalation hole the security reviewer
named: the audit framework's "smoke-test before shipping" Phase
10.5 results, mapped to `confirmed_to_contain` CoordinationFacts,
must additionally cite host-grounded Evidence (e.g.,
`GitRepositoryObservation` proving the workspace is the one named
in the audit profile) before promotion succeeds.

#### `cycle-history.md` ↔ CoordinationFact lifecycle binding

The audit framework's `cycle-history.md` (operator-ratified) +
`cycle-history-notes.md` (audit-proposed) workflow is **structurally
identical to Q-003's "agent proposes / verifier promotes" pattern**.
ADR 0036 commits the binding:

- **Audit framework proposes** via `cycle-history-notes.md` →
  produces unpromoted `CoordinationFact` records of
  `subject_kind: "audit_profile_snapshot"` with
  `predicate_kind: "claimed_to_contain"` (or similar) and
  `allowed_for_gate: false`.
- **Operator ratification** via `cycle-history.md` → serves as
  `verification_evidence_refs` for a Q-003 promotion-grant
  minted by the verifier session (closes architect N1 wording).
  Operator ratification is evidence, not the trigger; the verifier
  session is the trigger.
- **Promotion succeeds only when both (i) verifier visibility-
  authority rule AND (ii) Layer 1 host-observation grounding rule
  are satisfied** (per §Layer 1 grounding requirement above).
- **Human-identity binding for cycle-history.md ratification**
  (closes security NB-7): when the verifier is a human operator
  ratifying via cycle-history.md, the verifier-identity field
  binds to an existing `principal_id` resolved from the signed
  git commit's author identity (or a configured commit-signature-
  to-principal mapping per future Q-row). Synthetic identities
  rejected at Layer 1 mint.
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

- **Kernel-set**: workspace-diagnose service mints via NEW
  `Evidence.producer: "kernel_workspace_diagnose"` (kernel-trusted
  producer class extended; registry follow-up dependency);
  `manifest_valid_until` derived from `min(Evidence.valid_until)`
  across linked records (`null` on empty set per Sub-decision (b));
  `VerificationCommandSpec.author_session_id` and
  `author_agent_client_id` kernel-set at mint (closes security
  B-4).
- **Producer-asserted, kernel-verifiable**: `verify_operations`
  array on `WorkspaceContext` (refs to `VerificationCommandSpec`
  records); `search_exclusions` / `lint_exclusions` /
  `docs_exclusions` arrays; `docs_taxonomy_evidence_refs` array;
  `VerificationCommandSpec.command_shape` (kernel verifier runs
  argv + env scrubber pass at mint).
- **Audit-profile content-hash re-classification (canonical
  three-state progression)**: when `KnowledgeSource.security_label`
  upgrades on re-indexed content per the §Re-indexing label-recheck
  rule:
  - `"internal"` → `"secret_pointer"` on first appearance of
    pointer literals (`op://...`, etc.); chunks remain
    embedding-eligible; the chunker validates pointer-shape only.
  - `"secret_pointer"` → `"secret_referenced"` on first appearance
    of resolved-secret shapes; chunk-invalidation purge per ADR
    0019 v3 fires.
  Pure `"internal"` → `"secret_referenced"` direct upgrade is also
  valid when the only change is a resolved-secret appearance with
  no prior pointer literals. **Most-restrictive label wins**: when
  a single re-index introduces both pointer literals AND
  resolved-secret shapes simultaneously, the resulting label is
  `"secret_referenced"` (the strictest applicable), not
  `"secret_pointer"`. The label-recheck path composes with the
  universal scrubber rule (see Sub-decision (b)) so that
  resolved-secret shapes never persist regardless of label.

#### Cross-context binding rules per Ring 1 layer

Per registry v0.3.0:

- **`boundary_dimension: filesystem_inheritance` /
  `filesystem_protected_paths`**: Layer 1 enforces flat-payload
  validity per the per-dimension shape; Layer 2/3 re-checks
  per-dimension freshness rules.
- **`boundary_dimension: mcp_canonical_authority`**: Layer 1
  enforces `(execution_context_id, mcp_server_kind)` uniqueness
  (Ring 1 atomic-insert pattern, NOT ApprovalGrant scope-
  uniqueness — closes policy non-blocking #6); Layer 2/3 re-checks
  shim-chain freshness via `ToolProvenance` re-derivation.
- **`VerificationCommandSpec`**: Layer 1 enforces
  `(workspace_context_id, command_shape)` consistency; Layer 2 re-
  evaluates verification at operation-execution time per
  registry v0.3.0 §Cross-context enforcement layer.
- **`KnowledgeSource` of `source_kind: "audit_profile_yaml" |
  "cycle_history"`**: standard ADR 0019 v3 cross-context binding
  rules apply; cross-workspace audit-profile reuse rejected at
  Layer 1.

#### Sandbox-promotion rejection (charter inv. 8)

Inherited from ADR 0019 v3 / ADR 0034 v2 / ADR 0035 v2:

- `boundary_dimension: filesystem_inheritance` /
  `filesystem_protected_paths` / `mcp_canonical_authority`
  observations with `Evidence.authority` in `{sandbox-observation,
  self-asserted}` cannot be promoted to host-authoritative gate
  evidence.
- `VerificationCommandSpec` records cited in operations cannot
  launder sandbox-derived authority.
- `system.workspace.diagnose.v1` `DerivedSummary` outputs cannot
  promote across the sandbox/host boundary; per ADR 0019 v3 chain-
  promotion rule, `KnowledgeChunk` references in `derived_from`
  block promotion regardless of authority class; additionally per
  §Layer 1 grounding requirement above, host-observation grounding
  is required for `subject_kind: workspace_context |
  audit_profile_snapshot` CoordinationFact promotion.

### `Decision.reason_kind` reservations

Six new rejection-class names reserved (posture-only; schema enum
lands per `.agents/skills/hcs-schema-change`). All renames per
ontology B-7 use `<subject>_<state>` form (state-noun, not verb-
past or event-trigger), matching existing reason_kind precedent
(`boundary_evidence_stale`, `worktree_inventory_partial`, etc.):

- **`mcp_canonical_authority_duplicate`** (renamed from v1's
  `duplicate_mcp_config_detected`) — Layer 1 mint API rejects
  duplicate-target `BoundaryObservation` of `boundary_dimension:
  mcp_canonical_authority` for the same `(execution_context_id,
  mcp_server_kind)` triple where an existing observation is in
  `proven` state. Decision-level per ADR 0029 v2 framing; not
  forbidden-tier. **Decision body** carries `evidenceRefSchema`
  references to both conflicting observations only — no resolved
  credential-source content (closes security B-6).
- **`verification_command_spec_unmet`** (renamed from v1's
  `workspace_verify_command_failed`) — Layer 2 broker FSM re-runs
  a `VerificationCommandSpec` at operation-execution time and the
  command's exit code is not in `expected_exit_codes.success_codes`.
  Operations gating on workspace verification reject with this
  reason_kind. **Decision body shape** (closes security B-7):
  - `verification_command_spec_id` — FK reference (not command
    shape).
  - `observed_exit_code` — integer.
  - `failure_class` — typed discriminator: `"non_zero_exit" |
    "command_not_found" | "credential_missing" | "timeout"`.
  - **NO inline stderr/stdout content** in the Decision body.
    stderr, if captured, is stored in a separate `Evidence` record
    with `redaction_mode: "classified"` or `"hash_only"` per
    registry v0.3.3 §Redaction posture.
  - `failure_class: "credential_missing"` records only the
    credential-source `evidenceRefSchema` reference (existence-
    only), never the credential variable name in resolved form
    (closes runpod-incident regression class).
- **`derived_summary_secret_shape_in_text`** (NEW, closes security
  B-3) — Layer 1 mint API rejects a `DerivedSummary` whose
  `summary_text` field matches a secret-shape pattern per the
  registry §Field-level scrubber. Applies to all `summary_text`
  mints regardless of `derived_from` graph source labels.
- **`coordination_fact_insufficient_grounding`** (NEW, closes
  security B-5) — Layer 1 mint API rejects a cleanup operation
  citing `deletion_authority_kind: "coordination_fact"` whose
  referenced `CoordinationFact.evidence_refs` array contains no
  `Evidence` record of `authority: "host-observation"` or
  `"provider-asserted-kernel-verifiable"`.
- **`coordination_promotion_no_layer1_grounding`** (NEW, closes
  security B-8) — Layer 1 mint API rejects a promotion-grant for
  a `CoordinationFact` of `subject_kind: "workspace_context"` or
  `"audit_profile_snapshot"` whose `evidence_refs` array contains
  no `Evidence` record of `authority: "host-observation"` or
  `"provider-asserted-kernel-verifiable"`.
- **`deletion_authority_kind_ref_mismatch`** (NEW, closes security
  NB-4) — Layer 1 mint API rejects a cleanup operation whose
  `deletion_authority_source_ref` polymorphic FK does not resolve
  to an entity matching its `deletion_authority_kind` discriminator.

The existing reason_kinds cover the other failure modes:

- `worktree_inventory_partial` (ADR 0030 v2) — Trap #26 rejection.
- `knowledge_source_content_drift` (ADR 0019 v3) — Trap #28
  rejection.
- `derived_summary_unpromoted_dependency` (ADR 0019 v3) — Chain-
  promotion rule rejection for workspace-diagnose summaries citing
  `KnowledgeChunk` refs.
- `secret_resolution_in_chunk` (ADR 0019 v3) — Universal scrubber
  rejection on chunk mint.

**Closed-list fail-mode tightening rule** (closes policy non-
blocking #1): all new closed enums in this ADR (six new
`Decision.reason_kind` values; four `deletion_authority_kind`
values; new `boundary_dimension` values; new `source_kind` values;
new `subject_kind` and `predicate_kind` values; new
`security_label: "secret_pointer"` value; new `operation_class:
"workspace_verify"`; new `mutation_scope: "verify_workspace"`)
inherit the ADR 0029 v2 §Closed-list fail-mode tightening rule:
unrecognized values default to `block` for destructive operations
or `warn` for read-only operations.

### Out of scope

This ADR does not authorize:

- Zod schema source for `VerificationCommandSpec`,
  `boundary_dimension: filesystem_inheritance` /
  `filesystem_protected_paths` / `mcp_canonical_authority` payload
  schemas, or `OperationShape` field additions
  (`deletion_authority_source_ref`, `deletion_authority_kind`,
  `operation_class: "workspace_verify"`,
  `mutation_scope: "verify_workspace"`). Schema lands per
  `.agents/skills/hcs-schema-change`.
- `evidenceSubjectKindSchema` enum extension for
  `verification_command_spec` (NEW subject-kind value). Schema PR
  commits.
- Registry update PR for:
  - Producer-class allowlist extension: new
    `Evidence.producer: "kernel_workspace_diagnose"` value (closes
    architect B3).
  - `KnowledgeSource.source_kind` extensions: 2 new values
    (`audit_profile_yaml`, `cycle_history`).
  - `KnowledgeSource.security_label` extension: 1 new value
    (`secret_pointer`).
  - `CoordinationFact.subject_kind` extensions: 2 new values
    (`workspace_context`, `audit_profile_snapshot`).
  - `predicate_kind` reservations: 3 new values
    (`claimed_to_contain`, `confirmed_to_contain`,
    `claim_superseded_by_snapshot`).
  - `boundary_dimension` reservations: 3 new values
    (`filesystem_inheritance`, `filesystem_protected_paths`,
    `mcp_canonical_authority`); 1 stage-2-reserved value
    (`filesystem_path_authority_check`).
  - `path_authority_kind` enum: 4 new values (`rule_binding`,
    `lease_scope`, `tcc_scoped`, `human_dashboard_grant`) on the
    `filesystem_protected_paths` payload (closes ontology N-5).
  - `operation_class` extension: 1 new value (`workspace_verify`).
  - `mutation_scope` extension: 1 new value (`verify_workspace`)
    (closes policy non-blocking #4).
  - `deletion_authority_kind` enum: 4 new values
    (`filesystem_protected_paths_observation`, `coordination_fact`,
    `human_dashboard_grant`, `runtime_state_classification`).
  - `Decision.reason_kind` reservations: 6 new values
    (`mcp_canonical_authority_duplicate`,
    `verification_command_spec_unmet`,
    `derived_summary_secret_shape_in_text`,
    `coordination_fact_insufficient_grounding`,
    `coordination_promotion_no_layer1_grounding`,
    `deletion_authority_kind_ref_mismatch`).
  - Discriminated-union pattern shape (`pattern_kind: "glob" |
    "regex"`) on `WorkspaceContext` exclusion arrays.
- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. Per-
  `boundary_dimension` freshness windows; per-operation_class
  composition rules; verifier-class privileges for audit-framework
  promotion grants; canonical exclusion-pattern conflict resolution
  (closes security NB-2).
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
- `boundary_dimension: filesystem_path_authority_check` payload
  commitment (stage-2 Q-* row).
- Future Q-row for commit-signature-to-principal mapping (closes
  security NB-7 — the cycle-history.md ratification verifier-
  identity binding mechanism is committed by this ADR; the
  resolution rule for synthesizing `principal_id` from a signed
  git commit's author identity, including configured signature-to-
  principal mappings, defers to that future Q-row).
- Future ADR for `system.cleanup.plan.v1` composition with this
  ADR's `system.workspace.diagnose.v1` outputs (architect F4 —
  whether cleanup-plan consumes the workspace-diagnose summary as
  authoritative input, and what re-derivation is required).

## Consequences

### Accepts

- Q-009 settled at the design layer with a three-layer projection
  model, one new Ring 1 operation (`system.workspace.diagnose.v1`,
  `operation_class: read_only_diagnostic`), one new producer-
  asserted spec entity (`VerificationCommandSpec`), three new
  `boundary_dimension` values for filesystem authority
  (`filesystem_inheritance`, `filesystem_protected_paths`;
  `filesystem_path_authority_check` reserved-only for stage-2),
  one new `boundary_dimension` for MCP config
  (`mcp_canonical_authority`), one new kernel-trusted producer
  class (`kernel_workspace_diagnose`), one new `security_label`
  value (`secret_pointer`), two new `KnowledgeSource.source_kind`
  values, two new `CoordinationFact.subject_kind` values, three
  new `predicate_kind` values, four new `deletion_authority_kind`
  enum values, four new `path_authority_kind` enum values, six new
  `Decision.reason_kind` reservations, one new `operation_class`
  (`workspace_verify`), one new `mutation_scope`
  (`verify_workspace`), and three regression traps staged behind
  evidence dependencies.
- The workspace manifest is a Layer 3 retrieval projection (NOT a
  Ring 0 entity, NOT a file). Three explicit input layers compose
  via existing entities + minimal additions.
- The audit framework's `project_profile.yaml` is registered as a
  typed Layer 2 input (`KnowledgeSource` of `source_kind:
  "audit_profile_yaml"`) rather than a parallel HCS-specific
  manifest artifact. Profile-diff drift detection inherits ADR
  0019 v3 §Re-indexing label-recheck rule with a tighter
  three-state label progression
  (`internal` → `secret_pointer` → `secret_referenced`) for
  pointer-bearing content.
- `system.workspace.diagnose.v1` outputs a `DerivedSummary` whose
  `derived_from` cites Layer 1 + Layer 2 evidence. Both
  `allowed_for_gate: false` default AND ADR 0019 v3 chain-promotion
  rule structurally block gate-promotion when `KnowledgeChunk` refs
  are present (display-only by structure; no new gateability
  mechanism needed). Service mints via NEW
  `kernel_workspace_diagnose` kernel-trusted producer class
  (registry follow-up dependency).
- Universal `KnowledgeChunk` content scrubber rule applies at
  Layer 1 mint regardless of `security_label`; resolved-secret
  shapes never persist in the evidence cache.
- `DerivedSummary.summary_text` mint-time scrubber rule applies to
  all `DerivedSummary` records regardless of `derived_from` graph
  source labels.
- Claim reconciliation is settled by ADR 0019 v3 (`DerivedSummary`
  + Q-003 promotion workflow); NO new `ClaimReconciliationReceipt`
  entity. Promotion of `subject_kind: workspace_context |
  audit_profile_snapshot` CoordinationFacts requires Layer 1
  host-observation grounding in addition to verifier visibility-
  authority rule.
- `cycle-history.md` ↔ CoordinationFact lifecycle binding
  committed: audit-framework's audit-proposes/operator-promotes
  workflow maps directly to Q-003's verifier promotion pattern,
  with operator ratification serving as `verification_evidence_refs`
  for verifier-session-minted promotion grants. Human-identity
  binding via existing `principal_id` from signed git commit
  author identity (resolution rule deferred to future Q-row).
- D-025 deletion-authority-source field-shape committed on
  `OperationShape` as polymorphic `deletion_authority_source_ref`
  + `deletion_authority_kind` closed-enum discriminator, with
  per-target-kind validation enforced via
  `deletion_authority_kind_ref_mismatch` reason_kind. NO new
  no-suffix `CleanupAuthoritySource` entity.
- Cleanup operations citing `deletion_authority_kind:
  "coordination_fact"` require the referenced `CoordinationFact`
  to have at least one `Evidence` record of
  `authority: "host-observation"` or
  `"provider-asserted-kernel-verifiable"` in its `evidence_refs`
  array (closes inv. 8 escalation hole through cleanup path).
- `VerificationCommandSpec` (producer-asserted spec entity) holds
  the spec/shape of verify commands; per-execution verification
  results are separate `Evidence` records (not introduced in this
  ADR). `command_shape` carries typed `OperationShape` per inv.
  2; argv + env scrubber pass at Layer 1 mint rejects secret-
  shape env-var references without explicit `env_capture_mode`;
  author-identity fields kernel-set at mint.
- `mcp_canonical_authority` BoundaryObservation payloads carry
  `redaction_mode: "reference_only"`; duplicate-detection Decision
  bodies cite by `evidenceRefSchema` only; closes credential-
  exposure surface.
- `verification_command_spec_unmet` Decision body carries typed
  `failure_class` discriminator; no inline stderr/stdout;
  credential-missing failures record by ref only (closes
  runpod-incident regression class).
- `workspace_verify` operation_class committed in posture form on
  the ADR 0034 v2 boundary-evidence stateness matrix
  (warn/approval_required/block for stale/missing/contradictory).

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
- New `kernel_workspace_service` producer class (avoided in v1;
  v2 introduces `kernel_workspace_diagnose` instead — narrower
  scope, registry follow-up accepted).
- The v1 attempt to assert `Evidence.producer: "mint_api"` as if
  `mint_api` were a producer-class enum value (it is a Ring 1
  layer name per ADR 0019 v3 §Promotion workflow; not a producer
  class).
- The v1 attempt to collapse three structurally distinct
  filesystem-authority claim shapes onto a single
  `boundary_dimension: filesystem_authority` value via a
  `claim_kind` sibling-payload discriminator (violated registry
  Sub-rule 1; v2 splits into three separate
  `boundary_dimension` values).
- New no-suffix `CleanupAuthoritySource` entity (entity-name root
  ambiguity with `KnowledgeSource` / `CredentialSource`; replaced
  by typed field-shape on `OperationShape`).
- `boundary_dimension: mcp_canonical_source` naming (v1 spelling
  collided with `_source` entity-name-root convention per ontology-
  registry v0.3.3 §Naming suffix discipline; renamed to
  `mcp_canonical_authority` in v2).
- `subject_kind: "workspace"` and `subject_kind: "audit_profile"`
  v1 spellings (collided with FK-suffix vocabulary, existing
  `worktree` subject_kind, and cross-enum value with
  `KnowledgeSource.source_kind`; renamed to `workspace_context`
  and `audit_profile_snapshot` in v2).
- `predicate_kind: "superseded_by"` v1 spelling (ambiguous between
  CoordinationFact lifecycle and KnowledgeSource re-index; renamed
  to `claim_superseded_by_snapshot` in v2 with explicit binding
  to CoordinationFact-claim-level supersession only).
- `Decision.reason_kind: "duplicate_mcp_config_detected"` and
  `"workspace_verify_command_failed"` v1 spellings (verb-past /
  event-trigger suffixes violated existing `<subject>_<state>`
  pattern; renamed to `mcp_canonical_authority_duplicate` and
  `verification_command_spec_unmet` in v2).
- Free-form CLI strings as canonical verify commands (per inv. 2;
  `VerificationCommandSpec.command_shape` carries typed
  `OperationShape`).
- `VerificationCommand` no-suffix bare-noun naming for what is
  structurally a producer-asserted spec entity (renamed to
  `VerificationCommandSpec` in v2 to honor registry suffix
  discipline; `Spec` correctly classifies as producer-asserted).
- Cleanup operations citing `gitignore` as deletion authority
  (per D-025 + inv. 13).
- Cleanup operations citing `deletion_authority_kind:
  "coordination_fact"` whose referenced fact has no host-
  observation grounding in `evidence_refs` (closes inv. 8
  laundering through cleanup path).
- Promotion of `subject_kind: workspace_context |
  audit_profile_snapshot` CoordinationFacts on derived-only
  evidence chains (closes inv. 8 laundering through audit-
  framework workflow).
- Synthetic verifier identities for cycle-history.md ratification
  (verifier identity must resolve to existing `principal_id` per
  signed git commit author).
- Re-litigating Q-003's promotion workflow for workspace claims
  specifically (already accepted in ADR 0019 v3).

### Future amendments

- Schema PR per `.agents/skills/hcs-schema-change` for:
  `VerificationCommandSpec` producer-asserted spec entity; three
  separate `boundary_dimension` payloads
  (`filesystem_inheritance`, `filesystem_protected_paths`;
  `filesystem_path_authority_check` reserved-only stage-2);
  `boundary_dimension: mcp_canonical_authority` payload with
  `redaction_mode: reference_only` discipline;
  `OperationShape.deletion_authority_source_ref` polymorphic FK +
  `deletion_authority_kind` closed enum + per-target-kind
  validation; new `operation_class: "workspace_verify"` and
  `mutation_scope: "verify_workspace"` reservations;
  `KnowledgeSource.security_label: "secret_pointer"` value with
  pointer-shape validator; six new `Decision.reason_kind`
  reservations; argv + env scrubber pass on
  `VerificationCommandSpec.command_shape`.
- Registry update PR for:
  - Producer-class allowlist extension
    (`kernel_workspace_diagnose`).
  - `KnowledgeSource.source_kind` extensions (2 values).
  - `KnowledgeSource.security_label` extension (1 value:
    `secret_pointer`).
  - `CoordinationFact.subject_kind` extensions (2 values).
  - `predicate_kind` reservations (3 values).
  - `boundary_dimension` reservations (3 committed + 1 reserved).
  - `path_authority_kind` enum (4 values on
    `filesystem_protected_paths` payload).
  - `operation_class` extension (`workspace_verify`).
  - `mutation_scope` extension (`verify_workspace`).
  - `deletion_authority_kind` enum (4 values).
  - `Decision.reason_kind` reservations (6 values).
  - Discriminated-union pattern shape on exclusion arrays
    (`pattern_kind: "glob" | "regex"`).
  - `WorkspaceContext` field additions (`manifest_valid_until`,
    `verify_operations`, `search_exclusions` /
    `lint_exclusions` / `docs_exclusions`,
    `docs_taxonomy_evidence_refs`).
- Trap fixtures land when their evidence dependencies clear
  (Trap #26: `GitWorktreeInventoryObservation` schema PR; Trap
  #27: `boundary_dimension: mcp_canonical_authority` schema +
  scrubber-on-Decision-body fixture; Trap #28:
  `KnowledgeSource.content_hash` re-index hook +
  `security_label: "secret_pointer"` schema commitment).
- Stage-2 Q-* row commits `boundary_dimension:
  filesystem_path_authority_check` payload shape if and when
  per-operation per-path lookups become a Ring 1 service. The
  composition with the runtime broker FSM (Layer 2) — particularly
  whether the Layer 2 re-check uses cached
  `filesystem_protected_paths` observations or re-derives at every
  operation — is part of that stage-2 commitment (closes architect
  F2).
- Four deferred diagnostic operations land as evidence dependencies
  clear (`system.runtime.diagnose.v1`, `system.git.diagnose.v1`,
  `system.docs.diagnose.v1`, `system.cleanup.plan.v1`).
- Charter v1.4.0 amendment PR for inv. 19 text (per ADR 0034 v2
  candidate).
- Q-010 sub-decisions (separate Q-row).
- Future Q-row for commit-signature-to-principal mapping
  (cycle-history.md verifier-identity resolution).
- **Layer 1 grounding rule extensibility principle.** The Layer 1
  host-observation grounding requirement committed in this ADR
  names two specific `subject_kind` values: `"workspace_context"`
  and `"audit_profile_snapshot"`. The architectural principle
  behind the rule is broader: `subject_kind` values primarily
  backed by derived or Layer-2 content (audit-framework outputs,
  retrieval-projection outputs, summarization outputs) require
  Layer 1 host-observation grounding to promote — they cannot be
  promoted on derived-only `evidence_refs` chains regardless of
  verifier visibility-authority. Future ADRs introducing new
  `subject_kind` values backed by derived/Layer-2 content MUST
  add the new value to the Layer 1 grounding requirement at
  introduction time. Subject-kinds primarily backed by direct
  host-observation Evidence (e.g., existing `release | branch |
  worktree | ruleset | credential_audience | deployment |
  external_target` from ADR 0019 v3) inherit ADR 0019 v3's chain-
  promotion rule and do not require this additional rule.
- Future ADR for `system.cleanup.plan.v1` composition with this
  ADR's `system.workspace.diagnose.v1` outputs (architect F4).
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
  referenced sources rules, Redaction posture, Audit-chain coverage
  of rejections).
- Decision ledger: `DECISIONS.md` Q-009 (this row); D-025
  (deletion authority is not gitignore); D-028 (host_secret_*
  compatibility contract).
- ADR 0018:
  `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
  (CredentialSource consumed by `mcp_canonical_authority` payload).
- ADR 0019:
  `docs/host-capability-substrate/adr/0019-knowledge-and-coordination-store.md`
  (Q-003 v3 final; CoordinationFact composition pattern;
  KnowledgeSource / KnowledgeChunk / DerivedSummary; chain-promotion
  rule; verifier visibility-authority rule; promotion workflow;
  naming-discipline-never-memory; Predicate-kind registry
  reservation; Re-indexing label-recheck rule; Secret-referenced
  sources chunk-invalidation rule).
- ADR 0022:
  `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
  (BoundaryObservation envelope; `filesystem_authority` candidate
  boundary_dimension precursor split here; QualityGate deferral
  origin; Linked observations pattern).
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (Evidence base contract).
- ADR 0027:
  `docs/host-capability-substrate/adr/0027-q-006-stage-1-source-control-evidence-subtypes.md`
  (Q-006 stage-1 receipts; first-commit-SHA repository_id
  resolution).
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (Producer-vs-kernel-set authority fields; kernel-trusted
  producer allowlist extended here with
  `kernel_workspace_diagnose`).
- ADR 0029:
  `docs/host-capability-substrate/adr/0029-q-008-b-c-broker-fsm-and-cross-tool-authority.md`
  (operation_class enumeration; closed-list fail-mode tightening
  rule; three-state matrix pattern).
- ADR 0030:
  `docs/host-capability-substrate/adr/0030-q-006-stage-2-source-control-evidence-subtypes.md`
  (Q-006 stage-2 receipts; `worktree_inventory_partial`
  reason_kind for Trap #26).
- ADR 0031:
  `docs/host-capability-substrate/adr/0031-q-008-d-worktree-ownership-composition.md`
  (Q-008(d) v1 final; WorkspaceContext one-to-one with worktree
  cardinality; Lease lifecycle; lease_state bare-noun central-
  concept discriminator pattern reference for
  `verification_command_spec_state`; atomic-insert TOCTOU rule
  reference for `mcp_canonical_authority` uniqueness).
- ADR 0034:
  `docs/host-capability-substrate/adr/0034-q-007-b-f-boundary-evidence-composition-quality-gate-posture.md`
  (Q-007 (b)-(f) v2 final; ToolProvenance / GitIdentityBinding;
  flat-payload composition pattern reference for the three
  filesystem boundary_dimensions and `mcp_canonical_authority`;
  boundary-evidence stateness matrix; ApprovalGrant scope per-
  class extension pattern).
- ADR 0035:
  `docs/host-capability-substrate/adr/0035-q-007-g-quality-gate-standalone-entity.md`
  (Q-007(g) v2 final; gate identity triple pattern reference;
  dashboard-only break-glass `ApprovalGrant` precedent for
  `human_dashboard_grant` deletion authority kind).
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
- 1Password Secret References (`op://Vault/Item/field`) URI
  format — pointer vocabulary referenced by the
  `security_label: "secret_pointer"` classifier:
  <https://developer.1password.com/docs/cli/secret-references/>
- XDG Base Directory Specification (referenced by §Path
  canonicalization rule from ADR 0034 v2 inherited):
  <https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html>
- macOS Application Support / Logs convention (charter inv. 10
  deployment boundary; runtime state under `~/Library/Application
  Support/host-capability-substrate/`):
  <https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFileSystem/Articles/MacOSXDirectories.html>
