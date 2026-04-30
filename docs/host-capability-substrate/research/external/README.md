---
title: HCS external research artifacts
category: research
component: host_capability_substrate
status: active
version: 1.9.0
last_updated: 2026-04-30
tags: [research, external, substrate-config, auth, mcp, cloudflare, cloudflared, diagnostics, rate-limit, credential-broker, coordination, knowledge-store, rag, resource-budget, ci-runners, quality-management, github, macos, codex, worktree, branch-cleanup]
priority: medium
---

# External research artifacts

This directory preserves externally-sourced research documents that informed HCS design decisions. These are **input evidence, not first-party HCS decisions**. The reconciled view is captured in the session memory under `project_substrate_config_research_report1.md`; the approved decision matrix from that reconciliation is landed in `DECISIONS.md` and `PLAN.md`.

## Why in-repo

External research documents can disappear from their source locations (`/private/tmp/` clears on reboot; consultant URLs can change; browser research tools persist differently). Committing them preserves the original text for future ADR reviews and makes them citable by absolute repo path.

## Status discipline

These artifacts are **treated as external-source evidence subject to the same authority hierarchy as any other source cited in HCS work**. Per D-026 / charter invariant 14 (observed runtime + matching changelog > static docs > published schema), the current runtime state on this host overrides any claim in these documents where they disagree. Metal-verification notes for each report live in the synthesis memory.

Do **not** cite these documents as authoritative first-party HCS decisions. Cite the synthesis memory entry, or cite `DECISIONS.md` rows, or cite the charter.

## Contents

| File | Source date | Scope |
|---|---|---|
| `2026-04-23-substrate-config-research-v1.md` | 2026-04-23 | Tactical playbook: macOS Tahoe 26.4.1 / Codex CLI + app / Claude Code + Desktop / GitHub MCP / OAuth / 1Password. ~580 lines, ~70 URL citations. |
| `2026-04-23-substrate-config-research-v2.md` | 2026-04-23 | Architectural advisory: same topic scope, tighter evidence discipline, Anthropic-first-party citation that `apiKeyHelper` is CLI-only. ~130 lines, ~40 citations. |
| `2026-04-24-cloudflare-lessons.md` | 2026-04-24 | External-control-plane automation lessons from the Cloudflare Access Stage 3a service-token workflow. Produced by the Stage 3a executing agent after the incident; hand-delivered to HCS. Proposes 8 design rules, 7 regression-trap candidates, and 4 new Ring-0 entity classes (`RateLimitObservation`, `RemoteMutationReceipt`, `CredentialIssuanceReceipt`, `PathCoverage`) plus `ProviderObjectReference`/`McpAuthorizationSurface`. Synthesis memory: `project_cloudflare_stage3a_lessons.md`. |
| `2026-04-24-cloudflare-tunnel-audience-addendum.md` | 2026-04-24 | Field addendum from the later Codex/Hetzner coordination thread. Corrects the follow-on 403 root cause to `cloudflared` tunnel-side JWT audience validation (`audTag` missing the child Access app AUD), not Access policy evaluation. Q-004 is resolved by ADR 0015 as `OriginAccessValidator` with nested/linked `AudienceValidationBinding` semantics; trap seed #36 remains Phase 1 fixture work. |
| `2026-04-25-cloudflare-mcp-diagnostics-addendum.md` | 2026-04-25 | Field addendum from the temporary MCP usage collector and Cloudflare diagnostics. Confirms authenticated Cloudflare MCP fan-out across Claude/Codex hosts, 9 -> 0 authenticated-session drop after quarantine, docs-MCP degraded mode, and queues trap #38 plus ADR 0015/0012 broker requirements for principal-scoped rate-limit budgets. |
| `2026-04-24-coordination-lessons.md` | 2026-04-24 | Shared-state / coordination-store lessons from a separate "three-repo incident" (release coordination across producer/consumer/shared-worktree repos where prose, local checkouts, live infra, GHCR, 1Password, and docs drifted as competing partial sources of truth). Frames HCS shared state as **typed evidence + coordination + retrieval index — not agent memory**. Proposes ADR 0019 (knowledge-and-coordination store), 4 new Ring-0 entity classes (`KnowledgeSource`, `KnowledgeChunk`, `CoordinationFact`, `DerivedSummary`), 5 regression-trap candidates #31–#35, charter v1.3.0 invariant 18 candidate ("RAG may discover; only typed evidence may decide"), D-033 candidate, and a promotion workflow (agent proposes → verifier promotes). Five sub-decisions bundled as **Q-003 pending** rather than silently adopted — scope/sequencing/taxonomy is a major design commitment. Synthesis memory: `project_coordination_lessons_shared_state.md`. |
| `2026-04-26-research-execution-results.md` | 2026-04-26 | Research execution brief for the semantic ontology and resource-pressure plan. Recommends source-bound discovery before synthesis, a source-class taxonomy, worker result templates, verification gates, and Wave 1C/1D resource-pressure research as the first concrete batch. |
| `2026-04-26-proposed-runner-architecture.md` | 2026-04-26 | Proposed runner architecture for a separate CI project that must remain compatible with HCS and organizational principles. Recommends Proxmox-first/Linux-first/GitHub-orchestrated runners, hosted smoke sentinels, Citadel-owned OpenTofu/PaC, manual-only MacBook runner use, and HCS consuming runner/check/resource evidence rather than owning CI execution. |
| `2026-04-27-p06-probe-shape.md` | 2026-04-27 | P06 provenance-experiment brief originally delivered via a volatile `/private/tmp` path; staged verbatim for durable citation. Defines three proof lanes: tool-native trace, startup-file sentinels, and host-level process telemetry. SHA-256: `72aff550a5b2a096f537e56408c88b5b89c49c7098fe82b17a648bc15e28fdad`. |
| `2026-04-29-github-boundaries-research.md` | 2026-04-29 | Research-method blueprint plus short HCS worked example. Useful for future HCS research intake discipline: source ladders, extraction templates, credibility scoring, contradiction handling, and claim-to-source traceability. SHA-256: `9a9f6ec45ad39f7be78f9f711ed30eb65f85860d3389d397b5ea50bee4727193`. |
| `2026-04-29-hcp-quality-management.md` | 2026-04-29 | Document/source-code research report on HCS quality-management needs across macOS Tahoe app/filesystem boundaries, Git/GitHub, package-manager-installed tools, multiple GitHub identities, quality gates, candidate entities, dashboard views, and regression traps. SHA-256: `b5efcc662d9174896ba4f1ec421a00b3ea529ac9e2228adf13f16decd732edef`. |
| `2026-04-30-codex-scopecam-exchange-lessons.md` | 2026-04-30 | User-submitted evidence report from a separate Codex/ScopeCam exchange. Central lesson: the agent converted tool symptoms into environment explanations before proving execution state, then mixed normal/escalated shell observations, weak SSH/auth probes, worktree topology, branch-flow drift, destructive branch cleanup, and process argv secret exposure. SHA-256: `91c7c9e1ac6abd5cbc11596520bd2bf7e36995030e8808508620016ae3d571a5`. |

