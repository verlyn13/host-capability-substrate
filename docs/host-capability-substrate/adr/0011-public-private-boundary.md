---
adr_number: 0011
title: Public source, private deployment boundary
status: accepted
date: 2026-04-22
charter_version: 1.1.0
tags: [governance, public-private, deployment]
---

# ADR 0011: Public source, private deployment boundary

## Context

HCS is public-source infrastructure, but it holds authority over this host's runtime state and live policy. Treating the public repo as the authority for live behavior would conflate transparency with trust.

## Decision

Split by governance tier:

- **Public HCS repo:** source, schemas, generated JSON Schema, test fixtures (redacted/sample data), docs, ADRs, regression trap prompts, policy schema (definitions, not instances), test-only policy snapshot.
- **system-config:** canonical live policy YAML, launchd plist templates, sync-mcp integration, ng-doctor integration, 1Password `op://` reference conventions.
- **`~/Library/Application Support/host-capability-substrate/`:** SQLite state, materialized facts, cache, loaded policy copy (hash-verified against system-config source), local dashboard metadata.
- **`~/Library/Logs/host-capability-substrate/`:** structured runtime logs, audit archives.
- **1Password:** dashboard tokens, audit checkpoint references, signing/checkpoint material.

Enforcement: CI boundary scripts (`scripts/ci/forbidden-string-scan.sh`, `scripts/ci/no-live-secrets.sh`, `scripts/ci/no-runtime-state-in-repo.sh`) block commits that cross these boundaries.

## Consequences

### Accepts

- Transparency of structure without leaking authority over live host.
- Agents and humans can reason about HCS's shape via the public repo without needing host access.
- Runtime behavior requires host-local state + system-config policy; public repo alone is not runnable as a live substrate.

### Rejects

- Live policy in the public repo.
- Runtime state in the public repo.
- Resolved secret values anywhere in the public repo.

### Future amendments

- If the substrate adds cross-host federation, this ADR reopens to clarify tier of federation state.

## References

### Internal

- Research plan §3, §15
- Boundary decision §3 (public/private boundary), v1.1.0
- Charter invariant 10 (v1.1.0 new)
- Decision ledger: D-018

### External

- N/A
