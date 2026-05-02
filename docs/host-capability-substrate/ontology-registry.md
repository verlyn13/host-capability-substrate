---
title: HCS Ontology Registry
category: reference
component: host_capability_substrate
status: partial
version: 0.2.1
last_updated: 2026-05-02
tags: [ontology, registry, boundary-observation, evidence, naming-discipline, q-011]
priority: high
---

# HCS Ontology Registry

Authoritative registry for ontology-controlled vocabulary used inside HCS Ring 0
schemas. Initial scope is the `boundary_dimension` taxonomy that ADR 0022 names
as a precondition for `BoundaryObservation` schema implementation.

This file is a living registry. Entries are draft until `hcs-ontology-reviewer`
has filed objections and a human owner has accepted them. Adding, removing, or
renaming a registered value is itself a schema-change-workflow PR.

## Scope

In scope:

- Closed enumerations referenced by Ring 0 schemas where the values carry
  ontology meaning beyond an ad-hoc string (e.g., `boundary_dimension`).
- Naming-discipline rules for receipts, observations, and proof composites that
  Q-011 owns.

Out of scope:

- Live policy tiers, gateway rules, or canonical YAML — those remain in
  `system-config/policies/host-capability-substrate/`.
- Per-domain payload schemas. Domain payloads are owned by domain-specific
  evidence subtypes; the registry only fixes the discriminator vocabulary.
- Adapter-only enums (MCP tool names, dashboard view names). Those live with
  their adapter contracts.

## Registration rules

1. **Singular discriminator.** A boundary fact carries one
   `boundary_dimension`. Genuinely multi-dimensional facts are represented as
   linked `BoundaryObservation` records that share target references, not as
   one envelope with multiple dimensions.
2. **Narrowest matching dimension.** When multiple registered values could
   apply, emit the narrowest one. Umbrella values such as `containment_class`
   apply only when no narrower dimension fits.
3. **Primary target reference is mandatory per dimension.** Each entry below
   names the primary target reference (`surface_id`, `execution_context_id`,
   `workspace_id`, `credential_source_id`, or `tool_or_provider_ref`) that
   binds the observation to the host model. At least one target reference must
   be present on every `BoundaryObservation`; the per-dimension primary is the
   one that should normally be used.
4. **Supplemental target references are listed explicitly.** Adapters and
   producers may attach additional target references when they help downstream
   consumers, but only the ones the registry approves for that dimension.
5. **Version, build, and dependency drift are freshness signals, not
   dimensions.** A version bump, build change, or dependency change invalidates
   prior observations that depended on the changed surface; it does not become
   a `boundary_dimension` value unless the registry later approves a narrower
   entry. `BoundaryObservation` carries no `version_drift` dimension.
6. **One status per registered value.** A registered dimension is `proposed`,
   `accepted`, or `deferred`. Implementation work on `BoundaryObservation`
   payloads consumes only `accepted` dimensions; `proposed` values must clear
   ontology review first.
7. **Schema enum is a mirror of this registry.** The Zod
   `boundaryDimensionSchema` enum and this file must move together. Drift
   between them is a `just verify` failure once the schema lands.

## Q-011 review grammar (review buckets, not registry entries)

Q-011 governs which Ring 0 names land as evidence subtypes, standalone
entities, or proof composites. The same buckets apply when a dimension's
domain payload is later proposed:

- **Evidence subtype.** A freshness-bound observation that wraps the base
  `Evidence` provenance with a domain-specific payload. Most boundary
  dimensions live here.
- **Standalone Ring 0 entity.** A durable lifecycle object with its own
  identity and ownership. `BoundaryObservation` is the envelope that lets
  evidence subtypes share a discriminator without becoming standalone
  entities.
- **Proof composite.** An authored decision artifact (for example
  `BranchDeletionProof`) that aggregates multiple evidence records into a
  single gating shape. Dimensions never sit in this bucket; their associated
  domain payloads might.

## Naming suffix discipline

Per Q-011 sub-decision (d) (approved 2026-05-01,
`docs/host-capability-substrate/human-decision-report-2026-05-01.md`), Ring 0
entity and field names follow a closed suffix discipline. This codifies the
convention already in use across `packages/schemas/src/entities/` and
`docs/host-capability-substrate/adr/`.

### Entity-name suffixes

- **`*Observation`** — a freshness-bound observation. Typically an `Evidence`
  subtype envelope or a domain-specific observation record. Examples:
  `BoundaryObservation`, candidate `GitRepositoryObservation`,
  `GitWorktreeObservation`, `StatusCheckSourceObservation`,
  `GitBranchAncestryObservation`.
