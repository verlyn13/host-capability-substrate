---
title: Human Decision Report — 2026-05-01
category: decision-report
component: host_capability_substrate
status: active
date: 2026-05-01
charter_version: 1.2.0
tags: [human-decision, phase-1, ontology, evidence, q-011]
priority: high
---

# Human Decision Report — 2026-05-01

This report records human approvals made during the Phase 1 approval pass. It is
a docs-only decision artifact. It does not add schemas, generated JSON Schema,
policy tiers, hooks, adapters, dashboard routes, GitHub settings, runtime probes,
or mutation operations.

## Q-011 — Ontology Promotion And Receipt Dedupe Rule

Status: approved by the human owner on 2026-05-01.

Primary sources:

- `DECISIONS.md` Q-011
- `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- `packages/schemas/src/common.ts` current `evidenceRefSchema`
- `docs/host-capability-substrate/adr/0020-version-control-authority.md`
- `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`

Approved resolutions:

1. Approve the three review buckets: `Evidence subtype`, `Standalone entity`,
   and `Composite or authored decision artifact`.
2. Treat proof composites such as `BranchDeletionProof`,
   `CleanRoomSmokeReceipt`, and `PolicyPlanReceipt` as artifacts consumed by
   approval or execution flows, not as objects derived from `ApprovalGrant`.
3. Treat Q-003 authored facts such as `CoordinationFact` and `DerivedSummary`
   as authored coordination or knowledge artifacts, not as `Evidence`
   specializations. They may reference evidence; they are not observations.
4. Approve naming suffix discipline:
   - `*Observation` for freshness-bound observed facts.
   - `*Receipt` for point-in-time event, run, or action records.
   - `*Proof` for operation-bound proof composites.
   - no suffix for durable lifecycle entities.
5. Accept the near-term duplicate dispositions from the Q-011 plan, including
   `GitHubRepositorySettingsObservation` over `GitHubRepoSettingsObservation`,
   `GitWorktreeObservation` over `WorktreeStateObservation`, and one canonical
   `BranchDeletionProof`. Prefer generic `McpSessionObservation` with
   provider/surface fields unless Q-006 later proves provider-specific
   constraints are necessary.
6. Approve the dependency order as a guardrail: Q-011 first, then the Evidence
   base shape, then `BoundaryObservation` / ADR 0022. ADR 0020 may proceed only
   as limited posture acceptance until schema reconciliation.
7. Place the `boundary_dimension` registry in a future
   `docs/host-capability-substrate/ontology-registry.md` artifact. Dimensions
   are singular, define a primary target convention, and treat version/build
   drift as freshness invalidation unless a narrower dimension is later
   approved.
8. Require a full `Evidence` base entity before accepting any `Evidence` subtype
   envelope. The current embedded `evidence_refs` shape is temporary provenance
   scaffolding.
9. Keep `ExecutionContext.sandbox` as a coarse current snapshot for now. Future
   `BoundaryObservation` sandbox evidence should coexist first; repeated,
   stale, or fine-grained sandbox claims can migrate out of direct
   `ExecutionContext.sandbox` fields only after schema review proves the shape.

Boundary of this approval:

- This approves the review grammar and sequencing rule.
- This does not approve new schemas, generated JSON Schema, policy tiers, hooks,
  adapters, dashboard routes, GitHub settings, runtime probes, or mutation
  operations.
- Q-003, Q-005, Q-006, Q-007, Q-008, Q-009, Q-010, and Q-012 remain open except
  where this decision provides sequencing and dedupe constraints.

## Evidence Base Shape / ADR 0023 Drafting Approval

Status: ADR drafting posture approved by the human owner on 2026-05-01. This
section records the drafting approval; ADR 0023 was later accepted in the
section below.

Primary sources:

- `packages/schemas/src/common.ts` current `evidenceRefSchema`
- `docs/host-capability-substrate/ontology.md` current prose `Evidence` shape
- `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
- `.claude/agents/hcs-ontology-reviewer.md`

Approved drafting posture:

1. Draft ADR 0023 to define `Evidence` as the canonical Ring 0 fact base entity.
2. Require every evidence record to carry, at minimum, `source`, `observed_at`,
   `valid_until`, `authority`, `parser_version`, and `confidence`, plus a stable
   evidence identifier and schema version.
3. Keep `evidenceRefSchema` as a lightweight reference or embedded provenance
   shim during migration. It is not a competing substitute for the full entity.
4. Require evidence subtypes, observations, receipts, and future envelopes such
   as `BoundaryObservation` to inherit or wrap the base `Evidence` contract
   rather than defining provenance independently.