## Reconciled conclusions

### 2026-04-23 substrate-config reports (v1 + v2)

See session memory `project_substrate_config_research_report1.md` (which despite the name covers the synthesis of **both** reports). The memory file locks the approved decision matrix dated 2026-04-23, including:

- Charter v1.2.0 scope (invariants 13 + 14 + 15)
- D-028 (`host_secret_*` caller-facing credential plane)
- D-029 (amend D-022 to public-semver matching `--version`)
- D-030 (OAuth-preferred HTTP MCP baseline)
- D-031 (Codex profiles CLI-only opt-in)
- ADR 0012 committed, phased credential-broker scope

Metal-verified claims (live on this host 2026-04-23) also in the synthesis memory.

### 2026-04-24 Cloudflare lessons (Stage 3a)

See session memory `project_cloudflare_stage3a_lessons.md`. The memory captured the queued integration; the closeout state is:

- ADR 0015 accepted (**external control-plane automation**) — scope: Cloudflare, GitHub, 1Password-CLI, MCP-OAuth, DNS providers, Hetzner as one provider class with typed evidence discipline.
- Ring-0 entity additions to the Milestone 1 20-entity list: `RateLimitObservation`, `RemoteMutationReceipt`, `CredentialIssuanceReceipt`, `ProviderObjectReference` distinct from `SecretReference`, `PathCoverage`, `McpAuthorizationSurface`.
- 7 trap seeds added to `packages/evals/regression/seed.md` as #19–#25 (seeds only; scaffold expansion deferred to Phase 1).
- D-032 landed in the W3 DECISIONS.md batch: "HCS treats external APIs as typed, evidence-producing control planes, not shell-string targets."
- v1.3.0 charter candidate "inv. 16: external-control-plane evidence-first" — queue-only; v1.2.0 remains the active amendment draft.
- ADR 0012 broker scope expands to cover one-time-secret capture-at-source pattern (not just daemon-at-socket).

