## Working conclusion

Yes: **HCS should have a shared memory/database layer**, but it should not be designed as “LLM memory” in the casual sense. It should be designed as a **typed evidence, coordination, and retrieval substrate**.

The core rule I would carry forward from the three-repo incident is:

> **Shared state must be typed, source-ranked, freshness-aware, and gateable. RAG is only a discovery layer over that state, never the authority layer.**

That distinction matters. The failure pattern in the earlier project was not that agents lacked text to read; they had plenty of text. The failure was that **textual summaries, docs, local working trees, live infra, tags, 1Password state, GHCR, and pod state were all competing as partial sources of truth**. A vector/RAG layer over those documents would make retrieval faster, but it would not by itself prevent stale or wrong conclusions. The HCS design already points in the right direction: every `Evidence` record carries provenance, authority, freshness, confidence, host/session identity, and parser version; the research plan also separates visible state from audit state, and explicitly treats cache/evidence as typed rather than prose. 

So I would not add “memory” as a vague feature. I would add an ADR for something like:

> **ADR 0019 — Shared Evidence, Coordination State, and Retrieval Index**

or, if you want the language less broad:

> **ADR 0019 — HCS Knowledge and Coordination Store**

---

## The durable lesson to remember

The previous three-repo incident should become an HCS design invariant:

> **An agent may retrieve prose for context, but any action gate must be decided from typed evidence, receipts, leases, policy, and live probes.**

This fits your existing charter. HCS already forbids policy in adapters, forbids shell strings as primary intent, requires secrets to stay as references, blocks execute-lane work until approval/audit/dashboard/leases exist, and keeps runtime state outside the repo. 

It also fits the tooling matrix: `AGENTS.md`, `CLAUDE.md`, skills, and docs are behavior guidance; live policy and runtime state live elsewhere; enforceable surfaces are limited and should point to the substrate rather than duplicate policy. 

The thing to avoid is building a smarter version of the same problem: “agents now coordinate through a shared pile of embedded prose.” That would reproduce the old failure at higher speed.

---

## Recommended architecture: three layers, not one “memory”

### 1. Authoritative operational store

This is the HCS-owned database: SQLite WAL first, as your plan already says. It stores typed, validated, source-ranked objects:

* `Evidence`
* `Session`
* `Run`
* `Artifact`
* `Lease`
* `Decision`
* `ApprovalGrant`
* `ResolvedTool`
* `WorkspaceContext`
* `ResourceBudget`
* future `InterventionRecord`
* future external-control-plane receipts

This layer answers: **what is known, by what authority, observed when, valid until when, and safe for which use?**

It should remain the only store that can feed policy/gateway decisions. Your existing plan already has `audit_events`, `facts`, `fact_observations`, `cache_entries`, sessions, proposals, grants, runs, leases, and policy snapshots in the SQLite design. 

### 2. Coordination state layer

This is the missing piece exposed by the three-repo incident. It should be typed, but mostly generic. HCS should not hard-code “RunPod Stage 3a release semantics” in the kernel. It should provide primitives for project/domain controllers to record coordination facts safely.

Examples:

```json
{
  "schema_version": "1",
  "coordination_fact_id": "cfact_...",
  "workspace_id": "ws_...",
  "subject": "release:runpod-stage3a-2026-04-24",
  "predicate": "gate.phase4_dry_run",
  "object": {
    "status": "pass",
    "producer_ref": "runpod-inference@v0.4.0-rc1",
    "consumer_candidate": "runpod-review-webui release/v0.6.0",
    "blocked_actions": ["tag:v0.6.0"]
  },
  "source_evidence_ids": ["evid_...", "artifact_..."],
  "authority": "workspace-local",
  "confidence": "authoritative",
  "observed_at": "2026-04-24T19:42:00Z",
  "valid_until": "2026-04-25T19:42:00Z"
}
```

This layer answers: **what phase are we in, what gates are green, what is blocked, who owns the next action, and which receipts prove it?**

The previous incident showed several coordination facts that should have been typed rather than inferred from prose:

