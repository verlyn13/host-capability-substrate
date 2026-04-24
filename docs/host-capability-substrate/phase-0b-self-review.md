---
title: HCS Phase 0b Self-Review
category: review
component: host_capability_substrate
status: active
version: 1.1.1
last_updated: 2026-04-23
tags: [phase-0b, review, producer-critic, critique-response]
priority: medium
---

# HCS Phase 0b Self-Review

Record of producer/critic discipline on the Phase 0b measurement surface, per research plan §22.5 / §22.11.

## v1.1.1 — soak-window alignment

The critique findings below still stand. v1.1.1 only aligns the review with the
current repo-side soak cadence: an initial 3-day window from 2026-04-23 through
2026-04-25, with closeout on 2026-04-26. If the result is ambiguous after day 3,
the soak extends rather than the gate being relaxed.

## v1.1.0 — critique response

v1.0.0 of the plan + scripts shipped with six substantive defects caught by external review. This section records each finding honestly, the fix applied, and the verification that the fix holds. Producer/critic discipline is only credible if the critic's findings are acted on without minimization.

### P1 findings (blocking)

#### F-1 — Acceptance artifacts not generated
**Original critique:** The orchestration ran 6 collection scripts + the partition summary. No `measure-redundancy.sh`, no `tokens-estimate.json` generation, no `measure-brief` recipe. The documented week-one gate could not complete.

**Status:** resolved in v1.1.0.

**Fix:** added `scripts/dev/measure-redundancy.sh`, `measure-tokens-estimate.sh`, `measure-brief.sh`. At v1.1.0, `just measure` covered the 9 collection scripts required by the plan; v1.1.1 later documented the extra `commands` / `classify` / `confusion` analysis outputs that now run in the same pipeline. `just measure-brief` aggregates all partitions into `brief.md` + `brief.json` with an acceptance-gate table.

**Verification:** single-day smoke run produces `activity-claude-code.jsonl`, `activity-codex.jsonl`, `activity-ide-hosts.jsonl`, `traps.jsonl`, `governance-inventory.jsonl`, `protocol-features.json`, `redundancy.jsonl`, `tokens-estimate.json`. `just measure-brief` produces `brief.md` with the full acceptance-gate table.

#### F-2 — Daily partition was append-only, non-idempotent
**Original critique:** `jsonl_append` unconditionally appended. Re-running `just measure` the same day duplicated records with shifted totals, contradicting the plan's idempotency claim.

**Status:** resolved in v1.1.0.

**Fix:** added `snapshot_begin(file)` to `measure-common.sh`. Every measurement script calls `snapshot_begin()` for each file it owns at the top of the run, truncating to zero bytes before appending. Re-running the same day now produces byte-identical outputs (modulo timestamp fields).

**Verification:** ran `just measure` twice consecutively on 2026-04-22. Line counts match exactly across runs (43 / 39 / 5 / 39 / 44 / 291). No duplicate records.

#### F-3 — Claude Code tool-use extraction targeted wrong file format
**Original critique:** `measure-claude-code.sh` assumed `~/.claude/sessions/*.json` contained tool-use events. The files contain only `{pid, sessionId, cwd, startedAt, ...}` metadata. No `tool-use-shape` rows were being emitted.

**Status:** resolved in v1.1.0.

**Root cause:** the actual tool-use records live in `~/.claude/projects/<project-slug>/<session-uuid>.jsonl`, where each line is a JSON event and the tool-use records are nested at `assistant.message.content[].type == "tool_use"` with a `name` field. `~/.claude/sessions/*.json` is unrelated pid/session-start metadata.

**Fix:** rewrote the extractor to `find ~/.claude/projects -type f -name '*.jsonl' -mtime -7`, parse each line with Python, and count `tool_use` occurrences per `name`. `sessions/*.json` is now recorded as a file-count shape only with an explicit note about its real purpose.

**Verification:** smoke run now emits `tool-use-shape` records: `Bash` 3803, `Read` 1404, `Edit` 1242, `Grep` 404, etc. — real signal that matches observed Claude Code usage on this host.

#### F-4 — Codex measurement captured infra signal, not command activity
**Original critique:** The script grouped log rows by logger `target` and counted `thread_dynamic_tools`. Those are infrastructure signals, not `--help` / tool-resolution / command invocations. The logs SQLite has no command-text column. The script never inspected `~/.codex/sessions/` rollouts where the rich signal actually lives.

**Status:** resolved in v1.1.0.