- **`*Receipt`** — a typed receipt of a definite event or a positive
  existence claim, including positive-absence claims. Typically an `Evidence`
  subtype envelope. Examples: candidate `CleanRoomSmokeReceipt`,
  `WorkflowRunReceipt`, `PullRequestReceipt`, `PullRequestAbsenceReceipt`,
  `SourceControlContinuityReceipt`.
- **`*Proof`** — an authored decision composite (Q-011 review-grammar bucket
  3) that aggregates multiple evidence records into a single gating shape.
  Examples: candidate `BranchDeletionProof`.
- **no suffix** — a standalone Ring 0 entity (Q-011 review-grammar bucket 2)
  with durable identity and lifecycle. Examples: `HostProfile`,
  `WorkspaceContext`, `Evidence`, `ExecutionContext`, `Capability`,
  `Decision`, `ApprovalGrant`, `Run`, `Artifact`, `Lease`, `Lock`,
  `SecretReference`.

Sub-rules:

1. **Mixing suffix categories on a single entity name is forbidden.** No
   `BranchDeletionProofObservation` and no `BoundaryObservationReceipt`. A
   name carries at most one suffix.
2. **Positive-absence claims are explicit `*Receipt`s.** "No PR exists for
   this branch" is a `PullRequestAbsenceReceipt`, not a missing field. A
   missing field is structurally undefined; absence is itself an observation
   that must be produced, dated, and authority-tagged.
3. **`*Proof` composites do not subtype `Evidence`.** They reference
   `Evidence` records; they are not themselves freshness-bound observations.
   Proof composites carry their own authoring metadata
   (`*_authored_at`, `*_valid_until`, authoring-service identity, requesting
   principal identity).

### Field-name suffixes (single-FK and reference-array conventions)

- **`<entity>_id`** — a single typed FK to a specific Ring 0 entity by its
  primary key. Used when the entity kind is fixed by the field's name.
  Examples in current schemas: `evidence_id`, `workspace_id`,
  `execution_context_id`, `credential_source_id`, `boundary_observation_id`.
- **`<thing>_ref`** — a single typed FK that is polymorphic or kind-tagged.
  Used when the field can resolve to one of several entity kinds, with a
  separate discriminator field naming the kind. Example in current schemas:
  `tool_or_provider_ref` on `BoundaryObservation`.
- **`<thing>_evidence_refs`** (or `subject_refs`, `evidence_refs`) — an
  array of typed reference objects with embedded provenance preview, using
  the `evidenceRefSchema` shape from `packages/schemas/src/common.ts`.
  Component evidence on a proof composite uses this pattern; a single
  evidence record is the degenerate case (`min(1)`).

Sub-rules:

4. **Singular `_evidence_ref` is reserved for polymorphic single-FK use.**
   Component evidence on a composite uses the plural `_evidence_refs` form
   even when only one record is required, so the schema can later carry
   multiple supporting records without renaming the field.
5. **Discriminator fields name the kind, not the count.** A field like
   `merge_proof_kind: "ancestry" | "patch_equivalence" | "vacuous"` selects
   which sibling `_evidence_refs` array is required. Discriminator-and-array
   pairs are the recommended pattern when an OR-shape would otherwise
   collapse two ontologically distinct facts into one field.

### Version-field naming

Schema entities, evidence subtype envelopes, and proof composites carry up
to three independent version fields. Their names and semantics are fixed:

- **`schema_version`** — names the entity, envelope, or composite schema
  itself. Required on every Ring 0 entity, evidence subtype envelope, and
  proof composite. The current value across the Phase 1 schema slice is
  the literal `'0.1.0'`.
- **`evidence_schema_version`** — names the version of the base `Evidence`
  contract (ADR 0023) under which component evidence references were
  composed. Required on evidence subtype envelopes and proof composites
  whose validity depends on the base contract; the broker may reject
  records whose `evidence_schema_version` does not match the current
  accepted base contract.
- **`payload_schema_version`** — names the domain payload schema family
  when an evidence subtype envelope (or any composite) carries a
  discriminated domain payload field (such as
  `BoundaryObservation.observed_payload`). Optional and absent when the
  envelope or composite has no separate domain payload field; in that
  case the composite *is* the field block.

Sub-rule:

6. **No fourth version field without registry update.** A composite that
   needs a fourth independent version (for example a tier-specific window
   version, or a discriminator-payload-kind version) must add a new
   registry entry naming the field, the contract it tracks, and the
   freshness/composition semantics. Otherwise composites must reuse the
   three canonical fields and accept the current scope of each. This
   sub-rule prevents the asymmetry surfaced during ADR 0025 v2 review,
   where a composite without a domain payload had drifted to a redundant
   `proof_schema_version` field.

