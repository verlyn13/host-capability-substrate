---
adr_number: 0006
title: Policy source location — system-config is canonical
status: accepted
date: 2026-04-22
charter_version: 1.1.0
tags: [policy, governance, public-private-boundary]
---

# ADR 0006: Policy source location — system-config is canonical

## Context

Live HCS policy (tier classifications, forbidden rules, approval escalation patterns) needs an authoritative location. Candidates: in this repo, in system-config, or split. Charter invariant 10 requires public/private deployment boundary.

## Decision

**Canonical live policy lives at `~/Organizations/jefahnierocks/system-config/policies/host-capability-substrate/`.** This repo contains only schemas and a CI-regenerated test snapshot at `policies/generated-snapshot/`.

## Consequences

### Accepts

- Governance flows through system-config's review process.
- Cross-host consistency falls out of chezmoi-managed policy deployment.
- Repo is public source; live policy behavior does not depend on repo contents.

### Rejects

- Policy in the target repo alone (would conflate public source with host authority).
- Policy split (drift risk).

### Future amendments

- OPA adoption trigger per D-008 may add Rego files to the canonical location.

## References

### Internal

- Research plan §21.1 (policy YAML location)
- Decision ledger: `DECISIONS.md` entries D-004, D-018
- Charter invariants 5, 10

### External

- N/A
