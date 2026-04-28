---
title: P05 Claude Desktop Auth Boundary Metadata Smoke Test
category: research
component: host_capability_substrate
status: partial
version: 1.2.0
last_updated: 2026-04-26
tags: [phase-1, p05, claude-desktop, credential-source, oauth]
priority: high
---

# P05 Claude Desktop Auth Boundary Metadata Smoke Test

Partial read-only evidence for shell/environment research prompt P05: Claude
Desktop uses its own app auth surface and should not be modeled as consuming
Claude Code `apiKeyHelper` or shell-exported Anthropic API-key environment.

This memo records app/config metadata and approved synthetic runtime smoke
results. It does not set real auth variables, does not read OAuth token values,
and does not inspect any secret field values.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26; updated 2026-04-27T01:09Z |
| macOS | 26.4.1, build 25E253 |
| Claude Desktop app | `/Applications/Claude.app` |
| Claude Desktop bundle id | `com.anthropic.claudefordesktop` |
| Claude Desktop version | `1.4758.0` |
| Claude Desktop build | `1.4758.0` |
| Claude Code CLI | `/Users/verlyn13/.local/bin/claude`, `2.1.119 (Claude Code)` |

## Evidence Summary

| Probe | Result |
|---|---|
| App path discovery | `/Applications/Claude.app` exists. |
| App bundle metadata | Bundle id `com.anthropic.claudefordesktop`; version/build `1.4758.0`. |
| App `LSEnvironment` | Only `MallocNanoZone` key observed. No Anthropic credential env key observed in app bundle metadata. |
| Claude app support dir | `$HOME/Library/Application Support/Claude` exists. |
| `claude_desktop_config.json` metadata | Mode `600`, size `2095`, modified `Apr 26 08:27:17 2026`. |
| `claude_desktop_config.json` top-level keys | `globalShortcut`, `mcpServers`, `preferences`. |
| Desktop config auth-like top-level keys | No top-level `env` key and no top-level `apiKeyHelper` key observed. |
| Desktop MCP server names | `brave-search`, `cloudflare`, `cloudflare-docs`, `context7`, `firecrawl`, `github`, `memory`, `runpod`, `runpod-docs`, `sequential-thinking`. |
| Desktop MCP env key names | Only `memory` declared an env key name: `MEMORY_FILE_PATH`. Values were not read. |
| App config key inventory | `config.json` key names include `oauth:tokenCache`; values were not read. |
| Claude Code CLI auth status | `claude auth status` returned `loggedIn: false`, `authMethod: none`, `apiProvider: firstParty` for the CLI context. This is CLI state only, not Desktop state. |
| Terminal `open -b` synthetic-marker launch | A terminal-launched `open -b com.anthropic.claudefordesktop` run propagated `HCS_P05_GUI_COLD_MARKER_20260426` into the Claude Desktop process. This proves terminal `open` is not a clean GUI-origin proxy. |
| Finder-origin synthetic-marker launch | A Finder-origin cold launch with `HCS_P05_FINDER_COLD_MARKER_20260426` in the terminal wrapper environment reported `p05_finder_marker_present=false`. |
| Finder-origin credential-env-name check | Existence-only check against the Finder-launched Claude Desktop process reported `ANTHROPIC_API_KEY_present=false`, `ANTHROPIC_AUTH_TOKEN_present=false`, and `CLAUDE_CODE_OAUTH_TOKEN_present=false`. Values were not printed. |
| Human-observed app approval sequence | During the approved live run, the Claude app surfaced one Bash request that was allowed, then a Touch ID approval, then three more Bash requests that were allowed. This was a user observation, not a captured transcript. |

## Interpretation

The metadata is consistent with the research claim that Claude Desktop is a
separate app auth surface from Claude Code CLI:

- Desktop config does not expose top-level `apiKeyHelper` or `env` auth wiring.
- App bundle metadata does not inject Anthropic API-key environment variables.
- App config has an `oauth:tokenCache` key name, which is consistent with an
  app OAuth flow, but the value was not read and this memo does not claim token
  details.
- Claude Code CLI auth status is currently unauthenticated in this context,
  while Desktop app config still contains an OAuth token-cache key name. This
  supports treating Desktop and CLI auth as separate surfaces, but it is not a
  proof of Desktop runtime behavior.

The Finder-origin runtime smoke supports treating Claude Desktop as a GUI app
surface that does not inherit terminal-only environment markers. The
terminal-`open` result is the counterexample that matters operationally:
launching the app via terminal `open -b` can propagate the terminal environment
and is not a valid proxy for a normal GUI launch.

