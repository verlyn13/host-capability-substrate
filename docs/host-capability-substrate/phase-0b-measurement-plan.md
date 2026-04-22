---
title: HCS Phase 0b — Measurement Workplan
category: plan
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-22
tags: [phase-0b, measurement, baseline, metrics, traps, governance-inventory]
priority: high
---

# HCS Phase 0b — Measurement Workplan

Quantifies the economic and governance baseline before any substrate code ships. Runs for ~7 days; produces the numeric evidence the Phase 3 acceptance criteria will be measured against (≥50% reduction in redundant `--help` probes across agents, top-10 probed tools).

Parent: [`host-capability-substrate-research-plan.md`](../host-capability-substrate-research-plan.md) (v0.3.0+) §6 Phase 0b, §22.11.
Charter: [`implementation-charter.md`](./implementation-charter.md) v1.1.0+.
Boundary decision: [`0001-repo-boundary-decision.md`](./0001-repo-boundary-decision.md) v1.1.0+.

## Goals (per research plan §6 Phase 0b)

1. **Activity audit.** Count `--help` invocations, version probes, toolchain resolution commands, host-state probes, raw shell invocations across 5 clients.
2. **Redundancy measurement.** Same-command-different-agent-within-24h counts.
3. **Token-cost estimate.** `tokens/day/host` for redundant output.
4. **Hallucination-trap audit.** Observed stale-CLI-memory patterns; expand seed corpus to ≥15 entries.
5. **Governance-surface inventory.** Current hooks, tier classifications, `policies/`, runbook prose, hard-coded command lists.
6. **1Password migration reconciliation.** Confirm `docs/secrets.md` v2.1.0 authoritative; flag any residue.
7. **Client identity mechanism.** Per-host `InitializeRequest.clientInfo` probing; propose `MCP_CLIENT_ID` wrapper.
8. **Protocol feature matrix.** Per-host MCP stdio, Streamable HTTP, structured outputs, resources, prompts, elicitation, subagent scoping.

## Principles

- **Read-only.** No script writes to `~/.claude/`, `~/.codex/`, `~/.cursor/`, `~/.codeium/windsurf/`, `~/.copilot/`, or any IDE-owned path. Confirmed by `scripts/dev/measure-*.sh` header assertion + shellcheck pass.
- **Output-locally-only.** All artifacts go to `.logs/phase-0/` (gitignored). Never committed.
- **Privacy-redacting.** Raw user prompts, LLM responses, and secret-like patterns redacted before any observation hits disk. Scripts log command shape + counts, not content.
- **Idempotent.** Can be re-run daily; output timestamp-partitioned under `.logs/phase-0/YYYY-MM-DD/`.
- **Fail-open on missing source.** If `~/.claude/sessions/` is empty or a SQLite file is missing, log "source unavailable" and continue.

## Available local sources

Surveyed 2026-04-22 on this host:

| Source | Location | Size / Shape | Notes |
|--------|----------|--------------|-------|
| Claude Code user prompts | `~/.claude/history.jsonl` | ~10MB, JSONL | `display` field contains user-typed text |
| Claude Code sessions | `~/.claude/sessions/*.json` | per-session JSON | tool-call records live here |
| Claude Code shell env | `~/.claude/shell-snapshots/*.sh` | per-session .sh dumps | shows PATH, aliases per session |
| Codex session index | `~/.codex/session_index.jsonl` | JSONL | thread IDs + names + timestamps |
| Codex structured logs | `~/.codex/logs_2.sqlite` | SQLite WAL | `logs(ts, level, target, thread_id, body, ...)` |
| Codex state | `~/.codex/state_5.sqlite` | SQLite WAL | `threads`, `agent_jobs`, `agent_job_items`, `thread_spawn_edges`, `thread_dynamic_tools` |
| Cursor logs | `~/Library/Application Support/Cursor/logs/YYYYMMDDThhmmss/` | timestamped dirs | VS Code-style log folders per window |
| Windsurf logs | `~/Library/Application Support/Windsurf/` | similar to Cursor | — |
| Claude Desktop | `~/Library/Application Support/Claude/claude-code-sessions/` | — | desktop-hosted Claude Code sessions |
| Copilot CLI | `~/.copilot/logs/`, `command-history-state.json`, `session-state/` | mixed | CLI invocation history |

macOS unified log (`log show`) is out of scope — too noisy, not agent-scoped.

## Scripts

Under `scripts/dev/`. All read-only, output to `.logs/phase-0/YYYY-MM-DD/` (gitignored):

- `measure-claude-code.sh` — scans Claude Code history + sessions for tool-call shape counts per day
- `measure-codex.sh` — queries Codex SQLite for thread counts, tool invocations, `--help` proposals
- `measure-redundancy.sh` — aggregates cross-source; detects same-command-within-24h-across-agents
- `measure-traps.sh` — scans recent session content (redacted) for known trap patterns (deprecated verbs, wrong-toolchain proposals)
- `measure-governance-inventory.sh` — catalogs system-config hooks + tiers + runbook prose + `policies/` files
- `measure-protocol-features.sh` — probes each host's MCP `clientInfo` + supported primitives (where reachable)

All scripts source `scripts/dev/measure-common.sh` for shared redaction and JSONL-output helpers.

## Output schema

