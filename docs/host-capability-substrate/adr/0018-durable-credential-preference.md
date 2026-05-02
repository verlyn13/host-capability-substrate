---
adr_number: 0018
title: Durable credential source preference
status: accepted
date: 2026-05-01
charter_version: 1.2.0
tags: [credentials, oauth, keychain, broker, secret-reference, phase-1]
---

# ADR 0018: Durable credential source preference

## Status

accepted

## Date

2026-05-01

## Charter version

Written against charter v1.2.0.

## Context

ADR 0012 commits HCS to a phased credential broker behind the D-028
`host_secret_*` compatibility contract. ADR 0016 rejects inherited shell env as
a substrate contract. ADR 0017 separates the Codex app from Codex CLI so app,
CLI, IDE, setup-script, and app-integrated-terminal credential facts cannot be
promoted across surfaces.

Phase 1 auth evidence sharpens the remaining credential-source question:

- Codex P01 found a logged-in Codex context but did not prove local Keychain
  storage; the GitHub MCP entry still uses `bearer_token_env_var = "GITHUB_PAT"`
  because `codex mcp login github` failed when the endpoint rejected dynamic
  client registration.
- Claude P05 supports treating Claude Desktop as its own OAuth app surface,
  separate from Claude Code CLI `apiKeyHelper` and shell-exported Anthropic
  API-key variables.
- Shell research records Claude Code CLI `apiKeyHelper`, API-key env vars,
  `CLAUDE_CODE_OAUTH_TOKEN`, subscription OAuth credentials, and cloud-provider
  credentials as distinct credential-precedence cases.
- Shell research also records that `claude setup-token` can mint a long-lived
  subscription-scoped token for CI/headless use, but that token is not a
  general Remote Control credential.
- External-control-plane research shows one-time provider secrets must be
  captured at issuance and converted into secret references atomically.

HCS needs a credential preference that preserves tool-native OAuth where it is
actually supported, while avoiding both ambient shell-env auth and a brittle
assumption that subscription OAuth is a stable universal substrate.

## Options considered

### Option A: Prefer tool-native OAuth and Keychain everywhere

**Pros:**
- Keeps tokens out of project files and most shell environments.
- Aligns with OAuth-preferred HTTP MCP when servers and clients support it.
- Uses OS credential storage and vendor logout/revocation flows.

**Cons:**
- Not every MCP/server flow supports the required OAuth shape.
- P01 showed a real GitHub MCP OAuth migration failure on this host.
- Claude Desktop and Claude Code CLI do not share one portable OAuth surface.
- Subscription OAuth can have product/model/surface limitations that HCS
  cannot treat as a durable cross-tool contract.

### Option B: Keep PATs/API keys in shell env as the default fallback

**Pros:**
- Works with many existing CLIs and MCP server configs.
- Easy for humans to debug in terminal-only sessions.
- Requires little HCS infrastructure initially.

**Cons:**
- Violates ADR 0016's shell/env boundary if treated as substrate authority.
- Leaks into process env and argv/logging failure modes.
- Fails for GUI apps, IDE extensions, startup timing, and subagents.
- Encourages raw credentials in persistent dotfiles and project config.

### Option C: Prefer scoped durable credential sources plus brokered references

**Pros:**
- Lets HCS choose tool-native OAuth when a surface supports it cleanly.
- Covers non-OAuth, headless, one-time-secret, and provider API-key workflows.
- Preserves ADR 0012's broker path without making the broker a universal
  secret-read tool.
- Makes `CredentialSource`, `SecretReference`, expiry, health, storage, and
  surface binding explicit.

**Cons:**
- Requires Ring 0 schema and Ring 1 broker work before broad enforcement.
- Requires rotation/healthcheck UX and dashboard visibility.
- Some compatibility flows must still render process-scoped env values for
  legacy tools.

### Option D: Build an HCS OAuth/proxy layer to unify all providers

**Pros:**
- Could give HCS one apparent auth abstraction.
- Might centralize refresh, revocation, and audit.

**Cons:**
- Duplicates vendor/client OAuth machinery.
- Risks storing or brokering too much authority inside HCS too early.
- Does not solve providers that issue API keys, one-time secrets, service
  tokens, SSH keys, or non-OAuth credentials.