### 2026-04-24 Cloudflare tunnel-audience addendum

The later Codex/Hetzner coordination thread adds a separate root-cause lesson: Cloudflare Access can accept a child-app JWT while `cloudflared` rejects the same JWT before origin because the tunnel `audTag` allowlist contains only the parent Access app AUD. This strengthens ADR 0015 rather than creating a separate architecture track.

Closeout integration:

- **Q-004 resolved** by ADR 0015: model the tunnel/origin rejection surface as `OriginAccessValidator`, with nested/linked `AudienceValidationBinding` semantics rather than as plain `PathCoverage` or `McpAuthorizationSurface`.
- **Trap seed #36**: `cloudflare-access-token-valid-but-tunnel-audtag-mismatch`.
- **Fixture candidate**: `cloudflare-access-tunnel-audience-mismatch.fixture.md`.
- **D-032 landed wording**: distinguish Access app AUDs, tunnel validator allowlists, and origin reachability receipts from provider object ids, public client ids, secret material, and `SecretReference` values.
- **ADR 0015 requirement**: before proposing another Access policy mutation, collect evidence for "Access accepted/denied", "tunnel validator accepted/denied", and "origin reached/not reached" as separate facts.

### 2026-04-25 Cloudflare MCP diagnostics addendum

The temporary MCP usage collector and Cloudflare diagnostics confirm that the 429 lesson is principal-scoped fan-out, not just per-request retry hygiene. In the inspected window, authenticated Cloudflare MCP sessions peaked at 11 concurrent `mcp-remote` sessions against the same account-scoped token, across Claude Code CLI, Claude Code macOS app, Claude Desktop, and Codex CLI. Quarantine reduced authenticated Cloudflare MCP sessions from 9 to 0 in the next sample while `cloudflare-docs` remained available.

Queued integration:

- **Trap seed #38**: `cloudflare-mcp-mutation-without-fanout-check`.
- **ADR 0015 requirement**: Cloudflare mutations consume a principal-scoped `ResourceBudget`; agents must check local MCP fan-out, `last_cf_mcp_429`, and quarantine state before writes.
- **ADR 0012 broker requirement**: authenticated Cloudflare MCP should become a brokered surface with in-memory bearer handling, per-token/account serialization, and a shared quiet-window clock.
- **Entity/taxonomy candidate**: `McpSessionObservation` or an `Evidence` subtype for endpoint/owner/session-count diagnostics; `ControlPlaneBackoffMarker` or a `RateLimitObservation` subtype for `last_cf_mcp_429`.
- **Degraded-mode rule**: keep `cloudflare-docs` separate from authenticated Cloudflare API MCP so docs lookup remains available during quarantine.
- **Process-inspection dependency**: permanent diagnostics should use the typed process-inspection operation from trap #37; the temporary collector redacts persisted argv but still relies on process-command inspection internally.

### 2026-04-24 Coordination / shared-state lessons (three-repo incident)

See session memory `project_coordination_lessons_shared_state.md`. The brief's central thesis — "HCS should implement a shared evidence and coordination store with a derived retrieval index; do not make a general agent memory where models store conclusions" — is highly aligned with existing HCS posture (charter inv. 1/2/5/7/8/10, D-003/D-018/D-025/D-026, ADR 0004/0010/0011). The queued integration preserves that alignment and **explicitly defers five major decisions as Q-003 pending** rather than silently adopting the proposed architecture:

**Already-covered posture (preserve, do not duplicate):**

- Typed provenance/authority/freshness on `Evidence` — charter inv. 8, D-025, D-026.
- No policy decisions in adapters — charter inv. 1.
- No shell strings as primary intent — charter inv. 2.
- Secrets as references, not values — charter inv. 5.
- Execute-lane blocked until approval/audit/dashboard/leases stack is live — charter inv. 7.
- Runtime state outside repo — charter inv. 10, D-018, D-020.
- SQLite WAL as authority store — D-003, ADR 0004, PLAN.md Milestone 3.
- MCP Resources/Tools/Prompts primitive mapping — D-012, ADR 0010.
- Sandbox observations cannot be promoted to host-authoritative — charter inv. 8 (same pattern the brief extends to agent-summaries).

**Strengthens existing articulation:**

