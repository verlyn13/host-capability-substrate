---
title: HCS Tooling Surface Matrix
category: reference
component: host_capability_substrate
status: active
version: 1.4.0
last_updated: 2026-05-01
tags: [tooling, ide, claude-code, codex, cursor, warp, windsurf, vscode, iterm2, mcp, skills, integration, isolation]
priority: high
---

# HCS Tooling Surface Matrix

Authoritative reference for which config file belongs to which tool, what each tool can enforce vs observe, where skills and policy actually live, and what posture each surface must hold at Phase 0a / Phase 3 / Phase 4. Intended to prevent "where should this go?" drift.

Parent decision: [`adr/0001-repo-boundary.md`](./adr/0001-repo-boundary.md). Charter: [`implementation-charter.md`](./implementation-charter.md).

## Tool baseline (binding during early phases)

- **Claude Code CLI:** `2.1.120` minimum; Opus 4.7 model (`opus` short name in settings). Claude macOS app build identifiers are tracked separately.
- **Codex CLI:** `0.125.0` minimum; GPT-5.5/GPT-5.4-compatible HCS profiles. Codex macOS app build identifiers are tracked separately.
- **Subsequent minor updates:** acceptable without re-baselining

Re-evaluate after material version changes per D-029 and charter invariant 14.

## Reading this matrix

Columns in the full table below:

- **Surface:** the tool or file
- **Config path:** where the configuration lives
- **Scope:** user / project / managed
- **Canonical or generated:** is this the source of truth, or a projection of another artifact?
- **Can enforce:** can this surface block actions?
- **Can observe:** can this surface capture signals for audit/metrics?
- **Can call MCP:** does it speak MCP?
- **Can define skills:** does it load `.agents/skills/` or its own equivalent?
- **Allowed to contain policy:** yes / no / pointer-only
- **Owner of record:** who reviews changes here
- **Phase 0a / 3 / 4 posture:** what should exist at each phase

## Isolation vocabulary discipline

`Can enforce` in this matrix does not always mean OS-level containment. Keep
these evidence dimensions separate:

- permission gating: ask/allow/deny modes, allowlists, denylists, tool prompts;
- worktree/file isolation: separate branch/root, not separate process authority;
- local kernel sandbox: Seatbelt, bubblewrap, seccomp, Windows sandbox, or
  equivalent host-enforced process containment;
- container/VM isolation: devcontainer, Docker worker, VM snapshot, or runner
  boundary;
- remote cloud execution: vendor or managed infrastructure, external
  control-plane evidence, not local host evidence.

Tool docs and UI labels are observation sources. They do not become HCS policy
or host-authoritative runtime facts until reconciled through typed evidence.

## Full matrix

### Canonical cross-tool surfaces

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `AGENTS.md` | repo root | project | **canonical** | no (behavior only) | no | no | no (pointer) | pointer-only | hcs-architect + human | full contract; ≤ context cap | unchanged | unchanged |
| `CLAUDE.md` | repo root | project | **canonical** (behavior) | no | no | no | no | no | hcs-architect + human | imports AGENTS.md; Claude-specific notes | unchanged | unchanged |
| `.agents/skills/` | repo root | project | **canonical** (skill content) | no | no | no | **yes** | no | hcs-architect + hcs-eval-reviewer | 6 seed skills (see charter §§) | add/edit as workflows emerge | unchanged |
| `PLAN.md` | repo root | project | canonical (milestones) | no | no | no | no | no | human owns | milestones 0–6 | updated per milestone | updated per milestone |
| `IMPLEMENT.md` | repo root | project | canonical (workflow rules) | no | no | no | no | no | human owns | rules + change classes | unchanged | unchanged |
| `DECISIONS.md` | repo root | project | canonical (decision ledger) | no | no | no | no | no | human owns | seeded with D-001–D-016 | grows per ADR | grows per ADR |
| `docs/host-capability-substrate/implementation-charter.md` | repo / system-config | project | **canonical** (binding rule) | no (behavioral) | no | no | no | **yes (invariants)** | human owns; PRs via hcs-architect | v1.1.0 lifted from system-config | unchanged unless amended | unchanged unless amended |
| `docs/host-capability-substrate/ontology.md` | repo | project | canonical (human-facing) | no | no | no | no | no | hcs-ontology-reviewer + human | stub | populated in Phase 1 Thread D | stable |
| `system-config/policies/host-capability-substrate/` | system-config repo | project (governance) | **canonical** (live policy) | yes (via substrate) | no | no | no | **yes (runtime policy data)** | human; reviewed by hcs-policy-reviewer subagent | schema + seed tiers.yaml | populated incrementally | expanded with write-tier rules |
| `policies/generated-snapshot/` in HCS repo | repo | test fixture | generated | no | no | no | no | no (fixture only) | CI | empty with README | snapshot present for tests | snapshot current |
| `packages/schemas/` | repo | project | **canonical** (ontology) | no | no | no | no | no | hcs-ontology-reviewer | empty .gitkeep | 20 entities populated | stable + versioned |

