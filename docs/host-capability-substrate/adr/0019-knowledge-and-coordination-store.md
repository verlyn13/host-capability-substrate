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

proposed (v3)

## Date

2026-05-03

## Charter version

Written against charter v1.3.2 and
`docs/host-capability-substrate/ontology-registry.md` v0.3.3.

## Revision history

- **v1** (2026-05-03, commit `e16d270`): initial draft. Reviewers
  surfaced 8 blocking findings (1 ontology, 3 policy, 4 security)
  plus ~14 non-blocking concerns.
- **v2** (2026-05-03, this revision): closes all 8 blockers and
  folds 12 consolidated non-blocking observations.
  - **Ontology B1.** Restructured `CoordinationFact` to replace
    bare `subject` / `predicate` strings with `subject_kind`
    discriminator + `subject_ref` polymorphic FK + ontology-
    controlled `predicate_kind` closed enum (deferred to follow-up
    registry entry).
  - **Ontology N7.** Renamed `evidence_ids` → `evidence_refs`
    throughout (per registry §Field-name suffixes Sub-rule 4:
    `_id` reserved for typed FK; `evidenceRefSchema` arrays use
    `_refs`). Same class as ADR 0030's B1 fix.
  - **Policy B1.** Added §Verifier visibility-authority rule:
    verifier session must have read authority over every Evidence
    record cited in `evidence_refs` (and transitively in
    `derived_from`) at promotion grant mint time.
  - **Policy B2.** Tightened charter inv. 18 candidate text to
    forbid promotion when `derived_from` graph contains any
    record with `allowed_for_gate: false`. Added §DerivedSummary
    chain promotion rule.
  - **Policy B3.** Added §Closed-list fail-mode subsection
    mirroring ADR 0029 v2 pattern (tightening default for
    unrecognized rejection classes).
  - **Security B-1.** Added §Secret-referenced sources subsection:
    chunks from secret_referenced source carry the same
    `security_label` (label propagation); `KnowledgeChunk.text_hash`
    computed over reference-form content only; chunker
    materializing resolved `op://` value fails Layer 1 mint with
    new `secret_resolution_in_chunk` reason_kind.
  - **Security B-2.** Added embedding-eligibility rule:
    `KnowledgeChunk.embedding_ref` is null when parent source's
    `security_label == "secret_referenced"`; embedding job
    refuses to vectorize such content (closes embedding-inversion
    side-channel).
  - **Security B-3.** Added §Promotion audit-record completeness
    subsection naming explicit fields: candidate `evidence_id`,
    verifier `agent_client_id` + `session_id`, all
    `verification_evidence_refs`, promoting layer, resulting
    `promotion_grant_id`.
  - **Security B-4.** Bound verifier identity to `agent_client_id`
    + `session_id` per registry v0.3.1 §Audit-chain coverage of
    rejections canonical attribution fields.
  - **Architect N-1.** Added explicit Layer 3 retrieval-index
    indexer Ring 1 placement: indexer is a Ring 1 service; MCP /
    dashboard exposure is Ring 2.
  - **Architect N-2.** Added rationale for `valid_until`
    producer-asserted classification on `CoordinationFact`.
  - **Ontology N6.** Added explicit note that `evidence_refs`
    polymorphism over expanding subject-kind enum is intentional
    and absorbed by `evidenceRefSchema`.
  - **Policy N1.** Forward-look note on producer-equals-verifier
    separation-of-duties rule (canonical policy at Milestone 2).
  - **Policy N2.** Promotion-grant scope keys disjoint from
    `ApprovalGrant.scope` per-class extension keys.
  - **Policy N3.** Rejection-class discriminator identical
    across all three Ring 1 layers.
  - **Security N-1.** Cite charter inv. 8 explicitly: sandbox-
    observation authority blocks promotion.
  - **Security N-3.** Chunks display-only; chunk-to-command
    rendering forbidden.
  - **Security N-4.** Cross-context evidence chain default to
    strict (cross-context references require explicit Q-003
    follow-up amendment).
  - **Security N-5.** Cite charter inv. 10 deployment boundary
    explicitly (single-host posture; runtime state under
    `~/Library/Application Support/host-capability-substrate/`).
