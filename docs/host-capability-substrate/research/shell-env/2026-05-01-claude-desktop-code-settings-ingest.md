---
title: Claude Desktop and Claude Code Desktop Settings Ingest
category: research
component: host_capability_substrate
status: source-ingest
version: 1.0.0
last_updated: 2026-05-01
tags: [phase-1, claude-desktop, claude-code, macos-app, mcp, permissions, worktrees, preview, execution-context]
priority: high
---

# Claude Desktop and Claude Code Desktop Settings Ingest

Curated ingest of operator-provided Claude macOS application and Claude Code
Desktop settings observations on 2026-05-01. This is source intake, not a
runtime behavior probe. It does not edit Claude settings, launch Claude, change
permission modes, or inspect secret-bearing config values.

## Local Metadata Check

| Field | Evidence |
|---|---|
| Claude Desktop app | `/Applications/Claude.app` |
| Bundle identifier | `com.anthropic.claudefordesktop` |
| App bundle version | `1.5354.0` |
| App bundle build | `1.5354.0` |
| MCP config path | `/Users/verlyn13/Library/Application Support/Claude/claude_desktop_config.json` |
| MCP config metadata | Mode `644`, size `2251`, modified `Apr 30 21:14:22 2026` |

The metadata check intentionally did not read raw config values. The MCP config
path is user-global and app-managed; it may contain server commands, arguments,
or environment bindings and must be inspected only with a value-safe plan.

## Claude Desktop MCP Config Surface

Claude Desktop lists the MCP config path as:

```text
/Users/verlyn13/Library/Application Support/Claude/claude_desktop_config.json
```

HCS interpretation:

- Treat this as a user-global Claude Desktop MCP configuration surface.
- Do not collapse it with Claude Code CLI project `.mcp.json` or
  `~/.claude/settings.json`.
- Do not infer variable-expansion behavior, auth behavior, or credential
  availability from Claude Code CLI docs unless a matching Claude Desktop
  receipt exists.
- Do not read or record env values from this file. At most, record top-level
  keys, MCP server names, and env key names under a redaction-safe probe.

## Filesystem Tool Permissions

The Claude app exposes filesystem tool permission choices for the local
filesystem surface:

| Group | Tool | Observed permission |
|---|---|---|
| Read-only | Read File (Deprecated) | `ask` |
| Read-only | Read Text File | `ask` |
| Read-only | Read Multiple Files | `ask` |
| Read-only | List Directory | `ask` |
| Read-only | List Directory with Sizes | `ask` |
| Read-only | Directory Tree | `ask` |
| Read-only | Search Files | `ask` |
| Read-only | Get File Info | `ask` |
| Read-only | List Allowed Directories | `ask` |
| Write/delete | Write File | `ask` |
| Write/delete | Edit File | `ask` |
| Write/delete | Create Directory | `ask` |
| Write/delete | Move File | `ask` |
| Other | Copy file to Claude | App-mediated copy/import surface |

HCS interpretation:

- App-level `ask` prompts are not HCS `ApprovalGrant` records.
- Read/write permission groups are useful candidate evidence for a future
  `ExecutionContext` capability matrix, but they are not kernel policy.
- Write/delete tools remain mutating capability surfaces even when the app asks
  the user inline.
- "Copy file to Claude" is a data egress/import path and should be modeled
  separately from normal read-only file inspection.

## Claude Code Desktop Settings Surface

Operator-provided Claude Code Desktop settings include:

| Setting area | Observed option / description | HCS implication |
|---|---|---|
| Allow bypass permissions mode | Bypasses all permission checks and lets Claude work uninterrupted; vendor UI warns about data loss, system corruption, and exfiltration risk. | High-risk app posture. Do not treat as safe automation or HCS policy approval. |
| Allow auto permissions mode | Lets Claude handle permission decisions during coding sessions with additional prompt-injection safeguards. | App decision aid, not HCS policy evaluation or approval authority. |
| Notifications | Draw attention by bouncing the dock icon or flashing the taskbar when Claude needs attention. | UI-only signal; not operational evidence. |
| Worktree location | Inside project, `.claude/worktrees`, default. | Project-local generated worktree state; hidden or ignored state is not deletion authority. |
| Branch prefix | `claude`. | Naming convention only; not branch ownership proof. |
| Preview | Claude can start dev servers, open a live preview, and verify code changes with screenshots, snapshots, and DOM inspection. | Separate browser/dev-server execution surface; requires its own runtime and network/file evidence. |
| Persist Preview sessions | Saves cookies, local storage, and login sessions per workspace across app restarts; disabling clears saved session data. | Runtime/browser credential state. Do not store in repo or inspect without explicit redacted approval. |
| Create pull requests automatically | Claude Code on the Web can create PRs automatically when Claude pushes changes to a branch. | GitHub control-plane mutation; Q-006 authority modeling applies. |
| Autofix pull requests | Claude monitors CI failures and review comments and may post comments on the user's behalf. | External automation with GitHub-side effects; needs source/actor/authority evidence. |
| Auto-archive after PR merge or close | Desktop sessions can be archived after associated PR merge or close. | UI/session lifecycle behavior; not proof that branches/worktrees are safe to delete. |

## Design Consequences

1. Add Claude app settings as candidate source material for future
   `ExecutionContext` facets, not as accepted Ring 0 schema yet.
2. Keep Claude Desktop MCP config, Claude Code CLI settings, Claude Code
   Desktop settings, Preview state, and Claude Code on the Web automation as
   separate surfaces.
3. Treat bypass mode as an explicit high-risk posture that should require
   operation proof and human review before any HCS-mediated workflow relies on
   it.
4. Treat auto permissions as app-managed convenience, not as durable policy or
   an approval grant.
5. Treat persisted Preview sessions as runtime state that may hold cookies,
   local storage, and login sessions.
6. Treat `.claude/worktrees` as generated but potentially load-bearing state;
   do not delete or infer ownership from path shape alone.
7. Route automatic PR creation, autofix, and comment posting through the
   external-control-plane/GitHub authority workstream.

## Follow-Up

- Future runtime probes should capture only metadata, names, counts, and
  redacted classifications unless an operation proof explicitly authorizes more.
- If Claude app config values must be inspected, use a names-only/top-level-key
  probe first and keep raw values out of transcripts.
- Any test that enables bypass mode, auto mode, Preview persistence inspection,
  or web PR automation needs a separate operation proof.