### Claude Code surfaces

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `.claude/settings.json` | repo root | project | canonical (Claude Code project policy) | **yes** (permissions + hooks) | yes (hook telemetry) | yes (allowlist) | no | forbidden-literal list + server allowlist only | human owns; hcs-security-reviewer audits | model=opus, deny forbidden literals, hooks wired log-only | HCS MCP allowlisted | approval-mode managed |
| `.claude/settings.local.json` | repo root | local (not committed) | — | yes | yes | yes | no | no | individual dev | gitignored | gitignored | gitignored |
| `.claude/agents/hcs-*.md` | repo | project | canonical (subagent behavior) | no (model-guided) | no | no (inherits project MCP) | no | no | human owns; hcs-architect reviews | 6 subagents | unchanged unless ontology evolves | unchanged |
| `.claude/skills/` | repo | project | **Claude-specific wrappers only** | no | no | no | yes (Claude-specific) | no | hcs-architect + human | **empty at Phase 0a** | add only if Claude Code needs a wrapper for canonical `.agents/skills/` content | stable |
| `.claude/hooks/hcs-hook` | repo | project | canonical (implementation-phase hook) | **yes** (exit 2 blocks) | yes (logs to `.logs/phase-0/`) | no | no | literal forbidden patterns only; never tier tables | hcs-hook-integrator + human | log-only, blocks literal forbidden | upgraded to RPC HCS gateway; 50ms timeout + cache fallback | same |
| `~/.claude/agents/` | user-global | user | — | no | no | yes | no | no | user | unchanged (existing 6 generic) | unchanged | unchanged |
| `~/.claude.json` | user-global | user | generated per-machine | yes (permission precedence) | yes | yes (MCP baseline) | no | no (MCP config only) | user; `sync-mcp.sh` writes baseline | no HCS entry | no HCS entry | **decide via ADR** whether HCS joins baseline |
| Claude Code Desktop settings UI | app-managed storage | user/app | generated/user-managed | yes (app posture) | yes | yes | no | no | user + Claude app | observe only | observe only; map to `ExecutionContext` facets after probes | observe only |
| `.claude/worktrees` | repo-local generated worktrees | project/app | generated runtime/worktree state | limited | yes | no | no | no | Claude app + user | do not rely on; do not delete by path shape | observe only with worktree/branch proof | observe only with worktree/branch proof |
| Claude Preview session storage | app-managed per-workspace browser state | user/app | generated runtime state | limited | yes | no | no | no | user + Claude app | do not inspect | inspect only with redacted operation proof | inspect only with redacted operation proof |
| Claude Code on the Web automation settings | app/cloud setting | user/cloud | app/cloud managed | yes (GitHub-side effects) | yes | no | no | no | user + Claude service | observe only | route through GitHub authority model | route through GitHub authority model |