- "RAG may discover; only typed evidence may decide" extends charter inv. 8 + D-025 to a new surface (retrieval/RAG). Worth a charter v1.3.0 invariant 18 candidate.
- Write-class taxonomy (observed evidence / human decisions / receipts/artifacts / agent claims-or-summaries) formalizes what `Evidence.authority` + `confidence` already imply.
- `DerivedSummary.allowed_for_gate = false` generalizes the `authority: sandbox-observation` pattern to agent-authored derivative facts.

**Queued as genuinely new (ADR 0019 + entity additions + traps + D-033 candidate):**

- **ADR 0019 — HCS Knowledge and Coordination Store** candidate. Scope: define the three-layer taxonomy (authoritative operational store / coordination state layer / retrieval index) and the promotion workflow. **Drafting window: post-Phase-1 synthesis, not Week 1.** ADR 0019 is a larger design commitment than 0016/0017/0018 and should not race Phase 1.
- **4 Ring-0 entity candidates**: `KnowledgeSource` (indexable canonical source), `KnowledgeChunk` (derived chunk with stable hashing), `CoordinationFact` (subject/predicate/object gateable state assertion), `DerivedSummary` (agent-produced summary with `allowed_for_gate: false`). **Reconciliation with existing `Evidence` is a sub-question under Q-003** — the brief presents these as peers but they could also be specializations/subtypes.
- **5 regression trap seeds #31–#35** covering stale-RAG-release-gate, detached-worktree-false-regression, agent-summary-overclaim, stale-ssh-alias, auth-surface-conflation.
- **D-033 candidate**: "HCS shared memory is typed evidence + coordination state + derived retrieval index, not agent memory." Target landing: post-Phase-1 DECISIONS batch (NOT the W3 closeout batch — D-033 is a whole-architecture commitment that needs Q-003 resolution first).

**Five major decisions flagged as Q-003 pending (NOT silently adopted):**

1. **Timing/scope**: does the coordination layer (KnowledgeSource / KnowledgeChunk / CoordinationFact / DerivedSummary + retrieval index + promotion workflow) land within the initial build (Milestones 1–6), or post-Phase-1?
2. **Entity reconciliation**: how do new entities relate to the existing `Evidence` primitive? Peers in the ontology, or specializations/subtypes?
3. **`allowed_for_gate` schema representation**: first-class boolean field on fact-like entities, or derived from `authority` / `confidence` values?
4. **Promotion workflow formalization**: is "agent proposes / verifier promotes" a parallel track to the existing approval-grant pattern (M2), or does it reuse approval-grant semantics with a different target?
5. **Charter v1.3.0 invariant 18**: formalize "RAG/derived retrieval may discover; only typed evidence/receipts/leases/decisions/live-probes may decide" as a non-negotiable invariant, or keep as a strong guideline under existing inv. 8?

### 2026-04-26 research execution brief

This brief refines `docs/host-capability-substrate/semantic-ontology-resource-research-plan.md` rather than adding a standalone architecture decision.

Reconciled integration:

- The research remains Ring 3 planning until official-source findings pass a verification gate.
- Discovery workers should receive narrow source-bound prompts, not the full local HCS hypothesis set.
- Source classes (`official`, `primary`, `secondary`, `discovery`) must be recorded on every claim.
- Wave 1C/1D resource-pressure work should run first when capacity is limited because it is version-sensitive and directly affects `ResourceBudget`, `ResourceObservation`, `WorkloadShape`, and `ExecutionLease` design.
- Synthesis outputs queue ADRs for semantic foundation, governance authority semantics, ResourceBudget/host pressure, and rollout posture; no schema/entity changes land from the report alone.

Planning changes landed in `docs/host-capability-substrate/semantic-ontology-resource-research-plan.md` v1.1.0 and `PLAN.md`.

### 2026-04-26 proposed runner architecture

The runner report concerns a separate CI/runner project. HCS compatibility is strong if the boundary is kept explicit:

- GitHub remains the workflow scheduler, check/status source, and branch/ruleset gate.
- Citadel/OpenTofu/PaC owns desired infrastructure, runner group access, workflow policy, and Proxmox runner definitions if those become managed IaC.
- Proxmox/Linux x64 is the canonical self-hosted CI appliance class for trusted/private workloads.
- GitHub-hosted smoke/sentinel checks remain the clean-room proof, especially for public-source repos.
- MacBook M3 Max/macOS runner usage remains manual-only for macOS/ARM compatibility, not ordinary CI.
- HCS records typed runner, workflow, resource, cache, and credential-reference evidence. It does not become a parallel CI control plane.

