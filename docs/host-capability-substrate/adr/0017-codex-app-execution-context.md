---
adr_number: 0017
title: Codex app is a distinct execution context
status: proposed
date: 2026-05-01
charter_version: 1.2.0
tags: [codex, macos-app, execution-context, sandbox, app-settings, phase-1]
---

# ADR 0017: Codex app is a distinct execution context

## Status

proposed

## Date

2026-05-01

## Charter version

Written against charter v1.2.0.

## Context

ADR 0016 records the general shell/environment ownership boundary: inherited
terminal shell env is not a cross-surface substrate contract. Codex needs a
separate follow-up because the Codex CLI, Codex macOS app, Codex app server,
IDE extension, local-environments setup scripts, and app-integrated terminal
are easy to conflate.

Phase 1 evidence already rejects the "Codex is Codex" shortcut:

- P02 showed terminal `open -n` is not a clean GUI proxy, while a Finder-origin
  cold launch did not inherit a synthetic terminal-only marker.
- P13 captured Codex app bundle, helper, signing, process, app-server schema,
  and sandbox-flag evidence, but left app-internal Keychain/filesystem/network
  status pending.
- The 2026-05-01 Codex config/app-settings ingest observed the current local
  app bundle separately from Workspace Dependencies and recorded app settings,
  permissions, Git/worktree, and local-environment surfaces as source intake,
  not runtime proof.
- P06 closed shell carrier evidence for Codex CLI only; it did not close the
  app or IDE execution contexts.

The design problem is how to model the Codex app before every app-internal
capability row is proven. HCS needs to prevent agents from using CLI evidence
as app evidence while still allowing a typed place to attach future app
receipts.

## Options considered

### Option A: Treat Codex app as the same execution context as Codex CLI

**Pros:**
- Simple mental model.
- Reuses already-captured CLI shell and provenance fixtures.
- Avoids early schema branching.

**Cons:**
- Contradicts P02 GUI inheritance evidence.
- Promotes CLI-side observations to app authority.
- Hides app-managed settings, Workspace Dependencies, worktree pruning, and
  GUI/app sandbox behavior.
- Would let agents assume CLI profiles, shell env, Keychain access, and network
  state apply to app sessions without proof.

### Option B: Defer all Codex app modeling until P13 is complete

**Pros:**
- Avoids premature capability claims.
- Keeps Ring 0 schema smaller in the short term.
- Forces more direct runtime evidence before any app facts become modelable.

**Cons:**
- Leaves no typed home for already-valid P02/P13/source-ingest evidence.
- Makes it harder for policies and dashboards to explain why CLI evidence
  cannot satisfy app claims.
- Encourages ad hoc docs language instead of explicit pending capability
  fields.

### Option C: Model Codex app as a distinct execution context with pending facets

**Pros:**
- Separates proven identity/env-boundary facts from unproven capability rows.
- Gives future P13/P03/P04/P09 receipts a stable attachment point.
- Aligns with charter invariant 15 and ADR 0016.
- Prevents CLI, app, IDE, setup-script, and app-integrated-terminal evidence
  from being promoted across surfaces.

**Cons:**
- Requires schema support for unknown/pending/partial observations.
- Requires dashboard and policy code to handle incomplete capability matrices.
- Still needs human discipline until Ring 0 and Ring 1 are implemented.

### Option D: Treat app settings UI as the app execution context

**Pros:**
- Captures user-visible app posture such as approval policy, sandbox settings,
  full access, Auto-review, Workspace Dependencies, and local environments.
- Useful for dashboard display and operator review.

**Cons:**
- UI labels do not prove backing storage or runtime behavior.
- App settings are posture/source evidence, not live execution receipts.
- Does not prove Keychain, filesystem, network, shell carrier, or MCP startup
  behavior.

## Decision

HCS will model the Codex macOS app as a distinct `ExecutionContext` surface,
provisionally named `codex_app_sandboxed`, with identity, launch, app-setting,
and host-visible process evidence separated from pending app-internal
capability evidence. CLI evidence, temporary CLI-started app-server evidence,
IDE evidence, setup-script evidence, and app-integrated-terminal evidence must
not satisfy `codex_app_sandboxed` claims unless the receipt explicitly names
that surface and was captured through a valid app observation path.

## Consequences

### Accepts

- P02 Finder-origin marker absence is valid evidence for the Codex app GUI env
  boundary on this host/version family.
- P13 bundle/process/schema evidence is valid identity and probe-design input,
  but not a complete app sandbox capability matrix.
- Codex app settings, Workspace Dependencies, Git/worktree controls, local
  environments, and actions are source/app posture facets, not kernel policy or
  runtime proof.
- `codex_app_sandboxed` capability rows for Keychain, filesystem, network,
  shell carrier, MCP startup timing, and toolchain PATH remain pending until
  direct per-surface receipts exist.
- Dashboard-facing app capability rows should use the shared capability-state
  vocabulary from the dashboard contracts and ADR 0022: `proven`, `denied`,
  `pending`, `stale`, `contradictory`, `inapplicable`, and `unknown`. `stale`
  is required when evidence was valid for an older app build or freshness
  window but has not been re-observed for the current surface.
- App worktree pruning and snapshot behavior must not be treated as branch or
  worktree deletion authority.
- Runtime rows for P03, P04, and P09 must continue to name the exact surface:
  CLI, GUI app, IDE extension, setup script, MCP server, or app-integrated
  terminal.

### Rejects

- Treating Codex CLI `shell_environment_policy`, profiles, auth, or shell
  telemetry as Codex app proof.
- Treating terminal `open` launches as clean GUI-origin evidence.
- Treating temporary CLI-started `codex app-server --listen stdio://` probes as
  GUI app-server sandbox evidence.
- Treating app settings UI labels as proof of backing storage or effective
  runtime behavior.
- Using `thread/shellCommand` as the preferred HCS app probe path when the
  schema identifies it as unsandboxed full access; prefer typed
  `command/exec` status probes when an app control path exists.

### Future amendments

- Amend once a reachable GUI app-server control path or human-run sterile app
  UI turn supplies Keychain/filesystem/network status-code evidence.
- Re-review on material Codex app bundle or Workspace Dependencies changes per
  charter invariant 14.
- Re-observe stale capability rows after Codex app or Workspace Dependencies
  updates before treating older rows as current evidence.
- Amend if official Codex docs publish a stable app/IDE execution-context
  contract that supersedes local P13 inference.
- Extend after Q-006/Q-008 if app worktree and GitHub PR automation need
  stronger branch/worktree authority receipts.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0,
  invariants 8, 12, 14, and 15
- ADR 0016:
  `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- P02 Codex GUI launch probe:
  `docs/host-capability-substrate/research/shell-env/2026-04-26-P02-codex-app-gui-launch-env.md`
- P13 Codex app sandbox memo:
  `docs/host-capability-substrate/research/shell-env/2026-04-26-P13-codex-app-bundle-signing.md`
- Codex config/app settings ingest:
  `docs/host-capability-substrate/research/shell-env/2026-05-01-codex-official-config-app-settings-ingest.md`
- Shell/env research:
  `docs/host-capability-substrate/shell-environment-research.md` v2.12.0
- Related ADRs: ADR 0001, ADR 0007, ADR 0015, ADR 0016
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- OpenAI Codex config, sandbox, app, app-server, local-environments, and MCP docs
- Apple launchd, Launch Services, hardened runtime, and TCC documentation
- Chromium/Electron sandbox documentation where it informs helper-process
  sandbox flags