### Codex surfaces

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `AGENTS.md` | repo root | project | canonical (cross-tool) | no | no | no | no | pointer-only | — | see cross-tool row above | — | — |
| `.codex/config.toml` | repo root | project (opt-in trust) | canonical (project override) | limited | no | yes | no | no | human owns | minimal override | unchanged | adjusted if approvals flow through Codex |
| `.agents/skills/` | repo root | project | canonical (cross-tool) | no | no | no | **yes** | no | — | see cross-tool row above | — | — |
| `~/.codex/config.toml` | user-global | user | canonical (user defaults + profiles) | limited | no | yes | no | no | user; version-controlled via chezmoi backup | add `hcs-plan`/`hcs-implement`/`hcs-review` profiles + trusted-project entry | unchanged | unchanged |
| `/etc/codex/config.toml` | system | host | external canonical (system defaults, if present) | limited | no | yes | no | no | host/admin | observe only | observe only | observe only |
| Codex managed `requirements.toml` | managed machine | org/admin | external canonical (constraints) | yes (Codex constraints) | no | no | no | no HCS live policy | org/admin | observe only | observe only | observe only |
| Codex app settings UI | app-managed storage | user/app | generated/user-managed | yes (app posture) | yes (diagnostics) | yes | no | no | user + Codex app | observe only | observe only; map to `ExecutionContext` facets | observe only |
| Codex app Workspace Dependencies | app-managed bundle | user/app | generated | no | yes | no | no | no | Codex app | observe only | tool-resolution evidence only | tool-resolution evidence only |
| Codex app local environments/actions | `.codex/` project folder | trusted project/app | canonical (worktree bootstrap + app actions) | limited | yes | no | no | no secrets, no startup auth | human owns | absent/minimal | bootstrap/actions only | bootstrap/actions only |
| `~/.codex/skills/` | user-global | user | — | no | no | no | yes | no | user | unchanged (existing: codex-primary-runtime, pdf) | unchanged | unchanged |
| Codex hooks (Bash-only coverage) | `~/.codex/config.toml` | user-global | canonical | **advisory only** (not sufficient for hard enforcement — see §21.4 of plan) | yes | no | no | literal forbidden patterns only | user | log + warn | log + warn; forward severe cases to dashboard | same |

### Cursor surfaces

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `.cursor/mcp.json` | repo root | project | generated (project MCP) | no | no | yes | no | no | human | empty stub | HCS MCP populated if Cursor in use | same |
| `.cursor/rules/*.mdc` | repo root | project | pointer-only | no (advisory) | no | no | no | pointer-only | human; hcs-architect reviews | thin rules: `hcs-boundaries.mdc`, `hcs-review-checklist.mdc` | unchanged | unchanged |
| `~/.cursor/mcp.json` | user-global | user | generated | no | no | yes | no | no | user; `sync-mcp.sh` | no HCS entry | no HCS entry | possibly populated via sync |

### Windsurf surfaces

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `AGENTS.md` | repo root | project | canonical (cross-tool) | no | no | no | no | pointer-only | — | (Windsurf reads AGENTS.md at repo root) | — | — |
| `.agents/skills/` | repo root | project | canonical (cross-tool) | no | no | no | **yes** (Windsurf discovers) | no | — | — | — | — |
| `~/.codeium/windsurf/mcp_config.json` | user-global | user | generated | no | no | yes | no | no | user; `sync-mcp.sh` | unchanged | possibly populated for HCS if Windsurf used | same |
| (no project-scope Windsurf config) | — | — | — | — | — | — | — | — | — | **do not create** `.windsurf/` | — | — |

### Warp surfaces

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `AGENTS.md` | repo root | project | canonical (cross-tool) | no | no | no | no | pointer-only | — | Warp reads AGENTS.md when WARP.md absent | — | — |
| `WARP.md` | repo root | project | — | no | no | no | no | — | — | **absent at Phase 0a** | decide based on Phase 0b findings; if added, pointer-only referencing AGENTS.md | same |
| Warp Drive Rules / Workflows / MCP | Warp app config | user | app-managed | limited | yes | yes | no | no | user | unchanged | possibly register HCS MCP if Warp used | same |
| `.agents/skills/` | repo root | project | canonical (cross-tool) | no | no | no | yes (future Warp versions may honor) | no | — | — | — | — |

