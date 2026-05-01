---
title: P11 LaunchAgent Env Policy Table
category: research
component: host_capability_substrate
status: design-memo
version: 1.0.0
last_updated: 2026-04-30
tags: [phase-1, p11, launchagent, env, policy, execution-context]
priority: high
---

# P11 LaunchAgent Env Policy Table

Design memo for shell/environment research prompt P11: which environment values
belong at the macOS user-session / LaunchAgent layer.

This memo is **not** an accepted ADR, live policy, launchd plist, or
system-config change. It is a Phase 1 design input for ADR 0016/0017 synthesis.

## Decision Criteria

| Criterion | Question |
|---|---|
| Secrecy | Could the value reveal credential material, account tokens, private endpoints, or sensitive customer/project data? |
| Durability | Should the value survive shell restarts, GUI app launches, login sessions, or reboots? |
| GUI visibility | Does a Finder/Dock/Spotlight-launched app genuinely need the value? |
| Scope | Is the value host-wide, user-wide, project-specific, tool-specific, or session-specific? |
| Churn | Will the value change often enough that a long-lived session env becomes stale? |
| Verification | Can the value be safely inspected through names-only, existence-only, classified, or hashed checks? |

## Policy Table

| Variable / class | Secrecy | Durability | GUI need | Recommended plane | P11 disposition |
|---|---|---|---|---|---|
| `LANG` | none | login/reboot | often | user-session env or app default | Allowed when needed for GUI/agent consistency. |
| `LC_ALL` | none/low | login/reboot | rare | avoid globally; prefer per-command/session | Conditional. Global `LC_ALL` can override locale expectations; use only for known host-wide need. |
| `DEFAULT_EDITOR` / `EDITOR` / `VISUAL` | none/low | shell/session | rare | shell rc, agent config, or project config | Do not put in LaunchAgent by default; GUI apps have their own editor integration. |
| `TMPDIR` | low | OS-managed | yes, but OS owns | launchd/OS default | Do not override at HCS layer; observe only. |
| HTTP proxy vars (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`) | medium to high | session/login | sometimes | per-tool config or brokered non-secret profile | Conditional. Never include credentials in proxy URLs; avoid global GUI exposure unless an operator explicitly needs host-wide proxying. |
| Proxy bypass (`NO_PROXY`) | low/medium | session/login | sometimes | per-tool config or user-session env | Conditional when proxy vars are also intentionally user-session scoped. |
| Homebrew non-secret flags (`HOMEBREW_NO_ANALYTICS`) | none | login/reboot | no | shell rc or package-manager wrapper | Usually not LaunchAgent; keep package-manager behavior in the shell/tool plane. |
| Telemetry opt-out flags (`*_TELEMETRY_DISABLED`, `DO_NOT_TRACK`) | none/low | login/reboot | sometimes | user-session env only for broad host preference | Conditional. Prefer vendor config where available; user-session env is acceptable for genuinely host-wide preferences. |
| Org/project flags (`HCS_*`, `JEF_*`, repo-specific markers) | none to high | varies | rarely | project config, workspace manifest, agent session, or HCS runtime | Not LaunchAgent by default. Use only if the value is non-secret, host-wide, and GUI-required. |
| Credential env (`*_TOKEN`, `*_SECRET`, `*_API_KEY`, `GITHUB_PAT`) | high | should be bounded | sometimes claimed, but unsafe | broker, Keychain/OAuth, 1Password reference, `apiKeyHelper` where CLI-only | Forbidden for LaunchAgent/user-session env in HCS posture. |
| Tool path shims (`PATH`, language-specific `*_HOME`) | low/medium | session/login | sometimes | measured `ExecutionContext`, shell activation, mise/asdf/nix/devcontainer | Do not assume a single global value. Prefer per-surface measurement and tool-resolution evidence. |

## Provisional Rules

1. LaunchAgent/user-session env is for **non-secret, low-churn, user-wide**
   values that GUI-launched apps truly need.
2. Project-specific values belong in workspace/project config, not launchd.
3. Toolchain activation belongs in tool-resolution evidence and shell/session
   activation, not a universal GUI env claim.
4. Secret-shaped values do not belong in LaunchAgent env. Use Keychain/OAuth,
   1Password references, or the ADR 0012 broker contract.
5. Proxy values are sensitive unless proven otherwise. Credential-bearing proxy
   URLs are secret material.
6. Every GUI-env claim must name its `ExecutionContext.surface`; terminal
   evidence does not transfer to GUI apps.

## HCS Implications

- `EnvProvenance` should distinguish `launchd_user_session`,
  `launchagent_plist:<label>`, `shell_rc`, `direnv`, `mise`, `agent_session_hook`,
  and broker-provided credential material.
- `ExecutionContext` should carry whether a value came from user-session env,
  app launch env, shell activation, setup script, or MCP server init.
- Future dashboard views should separate "visible to shell" from "visible to
  GUI app" and "visible to MCP server".
- Policy should treat adding a secret-shaped variable to LaunchAgent env as a
  forbidden or non-escalable class unless a later ADR deliberately narrows that
  rule with brokered non-value references.

## Validation

Design-only memo. No host state was changed.
