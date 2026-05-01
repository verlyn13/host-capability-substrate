---
adr_number: 0016
title: Shell and environment ownership boundaries
status: proposed
date: 2026-05-01
charter_version: 1.2.0
tags: [shell, environment, execution-context, env-provenance, credentials, phase-1]
---

# ADR 0016: Shell and environment ownership boundaries

## Status

proposed

## Date

2026-05-01

## Charter version

Written against charter v1.2.0.

## Context

Phase 1 shell/environment research showed that shell state is not a stable
substrate contract. Codex CLI, Codex app, Claude Code CLI, Claude Desktop, IDE
extensions, MCP servers, setup scripts, and subagents all expose different
environment, shell, credential, startup, and sandbox behavior. The same vendor
surface can split further by phase: Codex CLI internal startup shells and actual
tool-call subprocesses were different observations, and Claude Code Bash calls
do not persist exported variables between commands.

The repo already has charter constraints that bear directly on this problem:
shell strings are downstream renderings, secrets do not live at rest in HCS,
sandbox observations cannot become host-authoritative evidence, runtime config
claims need authority provenance, and GUI/app/IDE agents must not be assumed to
inherit terminal shell env. The remaining Phase 1 question is how HCS should
own the boundary between project config, shell/bootstrap config, app settings,
MCP startup auth, and per-tool execution evidence.

This ADR records the design posture for subsequent Ring 0 schema work and Ring
1 operation design. It does not add schemas, adapters, hooks, live policy, or
mutating execution endpoints.

## Options considered

### Option A: Treat inherited shell env as the substrate contract

**Pros:**
- Minimal implementation work.
- Matches how many CLI-only workflows are hand-operated today.
- Lets existing `.zshrc`, `.envrc`, `mise activate`, and exported variables
  continue to work when a terminal happens to source them.

**Cons:**
- Fails for GUI apps, IDE extensions, MCP startup, and subagents.
- Repeats the exact failure class from P02/P04/P06/P09/P13 research.
- Encourages secret-bearing environment variables as ambient authority.
- Cannot explain timing-sensitive cases such as setup scripts vs MCP server
  initialization.

### Option B: Let each adapter implement vendor-specific env rules

**Pros:**
- Captures vendor quirks close to the protocol wrapper.
- Can be shipped incrementally per surface.
- Avoids broad schema work initially.

**Cons:**
- Violates the four-ring architecture by pushing policy and reasoning into
  adapters.
- Makes cross-surface comparisons impossible.
- Encourages duplicate hook/app/IDE policy and drift.
- Cannot give the dashboard a consistent review model for evidence freshness,
  confidence, or authority.

### Option C: Model env through typed execution context and provenance

**Pros:**
- Preserves CLI convenience while rejecting it as cross-surface authority.
- Gives HCS one vocabulary for Codex, Claude, GUI apps, IDEs, terminals, MCP
  servers, setup scripts, and subagents.
- Aligns with charter invariants 2, 5, 8, 14, and 15.
- Keeps adapters thin: they report surface facts; kernel/schema layers reason
  over typed evidence.

**Cons:**
- Requires Ring 0 schema design before broad enforcement.
- Requires per-surface probes and fixtures before claims can be trusted.
- Some user workflows will need explicit brokered credentials or app-native
  auth rather than implicit shell exports.

### Option D: Forbid environment-variable credentials entirely

**Pros:**
- Strongly reduces accidental credential leakage.
- Simplifies secret-scanning and audit posture.
- Forces durable secret references or brokered credentials.

**Cons:**
- Too disruptive for Phase 1 and for existing CLI tools.
- Conflicts with legitimate local developer workflows and vendor-supported
  escape hatches.
- Does not solve non-secret env provenance such as PATH, HOME, TMPDIR, cwd,
  feature flags, or setup markers.

## Decision

HCS will model shell and environment state through typed `ExecutionContext` and
`EnvProvenance` evidence rather than treating inherited shell env as a substrate
contract. Shell-exported values are allowed as explicit CLI-local convenience,
but they are not cross-surface authority and cannot be assumed for GUI apps,
IDE extensions, MCP startup, setup scripts, subagents, or app-managed preview
surfaces. Project config owns shared non-secret behavior; shell/bootstrap layers
own local activation; credential availability must come from typed credential
sources, app-native auth, brokered secret references, or direct per-surface
evidence.

## Consequences

### Accepts

- Future schema work should define `ExecutionContext`, `EnvProvenance`,
  `CredentialSource`, and `StartupPhase` as first-class concepts or evidence
  subtypes.
- HCS should adopt Codex's operator vocabulary:
  `inherit`, `include_only`, `exclude`, `set`, `overrides`, and
  `ignore_default_excludes`.
- HCS should adopt the devcontainer-style distinction between baked env,
  runtime-applied env, and probed env.
- `CLAUDE_ENV_FILE` is best-effort evidence, not durable substrate state.
- Subagent isolation is a security property; parent session env/auth should not
  be bridged implicitly.
- Setup scripts and local environments are worktree/bootstrap scope unless a
  direct startup-order receipt proves otherwise for a specific surface.
- Secret-safe env inspection should use names-only, existence-only,
  classified, or hashed output. Raw secret-shaped values stay out of
  transcripts and repo artifacts.

### Rejects

- Shell env inheritance as a general substrate contract.
- Putting env policy, credential classification, or startup-auth decisions into
  MCP, CLI, Claude, Codex, dashboard, or hook adapters.
- Treating Codex app, Claude Desktop, IDE extensions, or Preview sessions as if
  they inherit terminal `.zshrc`, direnv, mise, or per-command exports.
- Treating project config, app settings, setup scripts, shell startup files,
  and MCP auth as one interchangeable configuration plane.
- Treating app permission prompts as HCS `ApprovalGrant` records.
- Registering a universal shell execution tool to paper over env divergence.

### Future amendments

- ADR 0017 should specialize the Codex app as a distinct `ExecutionContext`
  once P13 app-internal proof exists.
- ADR 0018 should decide the durable credential preference between long-lived
  setup tokens, API keys, OAuth, and brokered secret references.
- Q-003 may later connect env/evidence facts to a coordination store, but
  derived summaries must not become decision authority.
- Q-007/Q-008 may extend this ADR with freshness-bound boundary claims and
  execution-mode receipts.
- If vendor docs or installed runtimes materially change shell/env behavior,
  this ADR should be re-reviewed under charter invariant 14.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0,
  invariants 2, 5, 8, 12, 14, and 15
- Shell/env research:
  `docs/host-capability-substrate/shell-environment-research.md` v2.12.0
- Phase 1 runbook:
  `docs/host-capability-substrate/phase-1-shell-env-direct-test-runbook.md`
- Codex config/app ingest:
  `docs/host-capability-substrate/research/shell-env/2026-05-01-codex-official-config-app-settings-ingest.md`
- Claude app/settings ingest:
  `docs/host-capability-substrate/research/shell-env/2026-05-01-claude-desktop-code-settings-ingest.md`
- Related ADRs: ADR 0001, ADR 0007, ADR 0012, ADR 0015
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- OpenAI Codex config, sandbox, hooks, local-environments, and feature docs
- Anthropic Claude Code authentication, settings, hooks, MCP, and subagent docs
- Apple launchd, LaunchAgent, and TCC/responsible-process documentation
- Dev Containers environment-variable model
- 1Password CLI and Infisical credential-injection documentation
