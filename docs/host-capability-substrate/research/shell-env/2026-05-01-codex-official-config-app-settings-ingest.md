---
title: Codex Official Config and App Settings Ingest
category: research
component: host_capability_substrate
status: source-ingest
version: 1.0.0
last_updated: 2026-05-01
tags: [phase-1, codex, config, macos-app, permissions, local-environments, git, execution-context]
priority: high
---

# Codex Official Config and App Settings Ingest

Curated ingest of operator-provided official Codex documentation excerpts and
Codex macOS app settings observations on 2026-05-01. This is source intake, not
a runtime behavior probe. It does not edit `~/.codex/config.toml`, launch Codex,
change app settings, or inspect secret-bearing config values.

## Local Metadata Check

| Field | Evidence |
|---|---|
| Codex CLI | `codex-cli 0.128.0`; `codex --version` printed a sandbox PATH warning but returned successfully |
| Codex app bundle | `/Applications/Codex.app` reports `CFBundleShortVersionString=26.429.20946`, `CFBundleVersion=2312` |
| App settings workspace dependencies | Operator-provided Codex app UI showed Workspace Dependencies current version `26.430.10722` |

Treat app-bundle version and Workspace Dependencies version as separate facts.
The dependencies bundle is an app-managed tool surface, not the same thing as
the signed app bundle version.

## Official Config Precedence

Codex resolves config in this order, highest precedence first:

1. CLI flags and `--config` overrides
2. Profile values from `--profile <name>`
3. Project config files: `.codex/config.toml`, ordered from project root down
   to current working directory; closest wins; trusted projects only
4. User config: `~/.codex/config.toml`
5. System config on Unix: `/etc/codex/config.toml`, if present
6. Built-in defaults

Project trust is a security boundary. If a project is untrusted, Codex skips
project-scoped `.codex/` layers, including project-local config, hooks, and
rules. User and system config still load, including user/global hooks and
rules.

Managed machines may also enforce constraints via `requirements.toml`, such as
disallowing `approval_policy = "never"` or `sandbox_mode = "danger-full-access"`.
HCS should model this as an external/admin constraint surface, not as live HCS
policy copied into this repo.

## Common Config Surfaces

| Surface | HCS classification |
|---|---|
| `~/.codex/config.toml` | User-global defaults, profiles, shared MCP definitions, auth-store preferences, hooks/rules. Secret values should not be stored here. |
| `.codex/config.toml` | Trusted project override. Good for non-secret behavior and project MCP identity; not a source of credentials by itself. |
| `/etc/codex/config.toml` | System config. External to this repo; useful for host profile evidence. |
| `requirements.toml` | Managed/admin requirements. External control-plane constraint, not canonical HCS policy. |
| CLI `--config` | Highest-precedence one-off override; useful for repeatable experiments when values are non-secret and explicit. |
| Profile values | Named config deltas. D-031 still holds: HCS profiles are CLI opt-ins until app/IDE runtime evidence proves otherwise. |

## Command Environment and Features

The official config surface confirms `shell_environment_policy` as the command
environment control plane:

```toml
[shell_environment_policy]
include_only = ["PATH", "HOME"]
```

This supports the P04 packet shape. Runtime behavior still requires direct
surface probes because official config syntax does not prove CLI/app/IDE
inheritance behavior.

Feature flags relevant to HCS:

| Feature / setting | HCS implication |
|---|---|
| `shell_snapshot = true` by default | Shell/env state can be cached; retest on Codex upgrades and avoid assuming fresh parent env every command. |
| `codex_hooks = true` by default | Hooks are a Codex lifecycle surface but must stay advisory/thin; no HCS policy in hooks. |
| `shell_tool = true` by default | This is Codex's default shell tool, but HCS must not introduce a universal shell execution tool. |
| `unified_exec = true` except Windows | Execution mode is a first-class observation; command symptoms are not diagnoses. |
| `web_search = "cached"` by default | Cached search is still untrusted input; live mode can be selected but should not become hidden network authority. |
| `apps`, `memories`, `multi_agent`, `undo` | These are separate feature surfaces that may affect evidence, state, and collaboration boundaries. |

