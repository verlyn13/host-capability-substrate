---
adr_number: 0019
title: HCS knowledge and coordination store
status: proposed
date: 2026-05-03
charter_version: 1.3.2
tags: [coordination, shared-state, retrieval, rag, knowledge-store, q-003, phase-1]
---

# ADR 0019: HCS knowledge and coordination store

## Status

proposed (v1)

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Context

The 2026-04-24 coordination-lessons brief
(`docs/host-capability-substrate/research/external/2026-04-24-coordination-lessons.md`)
synthesized a class of cross-session/cross-repo coordination failure
not currently covered by HCS's 20-entity Ring 0 ontology: an agent
treating prose documentation as authoritative state, mistaking a
detached worktree for a regression, asserting "all docs aligned"
without verification, and reading a multi-surface auth posture
(1Password CLI session, SSH-agent signing, `gh` keyring) as a single
state. The brief proposes a three-layer architecture and four new
Ring 0 entities to close the gap.

Q-003 is the deliberation row for that brief. The five sub-decisions
were settled in human review (2026-05-03):

- **(a) Timing.** ADR posture commitment in Phase 1; schema
  implementation deferred to Milestone 4 or later. Posture
  unblocks Q-008(d) (worktree-ownership composition) immediately.
- **(b) Entity relation.** All four new entities are peers of
  `Evidence` (Q-011 bucket 2: standalone Ring 0 entities), not
  subtypes. They reference `Evidence`; they don't extend it.
- **(c) `allowed_for_gate`.** First-class boolean field, kernel-set
  per registry v0.3.2 §Producer-vs-kernel-set authority fields.
  Producer-supplied values rejected at Layer 1 mint API.
- **(d) Promotion workflow.** Parallel track to `ApprovalGrant` in
  entity terms (different scope shape: facts vs operations);
  shared in infrastructure terms (typed `Decision` shape, audit-
  chain participation, Ring 1 mint API discipline).
- **(e) Charter inv. 18.** Promote to invariant in charter v1.3.x or
  v1.4.0 follow-up. Wording draft: *"Derived retrieval results are
  never decision authority. Gates consume only typed `Evidence` or
  `CoordinationFact` records with kernel-set `allowed_for_gate:
  true`."* Charter amendment lands per change-policy in a separate
  PR.

This ADR is doc-only and posture-only, mirroring the ADR 0029 / ADR
0030 acceptance pattern. It does not author Zod schema source, JSON
Schema, runtime probes, canonical policy YAML, dashboard routes, MCP
adapter contracts, embedding model commitments, or charter invariant
text. Schema implementation lands per
`.agents/skills/hcs-schema-change` once the ADR is accepted and
Milestone 4 reaches its schema-expansion window.

## Naming discipline

The naming discipline is binding throughout this ADR, the
`DECISIONS.md` ledger, downstream PRs, and agent guidance:

- **Use**: "evidence and coordination store" (canonical framing),
  "shared state" (cross-cutting concern), "knowledge index" /
  "retrieval index" (RAG layer), "coordination fact" (gateable
  state assertions), "derived summary" (agent-authored
  summaries).
- **Never**: "agent memory", "shared memory", "LLM memory",
  "persistent memory", "long-term memory", "context memory".

The "memory" framing carries LLM-industry connotations
("models store conclusions") that drift HCS away from its
authority-ranked posture. The four entities below name their
domain directly: knowledge source / chunk, coordination fact,
derived summary. None is "memory."

## Options considered

### Option A: Three-layer architecture with four new peer entities + promotion workflow (chosen)

**Pros:**
- Names all three layers explicitly: authoritative operational store
  (existing SQLite WAL, M3) + new coordination state + new derived
  retrieval index.
- Each layer has a typed Ring 0 entity boundary; cross-layer
  references go through `evidenceRefSchema` (already in use across
  ADR 0023 / 0025 / 0027 / 0028 / 0029 / 0030).
