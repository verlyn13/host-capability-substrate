---
adr_number: 0001
title: Repository boundary — name, path, scope
status: accepted
date: 2026-04-22
charter_version: 1.1.0
tags: [boundary, naming, governance]
---

# ADR 0001: Repository boundary — name, path, scope

## Status

`accepted`

## Date

2026-04-22

## Charter version

Written against charter v1.1.0.

## Context

HCS needs a canonical local path, GitHub slug, and scope boundary. Host-scoped infrastructure already has a precedent in the jefahnierocks subsidiary (`system-config`). Stale `.subsidiary.yaml` convention (`prefix: jfr`) contradicts observed practice (zero `verlyn13/jfr-*` repos exist).

## Options considered

### Option A: `jfr-host-capability-substrate` under `~/Organizations/jefahnierocks/`

**Pros:** follows the stated subsidiary convention in `.subsidiary.yaml`.
**Cons:** no existing repo uses the prefix; yaml is stale (same pattern as happy-patterns pending cleanup).

### Option B: `host-capability-substrate` under `~/Organizations/jefahnierocks/`

**Pros:** matches observed practice on 30+ verlyn13 repos; matches `system-config` precedent for host-scoped infrastructure.
**Cons:** contradicts the yaml (treated as stale and scheduled for separate cleanup).

### Option C: place under a parent-level tier (`the-citadel`)

**Pros:** host infrastructure might belong at parent scope.
**Cons:** jefahnierocks's `system-config` already establishes that host-scoped infrastructure lives in this subsidiary; parent tier is reserved for truly cross-subsidiary resources.

## Decision

**Option B.** Local path `~/Organizations/jefahnierocks/host-capability-substrate/`; GitHub `verlyn13/host-capability-substrate` (public source); subsidiary owner jefahnierocks; sibling to `system-config`.

## Consequences

### Accepts

- Non-compliance with stale `.subsidiary.yaml` prefix. Cleanup spawned separately.
- Long repo name, mitigated by `hcs` alias for env vars, CLI, and URLs.
- Public source with stricter private deployment boundary (see ADR 0011).

### Rejects

- Placing under `apps/` or `packages/` — wrong tier for host-scoped infrastructure.
- Prefixing — inconsistent with every other verlyn13 repo.

### Future amendments

- If the Nash Group formalizes a parent-scope "host-layer" pillar, reconsider placement.
- If cross-host / cross-subsidiary HCS usage emerges (unlikely), reconsider.

## References

### Internal

- Binding decision (master): `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate/0001-repo-boundary-decision.md` (v1.1.0+). **This ADR is a short in-repo pointer to that master document; edits go there.**
- Charter: `docs/host-capability-substrate/implementation-charter.md`
- Decision ledger: `DECISIONS.md` entry D-017

### External

- N/A