* “The shared working tree is intentionally detached at `v0.4.0-rc1`; do not treat older files as regression.”
* “The webui `v0.6.0` tag is blocked until producer dry-run is green.”
* “The pod is RUNNING but SSH NAT port changed.”
* “`/root`, `/run`, and `/root/.cache/uv` are ephemeral; workspace volume is durable.”
* “`op` CLI auth and 1Password SSH-agent signing are separate auth states.”
* “Dead RunPod aliases are stale resources and should be reconciled, not asked about.”

Your current `PLAN.md` is already moving this way: it queues a credential broker, forbidden-tier split, `InterventionRecord`, and external-control-plane automation with typed distinctions between provider object IDs, public client IDs, secret material, secret references, policy selector values, rate-limit observations, and remote mutation receipts. 

### 3. Retrieval index / RAG layer

This is a derived index over canonical sources:

* ADRs
* `DECISIONS.md`
* charter
* ontology docs
* tool/vendor docs snapshots
* generated JSON Schema
* runbooks
* receipts
* selected audit summaries
* regression traps
* source-code contract docs

This layer answers: **what context should the model read before deciding what to inspect next?**

It should support lexical search, metadata filters, and optional embeddings. But retrieval hits should always return structured metadata:

```json
{
  "chunk_id": "kchunk_...",
  "source_uri": "file://docs/host-capability-substrate/adr/0019-shared-state.md",
  "source_hash": "sha256:...",
  "source_type": "adr",
  "authority": "workspace-local",
  "observed_at": "2026-04-24T20:00:00Z",
  "valid_until": null,
  "schema_version": "1",
  "security_label": "public-source",
  "text": "...",
  "derived_from": ["artifact_...", "commit:..."]
}
```

This layer must never answer “allowed or denied?” by itself. It can only say “here are candidate sources; now verify through typed evidence or live probes.”

OpenAI’s current file-search docs describe vector stores as knowledge bases searched through semantic and keyword retrieval, and the tool is hosted by OpenAI. That is useful for non-sensitive docs, but it is not appropriate as the authority store for private host state, secrets, live policy, runtime facts, or audit data. ([OpenAI Developers][1])

---

## Why this is better than agent memory

Claude Code subagents can have their own context and, at user scope, persistent memory directories; the docs explicitly frame subagents as independent contexts with specific tool access and optional persistent learnings. That is useful for local productivity, but it is not cross-tool, not schema-validated, not source-ranked, and not an authoritative coordination mechanism. ([Claude][2])

LangGraph’s memory/persistence model is useful as a conceptual reference: it distinguishes thread-scoped memory from cross-thread long-term memory, and it names semantic, episodic, and procedural memory types. But HCS should adopt the taxonomy, not necessarily the framework. For HCS, semantic memory maps to verified facts, episodic memory maps to runs/receipts/interventions, and procedural memory maps to skills/runbooks/prompts. ([LangChain Docs][3])

The important distinction:

| Memory type                        | HCS equivalent                                 | Authority                                      |
| ---------------------------------- | ---------------------------------------------- | ---------------------------------------------- |
| “The user prefers X”               | User-scoped preference fact                    | Low-to-medium; human-editable                  |
| “This runbook says X”              | Knowledge chunk from source hash               | Context only                                   |
| “Pod status was X at time Y”       | `Evidence` from live probe                     | High until expiry                              |
| “Phase 4 is green”                 | Coordination fact backed by receipts           | Gateable                                       |
| “Agent summarized that X happened” | Derived summary / external testimony           | Not gateable                                   |
| “This tag exists”                  | Git/GitHub evidence                            | Gateable if fresh                              |
| “This command syntax is valid”     | Tool help/manpage evidence with parser version | Gateable for advice; recheck on version change |

---

## MCP mapping

The shared-memory design maps cleanly to MCP primitives.

The latest MCP server overview describes prompts as user-controlled templates, resources as application-controlled context, and tools as model-controlled functions. That means HCS should expose current state and cached knowledge primarily as **Resources**, expose live probes/searches as **Tools**, and expose workflows such as “explain this denial” or “prepare a release handoff” as **Prompts**. ([Model Context Protocol][4])

