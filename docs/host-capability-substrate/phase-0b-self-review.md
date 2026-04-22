---
title: HCS Phase 0b Self-Review
category: review
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-22
tags: [phase-0b, review, producer-critic]
priority: medium
---

# HCS Phase 0b Self-Review

Per research plan §22.11 critic prompt, reviewing the Phase 0b measurement plan + scripts for:
- privacy/security risks
- accidental mutation
- missing client identity data
- missing hook coverage
- insufficient trap capture
- mismatch with HCS v0.3.0 research plan

Reviewer: Opus 4.7 (same model as producer — `hcs-review` Codex profile should run this independently once daily baseline is in place; recording the self-review here so the critic discipline exists from commit 1 even if collapsed). Blocking issues first.

## Blocking issues

**None identified.** Smoke run produced real numbers with correct redaction and no mutation.

## Non-blocking concerns

### C-1 — Trap regex for `brew-vs-mise-node-resolution` is narrow
**Observation:** Only matches literal `brew install node` and variants with `@N`. Misses `brew install --verbose node`, `brew reinstall node`, and any commentary-style mentions like `should I `brew install node`?`.
**Impact:** False-negative rate likely elevated on trap #2.
**Resolution:** acceptable for Phase 0b baseline. Upgrade to a more forgiving pattern in Phase 1 Thread D when the full eval corpus is authored via `.agents/skills/hcs-regression-trap/SKILL.md`.

### C-2 — `measure-ide-hosts.sh` captures volume, not content
**Observation:** For Cursor/Windsurf/Claude Desktop/Copilot, we capture `entry_count` and `total_bytes`, not per-command shape. Their log formats are VS Code-style with window-scoped rotation and binary blobs.
**Impact:** These hosts contribute to Phase 0b evidence as "logs exist at this scale" rather than "this many redundant probes observed". Claude Code + Codex are the rich-signal hosts; IDEs are shape-only.
**Resolution:** acceptable. Phase 1 Thread B recommends connecting each host to a throwaway MCP echo server that records `clientInfo` + capability negotiation; that's the correct way to get per-host protocol feature data, not log parsing.

### C-3 — `.logs/phase-0/` is gitignored but scripts don't verify
**Observation:** scripts write to `.logs/phase-0/` trusting that `.gitignore` catches it. If `.gitignore` regresses, a future run could stage session-shape data.
**Impact:** Low (the repo has a top-level `.logs/` entry in `.gitignore`; `scripts/ci/forbidden-string-scan.sh` and `no-live-secrets.sh` would catch resolved secrets before commit).
**Resolution:** `scripts/ci/no-runtime-state-in-repo.sh` already scans for SQLite/log filenames. The current gitignore is specific (`.logs/`) so the protection is layered. Defer formal assertion.

### C-4 — Redaction depends on BSD sed syntax correctness
**Observation:** `redact()` uses BSD-compatible sed with `#` delimiter (fixed during smoke run after parenthesis-balance error). Future additions to the patterns must respect BSD sed quirks.
**Impact:** A regression could cause content to leak through redaction silently.
**Resolution:** add a `redact_test` helper to measure-common.sh that runs a known-bad input through `redact()` and asserts the output is sanitized. Medium-priority for next commit.

### C-5 — `measure-codex.sh` runs queries against SQLite WAL; partial state possible
**Observation:** Codex's SQLite is active (WAL mode). Read-only opens should be safe but count totals can shift mid-query.
**Impact:** Minor — counts may be off by a small delta from one moment to the next. Cross-session analysis uses data-at-rest day-over-day, so momentary skew doesn't matter.
**Resolution:** acceptable.

### C-6 — Client identity probing requires live MCP session
**Observation:** `measure-protocol-features.sh` marks `client_info_populated: "probe-required"` for every host because we have no artifact capturing `InitializeRequest.clientInfo` values. A throwaway echo MCP server would resolve this.
**Impact:** The Phase 0b acceptance checklist item "client identity mechanism" cannot be fully resolved from log parsing alone.
**Resolution:** Phase 1 Thread B deliverable — echo MCP server. Acknowledged in the workplan; not a Phase 0b blocker.

