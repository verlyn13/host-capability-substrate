---
title: P05 Claude Desktop Auth Boundary Metadata Smoke Test
category: research
component: host_capability_substrate
status: partial
version: 1.0.0
last_updated: 2026-04-26
tags: [phase-1, p05, claude-desktop, credential-source, oauth]
priority: high
---

# P05 Claude Desktop Auth Boundary Metadata Smoke Test

Partial read-only evidence for shell/environment research prompt P05: Claude
Desktop uses its own app auth surface and should not be modeled as consuming
Claude Code `apiKeyHelper` or shell-exported Anthropic API-key environment.

This memo records app/config metadata only. It does not launch Claude Desktop,
does not set synthetic auth variables, does not read OAuth token values, and
does not inspect any secret field values.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26 |
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

## Interpretation

The metadata is consistent with the research claim that Claude Desktop is a
separate app auth surface from Claude Code CLI:

- Desktop config does not expose top-level `apiKeyHelper` or `env` auth wiring.
- App bundle metadata does not inject Anthropic API-key environment variables.
- App config has an `oauth:tokenCache` key name, which is consistent with an
  app OAuth flow, but the value was not read and this memo does not claim token
  details.

This is still a partial smoke test. It does not prove runtime behavior under a
fresh GUI launch. The final P05 result needs a synthetic marker run that proves
Claude Desktop ignores CLI-only auth surfaces without setting real
`ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN` values.

## Follow-Up

1. Resolve whether a GUI runtime observation can report auth-surface selection
   without exposing tokens.
2. If a runtime smoke is run, use synthetic marker names only and never set
   real Anthropic credential variables.
3. Keep Claude Desktop as a separate `CredentialSource` / `ExecutionContext`
   surface from Claude Code CLI until a contrary primary-source or runtime
   receipt exists.
4. Do not infer Claude Code CLI `apiKeyHelper` state from Claude Desktop app
   auth state, or the reverse.

## Commands Used

Key commands used for evidence were read-only and value-safe:

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
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-04-26 | Initial partial P05 app/config metadata smoke result. |
