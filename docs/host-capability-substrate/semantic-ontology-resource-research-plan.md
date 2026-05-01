---
title: HCS semantic ontology and resource pressure research plan
category: research-plan
component: host_capability_substrate
status: draft
version: 1.1.0
last_updated: 2026-04-26
tags: [ontology, semantics, resource-budget, memory-pressure, test-concurrency, covenant, citadel]
priority: high
---

# Semantic Ontology and Resource Pressure Research Plan

This document defines the official-source research needed before HCS commits
its Phase 1 ontology and rollout posture. It is tailored to this repo, this
host, and related Covenant/Citadel work-in-progress previously reviewed as
local governance inputs.

This is a research intake plan, not a decision. Findings brought back from
official sources should be recorded with source URL, observed date, version,
and the HCS decision or entity they affect.

## Target Ring

Ring 3 research and planning. The expected downstream targets are Ring 0
ontology/schema work and Ring 1 resource-budget/policy work, but this document
does not change schemas or runtime behavior.

Matching existing ADR context:

- ADR 0001: repo boundary
- ADR 0009: ontology versioning
- ADR 0011: public/private boundary
- ADR 0012: credential broker
- ADR 0015: external control-plane automation
- Future ADR 0016/0017/0018: shell/environment and execution-context work
- Future ADR 0019 candidate: knowledge and coordination store

If the research changes entity semantics, source authority, or rollout safety
rules, draft a new ADR or amend the relevant future ADR before schema work.

## 2026-04-26 Research Execution Intake

The external research execution brief staged at
`docs/host-capability-substrate/research/external/2026-04-26-research-execution-results.md`
turns this plan into an agentic research workflow. Its core instruction is
binding for Phase 1 planning: discovery workers collect source-bound facts
first; synthesis happens only after a verification pass. Workers should not see
the full local hypothesis set, Covenant/Citadel conclusions, or sibling worker
outputs because those would bias discovery toward confirming the current HCS
design.

### Source Classes

Research outputs must classify every source:

| Class | Gate eligibility | Definition |
|---|---:|---|
| `official` | yes | Spec publisher, tool/project official docs, official repo docs, or official release notes. |
| `primary` | usually | Maintainer-authored RFC, design note, standards-track draft, or official project proposal. |
| `secondary` | no | Blog, book, tutorial, vendor article, or independent analysis. |
| `discovery` | no | Forums, Stack Overflow, Reddit, AI summaries, and issue comments unless maintainer-owned and explicitly promoted. |

Only `official` and promoted `primary` claims may influence ADR, schema, or
policy decisions. `secondary` and `discovery` sources can identify questions but
cannot become gate inputs.

### Result Template

Every worker claim should use this shape:

```markdown
### Source: <title>

- claim_id:
- workstream:
- source_class: official | primary | secondary | discovery
- verification_status: unverified | self-attested | re-fetched | conflicting | quarantined
- URL/citation:
- Publisher:
- Version/date:
- Retrieved/observed at:
- Official status:
- Relevant claim:
- Exact excerpt or tight paraphrase:
- HCS implication candidate:
- Affected entity/ADR/trap:
- Confidence:
- Open follow-up:
```

Workers may fill `HCS implication candidate`, but the coordinator treats it as
advisory until synthesis.

### Output Registry

Initial attachment targets:

- Entities: `Evidence`, `Decision`, `OperationShape`, `Run`, `Artifact`,
  `ResourceBudget`, `ResourceObservation`, `WorkloadShape`, `ExecutionLease`,
  `SecretReference`, `Principal`, `Capability`, `ApprovalGrant`, `Session`
- ADRs: ADR 0009 amendment candidate, semantic foundation ADR, governance
  authority semantics ADR, ResourceBudget/host-pressure ADR, rollout posture ADR
- Traps: `stale-ontology-term`, `summary-as-fact`,
  `retrieved-summary-as-authority`, `agent-overclaim`,
  `test-runner-unbounded-workers`, `watch-mode-left-running`,
  `browser-tests-without-resource-lease`,
  `memory-pressure-ignored-before-full-suite`, `secret-value-persisted`,
  `external-mutation-without-broker`

### Discovery Waves

Run Wave 1C and 1D first if capacity is limited; they are the most
version-sensitive and have the clearest operational payoff.