5. Preserve charter invariant 8: `authority: sandbox-observation` cannot be
   promoted above sandbox authority without a separate non-sandbox evidence
   source.
6. Preserve charter invariant 5: Evidence can contain references, hashes,
   classifications, or redacted payloads, but not raw secret material.

Boundary of this approval:

- This approves drafting ADR 0023 with the above posture.
- This does not accept ADR 0023 as final, and does not add schemas, generated
  JSON Schema, policy tiers, hooks, adapters, dashboard routes, runtime probes,
  or mutation operations.
- The eventual schema implementation must move Zod source, generated JSON
  Schema, ontology docs, tests, and fixtures together under the schema-change
  workflow.

## ADR 0023 — Evidence Base Shape

Status: accepted by the human owner on 2026-05-01 after
`hcs-ontology-reviewer` objections were addressed.

Primary sources:

- `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
- `packages/schemas/src/common.ts` current `evidenceRefSchema`
- `docs/host-capability-substrate/ontology.md` current prose `Evidence` shape
- `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`

Approved resolutions:

1. `Evidence` is the canonical Ring 0 fact base entity.
2. `evidenceRefSchema` remains a transitional reference or embedded provenance
   shim, not the permanent fact model.
3. Every full `Evidence` record must carry required provenance and freshness
   fields: `source`, `observed_at`, `valid_until`, `authority`,
   `parser_version`, and `confidence`, plus a stable evidence identifier and
   schema version.
4. Evidence with `authority: sandbox-observation` must be traceable to a
   sandboxed source: an `execution_context_id` plus a concrete trace reference
   such as `session_id`, `run_id`, or `source_ref`.
5. Sandbox-sourced data cannot be promoted to stronger authority without a
   separate non-sandbox evidence record.
6. Evidence payloads may be redacted, classified, hashed, or reference-only, but
   must not contain raw secret material.
7. `BoundaryObservation` remains gated until the Evidence entity is both
   accepted by this ADR and later implemented through the schema-change
   workflow.

Boundary of this approval:

- This accepts ADR 0023 as architecture.
- This does not add schemas, generated JSON Schema, policy tiers, hooks,
  adapters, dashboard routes, runtime probes, or mutation operations.
- The later Evidence implementation must move Zod source, generated JSON
  Schema, ontology docs, tests, and fixtures together.

## Q-006 / ADR 0020 — Version Control Authority

Status: approved by the human owner on 2026-05-01 as a limited posture
decision.

Primary sources:

- `DECISIONS.md` Q-006
- `docs/host-capability-substrate/adr/0020-version-control-authority.md`
- `docs/host-capability-substrate/research/local/2026-04-29-github-version-control-agentic-surface.md`
- `docs/host-capability-substrate/research/local/2026-05-01-version-control-authority-consult-synthesis.md`
- `docs/host-capability-substrate/research/external/2026-05-01-version-control-authority-consult.md`
- `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`

Approved resolutions:

1. Treat Git, GitHub, GitHub Actions, GitHub MCP, `gh`, SSH, signing, rulesets,
   branch protection, PR/review state, checks, and worktrees as separate
   authority surfaces.
2. Start with evidence subtypes and receipts rather than immediate
   GitHub-specific core entities.
3. Commit only the five load-bearing near-term Q-006 review names:
   `GitConfigResolution`, `GitIdentityBinding`, `BranchDeletionProof`,
   `StatusCheckSourceObservation`, and `SourceControlContinuityReceipt`.
4. Defer the broader ADR 0020 candidate inventory to Q-011-guided ontology
   review.
5. Check results are not gateable by name or conclusion alone. Gateable check
   evidence must include expected source app or integration, commit SHA,
   workflow path or provider source, observed time, and freshness.
6. Branch cleanup requires `BranchDeletionProof`. Remote-gone state, UI absence,
   or "merged somewhere" is not sufficient deletion authority.
7. GitHub credential authority remains split by surface: `gh`, SSH, signing,
   GitHub App, Actions token, OIDC, MCP PAT/OAuth, Copilot or agent app
   sessions, and web automation.

Boundary of this approval:

- ADR 0020 is accepted as source-control authority posture.
- This does not add schemas, generated JSON Schema, policy tiers, GitHub repo
  settings, branch protection, CODEOWNERS, workflows, Actions permissions, MCP
  credential migration, hooks, adapters, dashboard routes, runtime probes, or
  GitHub mutation endpoints.

## ADR 0016 — Shell/Environment Ownership Boundaries

Status: accepted by the human owner on 2026-05-01.

Primary sources:

- `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- `docs/host-capability-substrate/shell-environment-research.md` v2.12.0
- `docs/host-capability-substrate/research/shell-env/`
- `packages/evals/regression/claude-env-file-durability.md`
- `docs/host-capability-substrate/implementation-charter.md` v1.2.0

