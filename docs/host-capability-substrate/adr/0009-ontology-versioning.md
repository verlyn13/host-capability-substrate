---
adr_number: 0009
title: Ontology versioning — per-entity schema_version
status: accepted
date: 2026-04-22
charter_version: 1.1.0
tags: [ontology, schema, versioning]
---

# ADR 0009: Ontology versioning — per-entity schema_version

## Context

Entities evolve. Breaking changes need to be detectable and consumers need a migration path. Charter invariant 1 (no policy in adapters) and invariant 5 (secrets as references) already assume structured entities.

## Decision

- Every entity carries a `schema_version` field.
- Additive-with-defaults changes do NOT bump `schema_version` (backward compatible).
- Breaking changes DO bump `schema_version`; consumers expected to check and adapt.
- Gateway decision cache keys include every relevant entity `schema_version` so policy changes invalidate cache deterministically.
- Generated JSON Schema is regenerated in the same commit as Zod source changes.
- Entity schema versions are **independent** of adapter tool-name versions (MCP tool names follow `system.{namespace}.{verb}.v{N}` separately).

## Consequences

### Accepts

- Extra field in every entity.
- Coordination overhead on breaking changes.

### Rejects

- Monolithic repo-level schema version (too coarse).
- Relying on TypeScript types alone (runtime consumers matter).

### Future amendments

- If cross-entity version negotiation becomes necessary, this ADR reopens.

## References

### Internal

- Research plan §2, Appendix A
- `.agents/skills/hcs-schema-change/SKILL.md`
- `.claude/agents/hcs-ontology-reviewer.md`
- Charter invariant 1

### External

- N/A
