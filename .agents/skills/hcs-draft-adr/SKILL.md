---
name: hcs-draft-adr
description: Draft a new Architecture Decision Record (ADR) from a problem statement, set of options, or an accepted decision from DECISIONS.md that needs a formal ADR.
allowed-tools: Read, Grep, Glob, Edit
---

# Skill: Draft an ADR

Use when a decision has been made (or needs to be formalized) and requires an ADR for the public record.

## Inputs

- A problem statement, or
- A set of options with tradeoffs already considered, or
- A reference to an entry in `DECISIONS.md` marked `(pending ADR)`

## Procedure

1. Read `docs/host-capability-substrate/adr/0000-template.md`.
2. Determine the next ADR number by reading the existing files in `docs/host-capability-substrate/adr/`.
3. Derive a short slug (`0012-sandbox-executor-boundary.md` style — kebab-case, 2-5 words).
4. Draft the ADR with these sections:
   - **Status**: `proposed` (until a human accepts).
   - **Date**: today's ISO-8601 date.
   - **Context**: what problem or question prompted this ADR? what constraints apply?
   - **Options Considered**: at least two real alternatives; explicit pros/cons for each. Do not list only the chosen option.
   - **Decision**: the chosen option with one-paragraph rationale.
   - **Consequences**:
     - Accepts (what tradeoffs we are taking)
     - Rejects (what we are not doing and why)
     - Future amendments (what could trigger reopening this)
   - **References**: charter version, research plan section, applicable external docs.
5. If the ADR is a formalization of an accepted `DECISIONS.md` entry, update the entry's ADR column from `(pending ADR)` to the new ADR number.

## Rules

- ADRs do not decide; they record. The decision must already have been made (by the human) or must be explicitly marked `proposed` pending human acceptance.
- ADRs do not contain live policy data. They cite policy and reference where the data lives.
- ADRs cite the charter version they were written against.
- ADRs reference prior ADRs they supersede, and update the superseded one's status.

## Output

- The new ADR file at `docs/host-capability-substrate/adr/<NNNN>-<slug>.md`
- Optionally an update to `DECISIONS.md`
- A summary for the human:
  - What was decided
  - What was rejected
  - What remains open
  - Reviewer subagents to engage before merge

## Reference

- Template: `docs/host-capability-substrate/adr/0000-template.md`
- Charter: `docs/host-capability-substrate/implementation-charter.md`
- Decision ledger: `DECISIONS.md`
- Research plan: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`