### VS Code surfaces

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `.vscode/settings.json` | repo root | project | canonical (editor conveniences) | no | no | no | no | **no** — editor/task only | human; hcs-hook-integrator may edit | formatter = biome, format-on-save, TS SDK = workspace | unchanged | unchanged |
| `.vscode/extensions.json` | repo root | project | canonical | no | no | no | no | no | human | recommended: biome, vitest | unchanged | unchanged |
| `.vscode/tasks.json` | repo root | project | canonical | no | no | no | no | no | human | `just verify`, `just test`, `just boundary-check` | unchanged | unchanged |
| `.vscode/launch.json` | repo root | project | canonical (debug configs) | no | no | no | no | no | human | empty at Phase 0a | added when debug is needed | expanded as broker FSM lands |
| `.vscode/settings.local.json` | repo root | local | — | no | no | no | no | no | individual dev | gitignored | gitignored | gitignored |

### Copilot CLI surfaces

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `.copilot/mcp-config.json` | repo root | project | generated | no | no | yes | no | no | — | **absent at Phase 0a** (add only if Copilot becomes a target agent) | add when targeted | same |
| `~/.copilot/mcp-config.json` | user-global | user | generated | no | no | yes | no | no | user; `sync-mcp.sh` | unchanged (native github MCP) | unchanged | same |

### Adjacent agent/cloud surfaces (compatibility-only)

The 2026-05-01 agentic tool isolation intake widens compatibility awareness. The
rows below are not commitments to add project config or adapters. They prevent
future agents from treating product capability, permission prompts, worktrees,
and remote execution as one authority class.

| Surface | Evidence class | Scope | HCS posture |
|---------|----------------|-------|-------------|
| Devin sessions / child agents | remote VM / vendor cloud | user/org cloud | Observe as external control-plane / remote environment evidence only; no HCS local sandbox claim. |
| Codex cloud tasks | remote cloud sandbox | user/org cloud | Observe as remote execution receipts; do not satisfy local Codex CLI/app `ExecutionContext` claims. |
| Cursor cloud / self-hosted cloud agents | remote VM or self-hosted environment | user/org/cloud | Compatibility input for Q-010; local Cursor terminal sandbox remains a separate surface. |
| GitHub Copilot cloud agent | GitHub Actions-powered remote environment | GitHub cloud | Route through Q-005/Q-006 for runner/check/source identity evidence. |
| Warp Oz / self-hosted workers | remote cloud or isolated Docker worker | user/org/cloud | Treat local Warp terminal and Oz worker execution as different `ExecutionContext` classes. |
| Amp | permissioned local execution | user/project | No HCS policy in `.amp/`; require outer boundary evidence for sensitive autonomous execution. |
| OpenCode | permissioned local execution | user/project | Do not treat permissive default tools as safe; no HCS policy in opencode config. |
| Augment/Auggie + Intent | permissioned local execution plus Git worktrees | user/project | Worktree isolation is not process isolation; compose with `WorkspaceContext` / `Lease` before mutations. |

### Claude Desktop

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `~/Library/Application Support/Claude/claude_desktop_config.json` | user-global | user | app-managed | no | no | yes | no | no | user | unchanged | possibly register HCS MCP manually if desired | same |
| Claude Desktop filesystem tool permissions | app-managed storage | user/app | generated/user-managed | yes (app prompts) | yes | yes | no | no | user + Claude app | observe only | do not treat prompts as HCS approval grants | same |

### iTerm2

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| iTerm2 Dynamic Profiles | `system-config/iterm2/profiles/` | user (via system-config) | canonical (presentation) | no | yes (shell integration: cwd, host, username, exit codes) | no | no | no | system-config/iterm2-authority | **no new profile**; use existing `agentic-zsh` / `dev-zsh` | unchanged | unchanged |
| iTerm2 Shell Integration | shell-rendered | session | generated | no | yes (prompt boundaries, command history, return codes) | no | no | no | existing zsh config (chezmoi) | respected — HCS does not interfere | respected | respected |

### Runtime (not in repo)