### Adding a new suffix or convention

A new suffix or field-name convention requires:

- a citation in `DECISIONS.md` showing the design intent (typically a Q-011
  sub-decision or a downstream Q-* sub-decision approval);
- a registry update like this section, before any schema PR uses the new
  convention;
- an `hcs-ontology-reviewer` pass before the first schema PR using the new
  convention lands.

## Boundary dimension registry

Entries are alphabetised by name. Status reflects ontology review on this
registry, not the surrounding ADRs.

### `bundle_identity`

- Status: proposed
- Description: macOS app-bundle identity and signing facts for a surface,
  including bundle identifier, codesign team identifier, signature state
  (notarized, ad-hoc, broken), and observed bundle version/build.
- Primary target: `execution_context_id`
- Supplemental targets: `tool_or_provider_ref`
- Overlap notes: distinct from `launch_context` (how the process started) and
  `sandbox` (the named profile applied to the running bundle).
- Source: P13 research, 2026-04-29 quality-management synthesis.
- Sample observed payload sketch (illustrative only):
  `{ bundle_id, codesign_team_id, signature_state, version_observed, build_observed }`.

### `check_source`

- Status: proposed
- Description: GitHub check expected-source identity for a check name, including
  source app/integration, expected workflow path, commit SHA binding, and
  observed freshness.
- Primary target: `tool_or_provider_ref` (provider object reference for the
  check or workflow).
- Supplemental targets: `workspace_id`, `surface_id`.
- Overlap notes: ADR 0020 names `StatusCheckSourceObservation` as the
  evidence-subtype receipt; this dimension is the discriminator that envelope
  carries when emitted as a `BoundaryObservation`.
- Source: ADR 0020, 2026-05-01 version-control authority consult synthesis.
- Sample observed payload sketch:
  `{ check_name, source_app_id, expected_workflow_path, commit_sha, observed_at }`.

### `containment_class`

- Status: proposed (umbrella)
- Description: Cross-agent isolation posture for a surface, when no narrower
  dimension fits. Candidate values inside the payload:
  `permission_gated`, `worktree_isolated`, `kernel_sandboxed`,
  `container_or_vm`, `remote_cloud`, `mixed`.
- Primary target: `execution_context_id`
- Supplemental targets: `surface_id`, `workspace_id`
- Overlap notes: per ADR 0022, prefer the narrower dimensions
  (`sandbox`, `egress_policy`, `egress_observed`, `filesystem_authority`,
  `runner_isolation`, `worktree_ownership`) before falling back to
  `containment_class`.
- Source: Q-010, 2026-05-01 agentic tool isolation synthesis.
- Sample observed payload sketch:
  `{ class_name, mechanism, isolation_strength_label }`.

### `credential_routing`

- Status: proposed
- Description: Which credential source a surface picks for a given audience —
  `apiKeyHelper` resolution, OS Keychain item, env-var compatibility rendering,
  brokered `SecretReference`, or chained helpers.
- Primary target: `credential_source_id`
- Supplemental targets: `execution_context_id`, `tool_or_provider_ref`
- Overlap notes: never carries credential material. Distinct from observing a
  credential's value or rotating it; observation only.
- Source: ADR 0018, shell research v2 §V.P10.
- Sample observed payload sketch:
  `{ resolved_source_type, audience, helper_chain, observed_via }`.

### `egress_observed`

- Status: proposed
- Description: Observed network egress for a surface — DNS lookups, established
  connections, denial events, and "allowed but unused" markers.
- Primary target: `execution_context_id`
- Supplemental targets: `run_id`
- Overlap notes: complementary to `egress_policy` (declared rule). Distinct
  from `mcp_authorization` (provider-side identity for an MCP session) and
  `path_coverage` (provider-config scope coverage).
- Source: ADR 0015, ADR 0017, quality-management synthesis.
- Sample observed payload sketch:
  `{ destinations_observed, denied_attempts, observed_via, observation_window }`.

### `egress_policy`

- Status: proposed
- Description: Declared or configured network egress policy for a surface —
  Codex `network_access`, Claude Code permission rules, sandbox-exec policy,
  IDE extension allow/deny rules.
- Primary target: `execution_context_id`
- Supplemental targets: `workspace_id`
- Overlap notes: complementary to `egress_observed`. Records the rule, not the
  observed traffic.
