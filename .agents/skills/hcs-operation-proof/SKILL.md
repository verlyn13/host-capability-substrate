---
name: hcs-operation-proof
description: Render the HCS operation-proof structure for a command or operation proposal that will be shown to a human. Ensures every human-facing proposal includes context, evidence, argv, risk, preflight, preview, rollback, and verification.
allowed-tools: Read, Grep, Glob
---

# Skill: Render an operation proof

Use any time an agent produces a command suggestion or operation proposal that a human will review. This is the structural antidote to "plausible but wrong CLI advice" — if the proof can't be filled in, the proposal isn't ready.

## Inputs

- The operation intent (semantic, e.g., "restart this launchd service")
- Current session context (cwd, resolved toolchain if known)
- Available evidence (tool-resolve output, help cache, policy classification)

## Procedure

1. Read `docs/host-capability-substrate/operation-proof.md` for the canonical template.
2. Populate each section in order. **Do not skip any section.** If a section is unavailable, write "not available" with a one-line reason; do not omit.

## Template

```markdown
### Operation
{semantic operation name}

### Host context
- OS: {version}
- cwd: {path}
- Workspace: {id}
- Shell mode: {login|non_interactive|interactive}
- Resolved tool: {path}@{version}

### Evidence
- Source: {command or doc}
- Observed at: {ISO-8601 timestamp}
- Parser version: {version}
- Cache status: {hit|miss|stale}
- Confidence: {authoritative|high|best-effort}

### Proposed invocation
```json
{"command_mode": "argv", "file": "...", "argv": [...], "env_profile_id": "...", "lane": "..."}
```

### Risk
- Mutation scope: {none|write-local|write-project|write-host|write-destructive}
- Target resources: {list}
- Policy tier: {tier}

### Preflight
{validation command, or "not available: <reason>"}

### Preview
{dry-run/diff/plan output, or "not available: <reason>"}

### Rollback
{concrete rollback, or "not available: <reason>"}

### Verification
{command/fact to confirm success}
```

## Rules

- **Proposed invocation is argv, not a shell string.** Shell strings require explicit risk-elevated justification (see `system.exec.unsafe_shell_proposal.v1`, denied by default).
- **Evidence must cite a real source.** "My training data" is not evidence; the substrate's `tool.resolve`/`tool.help` output is.
- **Cache status is honest.** `stale` is a valid answer; so is `miss`. Never paper over a cache miss.
- **Policy tier is from substrate classification**, not agent memory.
- **If the resolved tool version is unknown, do not proceed.** Refuse the proposal with "evidence missing: tool version not resolved".

## Output

The populated operation-proof markdown. The dashboard renders this template directly; agents should produce it byte-identically.

## Reference

- Template source: `docs/host-capability-substrate/operation-proof.md`
- Research plan §19 (Operation proof standard)
- Tiers: `~/Organizations/jefahnierocks/system-config/policies/host-capability-substrate/tiers.yaml`