- **v3** (2026-05-03, this revision): closes 2 new security
  blockers introduced by v2's §Secret-referenced sources design
  + folds 4 security non-blocking observations + adds ontology
  registry reservation note.
  - **Security S-1.** Added re-indexing label-recheck rule:
    when `KnowledgeSource.content_hash` changes, the indexer
    recomputes `security_label` against the new content; chunks
    derived from the prior content_hash are marked stale and
    re-derived against the new content + new label.
  - **Security S-2.** Added label-upgrade chunk-invalidation
    rule: when `security_label` is upgraded to
    `secret_referenced` (e.g., indexer detected new `op://`
    content), all child chunks with non-null `embedding_ref`
    are purged or re-minted with `embedding_ref: null`.
    Closes the inv. 5 + inv. 8 composition gap.
  - **Security N-1.** Made explicit that §Verifier visibility-
    authority rule scopes read-authority to the minting session
    only, not transitively across the verifier's session graph
    (prevents verifier-session-aggregation escalation surface).
  - **Security N-2.** Added `promoted_at` to the §Promotion
    audit-record completeness field list (now seven fields, not
    six). Audit consumers reconstructing promotion timelines
    need the timestamp.
  - **Security N-3.** Tightened §Chunks display-only rule to
    forbid all paths where chunk content reaches typed records
    consumed by gates, including prompt-rendering paths an LLM
    might parse into operations.
  - **Security N-4.** Added explicit deployment-binding for
    `embedding_ref`: resolves only to on-host vector storage
    under `$HCS_STATE_DIR`; remote/hosted backends require ADR
    amendment.
  - **Ontology NB-1.** Added §Predicate-kind registry
    reservation note: ADR 0019 reserves the registry section
    name `§Predicate-kind vocabulary` paralleling §Boundary
    dimension registry; the registry entry lands in a separate
    registry update PR before the schema PR using
    `predicate_kind` is opened.

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
fact with `evidence_refs` and a `valid_until` window, not prose.

**Layer 3 — Derived retrieval index** (NEW): `KnowledgeSource` and
`KnowledgeChunk` index canonical sources for retrieval (RAG queries,
keyword search, content-hash lookups). The Layer 3 indexer runs as
a Ring 1 service against Ring 0 `KnowledgeSource` / `KnowledgeChunk`
records; MCP and dashboard exposure of retrieval results is Ring 2
per charter inv. 1. Retrieval results are *never* decision
authority. Per the inv. 18 candidate, gates consume only typed
`Evidence` or `CoordinationFact` records with kernel-set
`allowed_for_gate: true`.

The three layers compose (not substitute): a coordination fact
(Layer 2) cites evidence records (Layer 1) and may be discovered
through the retrieval index (Layer 3); the retrieval index never
replaces the typed fact.

**Deployment boundary.** Per charter inv. 10, the three layers run
on-host (single-host posture for Phase 1), with runtime state under
`~/Library/Application Support/host-capability-substrate/` and
`~/Library/Logs/host-capability-substrate/`, NOT in the repo. Hosted
vector stores (third-party SaaS RAG providers) are explicitly
rejected for private runtime state. Multi-host (Postgres/pgvector)
deployment is deferred until HCS goes multi-host or multi-writer; the
Phase 1 single-host SQLite WAL boundary is load-bearing.

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

**Secret-referenced sources (charter inv. 5):**

A source classified `security_label: "secret_referenced"` indexes
content that contains `op://` references or similar credential
placeholders. The following rules apply at all three Ring 1
layers:

- **Label propagation.** `KnowledgeChunk` records derived from a
  `secret_referenced` source carry the same `security_label`.
  Producer-supplied chunk labels diverging from the source label
  are rejected at Layer 1 mint API.
- **Reference-form-only chunking.** `KnowledgeChunk.text_hash` is
  computed over content in reference form (`op://Vault/Item/field`
  preserved as a literal string). A chunker that resolves an
  `op://` placeholder to its secret value before chunking fails
  Layer 1 mint with `Decision.reason_kind:
  secret_resolution_in_chunk`.
- **Embedding-eligibility (closes embedding-inversion side-
  channel).** `KnowledgeChunk.embedding_ref` is null when the
  parent source's `security_label == "secret_referenced"`. The
  embedding job refuses to vectorize such content; Layer 1 mint
  rejects any `KnowledgeChunk` with a non-null `embedding_ref`
  whose parent source carries the secret_referenced label. This
  closes the side-channel where embedding inversion or nearest-
  neighbor probing could leak secret-bearing content even when
  the index never persists the plaintext.
- **No raw secrets in chunks (charter inv. 5).** A
  `KnowledgeChunk` whose text matches secret-shaped patterns
  (per registry v0.3.0 §Field-level scrubber rule) is rejected
  at Layer 1 mint API regardless of the parent source's
  security_label, because secret material in a chunk is itself
  a charter inv. 5 violation.
- **Re-indexing label-recheck.** When a `KnowledgeSource`'s
  `content_hash` changes (the source's content shifts because
  the underlying file/doc was edited), the indexer recomputes
  `security_label` against the new content. The prior
  `KnowledgeChunk` records are marked stale (their `text_hash`
  no longer matches the source's current `content_hash` per
  the existing Layer 2 freshness re-check) and re-derived
  against the new content, with the new `security_label`
  applied to the new chunks. Stale chunks are purged from the
  retrieval index at re-derive time; pre-purge retrieval
  results are not gate-eligible per inv. 18 candidate.