- Source: ADR 0016, ADR 0017.
- Sample observed payload sketch:
  `{ policy_source, allow_default, deny_list, allow_list, last_modified }`.

### `filesystem_authority`

- Status: proposed
- Description: Filesystem read/write authority for a surface — bundled
  filesystem scope, sandbox path-write policy, Claude Code filesystem-tool
  permission set, app `Files & Folders` posture.
- Primary target: `execution_context_id`
- Supplemental targets: `workspace_id`, `surface_id`
- Overlap notes: distinct from `volume_authority` (mount-class facts) and
  `worktree_ownership` (lease/session ownership of a Git worktree).
- Source: ADR 0016, Codex sandbox docs, Claude Code filesystem permission
  research, quality-management synthesis.
- Sample observed payload sketch:
  `{ allowed_roots, denied_paths, read_scope, write_scope }`.

### `launch_context`

- Status: proposed
- Description: Process launch source — Finder origin, `open -n`, terminal
  child, IDE task, MCP server, launchd. Captures *how* the surface started.
- Primary target: `execution_context_id`
- Supplemental targets: `surface_id`
- Overlap notes: distinct from `bundle_identity` (the bundle that was
  launched).
- Source: P02 (`open -n` and Finder-origin probes), P05 (Claude Desktop
  launch-origin probe), shell research v2.
- Sample observed payload sketch:
  `{ launch_source, launcher_pid, launch_evidence_kind }`.

### `mcp_authorization`

- Status: proposed
- Description: MCP authorization surface — OAuth resource metadata, audience,
  principal-scoping, fan-out diagnostics, recent rate-limit markers (e.g.
  `last_cf_mcp_429`).
- Primary target: `tool_or_provider_ref` (MCP server reference).
- Supplemental targets: `execution_context_id`, `credential_source_id`.
- Overlap notes: distinct from `credential_routing` (local helper resolution).
  Specific to an MCP session's auth posture.
- Source: ADR 0015, Cloudflare MCP fan-out diagnostics addendum.
- Sample observed payload sketch:
  `{ mcp_server_ref, auth_kind, principal_audience, fan_out_state, last_429_at }`.

### `origin_access_validation`

- Status: proposed
- Description: Origin/tunnel validation evidence — Cloudflare `cloudflared`
  `audTag` allowlist, similar provider-side audience binding for an origin's
  reachability claim.
- Primary target: `tool_or_provider_ref` (validator/origin reference).
- Supplemental targets: `execution_context_id`.
- Overlap notes: distinct from `mcp_authorization`. Specific to origin/tunnel
  binding rather than client-session auth.
- Source: ADR 0015, Cloudflare tunnel-audience addendum.
- Sample observed payload sketch:
  `{ provider, validator_id, audience_allowlist, audience_observed, binding_state }`.

### `path_coverage`

- Status: proposed
- Description: Provider-side scope coverage gaps — Cloudflare Access wildcard
  coverage, GitHub ruleset path inclusion, MCP resource-scope coverage.
- Primary target: `tool_or_provider_ref`
- Supplemental targets: `workspace_id`
- Overlap notes: complementary to `origin_access_validation`. `path_coverage`
  is the ruleset's path scope; `origin_access_validation` is the validator
  binding.
- Source: ADR 0015 (Cloudflare Stage 3a).
- Sample observed payload sketch:
  `{ provider, ruleset_id, covered_paths, uncovered_paths, observed_at }`.

### `runner_isolation`

- Status: proposed (gated by Q-005)
- Description: CI runner-host isolation observation — clean-room versus
  persistent runner, multi-tenant exposure, ephemeral filesystem state, runner
  network egress class.
- Primary target: `execution_context_id` (runner host as context).
- Supplemental targets: `tool_or_provider_ref` (runner provider/group).
- Overlap notes: distinct from `sandbox` (process-level on developer host) and
  `containment_class` (umbrella). Q-005 must settle before this dimension is
  promoted from proposed to accepted.
- Source: 2026-04-26 proposed runner architecture report.
- Sample observed payload sketch:
  `{ runner_class, host_persistence, network_egress_class, observed_via }`.

### `sandbox`

- Status: proposed
- Description: Named OS-level sandbox profile applied to a surface — macOS
  Seatbelt profile, Codex `sandbox-exec` policy, Claude Code app sandbox,
  Electron sandbox flags. Records the profile identity and coarse capability
  outcomes.
- Primary target: `execution_context_id`
- Supplemental targets: `surface_id`, `workspace_id`
- Overlap notes: distinct from `egress_policy` (declared egress rules) and
  `filesystem_authority` (per-context path scope).
