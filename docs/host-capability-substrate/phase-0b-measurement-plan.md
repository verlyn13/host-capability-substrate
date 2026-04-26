---
title: HCS Phase 0b — Measurement Workplan
category: plan
component: host_capability_substrate
status: active
version: 1.2.2
last_updated: 2026-04-26
tags: [phase-0b, measurement, baseline, metrics, traps, governance-inventory, idempotency, supplementary-rubric, guidance-load, semantic-redundancy, scanner-parity]
priority: high
---

# HCS Phase 0b — Measurement Workplan

Quantifies the economic and governance baseline before any substrate code ships. The current repo execution window is a **3-day soak from 2026-04-23 through 2026-04-25**, with closeout on 2026-04-26. It produces the numeric evidence the Phase 3 acceptance criteria will be measured against (≥50% reduction in redundant `--help` probes across agents, top-10 probed tools).

Parent: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` (v0.3.0+) §6 Phase 0b, §22.11.
Charter: [`implementation-charter.md`](./implementation-charter.md) v1.2.0+.
Boundary decision: [`adr/0001-repo-boundary.md`](./adr/0001-repo-boundary.md).

## v1.2.2 revision note

v1.2.2 adds advisory scanner coverage for trap #37
`process-argv-secret-exposure` and trap #38
`cloudflare-mcp-mutation-without-fanout-check`. These are measurement-side
candidate detectors, not substitutes for the Phase 1 typed process-inspection
operation or broker-backed Cloudflare fan-out fixture.

`measure-traps.sh` now accepts `HCS_TRAP_FILE_LIST` for fixture-driven tests,
and `just trap-fixture` is wired into `just verify`.

## v1.2.1 revision note

v1.2.1 retires the literal-tool-name redundancy limitation in the measurement
layer. `measure-redundancy.sh` now emits `semantic-tool-map-v1`, aggregating a
small set of known cross-client aliases such as `Bash`/`exec_command`,
`TaskUpdate`/`update_plan`, `AskUserQuestion`/`request_user_input`, and matching
Runpod MCP aliases. Raw tool names remain preserved on every row for audit.

`measure-brief.sh` now selects the newest partition with a redundancy summary,
so a current semantic-map run is not shadowed by older name-only partitions. A
new `redundancy-fixture` recipe is wired into `just verify` to assert the
semantic map continues to report at least three cross-source capabilities.

This is a Phase 0b measurement fix only. Formal capability ontology and policy
schema work remains a Phase 1 concern.

## v1.2.0 revision note

v1.2.0 adds three supplementary measurement surfaces on top of v1.1.1 without
modifying the existing collectors or the primary acceptance gate. All three
are post-hoc analyses that read raw cross-agent transcripts already staged in
`.logs/phase-0/<partition>/raw/cross-agent/` and are safe to run during an
active soak without contaminating captured data:

1. **Extended (supplementary) rubric** (`measure-extended-rubric.sh` →
   `cross-agent-runs-extended.jsonl`). Heuristic scoring on three additional
   dimensions — `derivability_check`, `mutation_snapshot_intent`,
   `upstream_spec_provenance`. Uses null/applicable gating so the pass rate
   is computed only over dimensions the transcript triggered. Supplementary,
   not a replacement for the six-dim primary rubric.
2. **Guidance-load classification** (`measure-guidance-load.sh` →
   `cross-agent-guidance-load.jsonl`). Textual-reference extractor over raw
   transcripts, cross-joined with `cross-agent-runs.jsonl`, producing a
   three-way split (`loaded` / `loaded_behavior_divergent` / `unread`).
   Resolves the v1.1.1 acceptance ambiguity "Claude Code + Codex both load
   expected guidance → mixed".
3. **Known-limitations metadata for traps**
   (`packages/evals/regression/trap-known-limitations.yaml`). Annotates the
   brief's Trap observations table so raw hit counts from known-lossy
   heuristics (`shell-mode-confusion-login` FP-heavy; `brew-cask-escalation-missed`
   hard-capped at 50) are not read as true incident counts.

`measure-brief.sh` invokes the first two as pre-aggregation steps and reads
the third to annotate the trap table. Canonical session selection is driven
by `raw/source-manifest.jsonl` with `VARIANT_PREFERENCE` = (rollout-copy,
repo-root-copy, export-home, export-tmp) so duplicates across export variants
collapse to exactly one record per (agent, prompt_id). The manifest schema
is documented separately in
[`phase-0b-source-manifest-schema.md`](./phase-0b-source-manifest-schema.md);
consumers also carry a filesystem-walk fallback that infers variants from
path shape when the manifest is absent.

## v1.1.1 revision note

v1.1.1 aligns the repo plan and automation with the current **3-day soak** that starts on **2026-04-23**. The upstream research plan still describes Phase 0b in week-scale language; this repo is executing a compressed initial soak against the same artifact set. If day 3 does not yield a clean go/no-go, the soak extends rather than the acceptance gate being relaxed.

## v1.1.0 revision note

v1.0.0 of this plan described aspirational behaviour (acceptance artifacts `redundancy.jsonl`, `tokens-estimate.json`, consolidation brief) that the initial scripts did not generate. v1.0.0 also claimed idempotency while the scripts were append-only, corrupting any re-run within a day. v1.1.0 fixes the implementation to match the contract: snapshot semantics, acceptance artifacts produced end-to-end, correct log-source paths, provenance fields in trap records, and JSON parsing where regex was fragile. See [`phase-0b-self-review.md`](./phase-0b-self-review.md) v1.1.0 for the full acknowledgement of the v1.0.0 issues and the fixes applied.

## Current execution window

- Kickoff battery: 2026-04-23 via `just day1`
- Daily soak captures: 2026-04-23, 2026-04-24, 2026-04-25 via `just measure`
- Closeout: 2026-04-26 via `just measure-brief`
- Status checks: `just soak-status`
- Extension rule: if the April 23-25 window is inconclusive, extend the soak; do not reinterpret misses as passes

## Goals (per research plan §6 Phase 0b)

1. **Activity audit.** Count `--help` invocations, version probes, toolchain resolution commands, host-state probes, raw shell invocations across 5 clients.
2. **Redundancy measurement.** Same-tool-different-source counts per partition.
3. **Token-cost estimate.** `tokens/day/host` heuristic (char/4) across all observed sources.
4. **Hallucination-trap audit.** Observed stale-CLI-memory patterns; expand seed corpus to ≥15 entries.
5. **Governance-surface inventory.** Current hooks, tier classifications, `policies/`, runbook prose, hard-coded command lists, chezmoi wrappers, 1P reference manifests.
6. **1Password migration reconciliation.** Confirm `docs/secrets.md` v2.1.0 authoritative; flag any residue.
7. **Client identity mechanism.** Per-host `InitializeRequest.clientInfo` probing (fully resolved in Phase 1 Thread B echo MCP server).
8. **Protocol feature matrix.** Per-host MCP stdio, Streamable HTTP, structured outputs, resources, prompts, elicitation, subagent scoping.
9. **Cross-agent manual simulation.** Structured rubric scores and feedback items for the 8 prompt battery across the agents actually exercised during the soak.

## Principles

- **Snapshot semantics (idempotent).** Each script calls `snapshot_begin()` for every output file at the start of its run, truncating to empty. Subsequent `jsonl_append()` calls build the current snapshot. Re-running the same day replaces the partition's snapshot. Cross-day deltas are computed by diffing consecutive day-partition totals; the partition itself always holds the current state.
- **Read-only.** No script writes to `~/.claude/`, `~/.codex/`, `~/.cursor/`, `~/.codeium/windsurf/`, `~/.copilot/`, or any IDE-owned path. Codex SQLite is opened `file:...?mode=ro`.
- **Output-locally-only.** Artifacts go to `.logs/phase-0/` (gitignored). Never committed. `scripts/ci/no-runtime-state-in-repo.sh` enforces.
- **Privacy-redacting.** Raw user prompts, LLM responses, and secret-like patterns redacted before any observation hits disk. `redact()` supports self-test via `redact_self_test` in `measure-common.sh`.
- **7-day window.** File sources are bounded by `find -mtime -7` so scans complete in under two minutes even on hosts with thousands of transcripts. BSD find is the assumed default on macOS; `-newermt "@UNIX_TS"` is NOT used.
- **Fail-open on missing source.** Each missing source writes a `status: source-unavailable` record and continues. Claude Desktop session-dir unreadable emits `status: tcc_unknown` (first-class result; never silent skip).

## Available local sources (verified)

Surveyed 2026-04-22 on this host (rich sources first):

| Source | Path | Shape | Signal quality |
|--------|------|-------|----------------|
| Claude Code transcripts | `~/.claude/projects/<slug>/<uuid>.jsonl` | JSONL; `assistant.message.content[]` has `tool_use` items with `name` | **RICH** — tool-use shape per tool name |
| Claude Code history | `~/.claude/history.jsonl` | JSONL (`display`, `pastedContents`, `timestamp`, `project`) | Prompt volume; probe-proxy mentions only |
| Claude Code sessions | `~/.claude/sessions/*.json` | pid+sessionId metadata only | **File count shape only** — NOT tool-use |
| Codex rollouts | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (paths via `threads.rollout_path`) | JSONL (`timestamp`, `type`, `payload`); `type=response_item, payload.type=function_call, payload.name` | **RICH** — function-call counts per tool name |
| Codex state | `~/.codex/state_5.sqlite` (read-only WAL) | `threads`, `agent_jobs`, `thread_dynamic_tools` | Thread-level aggregates + tokens_used column |
| Codex logs | `~/.codex/logs_2.sqlite` (read-only WAL) | `logs(target, level, feedback_log_body, ts, ...)` | Infra-level logger signals only; no command text |
| Cursor logs | `~/Library/Application Support/Cursor/logs/<timestamp>/` | VS Code-style window-scoped rotating | Volume shape only |
| Windsurf logs | `~/Library/Application Support/Windsurf/` | VS Code-style | Volume shape only |
| Claude Desktop | `~/Library/Application Support/Claude/claude-code-sessions/` | Accessible iff Claude Desktop has FDA | Volume shape only when readable; `tcc_unknown` otherwise |
| Copilot CLI | `~/.copilot/logs/`, `command-history-state.json`, `session-state/` | Mixed | Volume shape only |

Per-host protocol-feature-capability probing (MCP `clientInfo`, elicitation, primitives) requires a live MCP exchange with a throwaway echo server — **this is a Phase 1 Thread B deliverable**, not Phase 0b.

## Scripts

Under `scripts/dev/`. All read-only, all snapshot-overwrite their partition outputs, all source `measure-common.sh` for shared helpers.

| Script | Writes | What it measures |
|--------|--------|------------------|
| `measure-common.sh` | (sourced) | shared `snapshot_begin`, `jsonl_append`, `redact`, `count_matches`, `first_match`, `iso_now`, `script_banner` |
| `measure-claude-code.sh` | `activity-claude-code.jsonl` | Prompt volume; **tool-use counts per tool name from 7-day transcripts**; assistant-content-shape; probe-proxy mentions; session file count (shape only) |
| `measure-codex.sh` | `activity-codex.jsonl` | Thread counts (total + recent 7d) + tokens_used; **function-call counts per tool name from 7-day rollouts**; dynamic-tool registration counts |
| `measure-ide-hosts.sh` | `activity-ide-hosts.jsonl` | Log volume shape for Cursor, Windsurf, Claude Desktop, Copilot CLI |
| `measure-traps.sh` | `traps.jsonl` | 17 currently-instrumented trap patterns scanned across 7-day file sources; **per-hit records with `source`, `file`, `line`, `evidence_redacted`, `severity`**; `__summary__` record with totals |
| `measure-governance-inventory.sh` | `governance-inventory.jsonl` | Claude Code + Codex user-scope + HCS-project-scope settings; system-config policies; HCS snapshot fixture; chezmoi MCP wrappers; **MCP baseline servers parsed via `jq`** (not regex); secrets policy version; runbook docs versions; 1P reference manifests |
| `measure-protocol-features.sh` | `protocol-features.json` | Per-host (6) MCP feature matrix with probe-required fields marked |
| `measure-redundancy.sh` | `redundancy.jsonl` | Cross-source redundancy: same semantic tool capability surfaced by ≥2 distinct sources in partition, using `semantic-tool-map-v1` while preserving raw tool names |
| `measure-tokens-estimate.sh` | `tokens-estimate.json` | Char-based tokens estimate (char/4 heuristic); per-source + totals |
| `measure-commands.sh` | `commands.jsonl` | Per-command extraction from Claude Code `Bash` calls and Codex `exec_command` rollouts |
| `measure-classify.sh` | `classify.jsonl` | Post-hoc classification of extracted commands via `classify.py` |
| `measure-confusion.sh` | `confusion-matrix.json` | Honest Phase 0b `source × classified_class` aggregate plus unknown/forbidden highlights |
| `measure-partition-summary.sh` | (stdout) | Human-readable summary of today's partition |
| `measure-brief.sh` | `.logs/phase-0/brief.md`, `.logs/phase-0/brief.json` | **Consolidates all partitions** into acceptance-gate table + trap aggregate + top-tools + redundancy summary + tokens total + extended-rubric supplementary + guidance-load classification + hook-decision attribution. Invokes `measure-extended-rubric.sh` and `measure-guidance-load.sh` as pre-aggregation steps. |
| `measure-extended-rubric.sh` (v1.2.0) | `cross-agent-runs-extended.jsonl` (per partition) | Post-hoc heuristic scoring on 3 supplementary dims (`derivability_check`, `mutation_snapshot_intent`, `upstream_spec_provenance`). Manifest-driven canonical-session selection; null/applicable gating. |
| `measure-guidance-load.sh` (v1.2.0) | `cross-agent-guidance-load.jsonl` (per partition) | Textual-reference extractor over raw transcripts; three-way classification (`loaded` / `loaded_behavior_divergent` / `unread`) cross-joined with `cross-agent-runs.jsonl`. |
| `record-cross-agent-run.sh` | `cross-agent-runs.jsonl` | Manual prompt-battery scoring record, one row per `(prompt, agent)` run |
| `record-cross-agent-feedback.sh` | `cross-agent-feedback.jsonl` | Structured feedback items opened from cross-agent prompt misses |

### Orchestration

- `just measure` — runs 11 data/transform scripts + partition-summary
- `just measure-summary` — prints today's partition summary
- `just measure-brief` — aggregates all partitions into `brief.md` + `brief.json`
- `just redundancy-fixture` — regression test for semantic tool mapping
- `just trap-fixture` — regression test for measurement-side trap heuristics
- `just day1` — runs the kickoff battery (`measure`, fixtures, over-fire, under-fire, faults, dashboard rehearsal)
- `just verify` includes `shellcheck-scan` as of v1.1.0

Measurement runtime on this host: **~60 seconds** per `just measure` pass (7-day file-window scope keeps the trap scan tractable across ~5k transcripts).

## Output schema

Per-run partition: `.logs/phase-0/<YYYY-MM-DD>/`

| File | Shape | Records |
|------|-------|---------|
| `activity-claude-code.jsonl` | `{ts, source, category, ...}` | prompt-volume, probe-proxy-mentions, metadata-file-count, transcript-volume, event-type-shape, assistant-content-shape, tool-use-shape |
| `activity-codex.jsonl` | `{ts, source, category, ...}` | thread-counts, rollout-volume, event-type-shape, response-item-shape, function-call-shape, dynamic-tool-registration |
| `activity-ide-hosts.jsonl` | `{ts, source, category, ...}` | log-volume-shape per host |
| `traps.jsonl` | `{ts, trap_name, source, file, line, evidence_redacted, severity}` + `__summary__` | per-hit provenance records |
| `governance-inventory.jsonl` | `{ts, category, path, kind, excerpt}` | per-artifact records |
| `protocol-features.json` | per-host capability matrix | 6 hosts, probe-required marks |
| `redundancy.jsonl` | `{ts, tool, semantic_tool, semantic_label, semantic_mapping_version, raw_tools, sources, count_by_source, count_by_raw_tool, total, cross_source}` + `__summary__` | per-semantic-tool cross-source records; `unique_tools_observed` remains raw-name count, `unique_semantic_tools_observed` is the mapped capability count |
| `tokens-estimate.json` | per-source + totals | back-of-envelope (char/4) |
| `commands.jsonl` | `{ts, source, transcript|rollout, line, tool_name, command, description?, cwd}` | per-shell-command extraction records |
| `classify.jsonl` | command record + classifier fields | per-command class, reason, first token, segments |
| `confusion-matrix.json` | aggregate JSON | `source × classified_class`, unknown-first-token clusters, overblock/parse-error gates |
| `cross-agent-runs.jsonl` | `{ts, schema_version, agent, prompt_id, ..., score, feedback_required}` | manual prompt battery scoring rows |
| `cross-agent-feedback.jsonl` | `{ts, schema_version, feedback_id, agent, prompt_id, severity, ...}` | manual feedback rows opened from prompt misses |
| `cross-agent-runs-extended.jsonl` | `{ts, schema_version, agent, prompt_id, session_ref, derivability_check, mutation_snapshot_intent, upstream_spec_provenance, applicable_dims[], supplementary_score, supplementary_score_max, evidence[]}` | heuristic supplementary-rubric per session (v1.2.0+) |
| `cross-agent-guidance-load.jsonl` | `{ts, schema_version, agent, prompt_id, session_ref, references[], references_by_type, reference_count, classification, paired_run?}` | guidance-load classification per session (v1.2.0+) |

Consolidated brief (at `.logs/phase-0/brief.md` + `brief.json`):
- acceptance-gate table
- tool-use totals aggregated across partitions
- trap observations by class with source distribution
- tokens estimate aggregate
- cross-source semantic redundancy summary
- governance inventory volume per partition
- cross-agent prompt-run and feedback summary when present

**Redaction rules (`redact()` in measure-common.sh):**

Applied to all text before it reaches disk. Covered: `sk-[A-Za-z0-9]{20,}`, `ghp_[A-Za-z0-9]{20,}`, `github_pat_[A-Za-z0-9_]{20,}`, `xoxb-…`, `AKIA[0-9A-Z]{16}`, `Bearer [A-Za-z0-9._-]+`, `op://…`, JWT 3-parter pattern, email addresses, `~/Documents|~/Desktop|~/Downloads|~/Library/Mail` paths. Long free-form text is truncated to 160 chars with an 8-char sha256 fingerprint suffix for dedup. Self-tested via `redact_self_test` helper.

## Cadence

- **2026-04-23:** `just day1` — kickoff battery + first partition
- **2026-04-23 to 2026-04-25:** run the 8 cross-agent prompts per [`phase-0b-cross-agent-prompts.md`](./phase-0b-cross-agent-prompts.md), recording both scores and feedback
- **2026-04-24 to 2026-04-25:** `just measure` — daily capture, then `just soak-status`
- **2026-04-26:** `just measure-brief` — consolidate the 3-day soak into `brief.md`
- **Phase 0b acceptance gate:** the brief acceptance-gate table shows all criteria met

## Acceptance checklist

Rendered as a table in the brief. All must be checked:

- [ ] Three consecutive days of partition data captured in the April 23-25, 2026 window
- [ ] All 5 primary clients represented: Claude Code, Codex, Cursor, Windsurf, Copilot CLI (Claude Desktop opportunistic)
- [ ] Redundancy analysis shows cross-source overlap for ≥3 semantic tool capabilities under `semantic-tool-map-v1`; raw tool names are preserved for audit and unmapped tools retain literal-name semantics.
- [ ] `tokens-estimate.json` present with a concrete `totals.estimated_tokens` number
- [ ] Seed regression corpus has ≥15 trap classes; observed hit counts may be lower than the seed size during the soak window
- [ ] `governance-inventory.jsonl` enumerates user-global + HCS-project Claude settings, subagents, Codex config, system-config policies, chezmoi MCP wrappers, MCP baseline (jq-parsed, not regex), 1P reference manifests
- [ ] `protocol-features.json` present for Claude Code, Codex, Cursor, Windsurf, Copilot CLI, Claude Desktop
- [ ] 1Password reconciliation: `docs/secrets.md` v2.1.0 confirmed; any gopass residue enumerated
- [ ] Client-identity probe deferred to Phase 1 Thread B (echo MCP server)

## Known limitations

These are documented constraints, not undisclosed gaps:

- **Semantic redundancy map is intentionally small.** `semantic-tool-map-v1` covers known aliases needed for Phase 0b acceptance, but it is not the final substrate ontology or policy schema. Unmapped tools retain literal-name semantics until Phase 1 formalizes capability identity.
- **Token counting is char/4 heuristic.** Accurate tokenization would require a live model tokenizer; the heuristic is adequate for baseline order-of-magnitude.
- **Trap scan window is 7 days.** Catches current habits; does not back-fill older history. Stale-but-not-used patterns in transcripts >7 days old are ignored.
- **Trap scanner coverage is narrower than the seed corpus.** `packages/evals/regression/seed.md` carries 38 seed traps, while `measure-traps.sh` currently instruments 17 heuristics. The acceptance gate counts the committed seed corpus; scanner expansion remains follow-up work.
- **IDE host signal is volume-only.** Cursor, Windsurf, Claude Desktop, Copilot CLI transcripts are VS Code-style rotating log dirs or binary blobs; we cannot extract per-tool-call signal without live MCP instrumentation. Phase 1 Thread B (echo MCP server) resolves this.
- **Claude Code session metadata is pid-only.** `~/.claude/sessions/*.json` contains `pid`, `sessionId`, `cwd`, `startedAt` — not tool-use records. Records file count only.
- **Codex SQLite `logs` table has no command-text column.** Used only for infra-level logger signals; real command activity comes from rollouts (which this script parses correctly).

## Risks and missing access

| Risk | Mitigation |
|------|------------|
| Session logs have ephemeral retention on some clients (e.g., Cursor rotates logs every N days) | Capture early, daily cadence |
| Raw session content may leak user/project secrets into observations | Aggressive redaction at source; `.logs/` gitignored; `scripts/ci/no-runtime-state-in-repo.sh` + `no-live-secrets.sh` enforce |
| TCC denials on Claude Desktop session directory | `tcc_unknown` as first-class result; does not silently skip |
| Codex SQLite WAL may be in flight; reads might see partial state | Use `?mode=ro`; treat counts as snapshot-at-moment |
| Observer effect — knowing we're measuring might alter behaviour | Acceptable; substrate exists to improve behaviour; measurement captures pre-change state |

## Producer / critic split

Per research plan §22.5 producer/critic loop:

- **Producer:** Opus 4.7 drafted this plan + scripts.
- **Critic:** critique logged in [`phase-0b-self-review.md`](./phase-0b-self-review.md) v1.1.0 (including the externally-received P1/P2 critique that produced this v1.1.0 revision).
- **Human approval:** required before the first day's soak formally begins.

## Deliverables at end of Phase 0b

Under `.logs/phase-0/` (gitignored — summary lifted into committed `phase-0b-brief.md`):

- `brief.md` + `brief.json` — consolidated 3-day soak acceptance report
- Governance inventory catalogued
- Protocol feature matrix complete (with probe-required fields deferred to Phase 1 Thread B)
- Trap corpus expanded
- Cross-agent prompt battery scored, with structured feedback logged for every meaningful miss
- Phase 1 thread briefs seeded with measurement input

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.2.2 | 2026-04-26 | Added advisory trap scanner heuristics for #37 and #38, fixture-list injection for `measure-traps.sh`, and `just trap-fixture` in `just verify`. |
| 1.2.1 | 2026-04-26 | Added `semantic-tool-map-v1` to `measure-redundancy.sh`, preserved raw tool names per row, changed `measure-brief.sh` to use the newest redundancy partition, and wired `just redundancy-fixture` into `just verify`. |
| 1.2.0 | 2026-04-23 | Added three post-hoc supplementary surfaces (all measurement-safe during an active soak): (1) `measure-extended-rubric.sh` emits `cross-agent-runs-extended.jsonl` with heuristic scoring on `derivability_check`, `mutation_snapshot_intent`, `upstream_spec_provenance` using null/applicable gating; (2) `measure-guidance-load.sh` emits `cross-agent-guidance-load.jsonl` with three-way classification (`loaded` / `loaded_behavior_divergent` / `unread`) cross-joined with `cross-agent-runs.jsonl`; (3) `packages/evals/regression/trap-known-limitations.yaml` annotates trap hits with known false-positive and cap semantics. `measure-brief.sh` renders Extended rubric, Guidance-load classification, and Hook-decision attribution sections, annotates the Trap table from the known-limitations yaml, and invokes the two new scripts as pre-aggregation steps. Canonical-session selection is driven by `raw/source-manifest.jsonl` with variant preference (`rollout-copy` > `repo-root-copy` > `export-home` > `export-tmp`) so session duplicates collapse to exactly one record per `(agent, prompt_id)`. Seed-trap corpus bumped from 15 to 17 (`ignored-but-load-bearing-deletion`, `harness-config-boolean-type`). |
| 1.1.1 | 2026-04-23 | Aligned the repo plan to the active 3-day soak window (2026-04-23 through 2026-04-25, closeout 2026-04-26). Documented the full `just measure` pipeline (`commands`, `classify`, `confusion`) and clarified that the seed trap corpus has 15 entries while the current scanner instruments 12 heuristics. |
| 1.1.0 | 2026-04-22 | Corrected after external P1/P2 critique. Switched to true snapshot semantics (`snapshot_begin()` truncates per-file at start of each run); added the 3 missing acceptance artifact scripts (`measure-redundancy.sh`, `measure-tokens-estimate.sh`, `measure-brief.sh`); rewrote `measure-claude-code.sh` to parse `~/.claude/projects/*/*.jsonl` (the actual tool-use source; prior version pointed at pid-metadata JSON files that contained no tool-use data); rewrote `measure-codex.sh` to parse `~/.codex/sessions/*/rollout-*.jsonl` function-call records (prior version measured logger-module signal only); added per-hit provenance (`source`, `file`, `line`, `evidence_redacted`) to `traps.jsonl`; switched MCP baseline parsing from regex to `jq` (fixes false `env` server entry); expanded governance inventory scope to chezmoi wrappers + runbook docs + 1P reference manifests; added `scripts/ci/shellcheck-scan.sh` and wired into `just verify`; fixed BSD find `-newermt` incompatibility (switched to `-mtime -7`); fixed grep-exit-on-no-match breaking scripts under `set -euo pipefail`; scoped trap scan to 7-day file window (was iterating all ~5k transcripts × 12 patterns). |
| 1.0.0 | 2026-04-22 | Initial. Aspirational; superseded by v1.1.0 after P1/P2 critique found idempotency, missing-acceptance-artifacts, wrong-log-source, and provenance-dropping issues. |
