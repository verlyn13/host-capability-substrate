# PLAN.md — Host Capability Substrate


Milestone-by-milestone implementation plan. Follow in order. Each milestone has acceptance criteria and validation commands. Do not skip validation.

Upstream research plan (canonical): `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`.

## Current Focus — Phase 0b

As of 2026-04-23, this repo is running a compressed **3-day Phase 0b soak** on top of the Milestone 0 scaffold.

- Soak window: 2026-04-23 through 2026-04-25
- Closeout: 2026-04-26 with `just measure-brief`
- Kickoff battery: `just day1`
- Daily cadence: `just measure` and `just soak-status`
- Extension rule: if the 3-day window does not produce a clean go/no-go, extend the soak rather than weakening the gate

### Closeout-week sequence (2026-04-24 → post-closeout)

Three-wave plan approved 2026-04-23 after synthesis of two external substrate-config research reports (see memory `project_substrate_config_research_report1.md`).

**W2 — days 2 + 3 (2026-04-24, 2026-04-25). Held-back drafts + outside-HCS work.**

- `system-config/scripts/lint-claude-settings.py` (new): validates `~/.claude/settings.json` and `~/.claude.json` against both (a) published JSON Schema and (b) installed-CLI runtime parse; flags divergence. Integrates into `system-update` hygiene flow. Outside this repo.
- Charter v1.2.0 amendment **draft branch** (not merged during soak). Includes invariants 13 (cleanup derivability-authority), 14 (config-spec authority + provenance), and 15 (GUI shell-env non-inheritance; Apple-doc + Anthropic-VS-Code-doc backed). Subagent objections from `hcs-architect`, `hcs-policy-reviewer`, `hcs-security-reviewer`, `hcs-ontology-reviewer` during days 2–3.
- ADR 0012 credential broker **draft branch** — scope revised 2026-04-24 after D-028 landed (system-config shipped the `host_secret_*` caller-facing contract + HCS_SECRET_* env namespace), the IPC deadlock recurred within 24 hours, AND the Cloudflare Stage 3a lessons brief (`docs/.../research/external/2026-04-24-cloudflare-lessons.md`) added one-time-secret capture-at-source as broker scope. Scope changes from "conditional, measurement-gated" to **"committed, phased; caller-facing phase already shipped as D-028; HCS work is the broker daemon at `$HCS_BROKER_SOCKET` speaking the existing contract, plus an atomic `create → capture → store → verify → scrub` pattern for provider-issued one-time secrets."** Broker serves CLI via `apiKeyHelper`/`awsCredentialExport` AND GUI via OAuth + Keychain separately (apiKeyHelper is CLI-only per metal-verified Anthropic docs); the broker does NOT unify the two surfaces.
- ADR 0013 forbidden-tier split **draft branch**.
- ADR 0014 InterventionRecord entity **draft branch**.
- ADR 0015 external-control-plane automation **draft branch** — NEW 2026-04-24. Scope: Cloudflare, GitHub, 1Password-CLI, MCP-OAuth, DNS providers, Hetzner as one provider class treated with typed evidence discipline (typed `OperationShape`, not shell strings). Absorbs the 8 design rules from the Cloudflare Stage 3a brief: minimal-request plan, budget-gated optional checks, 429-as-cooldown-not-retry, one-time-secret atomic broker path, ProviderObjectId / PublicClientId / SecretMaterial / SecretReference / PolicySelectorValue schema distinction, CLI-syntax-from-evidence-not-memory, typed MCP OAuth discovery (protected resource metadata + audience), explicit Cloudflare Access wildcard-path coverage warnings. Drafted in W2, merged in W3 sequence after ADR 0014. Drafting distributed across W2 + early W4; scaffold files for the 7 associated regression traps (#19–#25) are Phase 1 work, not W3.
- Daily `just measure` + `just soak-status`; re-run `measure-extended-rubric` + `measure-guidance-load` over new partitions; any field incidents captured under `.logs/phase-0/interventions/`.

**W3 — closeout 2026-04-26. Ordered merge sequence.**

1. `just measure-brief` — final narrative over the three partitions with v1.2.0 supplementary surfaces.
2. Merge charter v1.2.0 PR.
3. Merge ADR 0012, 0013, 0014, 0015 PRs in sequence (broker → forbidden-tier split → InterventionRecord → external-control-plane automation). ADR 0015 lands last because it depends on 0012's broker surface for the one-time-secret capture-at-source pattern.
4. Scanner parity: add heuristics for traps #16 (`ignored-but-load-bearing-deletion`), #17 (`harness-config-boolean-type`), and #18 (`agent-echoes-secret-in-env-inspection`) to `measure-traps.sh`; seed is at 30 (18 prior + 7 from the Cloudflare Stage 3a brief + 5 from the shell/environment research v2), scanner catches up to #16/#17/#18 only at closeout. Traps #19–#30 are seed-only at closeout; scanner heuristics + expanded scaffold files are Phase 1 work because they require live-provider/surface fixtures to validate. Hook literal-forbidden-list extension for trap #18's secret-echo regexes lands with this commit so day-over-day `forbidden` classification is consistent before/after closeout.
5. **DECISIONS.md batch commit (renumbered)**: D-029 (amend D-022 to public-semver strings), D-030 (OAuth-preferred HTTP MCP baseline; `enabled=false` + explicit opt-in, not profile-gating), D-031 (Codex profiles are CLI-only opt-ins), **D-032 (external control-plane automation: HCS treats external APIs as typed, evidence-producing control planes, not shell-string targets; provider object IDs, public client IDs, and secret material are distinct schema concepts; 429 is cooldown evidence, not a retry prompt; ADR 0015 is the master decision)**. Runtime-governs conflict rule absorbed into D-026 + charter inv. 14 — no standalone row. (D-028 already landed 2026-04-24 as the `host_secret_*` credential plane; see user commit `d59a35c`.)
6. Closeout narrative `docs/host-capability-substrate/phase-0b-closeout.md` answering the 5 runbook questions.
7. `phase-0b-self-review.md` v1.2.0 with closeout outcomes.

**W4 — post-closeout Phase 1 prep.**

The shell-environment research v2.0.0 (`docs/host-capability-substrate/shell-environment-research.md`) lays out a formal 10-working-day research program (2026-04-27 → 2026-05-08, ~55–60 hours) using prompt IDs P01–P13. The existing direct-test queue items below cross-reference those prompt IDs; several are resolved at the documentation level and reduce to confirmatory smoke tests.

Direct-test queue (combined from report 1 §14 + report 2 verification + shell research v2.0.0 P01–P13; blocks work that depends on each outcome):

1. `codex mcp login github` → Keychain entry → restart Codex → MCP starts clean without `GITHUB_PAT`. If successful, remove `bearer_token_env_var = "GITHUB_PAT"` from the system-config managed Codex block. *(Related: shell research v2 **P01** — resolved at doc level; this is the operational migration step.)*
2. Codex app + CLI + IDE reuse the same MCP OAuth token (same `CODEX_HOME` → same Keychain key). *(Shell research v2 **P01**: resolved at doc level — Keychain service `"Codex Auth"`, account `cli|<sha256(CODEX_HOME)[:16]>`. Smoke test only, 1h.)*
3. Codex app honors project-scoped `.codex/config.toml` MCP definitions in trusted projects.
4. Codex app launched from Spotlight does NOT inherit shell `GITHUB_PAT`. *(Shell research v2 **P02**: strongly inferred from launchd + issues #10695 / #13566; direct differential test on this host, 2h.)*
5. Claude Desktop uses OAuth-only; does NOT read `apiKeyHelper` or `ANTHROPIC_API_KEY`. *(Shell research v2 **P05**: resolved at doc level via Anthropic authentication.md. Confirmatory smoke test only, 1h.)*
6. Claude Code #18692 (resolved-secrets-into-`.mcp.json`) does NOT repro on 2.1.119.
7. `shell_environment_policy.include_only` reliably exposes named var on Codex 0.124.0. *(Shell research v2 **P04**: schema documented but cross-surface behavior undocumented; issue #3064 suggests divergence. Matrix test with env vectors, 10h.)*
8. Verify `apiKeyHelper` CLI-only scope statement against live Anthropic docs. *(Shell research v2 §2.3 confirms at doc level.)*
9. **Q-002**: our `[profiles.hcs-*]` consulted by which Codex surfaces?
10. Codex app MCP startup happens before worktree setup scripts. *(Shell research v2 **P03**: genuinely undocumented; marker-based timing test with synthetic repo, 8h.)*
11. **NEW — P06**: Shell wrapper-log validation. Install `/usr/local/bin/hcs-shell-logger` that logs argv/flags/PPID/cwd then `exec`s `/bin/bash`; route each surface through it. Confirms Codex CLI = `bash -lc`, Claude fresh = `bash -c`, apiKeyHelper = `/bin/sh -c`. 4h.
12. **NEW — P13**: Codex app sandbox boundary characterization (new `ExecutionContext` class). Inspect app bundle Info.plist + embedded sandbox profile + `codesign -d --entitlements -`; probe Keychain access, FS scope, network scope, env injection; cross-reference issue #10695. 4h.
13. **NEW — P08**: Provenance snapshot — capture each surface's PATH/SHELL/HOME/PWD/TMPDIR/CODEX_HOME value + provenance tags; commit as `packages/fixtures/provenance-snapshot-YYYY-MM-DD.json` golden data. 6h.
14. **NEW — P09**: direnv + mise cross-surface visibility. Synthetic repo with `.envrc` `HCS_DIRENV_MARKER` + `.mise.toml [env] HCS_MISE_MARKER`. Test terminal-launched vs GUI-launched for each surface. 6h.

Phase 1 work items (queued, unordered here — sequenced in ADR 0012, ADR 0015, ADR 0016/0017/0018, and the Phase 1 research plan):

- If W4-1 succeeds: migrate all HTTP MCP servers with OAuth support off `bearer_token_env_var` patterns (per D-028).
- Sparkle intervention F-08 (kernel RPC for typed per-section diagnostics) — permanent fix for `pipefail+head` class.
- Sparkle intervention F-09 (hook-decision schema v2 with version field + rotation).
- Extended-rubric formalization into primary scoring schema (Phase 1 cross-agent layer).
- `just verify-baseline` recipe — operationalizes charter inv. 14's "retest on upgrade" cadence.
- Semantic tool-name mapping (Bash ↔ exec_command) — resolves the acceptance-gate "cross-source redundancy = 0" known limitation.
- Remaining Sparkle follow-ups F-01/F-02/F-03/F-07/F-11/F-13.
- **Ring-0 entity additions from ADR 0015 scope** (Milestone 1 20-entity list expands; design choice of new-entity vs. Evidence-subtype deferred to ADR 0015 drafting): `RateLimitObservation`, `RemoteMutationReceipt`, `CredentialIssuanceReceipt`, `ProviderObjectReference`, `PathCoverage`, `McpAuthorizationSurface`.
- **Ring-0 entity additions from shell research v2 (ADRs 0016/0017)**: `ExecutionContext` (per-surface type with sub-classes `codex_cli`, `codex_app_sandboxed`, `codex_ide_ext`, `claude_code_cli`, `claude_desktop`, `claude_code_ide_ext`, `zed_external_agent`, `warp_terminal`; each with shell+invocation+startup-files+sandbox+env-inheritance facets per §II table). `EnvProvenance` (adopts devcontainer dichotomy: baked/runtime-applied/probed; carries provenance tags from the 14-source enum in §II). `CredentialSource` (10 classes listed in §II including `macos_keychain`, `long_lived_setup_token`, `api_key_helper`, `1password`, `infisical`, `devenv_secretspec`). `StartupPhase` (14-phase timeline from `boot` → `tool_call_subprocess` per §II.StartupPhase; enables temporal reasoning about env availability). These partially overlap ADR 0015's entities — reconciliation happens in the ADR 0016 drafting (shell research v2 §VIII).
- **Trap scaffold expansion for #19–#30** (12 traps total: #19–#25 from Cloudflare brief + #26–#30 from shell research v2). One file each under `packages/evals/regression/`, matching the #16/#18 scaffold format. Scaffolding requires live-provider/surface fixtures available in Phase 1 test harness.
- **Cloudflare Stage 3a eval fixture** — `cloudflare-access-stage3a-rate-limit-and-secret-capture.fixture.md` encoding the real trajectory. Seed trajectory in the Cloudflare lessons brief.
- **`hcs env-inspect` prototype** (shell research v2 §V.P12, 10h). Modes: `names_only | existence_check | classified | hashed`. Classifiers report "present + looks like JWT" / "present + looks like AWS key" / "present + non-secret shape" without echoing values. Includes regression trap for the `printenv | grep` anti-pattern. First-class operational surface for trap #18 defense-in-depth (text rule + hook + operation-shape).
- **Provenance snapshot data** (shell research v2 §V.P08, 6h) — committed as `packages/fixtures/provenance-snapshot-YYYY-MM-DD.json` golden regression fixture; re-snapshot on tool version changes per charter inv. 14.
- **Charter v1.3.0 candidate invariant 16** — "external-control-plane evidence-first": operations against remote control planes must produce typed evidence receipts (RateLimitObservation, RemoteMutationReceipt, CredentialIssuanceReceipt) and distinguish ProviderObjectReference from SecretReference. Queue-only; v1.2.0 remains active through W3.
- **Charter v1.3.0 candidate invariant 17** — "execution-context is declared, not inferred": every operation carries a resolved `ExecutionContext.surface` reference; agents must not assume a subprocess inherits credentials, env, or sandbox scope from the parent context. Motivated by shell research v2 conclusions 1, 8, 9, 10; §VI.
- **Principal-level `ResourceBudget` rollup** — the Cloudflare 5-minute/1200-request limit is a user-level budget cumulative across dashboard/API-key/API-token surfaces. Principal-scoped `ResourceBudget` abstraction queued in ADR 0015.

### Phase 1 shell/environment research program (shell research v2.0.0, 2026-04-27 → 2026-05-08)

Formal 10-working-day research program from `docs/host-capability-substrate/shell-environment-research.md` §IV. Secret-safe testing constraint throughout: existence-only checks, name-only capture, hashes, or classified/redacted — no raw secret values in transcripts. Grounded in trap #18 + NIST SP 800-92 + CWE-532/200 + OWASP logging guidance.

| Wave | Days | Prompts | Hours | Deliverable |
|------|------|---------|-------|-------------|
| Foundation | Mon 04-27 | — | 4 | Redaction-safe harness, synthetic repo, evidence template, redaction rules |
| Wave 1 — resolved/near-resolved | 04-27 → 04-29 | P01, P05, P02, P13, P06 | 12 | Five memos + wrapper logs + sandbox characterization |
| Wave 2 — genuinely open | 04-30 → 05-06 | P04, P03, P08, P09 | 30 | Cross-surface matrix + MCP/setup-script trace + provenance snapshot + direnv/mise matrix |
| Wave 3 — design + prototype (parallel with Wave 2) | 04-29 → 05-06 | P11, P12 | 16–20 | LaunchAgent-env policy table + `hcs env-inspect` prototype |
| Synthesis | 05-07 → 05-08 | — | 6 | ADR 0016 + 0017 + 0018 drafts, updated Ring-0 schemas, regression trap scaffolds #26–#30 |

**ADR candidates from synthesis (scoped by shell research v2 §VIII):**

- **ADR 0016 — Shell/environment ownership boundaries.** Policy conclusions 1–11 from shell research v2 §VI. Codifies: shell-exported secrets as CLI convenience only, prefer OAuth+Keychain or long-lived setup-token over env inheritance, project config vs shell/bootstrap config separation, no shell-persistence assumption between agent commands, explicit shell ownership for helper scripts, adopt Codex `shell_environment_policy` vocabulary for operator layer, adopt devcontainer `containerEnv`/`remoteEnv`/`userEnvProbe` for typing layer, `CLAUDE_ENV_FILE` as best-effort not durable, preserve subagent isolation as a security feature.
- **ADR 0017 — Codex app as distinct ExecutionContext.** Incorporates P13 sandbox characterization. Models Codex app's Seatbelt boundary as a strict-sandbox sub-class of `ExecutionContext` with its own capability matrix (Keychain access = false, shell-env inheritance = launchd-user-session-only, env injection = none). Blocks "Codex is Codex" mental model; makes the app/CLI divergence first-class.
- **ADR 0018 — Long-lived-token vs OAuth credential preference.** Reflects Anthropic's 2025–2026 removal of third-party OAuth support. Recommends `claude setup-token`-style 365-day tokens + API keys + 1Password service accounts over pure-subscription OAuth for HCS-integrated tooling. Subscription OAuth becomes a shrinking surface HCS must not architect around.

**Remaining unknowns** (shell research v2 §VII — upstream questions, not blocking Phase 1):

- `apiKeyHelper` Windows behavior (PowerShell vs cmd inconsistency).
- `CLAUDE_ENV_FILE` path uniqueness across parallel Claude Code sessions.
- Whether Codex `shell_snapshot` captures credential-shaped env vars under the default exclude filter.
- Whether `mise activate` runs in a non-TTY ACP session (Zed → Claude Agent).
- Whether Codex app Seatbelt profile is strictly tighter than CLI's.
- Claude Desktop Keychain service name vs CLI's `"Claude Code-credentials"`.

Discipline for W2–W3: no changes to `classify.py`, `.claude/hooks/`, `just measure` collectors, Codex profiles, `tiers.yaml`, or charter-on-main during the soak window (2026-04-24 and 2026-04-25). Draft-in-branch is permitted; merges land on 2026-04-26 in the ordered sequence above.

---

## Milestone 0 — Repository scaffold

**Goal:** The repo enforces its own discipline from commit 1.

**Acceptance:**

- Package layout exists (`packages/schemas`, `packages/kernel`, `packages/adapters`, `packages/dashboard`, `packages/evals`, `packages/fixtures`)
- `just verify` runs (even if it only runs lint + boundary-check + forbidden-string-scan + no-runtime-state-in-repo)
- Schema package compiles (empty but typed)
- `docs/host-capability-substrate/` exists with charter (v1.1.0+), tooling-surface-matrix, ADR stubs (0000 template + 0001-0011)
- `AGENTS.md`, `CLAUDE.md`, `PLAN.md`, `IMPLEMENT.md`, `DECISIONS.md` in place
- `.agents/skills/` has the six canonical workflow skills (hcs-adr-review, hcs-draft-adr, hcs-regression-trap, hcs-operation-proof, hcs-policy-tier-entry, hcs-schema-change)
- `.claude/agents/` has six subagents (architect, ontology-reviewer, policy-reviewer, security-reviewer, hook-integrator, eval-reviewer)
- `.claude/skills/` empty at Phase 0a
- `.claude/settings.json` present with model=opus, deny-list for forbidden literals, hook wiring
- `.claude/hooks/hcs-hook` present in log-only mode
- No `WARP.md`, no `.windsurf/`, no `.copilot/`
- CI boundary checks wired (strict from M0): boundary-check, policy-lint, schema-drift, forbidden-string-scan, no-live-secrets, no-runtime-state-in-repo

**Validation:**

```bash
just verify
```

---

## Milestone 1 — Ontology schemas (Ring 0)

**Goal:** 20 core entities are real and versioned.

**Acceptance:**

- 20 core entities (HostProfile, WorkspaceContext, Principal, AgentClient, Session, ToolProvider, ToolInstallation, ResolvedTool, Capability, OperationShape, CommandShape, Evidence, PolicyRule, Decision, ApprovalGrant, Run, Artifact, Lease, Lock, SecretReference, ResourceBudget) as Zod schemas
- JSON Schema generated from Zod
- Every entity has `schema_version`
- Provenance schema (`Evidence`) is reusable by every fact-returning service
- Docs autogenerated or hand-written and verified against schemas

**Validation:**

```bash
just test schemas
just generate-schemas --check
```

---

## Milestone 2 — Policy snapshot + decision package

**Goal:** Policy can be evaluated against structured inputs without a running kernel.

**Acceptance:**

- `tiers.yaml` schema validates against Zod entity schemas
- `Decision` and `ApprovalRequest` schemas exist
- YAML policy loader exists and rejects malformed or stale-schema-version files
- Policy input shape (principal + session + host + workspace + operation + resolved_tools + evidence + requested_capability + time) is defined
- **No execution path exists yet.** No `system.exec.*`, no approval endpoints.

**Validation:**

```bash
just test policy
just policy-lint
```

---

## Milestone 3 — SQLite audit/facts bootstrap

**Goal:** Visible state and audit state are both persisted and queryable, independently.

**Acceptance:**

- `storage.sql` applied to a temp SQLite DB with WAL mode
- `audit_events` append implemented with hash chain (row_hash = sha256(prev_hash || canonical(row)))
- Checkpoint table exists (checkpoints not yet written to `op://`)
- `facts` + `fact_observations` split implemented
- Read-only `recent_events(limit, filter)` query exists
- Power-cut mid-write test passes (WAL integrity)

**Validation:**

```bash
just test storage
just test audit-chain
```

---

## Milestone 4 — First MCP read tools

**Goal:** First adapter surface live. Five read-only capabilities callable from Claude Code, Codex, etc.

**Acceptance:**

- `system.host.profile.v1` exposes structured output matching `HostProfile` schema
- `system.session.current.v1` returns live `Session` + `SessionContext`
- `system.tool.resolve.v1` walks mise → project-local → brew → system and returns `ResolvedTool` with provenance
- `system.tool.help.v1` caches `--help` with provenance + parser version
- `system.policy.classify_operation.v1` accepts `OperationShape`, returns `Decision`
- **No mutating endpoints.** Charter invariant 7 enforced by absence.
- MCP stdio adapter wires these 5 tools with strict tool schemas
- Audit log records every call

**Validation:**

```bash
just test mcp
just test integration:claude-code
```

---

## Milestone 5 — Gateway propose + dashboard summary

**Goal:** Full slice-1 surface live; dashboard shows live state.

**Acceptance:**

- `system.gateway.propose.v1` creates a proposal, returns decision package, does not execute
- `system.audit.recent.v1` queries visible state
- `system.dashboard.summary.v1` returns summary payload + local dashboard URL
- Dashboard has read-only views: `/health`, `/sessions`, `/tools`, `/policy`, `/audit`, `/dashboard-summary.json`
- View-model contracts match `DashboardSummary`, `LiveSessionRow`, `HostFactCard`, `ToolResolutionTrace`, `PolicyDecisionCard`, `OperationProposalCard`, `AuditTimelineEvent`, `CacheEntryCard`, `HealthStatus`
- Dashboard never bypasses policy — calls through the same gateway

**Validation:**

```bash
just test dashboard
just test integration:end-to-end-readonly
```

---

## Milestone 6 — Hooks wired + regression corpus runner

**Goal:** Agent behavior is shaped by substrate from session 1.

**Acceptance:**

- Claude Code PreToolUse hook calls `resolve` + `classify_operation` with 50ms timeout and cache fallback
- Codex hook (where supported) logs advisory signals and blocks forbidden Bash patterns
- Regression corpus runner executes the seed 15 traps against at least Claude Opus
- Acceptance criteria from research plan §6 Phase 3 measurable:
  - ≥50% reduction in redundant `--help` probes across agents vs baseline (top 10)
  - cache-hit p50 < 20ms, p99 < 80ms
  - cache-miss overhead < 50ms above underlying CLI
  - graceful degradation when kernel down
  - ≥1 documented substrate-beats-raw-shell case

**Validation:**

```bash
just test evals
just measure       # run daily during the active soak window
just measure-brief # consolidate partitions into the metrics diff
```

---

## Stop-and-fix rules

- If `just verify` fails, fix before proceeding to the next milestone.
- If a boundary-check rule is violated, the PR does not merge — even if tests pass.
- If a regression trap is triggered by substrate changes, add the trap to the corpus and fix in the same PR.
- If a schema changes, regenerate JSON Schema in the same commit.

## Architecture notes

- Ring 0 (schemas) ships first. Every other ring builds on it.
- Ring 1 (kernel) ships before any adapter. Never the reverse.
- Dashboard view contracts land with Ring 1 services — kernel output must be dashboard-renderable from day 1.
- Execute lane (mutations) is blocked at CI until Milestone M4-Month-4 of the full roadmap in research plan §6 Phase 4.

## Out of scope for initial build (explicit)

- Execute lane endpoints
- Approval grant creation/consumption
- Sandbox executor
- Remote (non-localhost) MCP
- A2A facade
- MCP Apps UI embeds

These belong in later milestones after the read-only substrate has demonstrated value under soak.