A good HCS surface might look like this:

```text
Resources
  hcs://workspace/current
  hcs://workspace/{id}/coordination/current
  hcs://workspace/{id}/decisions
  hcs://workspace/{id}/evidence/recent
  hcs://policy/current
  hcs://run/{id}/receipt
  hcs://knowledge/source/{source_id}

Tools
  system.evidence.search.v1
  system.evidence.get.v1
  system.coordination.current.v1
  system.coordination.explain_gate.v1
  system.knowledge.search.v1
  system.lease.preview.v1
  system.lease.acquire.v1       # later, only through gateway
  system.reconcile.resources.v1 # e.g. SSH aliases, stale pods, tool caches

Prompts
  hcs-release-handoff
  hcs-explain-policy-denial
  hcs-write-regression-trap
  hcs-summarize-intervention
  hcs-prepare-adr
```

For GPT-side clients, OpenAI’s current `tool_search` guidance is directly relevant: defer tool loading, group functions into namespaces or MCP servers, and keep each namespace under about 10 functions for better token efficiency and model performance. That reinforces your existing low-friction HCS invariant about small namespaces. ([OpenAI Developers][5])

---

## Proposed rule: RAG may discover; only typed evidence may decide

I would add this as a charter candidate or ADR invariant:

> **Derived retrieval results are never decision authority. A retrieved chunk may guide the agent to a source, probe, receipt, or schema, but policy/gateway decisions and release gates consume only typed evidence, approved decisions, receipts, leases, and live observations.**

That would have prevented several classes from the three-repo incident:

| Incident pattern                                          | HCS memory fix                                                                                                   |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| “Docs say Phase 6, live stack says pre-Phase-1.”          | Release phase is a typed coordination fact backed by receipts and live probes; docs are generated summaries.     |
| “Local checkout looked reverted.”                         | Worktree/session state is recorded as an active deployment lease: detached at `v0.4.0-rc1` for tarball staging.  |
| “All docs aligned” was asserted but stale refs remained.  | Claim requires repo-wide grep evidence or cannot be promoted above best-effort.                                  |
| “Pod resumed but `/root` and `/run` vanished.”            | Resume event invalidates facts with authority tied to ephemeral paths; bootstrap receipts recreate them.         |
| “Dead SSH aliases remained.”                              | `system.reconcile.resources.v1` compares live RunPod MCP state with local SSH alias file and emits a receipt.    |
| “1Password CLI auth worked but SSH-agent signing failed.” | Auth state is split into separate evidence types: `op_cli_session`, `op_ssh_agent_signing`, `gh_active_account`. |
| “Webui tag gate was held correctly by judgment.”          | Gate should be machine-readable: `tag:v0.6.0 blocked_until producer.phase5.green`.                               |

Your existing decision ledger already contains closely related lessons: D-025 says gitignore is not deletion authority, D-026 defines a config-spec authority hierarchy, and D-028 defines a credential-plane contract that will later be brokered through `$HCS_BROKER_SOCKET`. Those are exactly the kinds of “memory” that should become typed state rather than repeated prompt instructions. 

---

## Minimal schema additions I would consider

I would resist adding 15 new entities at once. The current 20-entity ontology is strong. Add only the missing seams.

### 1. `KnowledgeSource`

A canonical source that may be indexed.

```json
{
  "schema_version": "1",
  "source_id": "ksrc_...",
  "uri": "file://docs/host-capability-substrate/implementation-charter.md",
  "source_type": "charter | adr | decision-ledger | runbook | vendor-doc | receipt | code | schema | audit-summary",
  "authority": "project-local | workspace-local | user-global | system | derived",
  "content_hash": "sha256:...",
  "observed_at": "2026-04-24T20:00:00Z",
  "valid_until": null,
  "security_label": "public-source | private-local | secret-reference-only",
  "indexable": true
}
```

### 2. `KnowledgeChunk`

