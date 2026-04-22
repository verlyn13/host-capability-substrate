---
title: HCS Phase 0b — Measurement Workplan
category: plan
component: host_capability_substrate
status: active
version: 1.1.0
last_updated: 2026-04-22
tags: [phase-0b, measurement, baseline, metrics, traps, governance-inventory, idempotency]
priority: high
---

# HCS Phase 0b — Measurement Workplan

Quantifies the economic and governance baseline before any substrate code ships. Runs for ~7 days; produces the numeric evidence the Phase 3 acceptance criteria will be measured against (≥50% reduction in redundant `--help` probes across agents, top-10 probed tools).

Parent: [`host-capability-substrate-research-plan.md`](../host-capability-substrate-research-plan.md) (v0.3.0+) §6 Phase 0b, §22.11.
Charter: [`implementation-charter.md`](./implementation-charter.md) v1.1.0+.
Boundary decision: [`0001-repo-boundary-decision.md`](./0001-repo-boundary-decision.md) v1.1.0+.

## v1.1.0 revision note

v1.0.0 of this plan described aspirational behaviour (acceptance artifacts `redundancy.jsonl`, `tokens-estimate.json`, consolidation brief) that the initial scripts did not generate. v1.0.0 also claimed idempotency while the scripts were append-only, corrupting any re-run within a day. v1.1.0 fixes the implementation to match the contract: snapshot semantics, acceptance artifacts produced end-to-end, correct log-source paths, provenance fields in trap records, and JSON parsing where regex was fragile. See [`phase-0b-self-review.md`](./phase-0b-self-review.md) v1.1.0 for the full acknowledgement of the v1.0.0 issues and the fixes applied.

## Goals (per research plan §6 Phase 0b)

1. **Activity audit.** Count `--help` invocations, version probes, toolchain resolution commands, host-state probes, raw shell invocations across 5 clients.
2. **Redundancy measurement.** Same-tool-different-source counts per partition.
3. **Token-cost estimate.** `tokens/day/host` heuristic (char/4) across all observed sources.
4. **Hallucination-trap audit.** Observed stale-CLI-memory patterns; expand seed corpus to ≥15 entries.
5. **Governance-surface inventory.** Current hooks, tier classifications, `policies/`, runbook prose, hard-coded command lists, chezmoi wrappers, 1P reference manifests.
6. **1Password migration reconciliation.** Confirm `docs/secrets.md` v2.1.0 authoritative; flag any residue.
7. **Client identity mechanism.** Per-host `InitializeRequest.clientInfo` probing (fully resolved in Phase 1 Thread B echo MCP server).
8. **Protocol feature matrix.** Per-host MCP stdio, Streamable HTTP, structured outputs, resources, prompts, elicitation, subagent scoping.

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
| `measure-traps.sh` | `traps.jsonl` | 12 trap patterns scanned across 7-day file sources; **per-hit records with `source`, `file`, `line`, `evidence_redacted`, `severity`**; `__summary__` record with totals |
| `measure-governance-inventory.sh` | `governance-inventory.jsonl` | Claude Code + Codex user-scope + HCS-project-scope settings; system-config policies; HCS snapshot fixture; chezmoi MCP wrappers; **MCP baseline servers parsed via `jq`** (not regex); secrets policy version; runbook docs versions; 1P reference manifests |
| `measure-protocol-features.sh` | `protocol-features.json` | Per-host (6) MCP feature matrix with probe-required fields marked |
| `measure-redundancy.sh` | `redundancy.jsonl` | Cross-source redundancy: same tool name surfaced by ≥2 distinct sources in partition |
| `measure-tokens-estimate.sh` | `tokens-estimate.json` | Char-based tokens estimate (char/4 heuristic); per-source + totals |
| `measure-partition-summary.sh` | (stdout) | Human-readable summary of today's partition |
| `measure-brief.sh` | `.logs/phase-0/brief.md`, `.logs/phase-0/brief.json` | **Consolidates all partitions** into acceptance-gate table + trap aggregate + top-tools + redundancy summary + tokens total |

### Orchestration

- `just measure` — runs 9 data-collection scripts + partition-summary
- `just measure-summary` — prints today's partition summary
- `just measure-brief` — aggregates all partitions into `brief.md` + `brief.json`
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
| `redundancy.jsonl` | `{ts, tool, sources, count_by_source, total, cross_source}` + `__summary__` | per-tool cross-source records |
| `tokens-estimate.json` | per-source + totals | back-of-envelope (char/4) |

Consolidated brief (at `.logs/phase-0/brief.md` + `brief.json`):
- acceptance-gate table
- tool-use totals aggregated across partitions
- trap observations by class with source distribution
- tokens estimate aggregate
- cross-source redundancy summary
- governance inventory volume per partition

**Redaction rules (`redact()` in measure-common.sh):**