**Root cause:** Codex stores per-turn records in rollout JSONL files at `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`. Each line is `{timestamp, type, payload}`. Tool calls live at `type=response_item, payload.type=function_call, payload.name`. Outputs at `payload.type=function_call_output`. The `threads.rollout_path` column in `state_5.sqlite` points to these files.

**Fix:** `measure-codex.sh` now queries `state_5.sqlite` for `rollout_path` of threads updated in the last 7 days, then parses each rollout JSONL in Python to count `function_call` occurrences per tool name. Dynamic-tool registration counts are retained as context (labelled "dynamic-tool-registration", explicitly distinguished from invocations).

**Verification:** smoke run now emits `function-call-shape` records across 7-day window: `exec_command` 5315, `write_stdin` 841, `firecrawl_scrape` 14, `firecrawl_search` 10, `update_plan` 109, etc. — real tool-invocation signal.

### P2 findings (non-blocking but should address)

#### F-5 — Trap output dropped provenance fields
**Original critique:** The plan specified `traps.jsonl` records `{ts, trap_name, source, evidence_redacted, severity}`. Implementation wrote only aggregate `{trap_name, hits_week, severity}`, losing provenance needed to validate hits or attribute to a host.

**Status:** resolved in v1.1.0.

**Fix:** each hit now emits `{ts, trap_name, source, file, line, evidence_redacted, severity}`. Source is the parent directory basename of the file (quick attribution). File is the full redacted path. Line is the line number within the file. Evidence is a truncated+redacted excerpt with an 8-char SHA fingerprint suffix for dedup. A separate `__summary__` record preserves aggregate counts.

**Verification:** smoke run `traps.jsonl` has 291 per-hit records + 1 summary. Each hit is auditable to source file + line.

#### F-6 — Governance inventory under-scoped; MCP regex produced false data
**Original critique:** The inventory scanned only top-level `system-config/scripts/*.sh` and a small subset of docs/config files. It missed runbook/prose surfaces and chezmoi template wrappers. The MCP server extraction regex `"[a-z-]+":\s*\{` matched `"env": {` inside server env blocks, inventing a fake `env` server name.

**Status:** resolved in v1.1.0.

**Fix:**
- MCP servers now parsed via `jq` (`.mcpServers | keys[]`), not regex. Per-server records include transport type. No more false `env` entries.
- Expanded scope to:
  - chezmoi-managed MCP wrapper templates under `home/dot_local/bin/executable_mcp-*`
  - runbook docs: `agentic-tooling.md`, `mcp-config.md`, `github-mcp.md`, `project-conventions.md`, `claude-cli-setup.md`, `codex-cli-setup.md`, `copilot-cli-setup.md`, `workspace-management.md`
  - 1Password reference manifests under `home/dot_config/mcp/common.env*`
  - system-config policy YAML/Rego/markdown (find across subdirs)
  - HCS project-scoped settings + subagents
  - Codex profiles + hooks + trusted projects

**Verification:** smoke run catalogued 39 artifacts (was 2–16). `jq` parses `scripts/mcp-servers.json` correctly; no `env` false entry. All 5 baseline servers (context7, memory, sequential-thinking, brave-search, firecrawl) emit per-server records with transport type.

### Assumptions and shellcheck critique

- **"If some outputs are intended to be produced manually later, state that in the plan."** — Addressed in v1.1.0 of the plan. The "Known limitations" section now enumerates every constraint explicitly: semantic redundancy undercounted, char/4 tokenization, 7-day trap window, IDE-host volume-only signal, Claude Code session metadata limits, Codex logs infra-only.
- **"shellcheck warnings existed and weren't part of `just verify`."** — Addressed. Added `scripts/ci/shellcheck-scan.sh` which scans all shell scripts (including shebang-detected ones in non-`.sh` paths). Wired into `just verify`. Fixed warnings: `SC2044` in `policy-lint.sh` (for-loop over find → while-read from process substitution), and `SC1072/SC1073` false positive on the em-dash-prefixed comment in `shellcheck-scan.sh` itself (renamed to ASCII-safe comment). Shellcheck clean on all 20 scripts.

## Fresh critic pass (v1.1.0)

After fixing F-1 through F-6, a fresh pass for any remaining risks:

### Remaining non-blocking items