Pending design question Q-005 records the HCS-side boundary and entity-shape work. The existing draft report `docs/host-capability-substrate/local-first-ci-opentofu-runner-design.md` remains the HCS compatibility synthesis; the external report staged here is preserved as input evidence.

### 2026-04-27 P06 probe-shape brief

The P06 probe-shape brief is preserved because the source was delivered under
volatile `/private/tmp/`. The reconciled runbook is
`docs/host-capability-substrate/research/shell-env/2026-04-27-P06-provenance-experiment-plan.md`.

Reconciled integration:

- P06 closure requires three independent lanes: tool-native trace, temporary
  startup-file sentinels, and host-level process telemetry.
- PATH-prefix wrapper interception is closed as unsuitable except for negative
  controls because observed Codex/Claude surfaces use absolute `/bin/zsh`.
- Host telemetry is the authority for `execve` truth; startup sentinels are the
  authority for user startup-file effects; tool-native trace is the authority
  for tool/controller intent.
- The brief is an execution plan, not a result. It does not change schema or
  policy by itself.

### 2026-04-29 quality-management reports

The two 2026-04-29 reports strengthen Phase 1 planning but do not make schema
or policy decisions by themselves.

Reconciled integration:

- `2026-04-29-github-boundaries-research.md` is primarily a research-method
  blueprint. It reinforces source ladders, extraction templates, credibility
  scoring, contradiction tracking, and claim-to-source traceability for future
  HCS research intakes.
- `2026-04-29-hcp-quality-management.md` is the substantive source-bound report.
  It argues that macOS Tahoe app/TCC/filesystem boundaries, Git/GitHub identity
  routing, package-manager provenance, and multiple GitHub identities are too
  loose to treat as one stable authority surface.
- The HCS synthesis lives at
  `docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md`.
- Q-007 records the pending design decision for quality-management and boundary
  accommodation. Q-006 remains focused on GitHub/version-control authority;
  Q-005 remains focused on CI runner/check evidence.
- No candidate entity, policy tier, dashboard view, or regression trap from the
  reports is accepted until Phase 1 synthesis or a concrete observed failure.

### 2026-04-30 Codex / ScopeCam exchange lessons

The ScopeCam exchange report is a user-submitted evidence report, not a primary
transcript in this repository. It is still strong planning evidence because the
failure classes match HCS field observations: process argv secret exposure,
auth-surface conflation, Git cleanup risk, and execution-context ambiguity.

Reconciled integration:

- The HCS synthesis lives at
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`.
- Q-008 records the pending design decision for agent execution reality and
  destructive Git hygiene. Q-006 remains the broader GitHub/version-control
  authority model; Q-007 remains boundary/quality management.
- Six seed-level traps are added as #39-#44: tool symptom as environment
  diagnosis, execution-mode conflation, remote-gone branch deletion without
  proof, worktree ownership ignored, branch-flow ancestry ignored, and inline PR
  body shell expansion.
- Trap #37 already covers process argv secret exposure, and trap #35 already
  covers auth-surface conflation. This report strengthens both without adding
  duplicate trap rows.
- Full trap scaffold files should wait for a redacted primary transcript or
  human-approved fixture. Until then the entries remain seed-level.
- No scripts, policy tiers, hooks, branch rules, or runtime behavior are accepted
  from this report by default. The scaffolding ideas are design inputs.

## What the reports do not cover

The **2026-04-23 substrate-config reports** do not address: audit hash chain, sandbox execution, lease/lock semantics, regression-trap patterns, intervention records, `op` IPC queue contention as a substrate problem, six-question surface-boundary methodology, Phase 0b measurement surfaces, or trajectory-scoring topics. Those remain the HCS team's design space. The IPC broker memory (`project_op_ipc_broker_requirements.md`) is the authoritative source for the `op` contention problem, not these reports.

The **2026-04-24 Cloudflare lessons** are a post-incident brief, not an exhaustive design document. Scope gaps to flag when the Phase 1 broker/provider-adapter work begins:

- Does not address per-provider retry semantics beyond 429 (e.g., idempotency keys, `If-Match` ETag patterns, `Retry-After` with date-vs-seconds ambiguity).
- Does not address provider-side eventual consistency (e.g., Cloudflare change propagation windows where a successful `PUT` is not immediately visible via `GET`). Rule 3 ("mutation response is authoritative evidence") partly mitigates, but longer-horizon verification under eventual consistency is its own design surface.
- Does not address audit-ID correlation across multi-step provider workflows (e.g., Cloudflare `cf-ray` → Zero-Trust audit log vs. Access audit log, and which audit stream is authoritative for which operation class).
- Does not address provider outage/partial-degradation semantics — the rate-limit posture is well-developed, the provider-unavailable posture is not.
- Rate-limit observations are treated per-request; the 5-minute cumulative window across all Cloudflare surfaces (dashboard + API key + API token) is a user-level budget, not a per-agent budget, and needs a principal-level `ResourceBudget` rollup to gate multi-agent contention.

## Update policy

When future external research reports land on similar topics:

1. Stage the source file here with date-prefixed filename.
2. Add a row to the Contents table above.
3. Do metal verification of any claims that can be checked on the host.
4. Synthesize into a project memory entry (not into this README).
5. If the synthesis changes the approved decision matrix, land DECISIONS.md / PLAN.md / charter amendments per the established W2→W3 closeout cadence.

Reports should be staged here verbatim from durable source files; do not edit the content of stored reports. If a report has internal citation artifacts (e.g., `citeturn*` tags), leave them — they preserve provenance. When a report is delivered inline rather than as a durable file, preserve a normalized source note, avoid expanding or adding secret-shaped content, and mark it as secondary evidence unless the primary transcript/log is also staged.

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.9.0 | 2026-04-30 | Staged the Codex/ScopeCam exchange lessons report, recorded its SHA-256, added a synthesis link, queued Q-008, and reconciled six seed-level trap additions (#39-#44). |
| 1.8.0 | 2026-04-29 | Staged the 2026-04-29 research-method blueprint and HCS quality-management report from `/private/tmp`, recorded SHA-256 hashes, and linked the local synthesis plus Q-007 planning path. |
| 1.7.0 | 2026-04-27 | Staged `2026-04-27-p06-probe-shape.md` verbatim from volatile `/private/tmp`, recorded its SHA-256, and reconciled it into the P06 provenance experiment plan. |
| 1.6.0 | 2026-04-26 | Staged the 2026-04-26 research execution and proposed runner architecture reports. Reconciled resource-pressure research sequencing into the semantic/resource plan and queued HCS runner-compatibility boundary work as Q-005. |
| 1.5.0 | 2026-04-26 | Reconciled Phase 0b closeout: ADR 0015 accepted, Q-004 resolved as `OriginAccessValidator` with `AudienceValidationBinding` semantics, D-032 landed, and ADR 0012 credential broker scope committed. |
| 1.4.0 | 2026-04-25 | Staged `2026-04-25-cloudflare-mcp-diagnostics-addendum.md`. Added trap #38 and ADR 0015/0012 integration notes for authenticated Cloudflare MCP fan-out, quarantine, principal-scoped `ResourceBudget`, and docs-MCP degraded mode. |
| 1.3.0 | 2026-04-24 | Staged `2026-04-24-cloudflare-tunnel-audience-addendum.md`, preserving the original Cloudflare lessons brief as first received. Added Q-004 / trap #36 / ADR 0015 integration notes for `cloudflared` tunnel-side audience validation (`audTag` missing child Access app AUD). |
| 1.2.0 | 2026-04-24 | Staged `2026-04-24-coordination-lessons.md` (shared-state / coordination-store brief from "three-repo incident"). Added Reconciled-conclusions subsection with four-category mapping (already-covered / strengthens-existing / genuinely-new / five-major-decisions-deferred). ADR 0019 candidate scoped for post-Phase-1, four Ring-0 entity additions queued, five trap seeds #31–#35 seeded, D-033 candidate queued (NOT in W3 batch), charter v1.3.0 invariant 18 candidate queued, **Q-003 pending added to DECISIONS.md** bundling five sub-decisions. Explicit discipline: the brief is highly aligned with existing HCS posture but committing to the three-layer architecture is a whole-system design commitment requiring deliberate consideration, not closeout-week silent adoption. |
| 1.1.0 | 2026-04-24 | Staged `2026-04-24-cloudflare-lessons.md` (external-control-plane automation brief from Cloudflare Stage 3a). Added Reconciled-conclusions subsection locking the queued integration matrix (ADR 0015 draft, 6 Ring-0 entity additions, 7 trap seeds #19–#25, D-032 candidate, v1.3.0 inv. 16 candidate, ADR 0012 broker-scope expansion). Added "What the reports do not cover" gaps list specific to the Cloudflare brief. |
| 1.0.0 | 2026-04-23 | Initial. Staged reports v1 + v2 of the substrate-config research series. README establishes the in-repo preservation pattern, status discipline, and update policy. |
