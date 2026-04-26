I read both uploaded docs as the governing brief: the HCS document is the substantive research intake plan, and the second document is the execution architecture for turning it into source-verified, agentic research. The important constraint is that this remains **Ring 3 research/planning** until official-source findings are verified; it should feed ADRs, Ring 0 schema requirements, Ring 1 resource-budget policy, and traps, but it should not itself change ontology or runtime behavior.  The second doc’s coordinator/worker split, version-pinning requirement, verification pass, and output registry are the right operating model for this.

## Consolidated execution plan

### 1. Research posture

Run this as **source-bound discovery first, synthesis second**.

Workers should not see the full Covenant/Citadel hypotheses, candidate defaults, or sibling workstream outputs. Each worker gets only its assigned question, the exact source family, the result template, and the names of potentially affected HCS entities. This prevents the research from merely confirming the local design sketch.

The coordinator sees the full plan only after the discovery reports pass verification. That coordinator then maps verified findings to ADRs, entity schemas, rollout gates, and traps.

### 2. Immediate source-status adjustments

A few official-source checks already affect the worker instructions:

RDF should be treated as a **version-sensitive semantic target**. RDF 1.2 Concepts is currently a W3C Candidate Recommendation Snapshot dated April 7, 2026, and W3C explicitly says Candidate Recommendation publication does not imply W3C endorsement; workers should compare stable RDF 1.1 posture against RDF 1.2 changes instead of assuming a single “current RDF” baseline. ([W3C][1])

JSON Schema should start from **Draft 2020-12**, because the official JSON Schema specification page says the latest meta-schema is 2020-12. ([JSON Schema][2])

OpenTelemetry semantic conventions should be pinned to the current observed docs version. The official page I found is “OpenTelemetry semantic conventions 1.40.0,” and it says the conventions define common semantic attributes for traces, metrics, logs, profiles, and resources. ([OpenTelemetry][3])

OPA is a strong fit for the governance-semantics worker because the official docs frame OPA as decoupling policy decision-making from policy enforcement, with policy decisions generated from structured input, policies, and data. ([Open Policy Agent][4])

For resource pressure, Apple’s Activity Monitor docs confirm that memory pressure is determined by free memory, swap rate, wired memory, and file cached memory; those are good seed candidates for `ResourceObservation.metric_name`. ([Apple Support][5]) Apple’s `setrlimit(2)` docs also confirm that per-process and child-process limits exist for CPU time, data size, file size, locked memory, open files, process count, and resident set size, which matters for the `soft_or_hard` distinction in `ResourceBudget`. ([Apple Developer][6])

The test-runner pressure problem is real enough to treat as first-class. Vitest’s current docs say `maxWorkers` defaults to all available parallelism outside watch mode and half available parallelism in watch mode, and that the default pool is `forks`. ([Vitest][7]) Jest 30.0 docs say `--maxWorkers` defaults to available cores minus one in single-run mode and half the available cores in watch mode. ([Jest][8]) Playwright Test runs worker processes in parallel, each worker starts its own browser, and workers can be capped with `--workers` or configuration. ([Playwright][9])

Go, Cargo, and Gradle each need separate build-vs-test concurrency handling. Go’s `-p` controls parallel build/test binaries and defaults to `GOMAXPROCS`, while `-parallel` controls simultaneous `t.Parallel` tests within one test binary and also defaults to `GOMAXPROCS`. ([Go Packages][10]) Cargo’s `--jobs` affects building test executables, defaults to logical CPUs, and does not control test harness threads; test threads are controlled after `--`, such as `-- --test-threads=2`. ([Rust Documentation][11]) Gradle’s `--max-workers` defaults to the number of processors, while Java test `maxParallelForks` defaults to 1 and cannot exceed max workers. ([Gradle Documentation][12])

OrbStack should be treated separately from Docker Desktop. Its official settings docs say container/machine memory is governed by `memory_mib`, memory is released when no longer used, and the default memory limit is no more than 8 GB. ([OrbStack Docs][13])

## 3. Phase 0: rails before research

Create three control files before any discovery worker runs.

### 0.1 Result template

Use the uploaded template, with these additions:

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

Workers may fill `HCS implication candidate`, but synthesis must treat it as non-authoritative. The coordinator decides implications.

### 0.2 Source-class taxonomy

Use this gate:

| Class       | Allowed to influence ADR/schema/policy? | Definition                                                                                                    |
| ----------- | --------------------------------------: | ------------------------------------------------------------------------------------------------------------- |
| `official`  |                                     Yes | Spec publisher or tool/project official docs, official repo docs, official release notes.                     |
| `primary`   |                                 Usually | Maintainer-authored RFC, design note, standards-track draft, or official project proposal.                    |
| `secondary` |                                      No | Blog, book, tutorial, vendor article, independent analysis.                                                   |
| `discovery` |                                      No | Forums, Stack Overflow, Reddit, AI summaries, issue comments unless maintainer-owned and explicitly promoted. |

### 0.3 Output registry

Seed a registry with these attachment targets:

```yaml
entities:
  - Evidence
  - Decision
  - OperationShape
  - Run
  - Artifact
  - ResourceBudget
  - ResourceObservation
  - WorkloadShape
  - ExecutionLease
  - SecretReference
  - Principal
  - Capability
  - ApprovalGrant
  - Session

adrs:
  - ADR-0009-ontology-versioning-amendment
  - ADR-00xx-semantic-foundation
  - ADR-00xx-governance-authority-semantics
  - ADR-00xx-resource-budget-host-pressure
  - ADR-00xx-rollout-posture

traps:
  - stale-ontology-term
  - summary-as-fact
  - retrieved-summary-as-authority
  - agent-overclaim
  - test-runner-unbounded-workers
  - watch-mode-left-running
  - browser-tests-without-resource-lease
  - memory-pressure-ignored-before-full-suite
  - secret-value-persisted
  - external-mutation-without-broker
```

## 4. Phase 1: discovery waves

### Wave 1A: semantic foundation

Run these as eight independent workers:

| ID            | Source family                                   | Worker question                                                                                 |
| ------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 1A-RDF        | W3C RDF 1.1 and RDF 1.2                         | What identifier and graph semantics matter if HCS adopts URI-shaped IDs?                        |
| 1A-OWL        | W3C OWL 2                                       | Which HCS relationships would benefit from formal class/property semantics?                     |
| 1A-SHACL      | W3C SHACL                                       | What validation semantics can be borrowed conceptually if implementation stays Zod/JSON Schema? |
| 1A-SKOS       | W3C SKOS                                        | How should controlled vocabularies, mappings, and deprecated terms behave?                      |
| 1A-PROV       | W3C PROV-DM / PROV-O                            | What minimum provenance vocabulary maps to `Evidence`, `Run`, `Artifact`, and `Decision`?       |
| 1A-JSONLD     | W3C JSON-LD 1.1                                 | What does optional `@context` add, and what commitments does it create?                         |
| 1A-JSONSCHEMA | JSON Schema Draft 2020-12                       | What is the validation/annotation split, and how should Ring 0 schemas use it?                  |
| 1A-VERSIONING | SemVer plus official schema/versioning guidance | How should entity schema, adapter, and policy versions compose?                                 |

### Wave 1B: governance semantics

| ID             | Source family               | Worker question                                                                          |
| -------------- | --------------------------- | ---------------------------------------------------------------------------------------- |
| 1B-OPA         | OPA/Rego official docs      | What belongs in policy evaluation versus schema validation?                              |
| 1B-AUDIT       | NIST logging/audit guidance | What minimum audit fields and retention posture should HCS require?                      |
| 1B-ACCESS      | NIST RBAC/ABAC guidance     | Which vocabulary best fits `Principal`, `Capability`, `ApprovalGrant`, and `Lease`?      |
| 1B-SUPPLYCHAIN | SLSA and Sigstore           | Should execution receipts align with provenance/attestation structures?                  |
| 1B-SECRETS     | 1Password and provider docs | How should `SecretReference` and broker receipts be typed without storing secret values? |

### Wave 1C: tool concurrency and resource pressure

This wave should run first if capacity is limited because it is the most version-sensitive.

| ID                  | Tool/platform                | Worker deliverable                                                             |
| ------------------- | ---------------------------- | ------------------------------------------------------------------------------ |
| 1C-VITEST           | Vitest                       | Current version, default pool/worker behavior, caps, watch mode, browser mode. |
| 1C-JEST             | Jest                         | Current version, `maxWorkers`, watch mode, open handles, worker threads.       |
| 1C-PYTEST           | pytest core and pytest-xdist | Core pytest default, xdist `-n auto`, caps, distribution modes.                |
| 1C-NODE             | Node.js                      | V8 heap flags, worker/threadpool limits, relevant env vars.                    |
| 1C-PLAYWRIGHT       | Playwright Test              | Workers, browser multiplication, `fullyParallel`, trace/video cost.            |
| 1C-GO               | Go test                      | `-p`, `-parallel`, `GOMAXPROCS`, race/coverage overhead.                       |
| 1C-CARGO            | Cargo test                   | `--jobs`, `--test-threads`, doctest behavior, workspace effects.               |
| 1C-GRADLE           | Gradle                       | `--max-workers`, daemon memory, `maxParallelForks`, worker daemons.            |
| 1C-PACKAGE-MANAGERS | npm, pnpm, bun               | Workspace fan-out, recursive execution, parallel/serial defaults.              |
| 1C-CONTAINERS       | Docker Desktop and OrbStack  | macOS container CPU/memory caps and host-pressure behavior.                    |