### C-7 — Token estimate uses char count, not tokenizer
**Observation:** `tokens-estimate.json` is not yet produced (deferred to the consolidation brief). When produced, it will approximate chars ÷ ~4 for rough token count.
**Impact:** Token numbers are back-of-envelope, not precise.
**Resolution:** acceptable for Phase 0b baseline — we're looking at order-of-magnitude signal, not precise accounting.

## Hook coverage audit (per critic prompt)

- ✅ Claude Code PreToolUse hook wired in project scope (`.claude/settings.json`); log-only, blocks literal forbidden patterns. Smoke-tested indirectly (Claude Code itself invokes it during this session).
- ✅ No Codex hook wired yet in project scope (per D-007 — advisory only; Codex hooks will be added in Phase 1 if trap corpus shows cross-host failure patterns).
- ⚠️  No unit test exercises `hcs-hook` with a known forbidden input. Adding would be trivial; defer to first `just test` milestone.

## Trap capture audit

- Seed corpus: 15 traps at `packages/evals/regression/seed.md`
- Smoke-run hits observed in real session data:
  - `rm-rf-no-escalation`: 11 hits across scanned sources
  - `gnu-bsd-sed-flag-divergence`: 3 hits
  - `launchctl-deprecated-verbs`: 2 hits
- Patterns **not** yet scanning: `venv-vs-system-python`, `tcc-denial-as-missing-file`, `quarantine-bit-as-codesign`, `subcommand-changed-between-versions`, `help-output-cached-across-version-change`, `shell-mode-confusion`, `brew-cask-escalation-missed`, `orbstack-docker-socket-confusion`
- **Action:** expand `measure-traps.sh` pattern map before week-one soak; add these 8 during Phase 1 Thread A (macOS surface APIs thread) when regex patterns are fully specified.

## Mismatch with HCS v0.3.0 research plan

- Research plan §6 Phase 0b lists 8 goals. All 8 are covered by the measurement plan. Smoke run delivers 4 of 8 directly (activity, traps, governance, protocol-features). 4 remaining (redundancy analysis, token-cost estimate, 1P migration reconciliation, client-identity probe) are end-of-week-1 consolidation tasks per the plan.
- §6 Phase 0b acceptance gate: "Trap corpus ≥15 entries." Seed already has 15; corpus will expand if smoke hits reveal new classes.
- §22.11 producer/critic split: honored via this self-review document. An independent critic pass via `hcs-review` Codex profile is a follow-up task once daily baseline is in place.

## Privacy / security summary

- All scripts confirmed read-only in source review.
- Redaction applied before any observation hits disk (`redact()` in measure-common.sh).
- Output directory is repo-local `.logs/phase-0/` which is gitignored; `scripts/ci/no-runtime-state-in-repo.sh` + `forbidden-string-scan.sh` enforce non-leakage.
- No escalated privileges required. No `sudo`, no TCC-gated path reads assumed to succeed — Claude Desktop session dir returns `tcc_unknown` as first-class result when FDA absent.
- Codex SQLite opens use `file:...?mode=ro` explicitly to prevent write attempts.
- Secret patterns (`sk-`, `ghp_`, `github_pat_`, `xoxb-`, `AKIA`, Bearer tokens, JWTs, `op://` URIs, emails) redacted at source.

## Recommendation

**Proceed with week-one soak.** Issues C-1 through C-7 are tracked as follow-up work but none block the acceptance gate. The scaffolding delivers real numbers (35 activity records / 16 governance artifacts / 4 trap findings in the first 30-second smoke run) and the privacy posture is correct.

## References

- Producer plan: [`phase-0b-measurement-plan.md`](./phase-0b-measurement-plan.md) v1.0.0
- Charter: [`implementation-charter.md`](./implementation-charter.md) v1.1.0+
- Research plan: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` §6 Phase 0b, §22.11 (producer/critic loop)
- Boundary decision: [`0001-repo-boundary-decision.md`](./0001-repo-boundary-decision.md) v1.1.0+

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-04-22 | Initial self-review during Phase 0b producer phase. |