Per-run directory: `.logs/phase-0/YYYY-MM-DD/`

| File | Shape | One-line per |
|------|-------|--------------|
| `activity.jsonl` | `{ts, source, session_id, agent_id, category, command_pattern, count}` | tool-call shape bucket, per source + day |
| `redundancy.jsonl` | `{ts, command_pattern, agents: [list], sessions: [list], count}` | cross-source dupe instance |
| `traps.jsonl` | `{ts, trap_name, source, evidence_redacted, severity}` | observed trap occurrence |
| `tokens-estimate.json` | `{date, top_patterns: [...], total_chars, estimated_tokens, per_agent: {...}}` | daily summary |
| `governance-inventory.jsonl` | `{category, path, kind, excerpt_redacted}` | current governance artifact |
| `protocol-features.json` | `{host, supports: {stdio, http, structured_outputs, resources, prompts, elicitation, subagent_scoping}}` | one per host |

**Redaction rules (`redact()` in measure-common.sh):**

- Any string matching `sk-[A-Za-z0-9]{20,}`, `ghp_[A-Za-z0-9]{20,}`, `xoxb-...`, `AKIA[0-9A-Z]{16}` → `<REDACTED:key>`
- Any string matching `op://[^\s]+` → `<REDACTED:op-uri>` (references are safe but not our concern here)
- Any free-form user prompt over 200 chars → truncated to first 200 + hash suffix (for dedup)
- Full filesystem paths under `~/Documents`, `~/Desktop`, `~/Downloads` → `<REDACTED:user-path>`
- Session content that looks like an email address → `<REDACTED:email>`

## Cadence

- **Daily**, manually or via cron: `just measure` runs all six scripts, appending to `.logs/phase-0/$(date -u +%Y-%m-%d)/`
- **End of week 1:** `just measure-brief` consolidates the 7 daily partitions into the 3-4 page measurement brief at `.logs/phase-0/brief.md`
- **Phase 0b acceptance gate:** the brief exists and shows real numbers; trap corpus has ≥15 entries

## Acceptance checklist

- [ ] 7 consecutive days of `activity.jsonl` captured (no gaps longer than 24h)
- [ ] All 5 primary clients represented in at least one day's data (CC, Codex, Cursor, Windsurf, Copilot CLI; CC Desktop opportunistic)
- [ ] Redundancy analysis shows cross-agent overlap for ≥3 command patterns
- [ ] Token-estimate gives a concrete `tokens/day` number, not an estimate range
- [ ] `traps.jsonl` captures ≥15 distinct trap classes (seed had 15; measurement should confirm + possibly expand)
- [ ] `governance-inventory.jsonl` enumerates every existing PreToolUse hook, every tier classification in `system-config/policies/`, every runbook that describes tiers in prose, every hard-coded command list in scripts
- [ ] `protocol-features.json` present for Claude Code, Codex, Cursor, Windsurf, Copilot CLI, Claude Desktop
- [ ] 1Password reconciliation: `docs/secrets.md` v2.1.0 confirmed authoritative, any gopass residue enumerated
- [ ] Client identity mechanism proposal: which hosts populate `clientInfo.name/version` distinctly, which need `MCP_CLIENT_ID` wrapper

## Risks and missing access

| Risk | Mitigation |
|------|------------|
| Session logs have ephemeral retention on some clients (e.g., Cursor rotates logs every N days) | Capture early, daily cadence |
| Raw session content may leak user/project secrets into observations | Aggressive redaction at source; never commit `.logs/` |
| TCC denials on Claude Desktop session directory | `measure-claude-desktop.sh` returns `tcc_unknown` as first-class result; does not silently skip |
| Cursor/Windsurf log format is VS Code-style and may not expose tool-call events cleanly | Shape-level counts only; skip detailed tool-call analysis for these hosts if not feasible |
| Codex SQLite WAL may be in flight; reads might see partial state | Use `sqlite3 -readonly`; treat missing rows as advisory not definitive |
| Measurement scripts themselves become source of redundant `--help` probes | Scripts call `help` once, cache locally |
| Observer effect — knowing we're measuring might alter behavior | This is acceptable; the substrate exists to improve behavior; measurement captures pre-change state |

## Producer / critic split

Per research plan §22.5 producer/critic loop. Phase 0b is plan-drafting, not implementation, but we still apply the split:

- **Producer:** Opus 4.7 (this document and associated scripts)
- **Critic:** to be invoked via Codex `hcs-review` profile (read-only) before the first week's measurement runs. Review prompt per §22.11:

```
Review the Phase 0b measurement plan for:
- privacy/security risks
- accidental mutation
- missing client identity data
- missing hook coverage
- insufficient trap capture
- mismatch with HCS v0.3.0
Return blocking issues first.
```

- **Human approval:** required before first `just measure` run.

## Deliverables at end of Phase 0b

Under `.logs/phase-0/` (all gitignored — summaries lifted into a brief commit):

- `brief.md` — 3-4 page consolidated report (lifted to `docs/host-capability-substrate/phase-0b-brief.md` post-week-1)
- Governance inventory catalogued
- Protocol feature matrix complete
- Trap corpus expanded
- Phase 1 thread briefs seeded with measurement input

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-04-22 | Initial. Surveyed local sources, defined output schema, enumerated scripts, set acceptance checklist. |