| Surface | Config path | Scope | Canonical or generated | Can enforce | Can observe | Can call MCP | Can define skills | Allowed to contain policy | Owner | Phase 0a | Phase 3 | Phase 4 |
|---------|-------------|-------|------------------------|-------------|-------------|--------------|-------------------|---------------------------|-------|----------|---------|---------|
| `~/Library/Application Support/host-capability-substrate/` | filesystem | local | generated | — | — | — | — | **loaded policy copy** (hash-verified against system-config source) | HCS runtime | **does not exist** | populated on first launchd load | populated |
| `~/Library/Logs/host-capability-substrate/` | filesystem | local | generated | — | — | — | — | no | HCS runtime | does not exist | populated | populated |
| `~/Library/LaunchAgents/com.jefahnierocks.host-capability-substrate.plist` | filesystem | user | generated from template | yes (service lifecycle) | yes (logs) | — | — | no | `scripts/install/install-launchd.sh` | not installed | installed at end of Phase 3 | installed |
| 1Password `Dev` vault (audit-checkpoint, dashboard tokens) | `op://Dev/host-capability-substrate/*` | user | canonical (secret store) | — | — | — | — | no (references only) | user | no items yet | created with dashboard launch | expanded with token rotation |

## Posture summary (one-line per surface)

```
AGENTS.md                  canonical behavior contract — required, ≤ context cap
CLAUDE.md                  imports AGENTS.md + Claude-specific notes — required
.agents/skills/            cross-tool canonical workflow home — 6 skills at Phase 0a
.claude/agents/            project-scoped subagents — 6 at Phase 0a
.claude/settings.json      Claude Code project policy — enforceable; forbidden literals only
.claude/skills/            Claude-specific wrappers only — empty at Phase 0a
.claude/hooks/hcs-hook     thin bash helper — log-only at Phase 0a
Claude Code Desktop UI     app permission/worktree/preview posture — observe only
Claude Preview sessions    runtime browser state — never repo state
Claude web automation      PR/comment side effects — GitHub authority model
.codex/config.toml         project Codex override — minimal
Codex app settings UI      app posture and diagnostics — observe only
Codex app local envs       worktree bootstrap/actions — not startup auth
.cursor/rules/             thin pointer rules — no policy duplication
.cursor/mcp.json           empty at Phase 0a
.vscode/*.json             editor/task convenience only — no policy
WARP.md                    absent at Phase 0a
.windsurf/                 absent (no project scope)
.copilot/                  absent at Phase 0a
system-config policies     LIVE AUTHORITY for runtime policy — canonical
~/Library/Application Support/host-capability-substrate/   runtime state — not in repo
~/Library/Logs/host-capability-substrate/                  logs — not in repo
~/Library/LaunchAgents/com.jefahnierocks.host-capability-substrate.plist   service lifecycle
```

## Routing rules (where does a new thing go?)

When adding X to the repo, route by type:

- **New skill / workflow**: `.agents/skills/<name>/SKILL.md`. Only if Claude Code fails to discover it, add a thin wrapper at `.claude/skills/<name>/SKILL.md` that references the canonical.
- **New forbidden literal pattern**: `.claude/settings.json` `deny` list AND the `.claude/hooks/hcs-hook` body. Do **not** duplicate into `.cursor/rules/`, `.vscode/`, `WARP.md`, or AGENTS.md.
- **New tier classification for a tool**: `system-config/policies/host-capability-substrate/tiers.yaml`. Never inline in `.claude/`, hooks, adapters, or Skills.
- **New architectural decision**: `docs/host-capability-substrate/adr/<next-number>-<slug>.md`. Record accepted state in `DECISIONS.md`.
- **New ontology entity or field**: `packages/schemas/src/entities/`. Simultaneous: `docs/host-capability-substrate/ontology.md`, tests, generated JSON Schema. One PR.
- **New regression trap**: `packages/evals/regression/<trap-name>.md`. Add to seed tracker; run in CI subset.
- **New capability (operation)**: `packages/kernel/src/capabilities/<capability>.ts` + renderer + preflight + verification. Simultaneous: tier entry in system-config policy. Six-question surface-boundary answers in capability description.
- **New adapter feature**: `packages/adapters/<adapter>/`. Zero policy, zero kernel internals. Boundary-check CI enforces.
- **New editor convenience**: `.vscode/settings.json` or equivalent. No policy, no forbidden lists.

