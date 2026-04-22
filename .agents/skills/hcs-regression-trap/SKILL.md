---
name: hcs-regression-trap
description: Convert an observed agent failure (stale CLI memory, wrong toolchain, deprecated syntax) into a regression trap entry for the HCS eval corpus.
allowed-tools: Read, Grep, Glob, Edit
---

# Skill: Write a regression trap

Use when an agent (yourself, a reviewer, a human) observes a failure class that should be caught by HCS going forward. Trap authorship is the mechanism that converts one-off bugs into permanent eval coverage.

## Inputs

- A description of the failure (what the agent did wrong)
- Citation: commit hash, session log, or memory note where the failure was observed (no synthetic traps)
- The expected correct trajectory (what the agent should have done)

## Procedure

1. Read the existing corpus at `packages/evals/regression/seed.md` and any expanded entries.
2. Check whether the failure pattern is already covered. If yes, extend the existing entry. If no, create a new entry.
3. For a new entry, fill in:
   - **Trap name** (kebab-case, matches a filename under `packages/evals/regression/`)
   - **Citation**: commit/session/memory where observed
   - **Failure pattern**: what the agent did wrong
   - **Forbidden outputs**: specific strings/patterns that constitute failure (deprecated syntax, bare shell strings, wrong version, etc.)
   - **Required trajectory assertions**: ordered list of substrate calls the agent must make (e.g., "call `system.tool.resolve.v1` before any `brew` proposal")
   - **Required evidence citations**: what observed_at / source / authority fields the agent must cite
   - **Pass criteria** (numeric): e.g., "in 10 runs against Opus 4.7, ≥9 cite `system.tool.resolve.v1` evidence before proposing `brew install`"
   - **Model coverage**: Claude Opus, GPT-5.4, Gemini/ADK — which are in scope for this trap
4. Add the entry to `packages/evals/regression/<trap-name>.md`.
5. Update `packages/evals/regression/seed.md` index if it exists.

## Rules

- **No synthetic traps.** Every trap cites a real incident.
- **Trajectory-scored, not answer-scored.** Whether the agent called the substrate first matters more than whether the final command was correct.
- **Forbidden outputs are explicit strings**, not vibes. List them.
- **Pass criteria are numeric**. "Usually correct" is not a pass criterion.

## Output

- New or updated file under `packages/evals/regression/`
- Updated `seed.md` index
- Summary for human:
  - Class of failure captured
  - Model coverage
  - Suggested cadence (pre-merge / weekly / monthly)

## Reference

- Eval section: research plan §18
- Seed corpus: `packages/evals/regression/seed.md`
- Charter invariant 11 (no deprecated syntax)
- Operation proof template: `docs/host-capability-substrate/operation-proof.md`
