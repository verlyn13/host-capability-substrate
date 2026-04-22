---
adr_number: 0007
title: Hook call pattern — blocking RPC with cache fallback
status: accepted
date: 2026-04-22
charter_version: 1.1.0
tags: [hooks, claude-code, codex, rpc]
---

# ADR 0007: Hook call pattern — blocking RPC with cache fallback

## Context

PreToolUse hooks need to consult the HCS substrate without adding perceptible latency. Substrate may be unavailable (Phase 0a, startup, crashes). Agents must degrade gracefully.

## Decision

- **Pattern:** blocking local RPC with 50ms timeout and cache fallback.
- **Reads:** warn-and-allow on timeout or substrate-unavailable (fail-open).
- **Writes:** warn-and-deny when the command is confidently classifiable as mutating/destructive (fail-closed).
- **Claude Code:** command hooks for hard decisions; HTTP hooks for advisory/telemetry only.
- **Codex hooks:** advisory only (Bash-only coverage); not the enforcement boundary.

## Consequences

### Accepts

- Slight latency budget for classification (50ms p99).
- Hook bodies stay thin; logic delegates to substrate + cache.

### Rejects

- Async hooks for hard decisions (loses fail-closed semantics).
- HTTP hooks as sole enforcement (Claude HTTP hook failures non-blocking).
- Codex hooks as enforcement boundary (incomplete coverage).

### Future amendments

- If Codex hook coverage improves, elevate Codex hooks.
- If substrate sub-20ms becomes achievable reliably, tighten timeout.

## References

### Internal

- Research plan §§21.2, 21.3, 21.4, 22.8
- Decision ledger: `DECISIONS.md` entries D-005, D-006, D-007
- `.claude/hooks/hcs-hook` Phase 0a implementation

### External

- [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Codex hooks](https://developers.openai.com/codex/hooks)