- Source: ADR 0017, P13 Codex app bundle/sandbox probe, quality-management
  synthesis.
- Sample observed payload sketch:
  `{ profile_name, profile_source, fs_scope, network_scope, keychain_scope }`.

### `tcc`

- Status: proposed
- Description: macOS TCC permission grants observed for an app surface —
  Camera, Microphone, Full Disk Access, Accessibility, Automation, Files &
  Folders, etc.
- Primary target: `execution_context_id`
- Supplemental targets: `surface_id`
- Overlap notes: distinct from `sandbox` (sandbox is the named profile; TCC
  records per-permission grants visible to that profile).
- Source: 2026-04-29 quality-management synthesis.
- Sample observed payload sketch:
  `{ tcc_service, grant_state, observed_via }` where `grant_state` is one of
  `granted | denied | not_determined | restricted`.

### `volume_authority`

- Status: proposed (speculative — needs primary citation in ontology review)
- Description: Filesystem volume / mount authority observation — encryption
  state, network mount, removable, snapshot-protected. Captures the volume the
  observed paths live on.
- Primary target: `workspace_id`
- Supplemental targets: `execution_context_id`
- Overlap notes: distinct from `filesystem_authority` (per-context path-scope
  rules). This dimension is listed in ADR 0022's candidate set without a
  strong motivating incident; ontology review should validate the dimension or
  remove it before any payload work begins.
- Source: ADR 0022 candidate list (motivation pending).
- Sample observed payload sketch:
  `{ volume_id, mount_point, encryption_state, mount_class }`.

### `worktree_ownership`

- Status: proposed (gated by Q-008)
- Description: Git worktree ownership — which session/lease/agent owns a
  worktree, observed worktree-to-branch attachment, ownership conflict state.
- Primary target: `workspace_id`
- Supplemental targets: `surface_id`, `execution_context_id`
- Overlap notes: distinct from `filesystem_authority`. Source-control receipts
  for the worktree-as-Git-object live under Q-006/ADR 0020 names; this
  dimension records the ownership/lease binding.
- Source: 2026-04-30 ScopeCam exchange synthesis, Q-008.
- Sample observed payload sketch:
  `{ worktree_path, attached_branch, lease_id, owning_session, lock_state }`.

## Adding or removing a dimension

Changes to this registry follow the schema-change workflow at
`.agents/skills/hcs-schema-change`:

1. Open a PR that updates this file and any matching enum in
   `packages/schemas/src/entities/boundary-observation.ts`.
2. Cite the motivating ADR or synthesis source. Speculative additions without a
   primary citation cannot be promoted from `proposed` and remain ineligible
   for downstream payload work.
3. `hcs-ontology-reviewer` files objections before human review.
4. Status moves from `proposed` to `accepted` only after human acceptance.
5. Removing or renaming a dimension requires evidence that no
   `BoundaryObservation` payload depends on it, plus an explicit deprecation
   note in this registry.

## References

- ADR 0022: `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
- ADR 0023: `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
- Q-011: `DECISIONS.md`
- Ontology overview: `docs/host-capability-substrate/ontology.md`
- Schema-change skill: `.agents/skills/hcs-schema-change/SKILL.md`

## Change log

| Version | Date | Change |
|---------|------|--------|
| 0.2.1 | 2026-05-02 | Added the §Version-field naming subsection codifying the three canonical version fields (`schema_version`, `evidence_schema_version`, `payload_schema_version`) and Sub-rule 6 (no fourth version field without registry update). Resolves the BoundaryObservation/BranchDeletionProof asymmetry surfaced during ADR 0025 v2 review, where a composite without a domain payload had drifted to a redundant `proof_schema_version` field. Used as a precondition for ADR 0025 acceptance. |
| 0.2.0 | 2026-05-02 | Added the §Naming suffix discipline section codifying Q-011 sub-decision (d) (approved 2026-05-01): closed `*Observation` / `*Receipt` / `*Proof` / no-suffix entity-name discipline, plus `<entity>_id` / `<thing>_ref` / `<thing>_evidence_refs` field-name discipline. Codifies the convention already in use across `packages/schemas/src/entities/` and `docs/host-capability-substrate/adr/`; resolves the `hcs-ontology-reviewer` finding that the suffix grammar was referenced but uncodified. Used as a precondition for ADR 0025 v2. |
| 0.1.0 | 2026-05-02 | Initial registry. Sixteen `boundary_dimension` candidates listed as proposed; Q-011 review grammar and registration rules captured. Created as the named registry for ADR 0022. |