| Wave | Scope | First batch |
|---|---|---|
| 1A | Semantic foundation | RDF, OWL, SHACL, SKOS, PROV, JSON-LD, JSON Schema, versioning |
| 1B | Governance semantics | OPA/Rego, audit guidance, RBAC/ABAC, SLSA/Sigstore, secrets management |
| 1C | Tool concurrency and resource pressure | Vitest, Jest, pytest/xdist, Node, Playwright, Go, Cargo, Gradle, package managers, containers |
| 1D | macOS host signals | memory pressure, `setrlimit`, launchd/shell limits |

Wave 1C has extra version discipline: each concurrency default must carry the
latest stable version or current doc version as of the observed date, plus
release-note review for changes in the last 24 months where available.

### Verification Gate

No discovery bundle moves to synthesis until these checks are clean:

| Gate | Check | Failure action |
|---|---|---|
| Citation re-fetch | Re-fetch at least 30%, minimum 3 cited sources per worker. | Mark claim `conflicting` or `quarantined`. |
| Source-class audit | Confirm every `official` source is actually controlled by the publisher/project. | Downgrade to `secondary` or `discovery`. |
| Version-pin audit | Require version/date for every 1C concurrency claim. | Return to worker. |
| Excerpt fidelity | Confirm excerpt/paraphrase is faithful. | Correct or quarantine. |
| Conflict log | Flag contradictions across workers. | Coordinator resolves in synthesis, not verifier. |

Exit criteria: zero fabricated citations, zero unpinned 1C defaults, zero
official-source misclassifications, and all conflicts logged.

## Local Principles To Preserve

These are local inputs from work-in-progress repositories, not external
standards. They should guide the questions we ask, but official-source claims
still need verification before they become HCS schema or policy.

### Covenant Inputs

Source files:

- `/Users/verlyn13/Organizations/the-nash-group/the-covenant/PRINCIPLES.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-covenant/GOVERNANCE.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-covenant/policies/gov-001-living-principles.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-covenant/policies/agt-001-agent-governance.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-covenant/policies/ops-002-quality-gates.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-covenant/policies/ops-004-observability.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-covenant/policies/sec-001-zero-trust.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-covenant/policies/sec-003-least-privilege.md`

Principles that map directly to HCS:

- Linear, meaningful history: HCS audit and decision records must be readable
  narratives, not opaque log dumps.
- Machines bless code: test/lint/security gates are mandatory, but they must
  be resource-governed so they do not destabilize the workstation.
- Infrastructure and configuration are code: HCS policy and host capability
  posture need declarative source-of-truth records, not UI-only state.
- Secrets never persist in repo or substrate state: HCS stores references and
  redacted evidence, not values.
- Zero trust and least privilege: every agent action has principal, authority,
  capability, scope, and audit context.
- If it is not measured, it does not exist: HCS resource and pressure claims
  need host observations, not vibes.
- Runbooks are executable documentation: operational procedures should be
  typed operation shapes and verifiable receipts where possible.
- Living principles: traps and field incidents update the corpus; dogma that
  fails in practice is amended deliberately.
- Agents are bounded tools, not decision-makers: agents propose, observe,
  escalate, and execute approved operations; humans retain governance
  authority.

### Citadel Inputs

Source files:

- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/README.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/OPENTOFU-SPECIFICATION.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/docs/METADATA-SECRETS-VARIABLES-SPEC.md`

Patterns that map directly to HCS:

- Separation of philosophy and enforcement: Covenant says why; Citadel says
  how. HCS should mirror that split: charter/ADR/policy explain intent,
  Ring 1 enforces, adapters translate.
- System/guardian split: automation applies invariant checks and reports
  deviations; humans exercise judgment on novel situations.
- Declarative managed state: runtime observations may inform decisions, but
  durable desired state belongs in explicit sources.
- Speculative plan before apply: HCS mutating operations need preflight,
  preview, approval, execution receipt, rollback, and verification.
- Labels and metadata: HCS entities need stable identifiers, owner, authority,
  environment/context, governing policy IDs, and lifecycle status.

## Research Workstream A - Semantic and Ontological Foundation

### Problem Statement

HCS already has a 20-entity Ring 0 sketch, but the project will fail if those
entities are only ad hoc TypeScript objects. The substrate needs disciplined
semantic practices: stable identifiers, explicit relationships, controlled
vocabularies, provenance, versioning, validation layers, deprecation behavior,
and a clear distinction between authoritative facts, derived summaries,
coordination state, and retrieved context.

### Official Sources To Bring Back

Bring official or primary sources only. For each source, capture title, URL,
publisher, version/date, and the exact claim we should rely on.

Research targets:

| Topic | Official-source target | HCS question |
|---|---|---|
| RDF / linked data model | W3C RDF docs | Do HCS entities need URI-like global identifiers or only local IDs? |
| OWL / ontology semantics | W3C OWL docs | Which relationships require formal ontology semantics vs TypeScript-only types? |
| SHACL / shape validation | W3C SHACL docs | Should HCS use shape constraints conceptually, even if implementation stays Zod/JSON Schema? |
| SKOS controlled vocabularies | W3C SKOS docs | How should authority, confidence, operation tier, and status vocabularies evolve? |
| PROV provenance model | W3C PROV docs | How should `Evidence.source`, `observed_at`, derivation, and authority map to provenance? |
| JSON-LD | W3C JSON-LD docs | Should JSON records carry optional `@context` mappings for future interoperability? |
| JSON Schema | JSON Schema official docs/spec | What is the correct validation/annotation split for Ring 0 schemas? |
| OpenAPI / AsyncAPI | Official specs | Which HCS operation/resource surfaces should be API-described vs ontology-described? |
| OpenTelemetry semantic conventions | OpenTelemetry docs | Which attributes should HCS reuse for service, process, host, and resource telemetry? |
| Semantic versioning | semver.org and schema/versioning guidance | How should entity schema versions, adapter tool versions, and policy versions interact? |

### Questions To Answer

1. What is the minimum semantic layer HCS needs in Phase 1?
   - Option A: Zod + JSON Schema + docs only.
   - Option B: Zod + JSON Schema + controlled vocabularies + provenance model.
   - Option C: Add JSON-LD/RDF mappings for selected entities.
   - Option D: Full formal ontology with OWL/SHACL toolchain.

2. Which HCS fields must become controlled vocabularies?
   - `Evidence.authority`
   - `Evidence.confidence`
   - `OperationShape.mutation_scope`
   - policy tier / decision outcome
   - execution context surface
   - resource pressure level
   - source authority class

3. How should HCS identify things?
   - Local IDs vs URIs vs compound keys.
   - Host-scoped vs workspace-scoped vs organization-scoped IDs.
   - Stable IDs for external provider objects.
   - ID rotation and tombstone behavior.

4. How should HCS represent relationships?
   - `Evidence` supports `derived_from`.
   - `OperationShape` targets entities.
   - `Run` realizes an approved `OperationShape`.
   - `Artifact` is emitted by `Run`.
   - `Lease` reserves a resource for a `Session` or `Run`.
   - `ResourceBudget` constrains a `Session`, `OperationShape`, or `Run`.

5. How should HCS distinguish facts from summaries?
   - Authoritative observation.
   - Human decision.
   - Runtime receipt.
   - Agent-authored summary.
   - Retrieved knowledge chunk.
   - Coordination fact pending verification.

6. What is the deprecation model for ontology terms?
   - How long must deprecated fields remain readable?
   - How are migrations represented?
   - How does a trap catch stale term usage?

### Expected HCS Outputs

Research should produce one of:

- ADR: "HCS semantic foundation and ontology validation posture"
- ADR 0009 amendment
- Phase 1 Thread D schema requirements
- Controlled-vocabulary registry under Ring 0
- Regression traps for stale ontology terms or summary-as-fact failures

## Research Workstream B - Governance Semantics and Authority

### Problem Statement

HCS must not blur governance authority. Covenant/Citadel split says principles
and enforcement are different layers. HCS has a similar risk: agent guidance,
policy YAML, runtime observations, retrieved docs, and human decisions can all
look like "context" unless the ontology keeps them separate.

### Official Sources To Bring Back

| Topic | Official-source target | HCS question |
|---|---|---|
| Policy-as-code model | OPA/Rego official docs | What belongs in policy evaluation vs schema validation? |
| Audit logging | NIST / official logging guidance | What minimum fields and retention posture should HCS audit records have? |
| Access-control models | NIST or vendor official docs | Which vocabulary best fits Principal, Capability, ApprovalGrant, and Lease? |
| Supply-chain attestations | SLSA / Sigstore official docs | Should HCS receipts align with attestation/provenance formats? |
| Secrets management | 1Password / provider official docs | How should SecretReference and broker receipts be typed without secret values? |

### Questions To Answer

1. Which HCS entities are governance-authoritative?
2. Which entities are advisory only?
3. Which records can be used as gate inputs?
4. How should a human decision be represented differently from an agent
   recommendation?
5. How should HCS show the chain from principle -> policy -> operation ->
   decision -> run -> artifact?
6. What must remain outside the public repo and outside Ring 0/1 persistence?

### Expected HCS Outputs

- Authority taxonomy for `Evidence` and `Decision`.
- Gate-eligible vs non-gate-eligible record types.
- Dashboard language that makes authority visible to the human reviewer.
- Regression traps for retrieved-summary-as-authority and agent-overclaim.

## Research Workstream C - Resource Pressure and Test Concurrency

### Problem Statement

This workstation is an M3 Max system, but it is still a finite shared host.
Multiple active projects and agents may run Vitest, pytest, Playwright, Jest,
Cargo, Go, Gradle, npm/pnpm scripts, model servers, browser tests, MCP
processes, and background collectors. Many test runners default to using free
cores or aggressive worker pools. Without HCS-level coordination, "just run the
tests" becomes a host pressure event: memory pressure rises, swap churns,
interactive agents stall, MCP sessions respawn, and unrelated work is blamed.

HCS already has a `ResourceBudget` entity in the core ontology sketch. This
research determines what that entity must mean before rollout.

### Official Sources To Bring Back

Bring official docs for default concurrency and limiting knobs. Use the exact
tool version where possible.

| Tool / platform | Official-source target | HCS question |
|---|---|---|
| macOS memory pressure | Apple developer/admin docs | Which host signals should HCS treat as memory-pressure evidence? |
| macOS process limits | Apple `launchd`, shell, or developer docs | Which limits are enforceable per process/session on macOS? |
| Node.js | Node official docs | How do V8 heap limits and worker/thread pools affect test commands? |
| Vitest | Vitest config docs | What are default worker/pool behaviors and supported caps? |
| Jest | Jest CLI/config docs | What default worker count is used and how is it limited? |
| Playwright | Playwright test docs | How do browser workers multiply CPU/RAM use? |
| pytest | pytest official docs | What is core pytest's default concurrency and memory behavior? |
| pytest-xdist | pytest-xdist official docs | What does `-n auto` mean and how can it be capped? |
| Python multiprocessing/concurrent futures | Python official docs | Which defaults use CPU count and which need explicit limits? |
| Go test | Go official docs | How do `-p` and `-parallel` interact with package/test concurrency? |
| Cargo test | Rust/Cargo official docs | What is the default job count and how is it capped? |
| Gradle | Gradle docs | How do workers, daemon memory, and parallel test execution behave? |
| npm/pnpm/bun scripts | Official docs | Which package manager commands spawn parallel work by default? |
| Docker/OrbStack | Official docs | How do container resource limits work on macOS? |

### Questions To Answer

1. What host-level signals should HCS record?
   - memory pressure state
   - free/active/wired/compressed memory
   - swap usage
   - process count
   - load average
   - CPU core saturation
   - per-process RSS
   - active browser/test worker count
   - MCP session count

2. What is a safe default budget on this workstation?
   - Reserve memory and cores for the human desktop and active agent sessions.
   - Cap each repo's default test worker count.
   - Cap aggregate test workers across repos.
   - Treat browser tests as heavier than unit tests.
   - Treat model inference and container workloads as budget-heavy.

3. What should HCS do when pressure is high?
   - Refuse to start heavy tests.
   - Queue tests behind a lease.
   - Run a smaller targeted test.
   - Ask for approval to exceed budget.
   - Suggest a single-owner terminal session for heavy workloads.
   - Emit a `ResourceBudgetExhausted` / `VerificationDeferred` receipt.

4. How should test commands be typed?
   - `test.unit.targeted`
   - `test.unit.full`
   - `test.browser`
   - `test.integration.local`
   - `test.integration.external`
   - `test.watch`
   - `build.typecheck`
   - `lint`
   - `benchmark`

5. Which commands are deceptively "read-only"?
   - Tests write caches, snapshots, reports, coverage, databases, temp files,
     and browser profiles.
   - Watch mode holds resources open.
   - Parallel tests can create external API pressure.
   - Package-manager scripts can run arbitrary hooks.

6. What belongs in repo config vs HCS policy?
   - Repo-local preferred commands and safe caps.
   - HCS host-wide aggregate budget.
   - Live pressure observations.
   - Emergency user override.

### Candidate Resource Ontology

Research should confirm or revise these candidate entities and fields.

`ResourceBudget`

```text
id
scope: host | workspace | session | operation | run
resource_class: cpu | memory | process | browser | network | external_api | gpu | disk_io
limit_value
limit_unit
soft_or_hard
valid_until
owner_principal_id
source_policy_id
```

`ResourceObservation`

```text
id
host_id
sampled_at
source
metric_name
metric_value
unit
authority
confidence
```

`WorkloadShape`

```text
id
kind: test | build | lint | typecheck | benchmark | package_install | model_inference
tool
estimated_cpu
estimated_memory
estimated_processes
estimated_external_calls
watch_mode
browser_count
declared_parallelism
```

`ExecutionLease`

```text
id
resource_budget_id
session_id
operation_shape_id
exclusive_or_shared
expires_at
state: requested | granted | denied | released | expired
```

### Candidate Defaults To Validate

These are hypotheses, not decisions:

- HCS should reserve at least one performance-core equivalent and a fixed
  memory floor for the human desktop and active agents.
- Full test suites should require a resource lease when another full suite or
  browser-test suite is active.
- Watch-mode tests should be budgeted as long-lived workloads, not one-shot
  commands.
- Browser tests should default to low worker counts unless a repo declares a
  safe profile.
- `pytest -n auto`, Vitest default workers, Jest default workers, Go package
  parallelism, and Cargo job parallelism should be capped through HCS-rendered
  command shapes when run by agents.
- HCS should prefer targeted tests first, then full-suite execution when the
  resource budget is available.

### Expected HCS Outputs

- ADR or ADR section: "ResourceBudget and host pressure semantics"
- Ring 0 schema additions or refinements: `ResourceBudget`,
  `ResourceObservation`, `WorkloadShape`, `ExecutionLease`
- Ring 1 broker behavior: global budget accounting and pressure gates
- Ring 2 CLI/dashboard behavior: show active workloads and budget denials
- Ring 3 runbook: how agents request heavy tests and how humans override
- Regression traps:
  - `test-runner-unbounded-workers`
  - `watch-mode-left-running`
  - `browser-tests-without-resource-lease`
  - `memory-pressure-ignored-before-full-suite`

## Research Workstream D - Rollout Posture

### Problem Statement

HCS should not roll out as a clever advisory system that creates new pressure
or ambiguity. Rollout must start with observability and planning, then move to
soft gates, then hard gates, with explicit human review.

### Questions To Answer

1. What can be measured passively without creating more host pressure?
2. Which gates can run in advisory mode first?
3. Which gates can block immediately because the failure mode is severe?
4. Which surfaces need brokered sessions before they may mutate external state?
5. Which repos need resource profiles before agents run their full suites?
6. What dashboard views are necessary before enforcement?

### Candidate Rollout Sequence

1. Passive resource observation:
   - sample host pressure
   - inventory active test/browser/MCP/model processes
   - record workload starts and exits
2. Repo profile discovery:
   - identify test tools
   - identify official limiting knobs
   - record safe targeted/full commands
3. Advisory gate:
   - warn before unbounded full-suite or watch-mode commands
   - suggest capped command shapes
4. Lease gate:
   - one full-suite/browser-suite per host budget class unless approved
   - queue or defer when memory pressure is high
5. Broker enforcement:
   - render test commands with explicit worker caps
   - record receipts and budget use
   - expose dashboard review and override

## Research Result Template

Use one block per official source:

```markdown
### Source: <title>