### Wave 1D: macOS host signals

| ID        | Source family                                                 | Worker question                                                                |
| --------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 1D-MEMORY | Apple Activity Monitor, dispatch memory pressure, macOS tools | Which memory-pressure signals should HCS record?                               |
| 1D-LIMITS | Apple `setrlimit`, `launchd`, shell limits                    | Which limits are enforceable, advisory, per-process, per-user, or per-session? |

## 5. Worker prompt template

Use this for ordinary discovery workers:

```text
You are a source-verified research worker for HCS.

WORKSTREAM: <A/B/C/D>
TASK_ID: <id>
SOURCE FAMILY: <official source family only>
QUESTIONS:
1. <question>
2. <question>

POTENTIALLY AFFECTED HCS TARGETS:
- <entity/ADR/trap names only>

RULES:
- Use official or primary sources only.
- Do not cite blogs, forums, Stack Overflow, AI summaries, or tutorials.
- Every claim must include source_class, version/date, observed_at, and either a short exact excerpt or tight paraphrase.
- Do not propose schema changes.
- Do not decide HCS policy.
- Report what the source says and what HCS target it might affect.
- If official sources do not answer the question, say so and create a research-debt item.

STOP CONDITIONS:
- Max 8 official URLs.
- One re-search if the first pass is empty.
- Escalate if current version cannot be determined.

OUTPUT:
- One result block per claim.
- Limits and unknowns.
- Research-debt items.
```

For Wave 1C, add this mandatory block:

```text
VERSION DISCIPLINE:
- Determine the latest stable version as of 2026-04-26 from official sources.
- Report version string, release date if available, doc date if visible, and observed_at.
- Every concurrency default must be tied to a version or doc version.
- If the current version cannot be determined from official sources, mark the task failed and escalate.
- Search release notes for changes to concurrency defaults in the last 24 months.
```

## 6. Verification pass

No discovery bundle moves to synthesis until this pass is clean.

| Gate               | Check                                                                            | Failure action                                 |
| ------------------ | -------------------------------------------------------------------------------- | ---------------------------------------------- |
| Citation re-fetch  | Re-fetch at least 30%, minimum 3 cited sources per worker.                       | Mark claim `conflicting` or `quarantined`.     |
| Source-class audit | Confirm every `official` source is actually controlled by the publisher/project. | Downgrade to `secondary` or `discovery`.       |
| Version-pin audit  | Require version/date for every 1C concurrency claim.                             | Return to worker.                              |
| Excerpt fidelity   | Confirm excerpt/paraphrase is faithful.                                          | Correct or quarantine.                         |
| Conflict log       | Flag contradictions across workers.                                              | Coordinator resolves in Phase 3, not verifier. |

Exit criteria: zero fabricated citations, zero unpinned 1C defaults, zero official-source misclassifications, all conflicts logged.

## 7. Phase 2: synthesis

Only the coordinator performs these.

### 2A: semantic stack proposal

Inputs: verified 1A reports plus the local HCS plan.

Expected output:

```text
Recommended Phase 1 semantic posture:
- Minimum stack:
- Controlled vocabularies:
- Identifier strategy:
- Relationship strategy:
- Provenance strategy:
- Deprecation model:
- Traps:
- ADR updates:
```

The likely hypothesis to test is **Option B with selective Option C**: Zod + JSON Schema + controlled vocabularies + provenance model, with optional JSON-LD `@context` only for entities likely to cross system boundaries. That is not an ADR conclusion yet; it is the candidate synthesis posture to validate.

### 2B: authority taxonomy

Inputs: verified 1B reports plus Covenant/Citadel governance inputs from the uploaded plan.

Expected output:

```text
Record authority classes:
- governance_authoritative
- policy_authoritative
- observation_authoritative
- receipt_authoritative
- human_decision
- agent_recommendation
- retrieved_context
- derived_summary
- unverified_coordination_fact

Gate eligibility:
- eligible:
- advisory_only:
- never_gate_input:

Required chain:
principle -> policy -> operation_shape -> approval/decision -> run -> artifact -> receipt/evidence
```

### 2C: resource ontology and budgets

Inputs: verified 1C and 1D reports.

Expected output:

```text
Confirmed/revised entities:
- ResourceBudget
- ResourceObservation
- WorkloadShape
- ExecutionLease

Workload taxonomy:
- test.unit.targeted
- test.unit.full
- test.browser
- test.integration.local
- test.integration.external
- test.watch
- build.typecheck
- lint
- benchmark
- package_install
- model_inference
- container_workload

Budget defaults:
- host reserve:
- per-session default:
- full-suite lease:
- browser-suite lease:
- watch-mode policy:
- high-pressure behavior:
```

Do not set numeric budgets from assumptions alone. Numbers need either host observation or a clearly labeled provisional policy.

## 8. Phase 3: integration outputs

Draft in this order:

1. **ADR 00xx: HCS semantic foundation and ontology validation posture**
2. **ADR 0009 amendment**, only if versioning findings require it
3. **ADR 00xx: Governance authority semantics**
4. **ADR 00xx: ResourceBudget and host-pressure semantics**
5. **Ring 0 schema requirements**
6. **Ring 1 resource broker behavior**
7. **Ring 2 dashboard/CLI behavior**
8. **Ring 3 runbook**
9. **Trap specifications**

Each trap gets:

```yaml
trap_id:
signal_observed:
decision_boundary:
evidence_required:
source_claims:
affected_entities:
severity:
default_action:
override_path:
receipt_emitted:
```

## 9. Rollout posture

Use five stages:

| Stage | Mode                   | Entry criterion                           | Exit criterion                                                |
| ----- | ---------------------- | ----------------------------------------- | ------------------------------------------------------------- |
| 1     | Passive observation    | Host sampler and process inventory exist. | Observations are recorded without destabilizing host.         |
| 2     | Repo profile discovery | Tool detectors exist.                     | Each repo has declared targeted/full commands and known caps. |
| 3     | Advisory gate          | Workload shapes can be classified.        | Warnings are accurate and not noisy.                          |
| 4     | Lease gate             | Active workload accounting exists.        | Full/browser suites require lease unless overridden.          |
| 5     | Broker enforcement     | Command renderer is trusted.              | Agents receive capped command shapes and receipts by default. |

Hard blocks should start only for severe cases: secret persistence, external mutation without broker/approval, browser/full-suite execution during red memory pressure, and unbounded worker fan-out when a safe cap is known.

## 10. First concrete next action

Start with **Wave 1C + Wave 1D**, not semantics. The resource-pressure work is the most version-sensitive and has the clearest operational payoff for HCS. The first batch should be:

```text
1C-VITEST
1C-JEST
1C-PYTEST
1C-NODE
1C-PLAYWRIGHT
1C-GO
1C-CARGO
1C-GRADLE
1D-MEMORY
1D-LIMITS
```

The coordinator should not synthesize budgets until those ten reports pass verification.

[1]: https://www.w3.org/TR/rdf12-concepts/ "RDF 1.2 Concepts and Abstract Data Model"
[2]: https://json-schema.org/specification "JSON Schema - Specification [#section]"
[3]: https://opentelemetry.io/docs/specs/semconv/ "OpenTelemetry semantic conventions 1.40.0 | OpenTelemetry"
[4]: https://openpolicyagent.org/docs "Open Policy Agent (OPA) | Open Policy Agent"
[5]: https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac "View memory usage in Activity Monitor on Mac - Apple Support"
[6]: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/setrlimit.2.html "Mac OS X Developer Tools
 Manual Page For setrlimit(2)"
[7]: https://vitest.dev/config/maxworkers "maxWorkers | Config | Vitest"
[8]: https://jestjs.io/docs/cli "Jest CLI Options · Jest"
[9]: https://playwright.dev/docs/test-parallel?utm_source=chatgpt.com "Parallelism"
[10]: https://pkg.go.dev/cmd/go "go command - cmd/go - Go Packages"
[11]: https://doc.rust-lang.org/cargo/commands/cargo-test.html "cargo test - The Cargo Book"
[12]: https://docs.gradle.org/current/userguide/command_line_interface.html?utm_source=chatgpt.com "Command-Line Interface"
[13]: https://docs.orbstack.dev/settings "Settings · OrbStack Docs"