- **Label-upgrade chunk-invalidation.** When a
  `KnowledgeSource.security_label` is upgraded to
  `secret_referenced` (whether via a re-index detecting newly
  added `op://` content, a manual policy reclassification, or
  any other path), **all existing child `KnowledgeChunk`
  records with non-null `embedding_ref` are purged from the
  retrieval index and re-minted with `embedding_ref: null`**.
  The kernel-side indexer enforces this at Layer 1 at the
  moment the label upgrade is committed; chunks minted before
  the upgrade with non-null embeddings cannot persist past
  the upgrade. Without this rule, secret-bearing embeddings
  would persist after correct re-classification, creating an
  inv. 5 + inv. 8 composition gap (the source's authority is
  correctly tightened, but the derived embedding leaks back).
  Label downgrades (e.g., `secret_referenced` → `internal`
  because the `op://` references were removed) do NOT
  retroactively re-embed prior chunks; downgrade requires a
  full re-index pass from fresh content.

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
  binding). **Deployment binding (charter inv. 10):**
  `embedding_ref` resolves only to on-host vector storage under
  `$HCS_STATE_DIR` (defaulting to
  `~/Library/Application Support/host-capability-substrate/`).
  Remote / hosted vector backends (e.g., Pinecone, Weaviate
  cloud, hosted pgvector) require a separate ADR amendment per
  charter change-policy. Multi-host deployment with on-host
  pgvector remains queued for the multi-host ADR named in
  §Future amendments.
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

**Chunks are display-only.** Chunk content (text, code blocks,
schema fragments) may be rendered for human review through Ring
2 dashboard / MCP surfaces. Chunk-to-command rendering is
forbidden: **no chunk content may reach any path that produces
typed records consumed by gates.** This includes:

- direct chunk-to-`OperationShape` materialization (an adapter
  copying chunk text into operation arguments);
- chunk-to-`ApprovalGrant.scope` injection;
- chunk-to-prompt rendering where an LLM might parse the chunk
  into a tool call, operation request, or grant scope (the
  indirection through an LLM does not break the rule — the
  chunk reached the gate-record-producing pipeline);
- any rendering that produces a typed input to a Ring 1 mint
  API call.

Allowed rendering surfaces: dashboard display to a human
reviewer; MCP `Resources` payloads explicitly tagged as
display-only; transcript inclusion for human inspection.
Charter inv. 1 / inv. 2 violations are the failure mode this
rule prevents; the typed-evidence pathway (mint API → Ring 0
record → gate consumption) is the only path.

#### `CoordinationFact`

A typed gateable assertion about cross-session/cross-repo state.

**Domain shape (illustrative):**

- `coordination_fact_id` — primary key.
- `subject_kind: "release" | "branch" | "worktree" |
  "ruleset" | "credential_audience" | "deployment" |
  "external_target"` — discriminator per registry Sub-rule 6.
  Names what kind of subject the assertion is about. The list
  is closed for stage-1 acceptance; new values require an
  ontology-controlled vocabulary update (see §`predicate_kind`
  ontology vocabulary below).
- `subject_ref` — polymorphic typed FK per registry Sub-rule 5
  (the `<thing>_ref` pattern from `BoundaryObservation.tool_or_provider_ref`).
  Resolves to a Ring 0 entity selected by `subject_kind`
  (e.g., when `subject_kind == "release"`, `subject_ref` is a
  release identifier; when `subject_kind == "branch"`,
  `subject_ref` is a `(repository_id, branch_ref)` pair). The
  schema PR commits the per-kind reference shape per
  `.agents/skills/hcs-schema-change`.
- `predicate_kind` — discriminator naming the assertion type.
  This is an ontology-controlled closed enum reserved for a
  follow-up ontology-registry entry; the registry entry must
  enumerate every `predicate_kind` value the canonical policy
  recognizes (candidate values: `blocked_until`, `depends_on`,
  `gate_token`, `phase_lock`, `release_phase`, `scope_assertion`).
  Until the registry entry lands, schema-side `predicate_kind`
  enum is empty and `CoordinationFact` cannot be minted; this
  ADR commits the shape, not the vocabulary. **Registry section
  name reserved.** ADR 0019 reserves the registry section name
  `§Predicate-kind vocabulary` (paralleling
  `ontology-registry.md` §Boundary dimension registry from ADR
  0022) for the follow-up registry update PR. Per registry
  §Adding a new suffix or convention, the registry update lands
  before any schema PR using `predicate_kind`. The follow-up
  registry update PR is a precondition for `CoordinationFact`
  schema implementation per `.agents/skills/hcs-schema-change`.
