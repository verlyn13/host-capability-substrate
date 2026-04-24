---
title: HCS external research artifacts
category: research
component: host_capability_substrate
status: active
version: 1.2.0
last_updated: 2026-04-24
tags: [research, external, substrate-config, auth, mcp, cloudflare, rate-limit, credential-broker, coordination, knowledge-store, rag]
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
| `2026-04-24-coordination-lessons.md` | 2026-04-24 | Shared-state / coordination-store lessons from a separate "three-repo incident" (release coordination across producer/consumer/shared-worktree repos where prose, local checkouts, live infra, GHCR, 1Password, and docs drifted as competing partial sources of truth). Frames HCS shared state as **typed evidence + coordination + retrieval index — not agent memory**. Proposes ADR 0019 (knowledge-and-coordination store), 4 new Ring-0 entity classes (`KnowledgeSource`, `KnowledgeChunk`, `CoordinationFact`, `DerivedSummary`), 5 regression-trap candidates #31–#35, charter v1.3.0 invariant 18 candidate ("RAG may discover; only typed evidence may decide"), D-033 candidate, and a promotion workflow (agent proposes → verifier promotes). Five sub-decisions bundled as **Q-003 pending** rather than silently adopted — scope/sequencing/taxonomy is a major design commitment. Synthesis memory: `project_coordination_lessons_shared_state.md`. |

## Reconciled conclusions

### 2026-04-23 substrate-config reports (v1 + v2)

See session memory `project_substrate_config_research_report1.md` (which despite the name covers the synthesis of **both** reports). The memory file locks the approved decision matrix dated 2026-04-23, including:

- Charter v1.2.0 scope (invariants 13 + 14 + 15)
- D-028 (OAuth-preferred HTTP MCP)
- D-029 (amend D-022 to public-semver matching `--version`)
- D-030 (absorbed into D-026 + charter inv. 14 body)
- D-031 (Codex profiles CLI-only opt-in)
- ADR 0012 conditional-broker scope

Metal-verified claims (live on this host 2026-04-23) also in the synthesis memory.

### 2026-04-24 Cloudflare lessons (Stage 3a)

See session memory `project_cloudflare_stage3a_lessons.md`. The memory captures the queued integration:

- ADR 0015 draft (**external control-plane automation**) — scope: Cloudflare, GitHub, 1Password-CLI, MCP-OAuth, DNS providers, Hetzner as one provider class with typed evidence discipline. Queued for W3 merge sequence after ADR 0014; drafting window is W2 + early W4.
- Ring-0 entity additions to the Milestone 1 20-entity list: `RateLimitObservation`, `RemoteMutationReceipt`, `CredentialIssuanceReceipt`, `ProviderObjectReference` distinct from `SecretReference`, `PathCoverage`, `McpAuthorizationSurface`.
- 7 trap seeds added to `packages/evals/regression/seed.md` as #19–#25 (seeds only; scaffold expansion deferred to Phase 1).
- D-032 candidate for the W3 DECISIONS.md batch: "HCS treats external APIs as typed, evidence-producing control planes, not shell-string targets."
- v1.3.0 charter candidate "inv. 16: external-control-plane evidence-first" — queue-only; v1.2.0 remains the active amendment draft.
- ADR 0012 broker scope expands to cover one-time-secret capture-at-source pattern (not just daemon-at-socket).

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

Reports should be staged here verbatim from the source; do not edit the content of stored reports. If a report has internal citation artifacts (e.g., `citeturn*` tags), leave them — they preserve provenance.

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.2.0 | 2026-04-24 | Staged `2026-04-24-coordination-lessons.md` (shared-state / coordination-store brief from "three-repo incident"). Added Reconciled-conclusions subsection with four-category mapping (already-covered / strengthens-existing / genuinely-new / five-major-decisions-deferred). ADR 0019 candidate scoped for post-Phase-1, four Ring-0 entity additions queued, five trap seeds #31–#35 seeded, D-033 candidate queued (NOT in W3 batch), charter v1.3.0 invariant 18 candidate queued, **Q-003 pending added to DECISIONS.md** bundling five sub-decisions. Explicit discipline: the brief is highly aligned with existing HCS posture but committing to the three-layer architecture is a whole-system design commitment requiring deliberate consideration, not closeout-week silent adoption. |
| 1.1.0 | 2026-04-24 | Staged `2026-04-24-cloudflare-lessons.md` (external-control-plane automation brief from Cloudflare Stage 3a). Added Reconciled-conclusions subsection locking the queued integration matrix (ADR 0015 draft, 6 Ring-0 entity additions, 7 trap seeds #19–#25, D-032 candidate, v1.3.0 inv. 16 candidate, ADR 0012 broker-scope expansion). Added "What the reports do not cover" gaps list specific to the Cloudflare brief. |
| 1.0.0 | 2026-04-23 | Initial. Staged reports v1 + v2 of the substrate-config research series. README establishes the in-repo preservation pattern, status discipline, and update policy. |
