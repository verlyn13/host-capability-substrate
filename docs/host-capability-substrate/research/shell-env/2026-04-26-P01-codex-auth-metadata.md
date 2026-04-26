---
title: P01 Codex Auth Metadata Smoke Test
category: research
component: host_capability_substrate
status: partial
version: 1.0.0
last_updated: 2026-04-26
tags: [phase-1, p01, codex, keychain, credential-source]
priority: high
---

# P01 Codex Auth Metadata Smoke Test

Partial read-only evidence for shell/environment research prompt P01: Codex
auth reuse through shared `CODEX_HOME` and OS credential storage.

This memo records metadata/existence checks only. It does not read
`auth.json`, does not request Keychain password data, and does not perform
`codex mcp login`.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26T19:26Z |
| macOS | 26.4.1, build 25E253 |
| Codex CLI | `/Users/verlyn13/.npm-global/bin/codex`, `codex-cli 0.125.0` |
| Effective `CODEX_HOME` | `/Users/verlyn13/.codex` |
| `CODEX_HOME` sha256 | `d7d426c0aea4430a8777be56266e979fcbcbf8e87d656ea4be0a53461b769d96` |
| Expected account prefix from research | `cli|d7d426c0aea4430a` |

## Evidence Summary

| Probe | Result |
|---|---|
| Keychain metadata lookup | `security find-generic-password -s "Codex Auth"` returned item-not-found / invalid search parameters. No Keychain item was observed by this metadata-only lookup. |
| `auth.json` existence | `${CODEX_HOME}/auth.json` exists. |
| `auth.json` file metadata | Mode `600`, size `4801`, modified `Apr 22 16:24:15 2026`. Contents were not read. |
| Config credential-store key | No `cli_auth_credentials_store` key was found in `$HOME/.codex/config.toml` by the narrow search. |

## Interpretation

The documentation-level P01 claim remains useful, but this host's current
observed state does not prove Keychain-backed Codex auth. The local evidence is
consistent with one of these possibilities:

- Codex is using the file credential store at `${CODEX_HOME}/auth.json`.
- The Keychain item uses a different service/query shape than the one searched.
- The Keychain item is absent because this installation has not migrated to
  Keychain storage.

Do not use this partial result to remove `bearer_token_env_var` or migrate MCP
auth in system-config. The operational migration step still requires a
successful `codex mcp login github` flow and a post-restart MCP startup check
without `GITHUB_PAT`.

## Follow-Up

1. Resolve the effective Codex credential store with official/local evidence,
   preferably through a Codex diagnostic that reports store type without token
   material.
2. If testing Keychain directly, use metadata-only queries and never pass `-g`.
3. Run `codex mcp login github` only as an explicit interactive operation with
   a separate proof. Do not bundle it with this metadata smoke test.
4. After successful OAuth login, restart Codex and verify GitHub MCP startup
   without `GITHUB_PAT` before changing system-config.

## Commands Used

All commands were read-only and token-safe:

```json
[
  {
    "file": "/usr/bin/security",
    "argv": ["security", "find-generic-password", "-s", "Codex Auth"]
  },
  {
    "file": "/bin/test",
    "argv": ["test", "-f", "/Users/verlyn13/.codex/auth.json"]
  },
  {
    "file": "/usr/bin/stat",
    "argv": ["stat", "-f", "auth_json_mode=%OLp size=%z modified=%Sm", "/Users/verlyn13/.codex/auth.json"]
  },
  {
    "file": "/usr/bin/rg",
    "argv": ["rg", "-n", "^cli_auth_credentials_store|\\[.*auth.*\\]", "/Users/verlyn13/.codex/config.toml"]
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-04-26 | Initial partial P01 metadata-only smoke result. |