- **Cross-source redundancy reports 0 despite 43 unique tools.** Correct by the current definition (same tool NAME across sources), because Claude Code and Codex never share a tool name. Semantic redundancy (Bash ≡ exec_command) requires a name-mapping layer, which is Phase 1 Thread D policy schema territory. Documented in the plan's "Known limitations" section. Not a Phase 0b blocker; the information is still captured via per-source counts.
- **Token-estimate for transcript-volume uses fixed 2KB-per-tool-use heuristic.** Reasonable for order-of-magnitude; not accurate to the token. Documented as back-of-envelope.
- **Measurement runtime ~60s per `just measure` pass.** Dominated by the trap scan across 4900+ Claude Code transcripts (even scoped to 7-day, ~70 files × 12 patterns). Acceptable for daily manual cadence; if moved to hourly/launchd, need to reduce scope further or use xargs parallelism.
- **Shell-mode-confusion-login trap over-fires.** Pattern `bash -lc` matches routine agent invocations. Not a true "shell-mode confusion" hit; more like a coarse `bash -lc` counter. May want to refine in the next trap-corpus iteration, or rename the trap.
- **Trap scanner coverage is narrower than the seed corpus.** The committed seed corpus already holds 15 trap classes, but `measure-traps.sh` currently instruments 12 heuristics. This is a coverage follow-up, not a reason to mark the seed corpus gate failed.

### Privacy / security audit (unchanged)

- All scripts confirmed read-only.
- Codex SQLite opened via `file:?mode=ro`.
- Output directory is gitignored.
- Redaction applied pre-disk with self-test (`redact_self_test` in `measure-common.sh` validates 5 secret-pattern families get sanitized).
- BSD sed + BSD find compatibility verified (critical on macOS default shell).
- `just verify` passes all 12 gates (format/lint/typecheck advisory for tsc/biome-not-yet-installed; schema-drift noop; boundary-check, policy-lint, forbidden-string-scan, no-live-secrets, no-runtime-state-in-repo, shellcheck-scan all clean).

## Acceptance-gate status (after v1.1.0 fixes)

From `.logs/phase-0/brief.json` after one smoke run:

| Criterion | Met |
|-----------|-----|
| three consecutive days of data | ✗ (needs the April 23-25 soak window to complete) |
| five primary clients covered | ✓ |
| cross source overlap at least 3 | ✗ (by current name-based definition) |
| tokens estimate present | ✓ |
| trap corpus 15 plus | ✓ (seed corpus has 15 entries; observed hit count may be lower) |
| governance inventory present | ✓ |
| protocol features present | ✓ |

**Assessment:** the remaining ✗ items reflect honest gaps:
- Three days requires actually running the soak; day 1 is now underway.
- Cross-source overlap is a known limitation (semantic redundancy undercounted).
- Scanner coverage of 12 heuristics is narrower than the 15-entry seed corpus. Expanding `measure-traps.sh` remains follow-up work per the regression-trap skill.
- All other acceptance items pass.

## Recommendation

**Proceed with the 3-day soak.** The critique surfaced real defects; v1.1.0 addressed them and v1.1.1 aligns the repo plan with the active soak window. Producer/critic discipline is honored: the critic's findings drove substantive rework, not defensive patching.

**Next honest follow-ups (not Phase 0b blocking):**
1. Refine trap patterns to reduce false positives (shell-mode-confusion-login, brew-cask-escalation-missed cap of 50 may be understating reality).
2. When Phase 1 Thread B ships the echo MCP server, resolve all `probe-required` fields in protocol-features.json.
3. Introduce a semantic-tool-name mapping (Bash ↔ exec_command ↔ subprocess.run) for real cross-agent redundancy measurement. This is Phase 1 Thread D policy-schema work.

## References

- Producer plan: [`phase-0b-measurement-plan.md`](./phase-0b-measurement-plan.md) v1.1.1
- Charter: [`implementation-charter.md`](./implementation-charter.md) v1.1.0+
- Research plan: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` §6 Phase 0b, §22.11
- Boundary decision: [`adr/0001-repo-boundary.md`](./adr/0001-repo-boundary.md) v1.1.0+

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.1.1 | 2026-04-23 | Aligned the self-review with the active 3-day soak window and corrected the trap-corpus gate to count the committed 15-entry seed corpus rather than only observed hits. |
| 1.1.0 | 2026-04-22 | Critique response. Each of 6 findings (F-1 through F-6) recorded with status, root cause, fix, verification. Fresh critic pass post-fix logged. Acceptance-gate status honestly assessed. Design-decision notes added for downstream Phase 1 work. |
| 1.0.0 | 2026-04-22 | Initial self-review during Phase 0b producer phase. Superseded by v1.1.0 after external critique. |
