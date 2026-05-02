---
title: HCS Hook Contracts
category: reference
component: host_capability_substrate
status: stub
version: 0.4.0
last_updated: 2026-05-01
tags: [hooks, claude-code, codex, policy, contracts]
priority: medium
---

# HCS Hook Contracts

Defines how hooks interact with the HCS substrate. Populated in Phase 3 when the kernel exposes `system.tool.resolve.v1` and `system.policy.classify_operation.v1`. At Phase 0a, hooks log only. During the current Phase 0b soak, a separate measurement hook is also available.

## Phase 0a (log-only)

`.claude/hooks/hcs-hook` and `.codex/hooks/hcs-hook` scripts:

- Reads JSON event from stdin
- Writes to `.logs/phase-0/hook-events.jsonl`
- Blocks only on literal forbidden patterns (SIP, Gatekeeper, `rm -rf /`, etc.)
- Exit codes:
  - 0 → allow
  - 1 → log and continue (advisory)
  - 2 → block with stderr reason

## Phase 0b (current soak)

Three hook surfaces coexist during the soak:

- `.claude/hooks/hcs-hook` remains the repo-local minimal guardrail for work inside this repo.
- `.codex/hooks/hcs-hook` mirrors the repo-local minimal guardrail for trusted
  Codex project config layers.
- `scripts/dev/hcs-hook-cli.sh` is the opt-in global measurement hook installed by `just soak-install-hook`.

The Phase 0b measurement hook:

- Reads the same JSON hook envelope from stdin
- Classifies shell commands with `scripts/dev/classify.py`
- Writes decision records to `.logs/phase-0/<YYYY-MM-DD>/hook-decisions.jsonl`
- Always returns `allow` in Phase 0b; it is measurement-only, never the enforcement boundary
- Exists to collect evidence for the April 23-25, 2026 soak, not to replace substrate policy

Closeout parity on 2026-04-26 added trap #18 coverage to the interim
classifier and repo-local literal hook: direct secret-shaped env echo and
`printenv|env | grep` value enumeration are treated as forbidden measurement
events. Safe alternatives are existence-only, names-only, classified, or hashed
inspection. This remains a thin guardrail; canonical enforcement moves to Ring 1
when `system.policy.classify_operation.v1` exists.

## Phase 3+ (RPC to substrate)

Hook upgrades to:

- Call `system.tool.resolve.v1` with 50ms timeout + cache fallback
- Call `system.policy.classify_operation.v1` with 50ms timeout + cache fallback
- Classification `read-safe` → allow
- Classification `write-local` / `write-project` → allow with warning
- Classification `write-host` → ask (substrate not yet running execute lane)
- Classification `write-destructive` or `forbidden` → block
- Fail-open for reads (warn + allow on timeout or substrate-unreachable)
- Fail-closed for writes (deny when command is confidently mutating/destructive and substrate can't classify)

## Phase 4+ (gateway integration)

Hook additionally:

- Proposes via `system.gateway.propose.v1`
- Consumes `ApprovalGrant` via `system.gateway.consume_grant.v1`
- Records pass-through events in audit log

## Codex hooks

Advisory only. Codex project hooks live in `.codex/hooks.json` and load only
when the project `.codex/` layer is trusted. Bash coverage is incomplete per
D-007 and the current Codex hooks documentation; Codex hooks can log and block
minimal literal forbidden patterns, but substrate policy/gateway remains the
real enforcement boundary.

## Populated by

- Phase 3 — hooks connected to substrate
- `hcs-hook-integrator` subagent maintains

## References

- Research plan §22.8 (implementation-phase hook strategy)
- Charter invariants 1 (no policy in adapters), 4 (audit internal)
- Boundary decision §11 (stage-by-stage config)
- D-005, D-006, D-007 in `DECISIONS.md`
- OpenAI Codex Hooks documentation:
  `https://developers.openai.com/codex/hooks`

## Change log

| Version | Date | Change |
|---------|------|--------|
| 0.4.0 | 2026-05-01 | Added project-scoped `.codex/` hook contract notes and clarified that Codex hooks are trusted-project advisory guardrails, not the enforcement boundary. |
| 0.3.0 | 2026-04-26 | Added Phase 0b closeout note for trap #18 secret-safe env-inspection parity in the interim classifier and repo-local hook. |
| 0.2.0 | 2026-04-23 | Added the Phase 0b measurement-hook contract and clarified the distinction between the repo-local guardrail hook and the opt-in soak hook. |
| 0.1.0 | 2026-04-22 | Initial stub. |