The Finder-launched process also did not expose common Claude credential
environment names by existence-only inspection. That is consistent with the
documentation-level claim that Claude Desktop uses its own OAuth app surface
rather than Claude Code `apiKeyHelper` or shell-exported API-key variables. It
does not prove token-cache internals, which were intentionally not inspected.

The human-observed Bash and Touch ID approval prompts show a separate runtime
approval surface. Model that as app-mediated action approval, not as evidence
that Claude Desktop is using Claude Code CLI credential sources.

## Follow-Up

1. Keep Claude Desktop as a separate `CredentialSource` / `ExecutionContext`
   surface from Claude Code CLI until a contrary primary-source or runtime
   receipt exists.
2. Do not infer Claude Code CLI `apiKeyHelper` state from Claude Desktop app
   auth state, or the reverse.
3. If future prompt sequences are used as evidence, capture only approval type,
   count, and outcome; do not capture request payloads or secrets.

## Commands Used

Key commands used for evidence were value-safe. Runtime commands used synthetic
marker names only and printed presence/absence, not values:

```json
[
  {
    "file": "/usr/bin/find",
    "argv": ["find", "/Applications", "/Users/verlyn13/Applications", "-maxdepth", "1", "-name", "*Claude*.app", "-print"]
  },
  {
    "file": "/usr/bin/plutil",
    "argv": ["plutil", "-extract", "CFBundleIdentifier", "raw", "/Applications/Claude.app/Contents/Info.plist"]
  },
  {
    "file": "/usr/bin/plutil",
    "argv": ["plutil", "-extract", "CFBundleShortVersionString", "raw", "/Applications/Claude.app/Contents/Info.plist"]
  },
  {
    "file": "/usr/bin/plutil",
    "argv": ["plutil", "-extract", "CFBundleVersion", "raw", "/Applications/Claude.app/Contents/Info.plist"]
  },
  {
    "file": "/usr/bin/plutil",
    "argv": ["plutil", "-extract", "LSEnvironment", "raw", "/Applications/Claude.app/Contents/Info.plist"]
  },
  {
    "file": "/usr/bin/stat",
    "argv": ["stat", "-f", "claude_desktop_config_mode=%OLp size=%z modified=%Sm", "/Users/verlyn13/Library/Application Support/Claude/claude_desktop_config.json"]
  },
  {
    "file": "/usr/bin/jq",
    "argv": ["jq", "-r", "{has_env:has(\"env\"), has_apiKeyHelper:has(\"apiKeyHelper\"), has_mcpServers:has(\"mcpServers\"), top_keys:keys}", "/Users/verlyn13/Library/Application Support/Claude/claude_desktop_config.json"]
  },
  {
    "file": "/usr/bin/jq",
    "argv": ["jq", "-r", ".mcpServers // {} | to_entries[] | [.key, ((.value|keys)|join(\",\")), (((.value.env // {})|keys)|join(\",\"))] | @tsv", "/Users/verlyn13/Library/Application Support/Claude/claude_desktop_config.json"]
  },
  {
    "file": "/usr/bin/jq",
    "argv": ["jq", "-r", "keys[]", "/Users/verlyn13/Library/Application Support/Claude/config.json"]
  },
  {
    "file": "/Users/verlyn13/.local/bin/claude",
    "argv": ["claude", "auth", "status"]
  },
  {
    "file": "/usr/bin/open",
    "argv": ["open", "-b", "com.anthropic.claudefordesktop", "with synthetic HCS_P05_GUI_COLD_MARKER_20260426 in the terminal environment"]
  },
  {
    "file": "/usr/bin/osascript",
    "argv": ["osascript", "-e", "tell application \"Finder\" to open application file \"Claude.app\" of folder \"Applications\" of startup disk"]
  },
  {
    "file": "/bin/ps",
    "argv": ["ps", "eww", "-p", "<Claude main pid>", "then existence-only checks for selected env key names"]
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.2.0 | 2026-04-26 | Added approved synthetic runtime smoke: terminal `open -b` propagated a marker, Finder-origin launch did not, common Claude credential env key names were absent, and the user observed Bash/Touch ID approval prompts. |
| 1.1.0 | 2026-04-26 | Added Claude Code CLI auth-status evidence as CLI-only context supporting Desktop/CLI auth separation. |
| 1.0.0 | 2026-04-26 | Initial partial P05 app/config metadata smoke result. |