- Exceeds Phase 1 scope and mutating-surface constraints.

## Decision

HCS will prefer explicit, scoped, durable credential sources over ambient shell
env or assumed subscription OAuth. Tool-native OAuth plus OS credential storage
remains preferred when it is first-party, supported by the exact target surface,
and verified by a restart/startup receipt. For HCS-integrated, headless,
non-OAuth, one-time-secret, and provider API-key workflows, prefer brokered
`SecretReference` values, long-lived setup-token-style credentials, API keys, or
service accounts with explicit scope, storage, expiry, rotation, and
healthcheck evidence. Environment variables are compatibility renderings for a
specific process or helper, not the durable credential source.

## Consequences

### Accepts

- `CredentialSource` should record source type, owning surface, storage plane,
  scope/audience, mutation-scope posture, expiry, rotation expectation,
  healthcheck status, and evidence authority. This records the field shape HCS
  may need later; it does not pre-accept any Q-006 GitHub MCP read/mutation
  split.
- Tool-native OAuth is still preferred for HTTP MCP when it works and remains
  explicitly enabled per D-030/ADR 0015.
- `bearer_token_env_var` patterns may remain as transitional or deliberate
  fallback paths until an accepted OAuth or broker strategy succeeds and passes
  restart verification.
- `apiKeyHelper`, `awsCredentialExport`, and similar helpers are CLI/helper
  surfaces that may call the HCS broker; they are not GUI/app credential
  inheritance.
- One-time provider secrets require the ADR 0012 atomic
  `create -> capture -> store -> verify -> scrub` path.
- Long-lived setup-token-style credentials are acceptable only when scoped,
  revocable, healthchecked, and recorded as their own credential source class.
  Missing expiry, rotation, or healthcheck evidence should make the source
  non-gateable or approval-required until policy defines a narrower exception.

### Rejects

- Raw secrets in committed files, project config, user config, or ADRs.
- Shell-exported PAT/API-key variables as the substrate default.
- Assuming Claude Desktop, Codex app, IDE extensions, or subagents can use a
  CLI credential helper or CLI OAuth state.
- Removing existing env/PAT fallbacks just because a theoretical OAuth path
  exists; migration needs a successful flow plus restart/startup proof.
- A universal "read any secret" agent-callable tool.
- A custom HCS OAuth proxy as a Phase 1 requirement.

### Future amendments

- Reopen if Codex/GitHub MCP supports a stable static-client or equivalent
  OAuth path on this host and restart verification succeeds.
- Reopen if Anthropic changes Claude Desktop, Claude Code CLI, or Remote
  Control credential behavior in a way that creates a stable shared surface.
- Reopen after the ADR 0012 broker lands and real credential health/audit data
  shows a better default.
- Reopen if Q-006 decides GitHub MCP read and mutation authority must be split
  into separate credentials.
- Reopen if a provider supports non-secret delegated auth that makes brokered
  secret material unnecessary for that surface.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0,
  invariants 5, 8, 12, 14, and 15
- ADR 0012:
  `docs/host-capability-substrate/adr/0012-credential-broker.md`
- ADR 0015:
  `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
- ADR 0016:
  `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- ADR 0017:
  `docs/host-capability-substrate/adr/0017-codex-app-execution-context.md`
- Decision ledger: `DECISIONS.md` D-028, D-030, D-031, Q-006
- P01 Codex auth metadata:
  `docs/host-capability-substrate/research/shell-env/2026-04-26-P01-codex-auth-metadata.md`
- P05 Claude Desktop auth boundary:
  `docs/host-capability-substrate/research/shell-env/2026-04-26-P05-claude-desktop-auth-boundary.md`
- Shell/env research:
  `docs/host-capability-substrate/shell-environment-research.md` v2.12.0
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- OpenAI Codex authentication and MCP documentation
- Anthropic Claude Code authentication documentation
- Model Context Protocol authorization and protected-resource metadata specs
- 1Password CLI and service account documentation
- Provider documentation for one-time API tokens, OAuth clients, and service
  accounts