Applied to all text before it reaches disk. Covered: `sk-[A-Za-z0-9]{20,}`, `ghp_[A-Za-z0-9]{20,}`, `github_pat_[A-Za-z0-9_]{20,}`, `xoxb-…`, `AKIA[0-9A-Z]{16}`, `Bearer [A-Za-z0-9._-]+`, `op://…`, JWT 3-parter pattern, email addresses, `~/Documents|~/Desktop|~/Downloads|~/Library/Mail` paths. Long free-form text is truncated to 160 chars with an 8-char sha256 fingerprint suffix for dedup. Self-tested via `redact_self_test` helper.

## Cadence

- **Daily:** `just measure` — runs in ~60s, writes today's partition
- **End of week 1:** `just measure-brief` — consolidates all partitions into `brief.md`
- **Phase 0b acceptance gate:** the brief acceptance-gate table shows all seven criteria met

## Acceptance checklist

Rendered as a table in the brief. All must be checked:

- [ ] Seven consecutive days of partition data captured
- [ ] All 5 primary clients represented: Claude Code, Codex, Cursor, Windsurf, Copilot CLI (Claude Desktop opportunistic)
- [ ] Redundancy analysis shows cross-source overlap for ≥3 tool patterns. **Caveat:** redundancy is matched by tool name only; tools with different names but equivalent semantics (e.g., `Bash` vs `exec_command`) do NOT count as redundant under the current definition. See "Known limitations" below.
- [ ] `tokens-estimate.json` present with a concrete `totals.estimated_tokens` number
- [ ] Trap corpus has ≥15 distinct trap classes (seed lists 15; measurement may trim or expand based on observed patterns)
- [ ] `governance-inventory.jsonl` enumerates user-global + HCS-project Claude settings, subagents, Codex config, system-config policies, chezmoi MCP wrappers, MCP baseline (jq-parsed, not regex), 1P reference manifests
- [ ] `protocol-features.json` present for Claude Code, Codex, Cursor, Windsurf, Copilot CLI, Claude Desktop
- [ ] 1Password reconciliation: `docs/secrets.md` v2.1.0 confirmed; any gopass residue enumerated
- [ ] Client-identity probe deferred to Phase 1 Thread B (echo MCP server)

## Known limitations

These are documented constraints, not undisclosed gaps:

- **Semantic redundancy undercounted.** Cross-source redundancy by tool name treats `Bash` (Claude Code) and `exec_command` (Codex) as distinct, even though they represent the same capability. A name-mapping layer to detect semantic redundancy is substrate-layer work (Phase 1 Thread D policy schema) — not Phase 0b.
- **Token counting is char/4 heuristic.** Accurate tokenization would require a live model tokenizer; the heuristic is adequate for baseline order-of-magnitude.
- **Trap scan window is 7 days.** Catches current habits; does not back-fill older history. Stale-but-not-used patterns in transcripts >7 days old are ignored.
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
- **Human approval:** required before the first week's soak formally begins.

## Deliverables at end of Phase 0b

Under `.logs/phase-0/` (gitignored — summary lifted into committed `phase-0b-brief.md`):

- `brief.md` + `brief.json` — 7-day consolidated acceptance report
- Governance inventory catalogued
- Protocol feature matrix complete (with probe-required fields deferred to Phase 1 Thread B)
- Trap corpus expanded
- Phase 1 thread briefs seeded with measurement input

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.1.0 | 2026-04-22 | Corrected after external P1/P2 critique. Switched to true snapshot semantics (`snapshot_begin()` truncates per-file at start of each run); added the 3 missing acceptance artifact scripts (`measure-redundancy.sh`, `measure-tokens-estimate.sh`, `measure-brief.sh`); rewrote `measure-claude-code.sh` to parse `~/.claude/projects/*/*.jsonl` (the actual tool-use source; prior version pointed at pid-metadata JSON files that contained no tool-use data); rewrote `measure-codex.sh` to parse `~/.codex/sessions/*/rollout-*.jsonl` function-call records (prior version measured logger-module signal only); added per-hit provenance (`source`, `file`, `line`, `evidence_redacted`) to `traps.jsonl`; switched MCP baseline parsing from regex to `jq` (fixes false `env` server entry); expanded governance inventory scope to chezmoi wrappers + runbook docs + 1P reference manifests; added `scripts/ci/shellcheck-scan.sh` and wired into `just verify`; fixed BSD find `-newermt` incompatibility (switched to `-mtime -7`); fixed grep-exit-on-no-match breaking scripts under `set -euo pipefail`; scoped trap scan to 7-day file window (was iterating all ~5k transcripts × 12 patterns). |
| 1.0.0 | 2026-04-22 | Initial. Aspirational; superseded by v1.1.0 after P1/P2 critique found idempotency, missing-acceptance-artifacts, wrong-log-source, and provenance-dropping issues. |