A chunk derived from a `KnowledgeSource`, with stable hashing.

```json
{
  "schema_version": "1",
  "chunk_id": "kchunk_...",
  "source_id": "ksrc_...",
  "chunk_index": 17,
  "text_hash": "sha256:...",
  "heading_path": ["Policy engine", "OPA trigger"],
  "token_count": 412,
  "embedding_ref": "local:emb_...",
  "metadata": {
    "adr": "0019",
    "ring": "1",
    "component": "evidence-cache"
  }
}
```

### 3. `CoordinationFact`

A generic, gateable state assertion.

```json
{
  "schema_version": "1",
  "fact_id": "cfact_...",
  "workspace_id": "ws_...",
  "subject": "release:stage3a",
  "predicate": "gate.webui_tag",
  "object": {
    "status": "blocked",
    "blocked_action": "git tag -s v0.6.0",
    "blocked_by": "producer.dry_run_verified"
  },
  "evidence_ids": ["evid_...", "artifact_..."],
  "authority": "workspace-local",
  "confidence": "authoritative",
  "observed_at": "2026-04-24T20:00:00Z",
  "valid_until": "2026-04-25T20:00:00Z"
}
```

### 4. `DerivedSummary`

A useful but non-authoritative model-produced summary.

```json
{
  "schema_version": "1",
  "summary_id": "sum_...",
  "summary_type": "handoff | closeout | intervention | release-status",
  "derived_from": ["artifact_...", "evid_...", "ksrc_..."],
  "generated_by": "agent:claude-code",
  "generated_at": "2026-04-24T20:00:00Z",
  "authority": "derived",
  "confidence": "best-effort",
  "allowed_for_gate": false
}
```

That last field is important. It prevents a polished summary from becoming a release gate.

---

## Storage recommendation

For Phase 1 and the first real HCS build slice:

1. **SQLite WAL remains the authority store.** This matches your current plan and the local-host nature of HCS.
2. **SQLite FTS is enough for the first retrieval layer.** Start with deterministic lexical search plus metadata filters.
3. **Add embeddings only as a derived index.** The embedding table or external vector index must be rebuildable from `KnowledgeSource` + `KnowledgeChunk`.
4. **Do not use hosted vector stores for private runtime state.** OpenAI file search/vector stores are useful for uploaded knowledge bases, but HCS runtime facts, secrets, live policy, and audit should remain local/private. ([OpenAI Developers][1])
5. **Postgres/pgvector only becomes worth it when HCS becomes multi-host or multi-writer.** For one macOS workstation with one HCS daemon, SQLite is the lower-entropy choice.

The key design constraint is not the database engine. It is the **authority boundary**.

---

## Write policy for shared memory

This is where most systems go wrong. I would use four write classes:

| Write class                | Who/what may write                     | Can feed gates?                    |
| -------------------------- | -------------------------------------- | ---------------------------------- |
| **Observed evidence**      | HCS probes, verified adapters, parsers | Yes, if fresh and authority-ranked |
| **Human decisions**        | ADR/DECISIONS/approved policy source   | Yes                                |
| **Receipts/artifacts**     | Broker/reconciler/runbook verifier     | Yes, if schema-valid               |
| **Agent claims/summaries** | Agent sessions                         | No, unless later verified/promoted |

Agents should be allowed to propose memory, not directly create authoritative memory.

For example, an agent may write:

```json
{
  "type": "candidate_memory",
  "claim": "All sibling docs use citadel-runpod-webui-internal-svc",
  "requires_verification": ["repo.grep:webhook-svc", "repo.grep:internal-svc"],
  "allowed_for_gate": false
}
```

A verifier then promotes or rejects it:

```json
{
  "type": "coordination_fact",
  "claim": "No stale webhook-svc references remain",
  "evidence_ids": ["grep_receipt_..."],
  "confidence": "authoritative",
  "allowed_for_gate": true
}
```

This is the difference between “memory” and “knowledge.”

---

## How this fits the four rings