- `object_kind: "status_block" | "dependency" | "gate_token" |
  "scoped_assertion"` — discriminator per registry Sub-rule 6.
- `object` — structured object whose shape is selected by
  `object_kind` (sibling-discriminator pattern per registry
  Sub-rule 5).
- `evidence_refs` — array of `evidenceRefSchema` references to
  supporting `Evidence` records (renamed from v1's
  `evidence_ids` per registry §Field-name suffixes Sub-rule 4).
  Cannot be empty; an assertion without component evidence is
  rejected at Layer 1 mint API. Polymorphism over the expanding
  `evidenceSubjectKindSchema` enum (e.g., future stage-2
  receipts adding `git_worktree`, `pull_request`, etc.) is
  intentional and absorbed by `evidenceRefSchema`; no
  per-subject-kind extension to `CoordinationFact` is required.
- `authority` — registry v0.3.0 ladder; cannot be `self-asserted`
  per charter inv. 8 (a self-asserted coordination fact is
  structurally undefined). Cannot be `sandbox-observation`
  promoted to a stronger class (inv. 8 forbids promotion);
  sandbox-derived facts can be minted with
  `authority: sandbox-observation` but cannot be promoted via
  the promotion workflow per §Promotion workflow shape rule
  below.
- `confidence` — `evidence_kind`-aligned (`receipt`, `observation`,
  `derived`).
- `valid_until` — freshness anchor; producer-asserted at mint
  time, kernel-verifiable. Producer asserts the candidate
  freshness window; the kernel may shorten at promotion time per
  canonical policy at Milestone 2 (canonical policy may impose
  per-`predicate_kind` maximum windows). Gateway re-derives at
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

**Chain promotion rule (closes promotion-laundering surface):**

A `DerivedSummary` whose `derived_from` array contains *any*
record (transitively) with `allowed_for_gate: false` cannot itself
be promoted. The Layer 1 mint API rejects promotion grants whose
candidate's `derived_from` graph contains:

- an unpromoted `DerivedSummary` at any depth,
- an unpromoted `CoordinationFact` at any depth,
- an `Evidence` record with `authority: sandbox-observation` or
  `authority: self-asserted` (per inv. 8),
- a `KnowledgeChunk` (per the inv. 18 candidate; retrieval-derived
  content is never gate authority).

This closes the promotion-laundering surface where summary A
cites unpromoted summary B in `derived_from`; promoting A would
not re-walk B's `allowed_for_gate: false`. The chain rule
forbids the promotion outright; B must be promoted first
(itself bottoming out in promoted facts or `evidence_kind:
receipt | observation` records with sufficient authority).

The Layer 1 enforcement is graph-walk-shaped; the broker FSM
re-checks at Layer 2 if intermediate links flip during the gap
window. The gateway re-derive at Layer 3 is the authoritative
non-escalable cycle per inv. 6.

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
   2) inspects the candidate's `evidence_refs` / `derived_from`
   against live state. The verifier's verification is itself a
   typed `Evidence` record (e.g.,
   `VerificationReceipt` — name reserved for follow-up ADR;
   stage-2 verification entity not committed by this ADR).
   Verification rejects candidates whose evidence chain
   terminates in `Evidence.authority: sandbox-observation` or
   `self-asserted` for the gate dimension being asserted, per
   charter inv. 8.
3. **Promotion grant** — the verifier mints a typed promotion
   grant binding the candidate's `evidence_id` + verifier
   identity + verification evidence. The grant's entity name is
   reserved for follow-up schema PR (candidate names:
   `PromotionGrant`, `CoordinationGrant`, `VerificationGrant`;
   final selection per ontology review). **Until the follow-up
   ADR selects a name, canonical policy YAML rejects any policy
   entry naming any of the three candidates** to prevent
   premature canonicalization.
4. **Promotion event** — Ring 1 mint API consumes the grant and
   flips the candidate's `allowed_for_gate: false → true`,
   sets `promoted_at` and `promotion_grant_id`, and emits a
   typed `Decision` recording the promotion in the audit chain.

**Verifier visibility-authority rule (closes visibility-leak
escalation hole):**

A promotion grant is rejected at Layer 1 mint API if the verifier
session lacks read authority over any Evidence record cited in:

- the candidate's `evidence_refs` (for `CoordinationFact`),
- the candidate's `derived_from` array (for `DerivedSummary`),
- the transitive closure of `derived_from` references (for
  multi-level summaries).