## Anti-patterns (what not to do)

- **Duplicating forbidden lists across `.claude/`, `.cursor/`, `.vscode/`, `WARP.md`** — live in one place (`.claude/settings.json` deny-list for enforcement, `system-config/policies/` for runtime policy).
- **Creating `WARP.md` in Phase 0a** — Warp prioritizes `WARP.md` over `AGENTS.md`; creating one before the contract stabilizes risks fork.
- **Creating `.windsurf/skills/`** — redundant with `.agents/skills/`; Windsurf already discovers the cross-tool location.
- **Putting policy tier data in Cursor rules or AGENTS.md** — these are pointers; the live tier file is in system-config.
- **Adding `.copilot/` stubs speculatively** — only add when Copilot is actually part of HCS workflow.
- **Scoping HCS subagents to `~/.claude/agents/`** — project-scope keeps them invisible outside HCS work.
- **Using `sonnet` or `haiku` models during early-phase HCS work** — early-phase baseline is Opus 4.7 for Claude, GPT-5.5/GPT-5.4-compatible HCS profiles for Codex.
- **Using WARP.md or .cursor/rules/ for policy enforcement** — those surfaces can't enforce; Claude Code settings + HCS gateway enforce.

## References

### Internal

- [`adr/0001-repo-boundary.md`](./adr/0001-repo-boundary.md)
- [`implementation-charter.md`](./implementation-charter.md) (v1.2.0+)
- `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`
- `~/Organizations/jefahnierocks/system-config/docs/mcp-config.md`
- `~/Organizations/jefahnierocks/system-config/docs/project-conventions.md`

### External

- Claude Code [Settings](https://docs.anthropic.com/en/docs/claude-code/settings), [Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks), [Sub-agents](https://docs.anthropic.com/en/docs/claude-code/sub-agents), [Memory](https://docs.anthropic.com/en/docs/claude-code/memory)
- Codex [AGENTS.md](https://developers.openai.com/codex/guides/agents-md), [Config basics](https://developers.openai.com/codex/config-basic), [Profiles](https://developers.openai.com/codex/config-advanced), Codex app settings pane (`codex://settings`), [Local environments](https://developers.openai.com/codex/app/local-environments), [Skills](https://developers.openai.com/codex/skills), [Subagents](https://developers.openai.com/codex/subagents), [Hooks](https://developers.openai.com/codex/hooks)
- Windsurf [Skills](https://docs.windsurf.com/windsurf/cascade/skills), [AGENTS.md](https://docs.windsurf.com/windsurf/cascade/agents-md), [MCP](https://docs.windsurf.com/windsurf/cascade/mcp)
- Warp [Agents](https://docs.warp.dev/agent-platform/getting-started/agents-in-warp), [Rules](https://docs.warp.dev/agent-platform/warp-agents/capabilities-overview/rules)
- iTerm2 [Shell Integration](https://iterm2.com/shell_integration.html)
- VS Code [Terminal Shell Integration](https://code.visualstudio.com/docs/terminal/shell-integration)

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.4.0 | 2026-05-01 | Added isolation vocabulary discipline and compatibility-only adjacent agent/cloud surface intake from the 2026-05-01 report. |
| 1.3.0 | 2026-05-01 | Added Claude Desktop and Claude Code Desktop settings, filesystem permission, worktree, Preview, and web automation surfaces. |
| 1.2.0 | 2026-05-01 | Added official Codex system/managed/app settings, Workspace Dependencies, and local-environment/action surfaces. |
| 1.1.0 | 2026-04-26 | Updated early-phase tool baselines to public CLI semver per D-029 and charter v1.2.0; app build identifiers are now tracked separately. |
| 1.0.0 | 2026-04-22 | Initial matrix. Created alongside boundary decision v1.1.0 to prevent "where should this go?" drift. |
