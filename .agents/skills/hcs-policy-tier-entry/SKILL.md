---
name: hcs-policy-tier-entry
description: Draft a proposed YAML tier entry for a new tool or capability. Target file is canonical in system-config, not this repo. Drafts require `hcs-policy-reviewer` subagent objections and human approval before merge.
allowed-tools: Read, Grep, Glob
---

# Skill: Draft a policy tier entry

Use when a new tool surfaces in HCS usage and needs a classification in the live policy. **This skill produces a draft only.** The live tier file lives at `~/Organizations/jefahnierocks/system-config/policies/host-capability-substrate/tiers.yaml` — editing it is a human-approved action in the system-config repo, not here.

## Inputs

- Tool name (e.g., `terraform`, `kubectl`, `docker`)
- Typical invocations + variants (e.g., `brew install`, `brew install --cask`)
- Any known destructive variants
- Dry-run / validate command (if any)

## Procedure

1. Read the existing tier schema at `policies/generated-snapshot/tiers.schema.json` (if snapshot is populated) or the Zod source at `packages/schemas/src/entities/PolicyRule.ts`.
2. Read existing entries in `~/Organizations/jefahnierocks/system-config/policies/host-capability-substrate/tiers.yaml` to match style and fill gaps.
3. Draft the entry following the schema. Required fields:
   - `capability` or `tool`: the canonical identifier
   - `default_tier`: one of `read-safe` | `write-local` | `write-project` | `write-host` | `write-destructive` | `forbidden`
   - `notes`: human-readable reasoning for the classification
4. Optional fields to populate when applicable:
   - `approval_required_for`: list of command-shape conditions that escalate one tier above default
   - `destructive_patterns`: regex list for fast pattern-match gating
   - `dry_run_command`: native dry-run if supported
   - `validate_command`: typed wrapper for `-t` / `validate` variants
   - `forbidden_verbs`: list of deprecated/disallowed verbs (e.g., `launchctl load` / `launchctl unload`)
   - `exceptions`: allow-list of known-safe command shapes

## Rules

- **`forbidden` tier has no `approval_required_for`.** If you're tempted to add one, the tool doesn't belong at `forbidden`.
- **Tier escalation is one level.** `approval_required_for` escalates `write-host` → `write-destructive`, not further.
- **Deprecated verbs are listed explicitly.** `launchctl load` / `launchctl unload` go in `forbidden_verbs` whenever the tool is `launchctl`.
- **Destructive patterns are regex, not prose.** Write actual regex, test against sample inputs.
- **Notes cite the reasoning.** Why is this tool classified this way? A future reviewer reads `notes` to understand intent.

## Output

1. A draft YAML block (one tool entry) to be reviewed by:
   - `hcs-policy-reviewer` for charter compliance, escalation holes, and forbidden-operation leaks
   - `hcs-ontology-reviewer` if the entry introduces new schema fields
   - Human for final acceptance
2. A summary of:
   - Chosen tier and why
   - Edge cases that were considered and how they were classified
   - Destructive patterns (if any)
   - Dry-run / validate commands (if supported)
   - Open questions that need human judgment

## Never do

- Edit the live `tiers.yaml`. That file lives in system-config and is human-owned per D-011.
- Classify a tool at `forbidden` without calling out what escalation path users would expect and why it is being explicitly refused.
- Speculate about tools you have not observed in session logs. Classify only what has concrete usage.

## Reference

- Canonical tiers.yaml location: `~/Organizations/jefahnierocks/system-config/policies/host-capability-substrate/tiers.yaml`
- Charter invariants 5, 6 (live policy is data; forbidden is non-escalable)
- Boundary decision §8 (four-layer policy set)
- Research plan §§9 (policy engine, YAML → OPA)
