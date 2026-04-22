---
name: hcs-schema-change
description: Change an HCS entity schema correctly — Zod source, generated JSON Schema, docs, tests, and fixtures all move together in a single PR.
allowed-tools: Read, Grep, Glob, Edit
---

# Skill: Change a schema

Use when adding, modifying, or removing an entity in `packages/schemas/`. Schema drift is the most expensive early mistake (per research plan §18 regression corpus); this skill enforces the "schema + docs + JSON Schema + tests move together" discipline.

## Inputs

- The entity to change (e.g., `HostProfile`, `OperationShape`, `Evidence`)
- The nature of the change (add field, remove field, change type, add new entity)
- The reason (cite an ADR, a policy need, or an observed failure)

## Procedure

1. Read `packages/schemas/src/entities/<entity>.ts` — the Zod source.
2. Read `docs/host-capability-substrate/ontology.md` — the human-facing description.
3. Read any tests under `packages/schemas/tests/` or `packages/fixtures/` covering the entity.
4. Read the generated JSON Schema at `packages/schemas/generated/<entity>.schema.json` (if present).
5. Determine whether the change is:
   - **Additive with defaults** — no `schema_version` bump; backward-compatible
   - **Breaking** — `schema_version` must bump; consumers may need migration
6. Make the change in the Zod source.
7. Update `docs/host-capability-substrate/ontology.md` in the same commit.
8. Regenerate JSON Schema in the same commit (`just generate-schemas`).
9. Update tests to cover the new shape, including edge cases.
10. Update fixtures if the entity is used in test data.

## Rules

- **One PR per schema change.** Do not bundle schema changes with unrelated kernel work.
- **`schema_version` bumps require an ADR** unless the change is strictly additive with defaults.
- **Evidence-shaped fields keep provenance.** Any new fact-returning field must include `source`, `observed_at`, `valid_until`, `authority`, `parser_version`, `confidence` — either directly or via embedding an `Evidence<T>` wrapper.
- **Ring 0 imports from nowhere above Ring 0.** Schemas do not import kernel types.
- **Generated JSON Schema is regenerated**, not hand-edited.
- **Deprecated fields get `@deprecated` in Zod `.describe()` and are removed only after a deprecation window.**

## Required reviewers

A PR with schema changes must receive objections from:

- `hcs-ontology-reviewer` (always; this is their scope)
- `hcs-policy-reviewer` if the change affects policy input/output shapes
- `hcs-security-reviewer` if the change touches Evidence authority, ApprovalGrant scope, or audit event schema

Escalate each via the appropriate subagent before requesting human review.

## Output

The committed change, containing in a single diff:

- Zod source edit
- Generated JSON Schema regeneration
- `ontology.md` update
- Test additions/edits
- Fixture updates (if applicable)
- Schema version bump if breaking (ADR referenced in commit message)

## Never do

- Bundle a schema change with unrelated work.
- Skip JSON Schema regeneration.
- Skip the `ontology.md` update.
- Remove a field without a deprecation window and an ADR.
- Hand-edit `packages/schemas/generated/**`.

## Reference

- Charter invariants 3 (layer discipline), 9 (skills location), 10 (public/private)
- Research plan §2 (Ontology) and §18 (evals)
- Ontology reviewer: `.claude/agents/hcs-ontology-reviewer.md`