- URL:
- Publisher:
- Version/date:
- Retrieved/observed at:
- Official status:
- Relevant claim:
- Exact excerpt or paraphrase:
- HCS implication:
- Affected entity/ADR/trap:
- Confidence:
- Open follow-up:
```

## Acceptance Criteria For Returned Research

The research is ready for ADR drafting when:

- Every claim needed for schema or policy is backed by an official or primary
  source.
- Version-sensitive claims include observed version/date.
- Any unofficial source is marked as discovery only, not authority.
- The resource-pressure section includes at least Vitest, pytest/xdist, Node,
  Python, Playwright, Jest, Go, Cargo, Gradle, and macOS host signals.
- The semantic section recommends a minimum viable semantic stack for Phase 1.
- The rollout section distinguishes passive observation, advisory gates, and
  hard enforcement.
- The output names the exact HCS entities, ADRs, and traps that need updates.

## Non-Goals

- Do not redesign the entire HCS ontology before source-backed research lands.
- Do not add a universal shell-execution capability.
- Do not make HCS a general workload scheduler.
- Do not commit host-specific runtime pressure samples to the repo.
- Do not treat Covenant/Citadel work-in-progress files as external official
  standards; they are local governance inputs.

## Change Log

| Version | Date | Change |
|---------|------|--------|
| 1.1.0 | 2026-04-26 | Ingested the research execution brief. Added source-class taxonomy, worker result template, output registry, discovery wave sequencing, and verification gates; prioritized Wave 1C/1D resource-pressure work before synthesis. |
| 1.0.0 | 2026-04-25 | Initial research plan for semantic/ontology foundation, Covenant/Citadel alignment, and host resource-pressure/test-concurrency controls. |