Approved resolutions:

1. Shell-exported values are allowed as explicit CLI-local convenience, but are
   not cross-surface authority.
2. GUI apps, IDE extensions, MCP startup, setup scripts, subagents, and
   app-managed Preview surfaces cannot be assumed to inherit terminal env.
3. HCS models shell and environment behavior through typed `ExecutionContext`
   and `EnvProvenance`, not through adapter-specific rules or ambient shell
   state.
4. Project config, shell/bootstrap config, app settings, setup scripts, and MCP
   auth remain separate planes.
5. Credential availability must come from typed credential sources, app-native
   auth, brokered secret references, or direct per-surface evidence.
6. Secret-safe env inspection remains names-only, existence-only, classified, or
   hashed.
7. Existing trap #29, `packages/evals/regression/claude-env-file-durability.md`,
   remains the canonical trap for `CLAUDE_ENV_FILE` durability. No duplicate
   trap is accepted.

Boundary of this approval:

- ADR 0016 is accepted.
- This does not add schemas beyond the already-landed shell/env slice, policy
  tier entries, live host config changes, hooks, adapters, dashboard routes,
  runtime probes, or mutation operations.

## ADR 0017 — Codex App Distinct Execution Context

Status: accepted by the human owner on 2026-05-01.

Primary sources:

- `docs/host-capability-substrate/adr/0017-codex-app-execution-context.md`
- `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- `docs/host-capability-substrate/research/shell-env/2026-04-26-P02-codex-app-gui-launch-env.md`
- `docs/host-capability-substrate/research/shell-env/2026-04-26-P13-codex-app-bundle-signing.md`
- `docs/host-capability-substrate/research/shell-env/2026-05-01-codex-official-config-app-settings-ingest.md`
- `docs/host-capability-substrate/dashboard-contracts.md`

Approved resolutions:

1. Codex CLI, Codex macOS app, Codex IDE extension, setup scripts,
   app-integrated terminal, and app-server probes are separate surfaces.
2. Model the Codex macOS app as a distinct `ExecutionContext`, provisionally
   `codex_app_sandboxed`.
3. P02 Finder-origin evidence supports that the Codex app GUI does not inherit
   terminal-only env markers for this host/version family.
4. P13 bundle, process, and schema evidence is valid identity and probe-design
   input, but not complete app-internal capability proof.
5. CLI evidence and temporary CLI-started app-server evidence must not satisfy
   `codex_app_sandboxed` claims.
6. Codex app Keychain, filesystem, network, shell, MCP, and PATH rows remain
   `pending` until direct per-surface receipts exist.
7. Dashboard-facing app capability rows use the canonical seven-state vocabulary
   from `docs/host-capability-substrate/dashboard-contracts.md`: `proven`,
   `denied`, `pending`, `stale`, `contradictory`, `inapplicable`, and
   `unknown`.

Boundary of this approval:

- ADR 0017 is accepted.
- This does not run app-internal probes, complete P13, change app settings,
  change live config, add schemas, policy tiers, hooks, adapters, dashboard
  routes, runtime probes, or mutation operations.

## ADR 0018 — Durable Credential Source Preference

Status: accepted by the human owner on 2026-05-01 with schema-field-only
posture.

Primary sources:

- `docs/host-capability-substrate/adr/0018-durable-credential-preference.md`
- `docs/host-capability-substrate/adr/0012-credential-broker.md`
- `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- `docs/host-capability-substrate/adr/0017-codex-app-execution-context.md`
- `docs/host-capability-substrate/research/shell-env/2026-04-26-P01-codex-auth-metadata.md`
- `docs/host-capability-substrate/research/shell-env/2026-04-26-P05-claude-desktop-auth-boundary.md`

Approved resolutions:

1. Prefer explicit, scoped, durable credential sources over ambient shell env or
   assumed subscription OAuth.
2. Tool-native OAuth plus OS credential storage remains preferred when it is
   first-party, supported by the exact target surface, and verified by restart
   or startup evidence.
3. For HCS-integrated, headless, non-OAuth, one-time-secret, and provider
   API-key flows, prefer brokered `SecretReference`, setup-token-style
   credentials, API keys, or service accounts with explicit scope, storage,
   expiry, rotation, and health evidence.
4. Environment variables are compatibility renderings for specific processes or
   helpers, not durable credential sources.
5. Future `CredentialSource` schema work should preserve fields for audience,
   scope, mutation-scope posture, expiry, rotation, and healthcheck evidence.