## Codex macOS App Settings Surface

The app settings UI exposes user-level controls that may render into
`config.toml`, app-managed storage, or app-specific state. HCS must not assume
the backing storage without direct evidence.

| UI area | Observed options | HCS implication |
|---|---|---|
| Approval policy | `untrusted`, `on failure`, `on request`, `never` | Same semantic family as CLI approval policy; exact serialization should be verified before writing config. |
| Sandbox settings | `Read only`, `Workspace write`, `Full access` | Maps to app permission posture. Full access is high-risk and must not be normalized as safe. |
| Workspace Dependencies | Current version `26.430.10722`; install/expose bundled Node.js and Python tools | App-managed toolchain surface. Treat as `ToolInstallation` / `ResolvedTool` evidence, not shell PATH truth. |
| Diagnose issues | Records diagnostic logs for current bundle | Diagnostic logs are runtime evidence; keep out of repo unless curated/redacted. |
| Reset and install Workspace | Deletes local bundle, downloads again, reloads tools | Mutating app-managed state; requires operation proof and approval. |
| Permissions default | Read/edit files in workspace; can ask for additional access | A permission baseline, not an HCS approval grant. |
| Auto-review | App automatically reviews requests for additional access | Risk-bearing app decision aid; can make mistakes. Do not treat as HCS policy evaluation. |
| Full access | Can edit any file and run network commands without approval | Non-default dangerous posture; incompatible with assumptions that app operations are workspace-scoped. |

## Codex App Git and Worktree Settings

| Setting | Observed value/options | HCS implication |
|---|---|---|
| Branch prefix | `codex/` | Branch naming convention; not proof of branch ownership or safe deletion. |
| PR merge method | `Merge` or `Squash` | GitHub control-plane preference; actual merge authority still belongs to GitHub/rulesets. |
| Show PR icons | Toggle | UI observation only. |
| Always force push | Uses `--force-with-lease` when pushing | Mutating Git operation preference; still requires branch/worktree proof before cleanup or force updates. |
| Create draft pull requests | Toggle | PR creation posture; GitHub state remains authoritative. |
| Automatically delete old worktrees | Recommended on; auto-delete limit observed as `15` | App-managed cleanup can delete worktrees after snapshots. HCS must not treat missing worktrees as safe deletion proof without app snapshot evidence. |
| Commit instructions | Added to commit-message generation prompts | Prompt influence, not policy. |
| PR instructions | Added to PR title/description generation prompts | Prompt influence, not policy. |

## Local Environments and Actions

Official local-environments docs confirm:

- Codex stores local-environment config inside `.codex` at the project root.
- Setup scripts run automatically when Codex creates a new worktree at the start
  of a new thread.
- Setup scripts are for dependency install, builds, and worktree preparation.
- Actions run in the Codex app integrated terminal and are intended for common
  project tasks such as dev servers or tests.
- Platform-specific scripts can override defaults for macOS, Windows, or Linux.

HCS interpretation:

- Local environments are worktree/bootstrap scope, not startup-auth authority.
- Actions are app/integrated-terminal execution context, not CLI shell truth.
- `.codex/` project layers are trust-scoped; untrusted projects skip them.
- P03 remains necessary because setup-script vs MCP startup ordering is still a
  runtime question when someone proposes setup scripts as a bearer-token source.

## Design Consequences

1. Add `codex_app_settings` / `codex_workspace_dependencies` as candidate
   evidence facets under `ExecutionContext` or `ToolInstallation`.
2. Treat `requirements.toml` as an admin-enforced constraint source that HCS can
   observe, not as HCS live policy.
3. Preserve D-031 until runtime evidence proves app/IDE profile coverage.
4. Keep P03/P04/P09 runtime rows approval-gated.
5. Model app worktree pruning as a Git/worktree cleanup risk; do not equate app
   snapshots with branch deletion proof.
6. Treat commit/PR instructions as prompt inputs, not durable policy.
