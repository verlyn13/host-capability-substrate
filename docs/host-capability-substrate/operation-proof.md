---
title: HCS Operation Proof Template
category: reference
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-22
tags: [operation-proof, human-facing, template]
priority: high
---

# HCS Operation Proof Template

Normative template for any command suggestion or operation proposal shown to a human. The dashboard renders this template directly. Skills and runbooks that generate human-facing advice consume the same template byte-identically.

This template is the structural antidote to "plausible but wrong CLI advice". If the proof can't be filled in, the proposal isn't ready.

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
{
  "command_mode": "argv",
  "file": "...",
  "argv": [...],
  "env_profile_id": "...",
  "lane": "resolve|inspect|validate|preview|execute|sandbox|interactive"
}
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

- **Proposed invocation is argv, not a shell string.** Shell strings require explicit risk-elevated justification (via `system.exec.unsafe_shell_proposal.v1`, denied by default).
- **Evidence must cite a real source.** Training-data recall is not evidence; substrate `tool.resolve` / `tool.help` output is.
- **Every section is present.** Missing sections say "not available: <reason>" — never omitted.
- **Cache status is honest.** `stale` is valid; `miss` is valid; never paper over a miss.
- **Policy tier is from substrate classification**, not agent memory.
- **If the resolved tool version is unknown, do not proceed.** Refuse with "evidence missing: tool version not resolved".

## References

- Research plan §19 (Operation proof standard)
- Skill: `.agents/skills/hcs-operation-proof/SKILL.md`
- Charter invariants 2 (OperationShape upstream), 9 (canonical skill location)

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-04-22 | Initial. Normative template. |