- The promotion workflow makes the producer/verifier asymmetry
  explicit: agents propose, verifiers promote.
- Closes the seven incident-derived patterns from the brief
  ("docs say Phase 6, live stack pre-Phase-1"; "checkout looked
  reverted"; "stale SSH aliases"; etc.) at the schema-shape layer.

**Cons:**
- Adds four new Ring 0 entities to the canonical entity list (current
  count expands from 20 to 24 plus `PromotionGrant`-class entity).
- Q-011 review-grammar bucket 2 entities require their own discriminator
  and lifecycle discipline.
- Multi-host deployment (Postgres/pgvector replacement for SQLite)
  remains deferred; ADR 0019 explicitly does not address.

### Option B: Single entity with kind discriminator covering all four cases

**Pros:**
- Smaller ontology surface (one entity vs four).

**Cons:**
- The four entity shapes are fundamentally different: `Evidence` is
  observation-shaped; `CoordinationFact` is subject/predicate/object-
  shaped; `DerivedSummary` is multi-source-aggregation-shaped;
  `KnowledgeSource`/`KnowledgeChunk` are document-content-shaped.
  Forcing them into one entity with a kind discriminator collapses
  semantically distinct facts into one type — exactly the failure
  mode registry §Sub-rule 5 was codified to prevent.
- A single-entity gate-eligibility rule would need branching logic on
  the discriminator; first-class typed peers carry the eligibility
  rule per-entity.

### Option C: Subtypes of Evidence

**Pros:**
- Inherits authority/freshness/provenance discipline directly.

**Cons:**
- Q-011 bucket 1 (Evidence subtype) requires the entity to be
  observation-shaped (subject + observed_at + authority +
  provenance). Three of the four entities are not observation-
  shaped:
  - `CoordinationFact` is an *assertion* about gateable state;
    its subject/predicate/object structure is closer to a triple
    store than to an observation.
  - `DerivedSummary` is an *aggregation*; its provenance is the
    multi-source set, not a single observation.
  - `KnowledgeSource` is a *document index entry*; it has a URI
    and content hash, not an observation timestamp.
  - `KnowledgeChunk` is a *derived chunk*; its provenance is the
    source's content hash, not an observation.
- Subtyping would force square-peg-round-hole field shapes on
  three of the four entities.

## Decision

Choose Option A. Q-003 commits a three-layer knowledge and
coordination store with four new peer Ring 0 entities, a typed
promotion workflow, kernel-set `allowed_for_gate` discipline, and a
charter inv. 18 candidate.

### Three-layer architecture

**Layer 1 — Authoritative operational store** (existing): the SQLite
WAL session ledger from ADR 0004 + D-003 + Milestone M3. Already
covered. ADR 0019 does not modify this layer. Operational state
(active sessions, leases, locks, runs, evidence records) lives here.

**Layer 2 — Coordination state layer** (NEW): typed gateable
assertions (`CoordinationFact`) with kernel-set `allowed_for_gate`
boolean and the agent-proposes / verifier-promotes workflow. This
is the layer that closes the brief's "release X.Y blocked until
producer.phase5.green" failure pattern: the gate state is a typed
fact with `evidence_ids` and a `valid_until` window, not prose.

**Layer 3 — Derived retrieval index** (NEW): `KnowledgeSource` and
`KnowledgeChunk` index canonical sources for retrieval (RAG queries,
keyword search, content-hash lookups). Retrieval results are *never*
decision authority. Per the inv. 18 candidate, gates consume only
typed `Evidence` or `CoordinationFact` records with kernel-set
`allowed_for_gate: true`.

The three layers compose (not substitute): a coordination fact
(Layer 2) cites evidence records (Layer 1) and may be discovered
through the retrieval index (Layer 3); the retrieval index never
replaces the typed fact.

### Four new Ring 0 entity sketches

All four are no-suffix Ring 0 entities (Q-011 bucket 2: standalone
entities with durable identity and lifecycle), per registry
§Naming suffix discipline. The `Fact` / `Summary` / `Source` /
`Chunk` strings are part of the entity-name root (descriptive
nouns naming the entity's domain), not suffixes. This matches
existing precedent for no-suffix entities like `Decision`,
`ApprovalGrant`, `Lease`, `Lock`, `SecretReference`.

The sketches below commit *shape* posture, not Zod schema source.
Field-name and discriminator details follow registry v0.3.3
discipline. Schema implementation lands per
`.agents/skills/hcs-schema-change` after acceptance.

#### `KnowledgeSource`

A canonical source registered in the retrieval index.

**Domain shape (illustrative):**

- `knowledge_source_id` — primary key.
- `uri` — canonical URI (file path, repo path, doc URL).
- `content_hash` — SHA-256 hash of source content at index time.
- `source_kind: "charter" | "adr" | "decision_ledger" | "runbook" |
  "vendor_doc" | "audit_summary" | "schema" | "code"` —
  discriminator per registry Sub-rule 6.
- `security_label: "public" | "internal" | "confidential" |
  "secret_referenced"` — discriminator; `secret_referenced` is
  required for any source containing `op://` references or
  similar credential placeholders.
- `indexable: bool` — whether this source is currently in the
  retrieval index. False for sources excluded by policy or
  awaiting ontology review.
- `indexed_at` — timestamp when the source was last indexed.
- Standard cross-context binding: `execution_context_id`,
  `target_refs`.

**Authority discipline:** `content_hash`, `indexed_at`,
`security_label` are kernel-set per registry v0.3.2 (authority-
class signals); `uri`, `source_kind`, `indexable` are
producer-asserted but kernel-verifiable.

#### `KnowledgeChunk`

A derived chunk from a `KnowledgeSource`.

**Domain shape (illustrative):**

- `knowledge_chunk_id` — primary key.
- `knowledge_source_id` — typed FK to `KnowledgeSource`.
- `chunk_index` — ordinal within the source.
- `text_hash` — SHA-256 of the chunk's text content.
- `heading_path` — array of heading strings down to the chunk
  (e.g., `["Charter v1.3.2", "Invariants", "Inv. 8"]`).
- `token_count` — token count under the canonical tokenizer.
- `embedding_ref` — reference to the embedding vector (storage
  shape deferred to follow-up ADR; the field is here for future-
  binding).
- `chunk_kind: "prose" | "code" | "schema_block" | "table" |
  "audit_record"` — discriminator per registry Sub-rule 6.
- `metadata` — open-record for indexing-side metadata; secret-
  shape scrubber applies (registry v0.3.0 §Field-level scrubber
  rule).

**Authority discipline:** `text_hash`, `chunk_index`,
`token_count`, `embedding_ref` are kernel-set; `heading_path`,
`chunk_kind`, `metadata` are producer-asserted but
kernel-verifiable.

**`allowed_for_gate` rule:** `KnowledgeChunk` carries no
`allowed_for_gate` field because retrieval results are never
gate authority per the inv. 18 candidate. Consumer code that
treats a chunk as gate authority is a charter violation.

#### `CoordinationFact`

A typed gateable assertion about cross-session/cross-repo state.

**Domain shape (illustrative):**

- `coordination_fact_id` — primary key.
- `subject` — typed string identifying the coordination subject
  (e.g., `"release:runpod-stage3a-2026-04-24"`,
  `"branch:main:host-capability-substrate"`).
- `predicate` — typed string naming the assertion
  (e.g., `"gate.phase4_dry_run"`, `"blocked_until"`,
  `"depends_on"`).
- `object_kind: "status_block" | "dependency" | "gate_token" |
  "scoped_assertion"` — discriminator per registry Sub-rule 6.
- `object` — structured object whose shape is selected by
  `object_kind` (sibling-array pattern per registry Sub-rule 5).
- `evidence_ids` — array of `evidenceRefSchema` references to
  supporting `Evidence` records. Cannot be empty; an assertion
  without component evidence is rejected at Layer 1 mint API.
- `authority` — registry v0.3.0 ladder; cannot be `self-asserted`
  (a self-asserted coordination fact is structurally undefined per
  inv. 8).
- `confidence` — `evidence_kind`-aligned (`receipt`, `observation`,
  `derived`).
- `valid_until` — freshness anchor; gateway re-derives at
  decision time per registry v0.3.2 §Cross-context enforcement
  layer Layer 3.
- `allowed_for_gate: bool` — kernel-set per registry v0.3.2;
  producer-supplied values rejected at Layer 1 mint API. False
  until promoted via the promotion workflow.
- `promoted_at` — kernel-set timestamp when `allowed_for_gate`
  flipped from false to true; null when `allowed_for_gate`
  is false.
- `promotion_grant_id` — kernel-set FK to the typed grant that
  authorized the promotion; null when `allowed_for_gate` is false.
- Standard cross-context binding: `execution_context_id`,
  `target_refs`.

**`allowed_for_gate` semantics:**

- A coordination fact is created with `allowed_for_gate: false`.
  Gates that consume it at this state will reject (the gate's
  Decision cites `Decision.reason_kind:
  coordination_fact_unpromoted`).
- The promotion workflow (described below) authorizes the flip
  to `true`. The flip is itself a typed `Decision` recording the
  authority claim; the audit chain participates per registry
  v0.3.1 §Audit-chain coverage of rejections (extends to
  promotions by inheritance).
- Once `allowed_for_gate: true`, the fact is gate-eligible until
  `valid_until` expires. After expiry, gateway re-derive at
  Layer 3 fails the binding; the fact must be re-promoted with
  fresh component evidence.

#### `DerivedSummary`

An agent-authored summary aggregating multiple sources.

**Domain shape (illustrative):**

- `derived_summary_id` — primary key.
- `derived_from` — array of `evidenceRefSchema` references to
  source `Evidence` / `CoordinationFact` / `KnowledgeChunk`
  records.
- `generated_by` — producer reference (kernel-set per registry
  v0.3.2 when value names a kernel-trusted producer class).
- `generated_at` — timestamp.
- `summary_kind: "intervention_summary" | "closeout_narrative" |
  "release_summary" | "audit_summary" | "operational_summary"` —
  discriminator per registry Sub-rule 6.
- `summary_text` — the agent-authored narrative; secret-shape
  scrubber applies.
- `authority: "derived"` — fixed at this class per the entity's
  lifecycle (registry v0.3.0 ladder).
- `confidence: "best-effort"` — fixed; agent-authored summaries
  do not carry stronger confidence claims.
- `allowed_for_gate: bool` — kernel-set; **starts at false**;
  flips to true only after promotion via the promotion workflow.
- `promoted_at`, `promotion_grant_id` — same shape as
  `CoordinationFact`.
- Standard cross-context binding.

**`allowed_for_gate` discipline:** unpromoted derived summaries
are NOT gate authority. This generalizes the inv. 8
sandbox-observation non-promotion pattern to agent-authored
aggregation. A gate consuming an unpromoted summary rejects with
`Decision.reason_kind: derived_summary_unpromoted`.

### Promotion workflow shape

The promotion workflow is a typed grant pattern, parallel to
`ApprovalGrant` per Q-003(d) sub-decision.

**Workflow shape:**

1. **Candidate authorship** — an agent (or verifier candidate)
   creates a `CoordinationFact` or `DerivedSummary` with
   `allowed_for_gate: false`. The Ring 1 mint API accepts the
   record at this state per registry v0.3.0 §Cross-context
   enforcement layer (the record's `execution_context_id` must
   resolve consistently).
2. **Verification** — a verifier (a session with verifier-class
   privileges; specifics defer to canonical policy per Milestone
   2) inspects the candidate's `evidence_ids` / `derived_from`
   against live state. The verifier's verification is itself a
   typed `Evidence` record (e.g.,
   `VerificationReceipt` — name reserved for follow-up ADR;
   stage-2 verification entity not committed by this ADR).
3. **Promotion grant** — the verifier mints a typed promotion
   grant binding the candidate's `evidence_id` + verifier
   identity + verification evidence. The grant's entity name is
   reserved for follow-up schema PR (candidate names:
   `PromotionGrant`, `CoordinationGrant`, `VerificationGrant`;
   final selection per ontology review).
4. **Promotion event** — Ring 1 mint API consumes the grant and
   flips the candidate's `allowed_for_gate: false → true`,
   sets `promoted_at` and `promotion_grant_id`, and emits a
   typed `Decision` recording the promotion in the audit chain.

**Shared infrastructure with `ApprovalGrant`:**

- Typed `Decision` shape with `reason_kind` /
  `required_grant_kind` discriminators per registry v0.3.3
  Sub-rule 6.
- Audit-chain participation per registry v0.3.1 §Audit-chain
  coverage of rejections (extends to promotions by inheritance).
- Ring 1 mint API enforcement at Layer 1; broker FSM and
  gateway re-check at Layers 2 and 3 per registry v0.3.2
  §Cross-context enforcement layer.

**Differences from `ApprovalGrant`:**

- `ApprovalGrant` scopes *operations* (operation_class +
  execution_context_id + target_ref + per-class extensions per
  ADR 0029 v2 §`ApprovalGrant.scope` shape sketch).
- Promotion grants scope *facts* (candidate evidence_id + verifier
  identity + verification evidence_ids + scoped fact-classes).
- `ApprovalGrant` is single-use per operation invocation; promotion
  grants are single-use per fact-promotion event.

### Cross-context binding rules per Ring 1 layer

Per registry v0.3.0 §Cross-context enforcement layer requirement:

- **`KnowledgeSource`**: Layer 1 enforces `uri` + `content_hash`
  consistency with `ExecutionContext`; Layer 2 re-checks
  `indexable` flag at retrieval time; Layer 3 re-derives.
- **`KnowledgeChunk`**: Layer 1 enforces `knowledge_source_id`
  resolution within the same `execution_context_id`; Layer 2
  re-checks `text_hash` against the source's current content;
  Layer 3 rejects retrieval results that fail the
  freshness check.
- **`CoordinationFact`**: Layer 1 enforces `evidence_ids`
  consistency (each cited Evidence must share the
  `execution_context_id` or carry an explicit cross-context
  reference per future Q-003 amendment); Layer 2 re-checks
  `allowed_for_gate` and `valid_until` at operation-execution
  time; Layer 3 re-derives at decision time.
  Producer-supplied `allowed_for_gate` rejected at Layer 1.
- **`DerivedSummary`**: Layer 1 enforces `derived_from`
  consistency and `authority: "derived"` fixity (any other value
  rejected); Layer 2 re-checks `allowed_for_gate` and
  `promoted_at` freshness; Layer 3 re-derives.

### Authority discipline

Authority-class signals across the four entities follow registry
v0.3.2 §Producer-vs-kernel-set discipline:

- **Kernel-set**: `content_hash`, `indexed_at`, `security_label`
  (KnowledgeSource); `text_hash`, `chunk_index`, `token_count`,
  `embedding_ref` (KnowledgeChunk); `allowed_for_gate`,
  `promoted_at`, `promotion_grant_id` (CoordinationFact +
  DerivedSummary); `generated_by` when value names a
  kernel-trusted producer class (DerivedSummary).
- **Producer-asserted, kernel-verifiable**: `uri`, `source_kind`,
  `indexable` (KnowledgeSource); `heading_path`, `chunk_kind`,
  `metadata` (KnowledgeChunk); `subject`, `predicate`,
  `object_kind`, `object`, `evidence_ids`, `valid_until`
  (CoordinationFact); `derived_from`, `summary_kind`,
  `summary_text` (DerivedSummary).
- **Fixed at construction**: `authority: "derived"` and
  `confidence: "best-effort"` on DerivedSummary.

### `Decision.reason_kind` reservations

New rejection classes reserved (posture-only; schema enum lands
per `.agents/skills/hcs-schema-change`):

- `coordination_fact_unpromoted` — gate consumed a coordination
  fact with `allowed_for_gate: false`.
- `coordination_fact_expired` — `valid_until` passed at
  Layer 2/3 re-check.
- `coordination_fact_evidence_drift` — cited `evidence_ids` no
  longer match live state at re-check.
- `derived_summary_unpromoted` — gate consumed a derived summary
  with `allowed_for_gate: false`.
- `knowledge_chunk_used_as_gate_authority` — operation cited a
  retrieval-derived chunk as gate evidence (charter inv. 18
  candidate violation).
- `knowledge_source_content_drift` — `content_hash` mismatch
  detected at retrieval time.
- `promotion_grant_scope_mismatch` — promotion grant's bound
  evidence_id does not match the candidate's id at promotion
  consumption.

`Decision.required_grant_kind` reservations:

- `coordination_promotion` — promotion grant for a
  `CoordinationFact`.
- `summary_promotion` — promotion grant for a `DerivedSummary`.

### Charter inv. 18 candidate

The "RAG may discover; only typed evidence may decide" rule is
proposed as charter invariant 18:

> **Inv. 18 (candidate, v1.3.x or v1.4.0).** Derived retrieval
> results — `KnowledgeChunk` records, RAG-retrieved content,
> agent-authored summaries before promotion, query-derived
> knowledge fragments — are never decision authority. Gates
> consume only typed `Evidence` or promoted `CoordinationFact` /
> `DerivedSummary` records with kernel-set `allowed_for_gate:
> true`. Producer-supplied or retrieval-derived gate-eligibility
> claims are rejected at the mint API.

The charter amendment lands per change-policy in a separate PR
(this ADR does not modify the charter). The wording above is a
candidate; the actual amendment ADR (numbered after current ADR
0024 charter wave-2/3) will refine.

### Interaction edges parked for future work

The following interactions are flagged but NOT committed by this
ADR:

- **`CoordinationFact` ↔ `Lease`** — both can represent "this is
  blocked until X." A worktree lease has its own gateable shape;
  a `CoordinationFact` can also assert "branch-X blocked until
  release-Y." The boundary between them is not yet committed.
  Q-003(b) sub-question.
- **`DerivedSummary` ↔ provenance hardening** — the
  `derived_from` array can include unpromoted summaries
  recursively. The recursion depth limit and cycle-detection
  rules are not committed.
- **Multi-host deployment** — Postgres/pgvector replacement for
  SQLite WAL is deferred until HCS goes multi-host or
  multi-writer. Explicit per the brief.
- **Failure modes for retrieval index** — stale chunks, source
  hash mismatches, content-hash rolling — future work.

### Out of scope

This ADR does not authorize:

- Zod schema source for any of the four entities. Schema
  implementation lands per `.agents/skills/hcs-schema-change`
  after acceptance and Milestone 4.
- `evidenceSubjectKindSchema` enum extension for any new subject
  kinds (`knowledge_source`, `knowledge_chunk`,
  `coordination_fact`, `derived_summary`). Extensions land with
  the schema PR.
- `Decision.reason_kind` / `Decision.required_grant_kind` enum
  extensions. Posture only.
- Embedding model commitment, embedding dimensions, re-indexing
  triggers, retrieval tuning. Follow-up ADR.
- Dashboard views (`/evidence`, `/coordination`, `/knowledge`,
  `/interventions`, `/reconciliation`). Separate dashboard ADR.
- MCP surface (Resources `hcs://...`, Tools `system.*`,
  Prompts). Separate adapter ADR.
- The promotion-grant entity name. Reserved for follow-up
  ontology review.
- Charter invariant text. The inv. 18 wording is a candidate;
  the actual charter amendment lands per change-policy in a
  separate PR.
- Canonical policy YAML at
  `system-config/policies/host-capability-substrate/`. Promotion-
  grant verifier-class privileges, retention windows for
  unpromoted candidates, and similar canonical-policy concerns
  land at HCS Milestone 2.
- Multi-host coordination-store deployment. Postgres/pgvector
  deferred per the brief.
- Q-008(d) worktree-ownership composition rules. Q-008(d) gates
  on Q-003 *posture*, which this ADR commits; the actual
  composition between `WorkspaceContext` / `Lease` / `CoordinationFact`
  continues under Q-008(d).

## Consequences

### Accepts

- Q-003 is settled at the design layer with the three-layer
  knowledge and coordination store: authoritative operational
  store (existing) + coordination state layer (NEW) + derived
  retrieval index (NEW).
- Four new Ring 0 entities reserved as no-suffix peers of
  `Evidence` (Q-011 bucket 2): `KnowledgeSource`,
  `KnowledgeChunk`, `CoordinationFact`, `DerivedSummary`.
- The promotion workflow is a typed grant pattern parallel to
  `ApprovalGrant` (different scope shape: facts vs operations;
  shared typed Decision + audit-chain infrastructure).
- `allowed_for_gate` is a first-class kernel-set boolean field on
  `CoordinationFact` and `DerivedSummary`; producer-supplied
  values rejected at Layer 1 mint API; starts false; flips true
  only via the promotion workflow.
- Cross-context binding rules are explicit per Ring 1 layer
  (mint API / broker FSM / gateway) per registry v0.3.0
  requirement.
- Authority-class signals follow registry v0.3.2 §Producer-vs-
  kernel-set discipline: `content_hash`, `indexed_at`,
  `security_label`, `text_hash`, `chunk_index`, `token_count`,
  `embedding_ref`, `allowed_for_gate`, `promoted_at`,
  `promotion_grant_id`, kernel-set `generated_by` are all
  kernel-set.
- Seven new `Decision.reason_kind` rejection-class names reserved
  (posture-only): `coordination_fact_unpromoted`,
  `coordination_fact_expired`, `coordination_fact_evidence_drift`,
  `derived_summary_unpromoted`,
  `knowledge_chunk_used_as_gate_authority`,
  `knowledge_source_content_drift`,
  `promotion_grant_scope_mismatch`.
- Two new `Decision.required_grant_kind` reservations
  (posture-only): `coordination_promotion`, `summary_promotion`.
- Naming discipline is binding: "evidence and coordination
  store," "shared state," "knowledge index," "coordination
  fact," "derived summary." Never "memory."
- Charter inv. 18 candidate is queued for charter v1.3.x or
  v1.4.0 follow-up. Charter amendment lands per change-policy in
  a separate PR.
- Q-008(d) worktree-ownership composition is unblocked at the
  posture layer (the `CoordinationFact` shape is now committed;
  Q-008(d) can compose against it).

### Rejects

- Single-entity-with-kind-discriminator covering all four cases
  (Option B). Collapsing semantically distinct facts into one
  type violates registry §Sub-rule 5.
- Subtypes of `Evidence` for the four new entities (Option C).
  Three of the four are not observation-shaped; subtyping forces
  square-peg-round-hole.
- Producer-supplied `allowed_for_gate` values. Kernel-set only;
  rejected at Layer 1 mint API.
- Treating `KnowledgeChunk` records or unpromoted
  `DerivedSummary` records as gate authority. Charter inv. 18
  candidate violation.
- "Memory" framing in any HCS naming. The brief is explicit; this
  ADR codifies the discipline.
- Hosted vector stores (third-party SaaS RAG providers) for
  private runtime state. Per the brief and charter inv. 10
  (runtime state outside repo, on-host).
- Reusing `ApprovalGrant` for fact-promotion. Different scope
  shape; parallel track per Q-003(d).
- Self-asserted authority on `CoordinationFact`. Structurally
  undefined per inv. 8.

### Future amendments

- Charter inv. 18 amendment (separate PR per change-policy).
- Schema implementation PR (per `.agents/skills/hcs-schema-change`)
  for the four entities + the promotion-grant entity (name
  selected at that time).
- Follow-up ADR for embedding model commitment, dimensions,
  re-indexing triggers, retrieval tuning.
- Follow-up dashboard ADR for `/evidence`, `/coordination`,
  `/knowledge`, `/interventions`, `/reconciliation` views.
- Follow-up adapter ADR for MCP Resources / Tools / Prompts
  surface.
- Q-008(d) ADR closing worktree-ownership composition with
  `WorkspaceContext` / `Lease` / `CoordinationFact`.
- Multi-host deployment ADR (Postgres/pgvector) when HCS
  outgrows single-host SQLite.
- `CoordinationFact` ↔ `Lease` interaction-edge ADR (parked).
- `DerivedSummary` recursion depth + cycle-detection ADR
  (parked).
- Reopen if a future incident shows the four-entity coverage
  misses a class of failure or the promotion workflow over-
  blocks legitimate flows.

## References

### Internal

- Charter:
  `docs/host-capability-substrate/implementation-charter.md` v1.3.2,
  invariants 1, 4, 5, 6, 7, 8, 10, 16, 17 (and v1.3.x or v1.4.0
  candidate inv. 18)
- Ontology registry:
  `docs/host-capability-substrate/ontology-registry.md` v0.3.3
  (Naming suffix discipline including no-suffix entity precedent;
  Authority discipline including Producer-vs-kernel-set;
  Cross-context enforcement layer including layer-disagreement
  tiebreaker and audit-chain coverage of rejections; Redaction
  posture)
- Decision ledger: `DECISIONS.md` Q-003, Q-008
- Coordination-lessons brief:
  `docs/host-capability-substrate/research/external/2026-04-24-coordination-lessons.md`
- ADR 0004:
  `docs/host-capability-substrate/adr/0004-session-ledger.md`
  (SQLite WAL session ledger; Layer 1 of the three-layer
  architecture)
- ADR 0023:
  `docs/host-capability-substrate/adr/0023-evidence-base-shape.md`
  (`Evidence` base contract; the four new entities are peers,
  not subtypes; cross-context references go through
  `evidenceRefSchema`)
- ADR 0025:
  `docs/host-capability-substrate/adr/0025-branch-deletion-proof.md`
  (BranchDeletionProof composite; future composition with
  `CoordinationFact` for branch-protection coordination state)
- ADR 0028:
  `docs/host-capability-substrate/adr/0028-q-008-a-execution-mode-receipts.md`
  (`self-asserted` authority class; CoordinationFact rejects)
- ADR 0029:
  `docs/host-capability-substrate/adr/0029-q-008-b-anomalous-capture-blocking-thresholds.md`
  (`ApprovalGrant.scope` shape sketch; promotion workflow
  parallels but does not reuse)
- ADR 0030:
  `docs/host-capability-substrate/adr/0030-q-006-stage-2-source-control-evidence-subtypes.md`
  (per-receipt Ring 1 layer assignment pattern; ADR 0019 mirrors)
- D-003, D-018, D-020, D-025, D-026, D-028 (decision ledger
  entries cited by the brief)
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- LangGraph persistence taxonomy
  (architectural pattern reference cited in the brief):
  <https://langchain-ai.github.io/langgraph/concepts/persistence/>
- MCP specification 2025-11-25 (Resources / Tools / Prompts
  surface, cited for follow-up adapter ADR):
  <https://spec.modelcontextprotocol.io/specification/2025-11-25/>
- OpenAI file-search tool documentation (cited for the
  retrieval-as-discovery, not-as-decision pattern):
  <https://platform.openai.com/docs/guides/tools-file-search>