Read authority is determined by the verifier session's
`ExecutionContext` and `subject_refs` scope at the time the
promotion grant is minted. **The scope is single-session: read
authority is evaluated against the minting session only, not
transitively across the verifier's session graph or aggregated
across the verifier's other concurrent sessions.** This
prevents verifier-session-aggregation as a privilege-escalation
surface (a verifier with read authority over E1 in session A
and E2 in session B cannot mint a promotion grant in session A
that requires read authority over both unless session A
independently has read authority over both). A verifier
rubber-stamping records they could not have meaningfully
verified is the escalation hole this rule closes. The Decision
rejection class is `Decision.reason_kind:
coordination_promotion_visibility_unauthorized`.

This rule composes with the §Chain promotion rule on
`DerivedSummary`: if a transitive `derived_from` reference
fails the visibility-authority check, the promotion fails
regardless of whether the chain link is itself promoted.

**Verifier identity binding (closes identity/attribution gap):**

The promotion grant's verifier identity is bound to two fields:

- **`agent_client_id`** — kernel-set per registry v0.3.1
  §Audit-chain coverage of rejections canonical attribution.
  Names the agent client (Claude Code session, Codex session,
  MCP-attached tool) that minted the grant.
- **`session_id`** — kernel-set. Names the specific session
  within the agent client.

Producer-supplied verifier identity values rejected at Layer 1
mint API. The two-field binding ensures the audit chain can
trace any promotion back to a specific agent client + session
combination, matching the rigor of ADR 0029 v2's typed
self-assertion-acknowledgment grant pattern.

**Promotion audit-record completeness (closes inv. 4 audit gap):**

Every successful promotion event emits a typed `Decision`
record carrying the following seven fields, mirroring registry
v0.3.1 §Audit-chain coverage of rejections rejection-event
shape:

- `agent_client_id` — verifier's agent client identity.
- `session_id` — verifier's session identity.
- `promotion_layer` — always `mint_api` for promotions (the
  promotion event happens at Layer 1; subsequent re-checks at
  Layer 2/3 are not promotion events but freshness/visibility
  re-derivations).
- `candidate_evidence_id` — the `coordination_fact_id` or
  `derived_summary_id` being promoted.
- `verification_evidence_refs` — array of `evidenceRefSchema`
  references to the verification Evidence records the verifier
  cited.
