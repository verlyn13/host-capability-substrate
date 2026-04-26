---
adr_number: 0012
title: Credential broker contract and phased implementation
status: accepted
date: 2026-04-26
charter_version: 1.2.0
tags: [credentials, broker, secrets, op, keychain, mcp]
---

# ADR 0012: Credential broker contract and phased implementation

## Context

Phase 0b produced two converging facts. First, 1Password CLI IPC queue
contention recurred within 24 hours of the initial field report, and `op`
2.32.1 has no client-side timeout flag. Second, the Cloudflare Stage 3a
incident showed that one-time-visible provider secrets must be captured at the
source response, stored, verified, and scrubbed atomically.

D-028 already shipped the caller-facing contract in system-config:
`host_secret_read`, `host_secret_export`, `use_host_secrets`,
`host_secret_diag`, and the `HCS_SECRET_*` namespace including
`HCS_BROKER_SOCKET`. HCS must now own the eventual broker behind that stable
contract without forcing callers to change again.

## Options considered

### Option A: Keep direct `op read` wrappers indefinitely

**Pros:**
- Already shipped.
- Simple shell contract.
- No new daemon or socket.

**Cons:**
- Every caller still contends on the same `op` IPC path.
- Timeouts remain wrapper-specific.
- No atomic one-time-secret capture path.
- GUI, CLI, and MCP auth surfaces remain conflated.

### Option B: Build a broker daemon at `$HCS_BROKER_SOCKET`

**Pros:**
- Preserves the D-028 caller contract.
- Centralizes timeout, health, queue, and diagnostic behavior.
- Provides a natural place for `create -> capture -> store -> verify -> scrub`
  one-time-secret workflows.
- Can expose typed `CredentialSource` and `SecretReference` evidence later.

**Cons:**
- Requires a long-running local process.
- Requires launchd lifecycle, socket permissions, audit, and status surfaces.
- Must avoid becoming a universal secret exfiltration API.

### Option C: Move all credentials to OAuth/Keychain and remove env helpers

**Pros:**
- Reduces secret-in-env exposure.
- Aligns with OAuth-preferred HTTP MCP where available.

**Cons:**
- Does not cover 1Password service-account or provider-issued API-key cases.
- Anthropic and Codex app/CLI surfaces diverge on Keychain and OAuth behavior.
- Does not solve one-time provider secrets that must be captured on creation.

## Decision

Use a phased broker. D-028 wrappers remain the caller-facing contract; Phase 1+
implements a local broker daemon at `$HCS_BROKER_SOCKET` behind the same
functions. The broker is not a universal secret-read tool for agents. It serves
declared credential operations, emits typed health/evidence, enforces bounded
wall-clock behavior, and owns one-time-secret capture-at-source workflows.

The broker serves CLI helper surfaces such as `apiKeyHelper` and
`awsCredentialExport` separately from GUI/OAuth/Keychain surfaces. It does not
pretend those execution contexts are the same.

## Consequences

### Accepts

- A small local daemon and socket become part of the Phase 1+ runtime plan.
- Credential operations need typed schemas and audit-visible receipts before
  mutating execution lanes can consume them.
- Direct `op read` wrappers stay as compatibility shims until the broker lands.

### Rejects

- A universal "read any secret" agent tool.
- Shell-exported secrets as the substrate credential contract.
- Treating CLI `apiKeyHelper`, GUI OAuth, and app Keychain behavior as one
  portable auth surface.

### Future amendments

- If `op` gains a reliable client-side timeout and queue diagnostics, the
  broker may narrow its 1Password role but still keeps one-time-secret capture.
- If a provider supports first-party non-secret delegated auth for a surface,
  HCS may prefer that provider-specific path over brokered env materialization.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0
- Decision ledger: `DECISIONS.md` D-028, D-029, D-031
- Phase 0b closeout: `docs/host-capability-substrate/phase-0b-closeout.md`
- Cloudflare lessons: `docs/host-capability-substrate/research/external/2026-04-24-cloudflare-lessons.md`
- Shell/environment research: `docs/host-capability-substrate/shell-environment-research.md`
- Research plan: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` §6, §22

### External

- 1Password CLI documentation
- Anthropic Claude Code authentication documentation
- OpenAI Codex authentication and MCP documentation