| Ring                   | Shared-state responsibility                                                                                |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Ring 0 — schemas**   | `KnowledgeSource`, `KnowledgeChunk`, `CoordinationFact`, `DerivedSummary`; JSON Schema; tests              |
| **Ring 1 — kernel**    | evidence store, retrieval indexer, promotion rules, source authority ranking, freshness invalidation       |
| **Ring 2 — adapters**  | MCP resources/tools, CLI search, dashboard views; no policy decisions in adapter                           |
| **Ring 3 — workflows** | skills/prompts that tell agents when to query evidence, how to write handoffs, how to add regression traps |

This preserves your existing HCS rule that adapters translate but do not classify, and that no lower ring imports from a higher ring. 

---

## Dashboard implications

The dashboard should gain a “Memory / Evidence” set of views early, even if read-only:

```text
/evidence
  recent facts, freshness, authority, confidence

/coordination
  current workspace/release gates, blocked actions, owners

/knowledge
  indexed sources, stale chunks, source hashes, search diagnostics

/interventions
  human/agent incidents, root cause class, regression trap link

/reconciliation
  stale SSH aliases, dead pods, stale GH account, expired tool evidence
```

The dashboard should show when a model used a retrieved chunk versus when a gate used typed evidence. That distinction should be visible to the human reviewer.

---

## Concrete “remember this” entry

I would add something like this to `DECISIONS.md` after Phase 0b closeout, or as a candidate D-033:

```markdown
| D-033 | HCS shared memory is typed evidence + coordination state + derived retrieval index, not agent memory. Retrieval/RAG may discover candidate context, but gates and policy decisions consume only schema-valid Evidence, CoordinationFact, receipts, leases, human decisions, and live probes. Agent-authored summaries are `derived` and not gate-authoritative unless promoted by verification. | Three-repo Stage 2/3a incident showed that prose coordination, local checkout state, live infra, GHCR, 1Password, and docs can drift. A vector index over prose would speed retrieval but not fix authority. HCS must separate context retrieval from decision authority. | ADR 0019 candidate | 2026-04-24 |
```

This should also produce regression traps:

```text
#31 stale-rag-release-gate
Model retrieves old doc saying “Phase 6 complete” but live receipts say Phase 1. Must refuse gate.

#32 detached-worktree-false-regression
Shared worktree checked out at release tag appears older than origin/main. Must identify active lease/worktree purpose.

#33 agent-summary-overclaim
Agent claims all docs aligned. Must require repo-wide search receipt before promotion.

#34 stale-ssh-alias
Deleted RunPod alias remains in SSH config. Must reconcile against RunPod MCP before asking operator.

#35 auth-surface-conflation
op CLI works but 1Password SSH-agent signing fails. Must model separate credential surfaces.
```

Your `AGENTS.md` already says to update agent rules after repeated mistakes and record the trap in the regression corpus. This is exactly the class of mistake that deserves that treatment. 

---

## Final recommendation

Build the shared memory/database system, but name and constrain it carefully:

> **HCS should implement a shared evidence and coordination store with a derived retrieval index.**

Do **not** make a general “agent memory” where models store conclusions. The safe version is:

1. **Typed evidence for facts.**
2. **Receipts for phase transitions.**
3. **Leases for mutable resources and worktrees.**
4. **Human decisions for policy.**
5. **Derived RAG for search only.**
6. **Promotion rules before anything becomes authoritative.**

That gives you the speed benefit of shared memory and RAG, while avoiding the exact failure mode from the previous project: agents confidently coordinating through stale prose.

[1]: https://developers.openai.com/api/docs/guides/tools-file-search "File search | OpenAI API"
[2]: https://code.claude.com/docs/en/sub-agents "Create custom subagents - Claude Code Docs"
[3]: https://docs.langchain.com/oss/python/langgraph/persistence "Persistence - Docs by LangChain"
[4]: https://modelcontextprotocol.io/specification/2025-11-25/server?utm_source=chatgpt.com "Overview"
[5]: https://developers.openai.com/api/docs/guides/tools-tool-search "Tool search | OpenAI API"