6. Missing expiry, rotation, or healthcheck evidence should make a credential
   source non-gateable or approval-required until policy defines a narrower
   exception.
7. Existing env/PAT fallbacks remain until an accepted OAuth or broker strategy
   succeeds and passes restart or startup proof.

Rejected by this approval:

- Raw secrets in committed files, config, or ADRs.
- Shell-exported PAT/API-key variables as the substrate default.
- Assuming apps, IDE extensions, or subagents can use CLI credential helpers or
  CLI OAuth state.
- Removing existing fallbacks based on theoretical OAuth.
- A universal "read any secret" agent-callable tool.
- A custom HCS OAuth proxy as Phase 1 scope.

Boundary of this approval:

- ADR 0018 is accepted as credential-source schema posture.
- This does not change live credentials, migrate GitHub MCP auth, add schemas,
  add policy tiers, implement the broker, change hooks/adapters/dashboard
  routes, run runtime probes, or add mutation operations.

## ADR 0022 / Q-007a — BoundaryObservation Envelope Disposition

Status: disposition approved by the human owner on 2026-05-01. ADR 0022 remains
proposed; Q-007(a) remains pending.

Primary sources:

- `DECISIONS.md` Q-007
- `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md`
- `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
- `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- `docs/host-capability-substrate/human-decision-report-2026-05-01.md` Q-011

Approved disposition:

1. Do not accept ADR 0022 yet.
2. Keep ADR 0022 in `proposed` status.
3. Update ADR 0022's acceptance preconditions to reflect that Q-011 is approved
   and ADR 0023 is accepted as Evidence base-shape architecture.
4. Use `docs/host-capability-substrate/ontology-registry.md` as the future
   `boundary_dimension` registry artifact location.
5. Require `boundary_dimension` values to be singular and registered before
   schema implementation.
6. Treat version/build/dependency drift as freshness invalidation unless a
   narrower dimension is explicitly approved in the registry.
7. Require the full `Evidence` base entity to be implemented before accepting
   `BoundaryObservation` as an `Evidence` subtype envelope.
8. Keep Q-007(a) pending until ADR 0022 can be accepted after Evidence
   implementation.
9. Keep `QualityGate` deferred.

Boundary of this disposition:

- This updates proposed ADR preconditions only.
- This does not add schemas, generated JSON Schema, policy tiers, hooks,
  adapters, dashboard routes, GitHub settings, runtime probes, macOS probes, or
  mutation operations.

## Q-012 / ADR 0021 — Charter v1.3.0 Wave 1

Status: approved by the human owner on 2026-05-01 after `hcs-policy-reviewer`
and `hcs-security-reviewer` objections were addressed.

Primary sources:

- `DECISIONS.md` Q-012
- `docs/host-capability-substrate/adr/0021-charter-v1-3-wave-1.md`
- `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
- `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- `docs/host-capability-substrate/implementation-charter.md` v1.2.0

Approved resolutions:

1. Approve invariant 16: external-control-plane operations are evidence-first.
   Typed provider evidence is necessary before provider-side mutation is
   proposed or rendered.
2. Approve invariant 17: execution context is declared, not inferred. Every
   operation carries a resolved execution-context surface reference.
3. Preserve the reviewer-added guard: typed evidence is necessary, not
   sufficient. It does not bypass policy/gateway decisions, `ApprovalGrant`
   consumption, broker finite-state-machine requirements, audit, dashboard
   review, or lease requirements.
4. Preserve the narrowed inheritance carve-out: surface operators such as Codex
   `shell_environment_policy inherit/include_only` can prove only
   environment-materialization for the named target context through secret-safe
   `EnvProvenance` evidence. They do not prove credential authority, sandbox
   scope, app/TCC permission, provider mutation authority, or HCS
   `ApprovalGrant` status.
5. Keep invariants 18-20 queued until Q-003, Q-007, and Q-008 settle.
6. The charter-edit PR must be charter and related bookkeeping only. It must not
   add schemas, generated JSON Schema, policy tiers, hooks, adapters, dashboard
   routes, runtime probes, or mutation operations.
7. The accepted charter-edit target is v1.3.0 unless another charter amendment
   intervenes first.
8. Treat `ExecutionContext` as the intended canonical Ring 0 concept for
   invariant 17 unless schema reconciliation deliberately replaces it with an
   equivalent canonical entity.

Boundary of this approval:

- ADR 0021 is accepted.
- The active charter remains v1.2.0 until a separate charter-edit PR lands.
- This approval does not add schemas, policy, hooks, adapters, dashboard routes,
  runtime probes, or mutation operations.