- `promotion_grant_id` — the grant ID consumed.
- `promoted_at` — kernel-set timestamp of the
  `allowed_for_gate: false → true` flip. Audit consumers
  reconstructing promotion timelines (e.g., "what was promoted
  in the past hour?") need this timestamp explicitly in the
  audit record; it must not require joining to the underlying
  `CoordinationFact` / `DerivedSummary` row.

This rule extends registry v0.3.1's rejection-event shape to
promotion-success events. Promotion is a higher-impact event
than rejection (it grants gate authority); the explicit field
list prevents identity-attribution gaps.

**Closed-list fail-mode (mirrors ADR 0029 v2):**

When a gate consumes a `CoordinationFact` or `DerivedSummary`
and observes a failure class not present in the §`Decision.reason_kind`
reservations list below, the gateway applies a tightening
default per the consuming operation's class:

- For operation classes `destructive_git`,
  `external_control_plane_mutation`, `worktree_mutation`,
  `merge_or_push` (per ADR 0029 v2): default to **`block`**
  with `Decision.reason_kind:
  coordination_fact_unrecognized_failure` or
  `derived_summary_unrecognized_failure` (placeholder
  rejection class; canonical name lands per
  `.agents/skills/hcs-schema-change`).
- For operation classes `read_only_diagnostic`,
  `agent_internal_state`: default to **`warn`** with the same
  placeholder reason_kind, recording the unrecognized
  combination in the audit chain for ontology review.
- The fail-mode is intentionally tightening; loosening defaults
  requires a registry/ADR pass.

**Rejection-class consistency across layers:**

The seven `Decision.reason_kind` reservations below carry the
same string discriminator value across all three Ring 1 layers
(mint API, broker FSM, gateway). A rejection at Layer 1 with
`reason_kind: coordination_fact_unpromoted` reads identically
in audit chain queries to a Layer 3 re-derive rejection with
the same reason_kind. This prevents audit-chain query drift
across enforcement layers.

**Shared infrastructure with `ApprovalGrant`:**

- Typed `Decision` shape with `reason_kind` /
  `required_grant_kind` discriminators per registry v0.3.3
  Sub-rule 6.
- Audit-chain participation per registry v0.3.1 §Audit-chain
  coverage of rejections (extends to promotions per
  §Promotion audit-record completeness above).
- Ring 1 mint API enforcement at Layer 1; broker FSM and
  gateway re-check at Layers 2 and 3 per registry v0.3.2
  §Cross-context enforcement layer.

**Differences from `ApprovalGrant`:**

- `ApprovalGrant` scopes *operations* (operation_class +
  execution_context_id + target_ref + per-class extensions per
  ADR 0029 v2 §`ApprovalGrant.scope` shape sketch).
- Promotion grants scope *facts* (candidate evidence_id + verifier
  identity + verification evidence_refs + scoped fact-classes).
- `ApprovalGrant` is single-use per operation invocation; promotion
  grants are single-use per fact-promotion event.
- **Scope-key disjointness rule.** Promotion-grant scope keys
  (`coordination_promotion`, `summary_promotion`) are disjoint
  from `ApprovalGrant.scope` per-class extension keys
  (`destructive_git`, `merge_or_push`,
  `external_control_plane_mutation`, `worktree_mutation` per
  ADR 0029 v2). Canonical policy YAML at
  `system-config/policies/host-capability-substrate/` must not
  reuse `ApprovalGrant.scope` per-class keys for promotion
  grants. Policy-lint rejects overlapping keys.

**Forward-look — separation-of-duties (canonical policy at
Milestone 2):**

Canonical policy YAML must define:

- which authority classes can verify which fact-class scopes
  (e.g., `coordination_promotion` for `subject_kind: release`
  may require a different verifier authority than
  `summary_promotion` for `summary_kind: closeout_narrative`);
- a producer-equals-verifier prohibition: a session that
  produces a candidate fact MUST NOT mint the promotion grant
  for that same candidate. The two roles are structurally
  separated (the producer asserts; the verifier promotes). The
  Layer 1 mint API enforces this once canonical policy lands.

Without (b), the producer-equals-verifier path circumvents
the workflow's authority asymmetry. ADR 0019 commits the
*posture* (separation-of-duties is required); canonical policy
commits the *enforcement rules* at Milestone 2.

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
- **`CoordinationFact`**: Layer 1 enforces `evidence_refs`
  consistency. **Default rule (strict): every cited Evidence must
  share the `execution_context_id`.** A cross-context reference
  (e.g., a fact in execution_context A citing Evidence in
  execution_context B) is rejected at Layer 1 unless an explicit
  cross-context-reference mechanism is committed by a future
  Q-003 follow-up amendment. Until that amendment lands, the
  default is strict to prevent cross-context evidence laundering.
  Layer 2 re-checks `allowed_for_gate` and `valid_until` at
  operation-execution time; Layer 3 re-derives at decision time.
  Producer-supplied `allowed_for_gate` rejected at Layer 1.
- **`DerivedSummary`**: Layer 1 enforces `derived_from`
  consistency (same strict cross-context rule as
  `CoordinationFact.evidence_refs`) and `authority: "derived"`
  fixity (any other value rejected). Layer 1 also enforces the
  §Chain promotion rule (any unpromoted record in the
  `derived_from` graph blocks promotion). Layer 2 re-checks
  `allowed_for_gate` and `promoted_at` freshness; Layer 3
  re-derives.

### Authority discipline

Authority-class signals across the four entities follow registry
v0.3.2 §Producer-vs-kernel-set discipline:

- **Kernel-set**: `content_hash`, `indexed_at`, `security_label`
  (KnowledgeSource); `text_hash`, `chunk_index`, `token_count`,
  `embedding_ref` (KnowledgeChunk); `allowed_for_gate`,
  `promoted_at`, `promotion_grant_id` (CoordinationFact +
  DerivedSummary); `generated_by` when value names a
  kernel-trusted producer class (DerivedSummary); promotion grant's
  `agent_client_id` and `session_id` (verifier identity binding
  per registry v0.3.1 §Audit-chain coverage of rejections
  canonical attribution).
- **Producer-asserted, kernel-verifiable**: `uri`, `source_kind`,
  `indexable` (KnowledgeSource); `heading_path`, `chunk_kind`,
  `metadata` (KnowledgeChunk); `subject_kind`, `subject_ref`,
  `predicate_kind`, `object_kind`, `object`, `evidence_refs`,
  `valid_until` (CoordinationFact); `derived_from`,
  `summary_kind`, `summary_text` (DerivedSummary).
- **`valid_until` rationale.** Producer asserts the candidate
  freshness window at mint time; the kernel does not pre-set
  the window. Canonical policy at Milestone 2 may impose
  per-`predicate_kind` maximum windows (e.g., a release-phase
  fact may carry at most a 7-day window; a worktree-attachment
  fact may carry at most a 30-minute window). The kernel may
  shorten the producer-asserted window at promotion time per
  canonical policy; the kernel does not lengthen it. Gateway
  re-derive at Layer 3 enforces the (kernel-shortened-or-
  producer-asserted) window per inv. 6.
- **Fixed at construction**: `authority: "derived"` and
  `confidence: "best-effort"` on DerivedSummary.

### `Decision.reason_kind` reservations

New rejection classes reserved (posture-only; schema enum lands
per `.agents/skills/hcs-schema-change`):

- `coordination_fact_unpromoted` — gate consumed a coordination
  fact with `allowed_for_gate: false`.
- `coordination_fact_expired` — `valid_until` passed at
  Layer 2/3 re-check.
- `coordination_fact_evidence_drift` — cited `evidence_refs` no
  longer match live state at re-check.
- `coordination_promotion_visibility_unauthorized` — verifier
  session lacks read authority over Evidence cited in the
  candidate's `evidence_refs` (or transitively in `derived_from`).
  Closes the visibility-leak escalation hole at Layer 1 mint API.
- `derived_summary_unpromoted` — gate consumed a derived summary
  with `allowed_for_gate: false`.
- `derived_summary_unpromoted_dependency` — promotion grant
  attempted on a `DerivedSummary` whose `derived_from` graph
  contains an unpromoted record (per §Chain promotion rule).
- `knowledge_chunk_used_as_gate_authority` — operation cited a
  retrieval-derived chunk as gate evidence (charter inv. 18
  candidate violation).
- `knowledge_source_content_drift` — `content_hash` mismatch
  detected at retrieval time.
- `promotion_grant_scope_mismatch` — promotion grant's bound
  evidence_id does not match the candidate's id at promotion
  consumption.
- `secret_resolution_in_chunk` — `KnowledgeChunk` minted with
  resolved secret value (`op://` reference materialized to
  plaintext) at Layer 1 mint API. Charter inv. 5 violation.

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
> claims are rejected at the mint API. Promotion of a
> `CoordinationFact` or `DerivedSummary` is forbidden when the
> candidate's `evidence_refs` or transitive `derived_from` graph
> contains any record with `allowed_for_gate: false`,
> `authority: sandbox-observation`, `authority: self-asserted`,
> or any `KnowledgeChunk` reference; the promotion-laundering
> surface is structurally closed by graph-walk enforcement at
> Layer 1 mint API. Cross-context evidence references are
> rejected by default; cross-context use requires explicit
> typed mechanism committed by future Q-003 amendment.

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
  store (existing, Ring 1 service) + coordination state layer
  (NEW, Ring 0 entity + Ring 1 mint/broker/gateway) + derived
  retrieval index (NEW, Ring 1 indexer service against Ring 0
  records). MCP / dashboard exposure is Ring 2.
- Four new Ring 0 entities reserved as no-suffix peers of
  `Evidence` (Q-011 bucket 2): `KnowledgeSource`,
  `KnowledgeChunk`, `CoordinationFact`, `DerivedSummary`.
- `CoordinationFact` shape uses typed
  `subject_kind` discriminator + `subject_ref` polymorphic FK
  per registry Sub-rule 5/6, replacing v1's bare `subject` /
  `predicate` strings. `predicate_kind` is reserved as ontology-
  controlled vocabulary (closed enum landed in follow-up registry
  entry). Reference arrays use `_refs` plural form per registry
  Sub-rule 4 (`evidence_refs`, not `evidence_ids`).
- The promotion workflow is a typed grant pattern parallel to
  `ApprovalGrant` (different scope shape: facts vs operations;
  shared typed Decision + audit-chain infrastructure).
  Promotion-grant scope keys (`coordination_promotion`,
  `summary_promotion`) are disjoint from `ApprovalGrant.scope`
  per-class extension keys.
- Verifier visibility-authority rule: a promotion grant is
  rejected at Layer 1 mint API if the verifier session lacks
  read authority over any Evidence record cited in the
  candidate's `evidence_refs` or transitively in `derived_from`.
  Closes the visibility-leak escalation hole.
- Verifier identity is bound to `agent_client_id` + `session_id`
  per registry v0.3.1 §Audit-chain coverage of rejections
  canonical attribution; producer-supplied verifier identity
  rejected at Layer 1.
- Promotion audit-record completeness: every successful
  promotion event emits a typed `Decision` carrying
  `agent_client_id`, `session_id`, `promotion_layer`,
  `candidate_evidence_id`, `verification_evidence_refs`,
  `promotion_grant_id`. Extends registry v0.3.1's rejection-event
  shape to promotion-success events.
- `allowed_for_gate` is a first-class kernel-set boolean field on
  `CoordinationFact` and `DerivedSummary`; producer-supplied
  values rejected at Layer 1 mint API; starts false; flips true
  only via the promotion workflow.
- §Chain promotion rule for `DerivedSummary`: a candidate cannot
  be promoted if its `derived_from` graph contains any
  unpromoted record, sandbox-observation/self-asserted Evidence,
  or `KnowledgeChunk` reference. Closes the promotion-laundering
  surface at Layer 1 mint API by graph-walk enforcement.
- Cross-context binding rules are explicit per Ring 1 layer
  (mint API / broker FSM / gateway) per registry v0.3.0
  requirement. **Default rule (strict): cross-context Evidence
  references rejected at Layer 1**; cross-context use requires
  explicit typed mechanism committed by future Q-003 amendment.
- §Closed-list fail-mode (mirrors ADR 0029 v2): unrecognized
  rejection classes against destructive_git /
  external_control_plane_mutation / worktree_mutation /
  merge_or_push default to `block`; against
  read_only_diagnostic / agent_internal_state default to
  `warn`.
- Rejection-class discriminator string is identical across all
  three Ring 1 layers (mint API, broker FSM, gateway); audit-
  chain queries find rejections by single name regardless of
  rejecting layer.
- §Secret-referenced sources (charter inv. 5): security_label
  propagates source → chunk; `text_hash` over reference-form
  content only; chunker materializing resolved `op://` value
  fails Layer 1 mint with `secret_resolution_in_chunk` reason
  class. **Embedding-eligibility rule** (closes embedding-
  inversion side-channel): `KnowledgeChunk.embedding_ref` is
  null when parent source's `security_label ==
  "secret_referenced"`; embedding job refuses to vectorize.
  **Re-indexing label-recheck rule**: when source `content_hash`
  changes, indexer recomputes `security_label`; prior chunks
  marked stale and re-derived. **Label-upgrade chunk-
  invalidation rule**: when source `security_label` is upgraded
  to `secret_referenced`, all child chunks with non-null
  `embedding_ref` are purged or re-minted with `embedding_ref:
  null`. Closes inv. 5 + inv. 8 composition gap.
- Chunks are display-only (charter inv. 1 / inv. 2): no chunk
  content may reach any path that produces typed records
  consumed by gates, including direct rendering, prompt
  rendering, or any indirection through an LLM. Allowed
  surfaces: dashboard display to a human reviewer; MCP
  Resources tagged display-only; transcript inclusion for human
  inspection.
- `KnowledgeChunk.embedding_ref` deployment-binding (charter
  inv. 10): resolves only to on-host vector storage under
  `$HCS_STATE_DIR`; remote/hosted backends require ADR amendment.
- §Verifier visibility-authority single-session scope: read
  authority evaluated against minting session only, not
  transitively across verifier's session graph. Closes
  verifier-session-aggregation escalation surface.
- §Promotion audit-record completeness commits seven explicit
  fields: `agent_client_id`, `session_id`, `promotion_layer`,
  `candidate_evidence_id`, `verification_evidence_refs`,
  `promotion_grant_id`, `promoted_at`.
- ADR 0019 reserves the registry section name `§Predicate-kind
  vocabulary` paralleling §Boundary dimension registry; the
  registry update PR is a precondition for `CoordinationFact`
  schema implementation.
- Authority-class signals follow registry v0.3.2 §Producer-vs-
  kernel-set discipline. `valid_until` on `CoordinationFact` is
  producer-asserted at mint time, kernel-shortenable at
  promotion time per canonical policy.
- Eleven new `Decision.reason_kind` rejection-class names
  reserved (posture-only): `coordination_fact_unpromoted`,
  `coordination_fact_expired`, `coordination_fact_evidence_drift`,
  `coordination_promotion_visibility_unauthorized`,
  `derived_summary_unpromoted`,
  `derived_summary_unpromoted_dependency`,
  `knowledge_chunk_used_as_gate_authority`,
  `knowledge_source_content_drift`,
  `promotion_grant_scope_mismatch`,
  `secret_resolution_in_chunk` (and the placeholder
  `coordination_fact_unrecognized_failure` /
  `derived_summary_unrecognized_failure` from §Closed-list
  fail-mode).
- Two new `Decision.required_grant_kind` reservations
  (posture-only): `coordination_promotion`, `summary_promotion`.
- Naming discipline is binding: "evidence and coordination
  store," "shared state," "knowledge index," "coordination
  fact," "derived summary." Never "memory."
- Charter inv. 18 candidate (tightened in v2 to forbid
  derived_from chaining with unpromoted records) is queued for
  charter v1.3.x or v1.4.0 follow-up. Charter amendment lands
  per change-policy in a separate PR.
- Charter inv. 10 deployment boundary explicit: Phase 1
  single-host posture; runtime state under
  `~/Library/Application Support/host-capability-substrate/` and
  `~/Library/Logs/host-capability-substrate/`, NOT in repo;
  hosted vector stores rejected for private runtime state.
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
