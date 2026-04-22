---
adr_number: 0002
title: Runtime — Node LTS
status: proposed
date: 2026-04-22
charter_version: 1.1.0
tags: [runtime, node, bun]
---

# ADR 0002: Runtime — Node LTS

## Status

`proposed` (to be accepted at end of Phase 1 Thread B)

## Date

2026-04-22

## Charter version

Written against charter v1.1.0.

## Context

HCS is an always-on service. Cold start matters less than ecosystem maturity, OpenTelemetry support, SQLite library maturity, long-lived process behavior, and boring production debugging. Research plan §22.2 recommends Node LTS first; Bun only with measured evidence.

## Options considered

### Option A: Node LTS (v24)

**Pros:** mature ecosystem, OTEL support, boring process behavior, broad SQLite library options.
**Cons:** slower stdio cold-start than Bun.

### Option B: Bun

**Pros:** faster stdio cold-start.
**Cons:** less mature for always-on service patterns, less OTEL-stable, less widely-used SQLite libraries.

## Decision

(Pending Phase 1 Thread B measurements.) Default recommendation: **Node LTS v24**. Bun may be adopted for scripting subsections if Thread B reveals material benefit for stdio latency.

## Consequences

### Accepts

- Boring runtime for the kernel; fast iteration for scripts.
- `.mise.toml` pins `node = "24"` in Phase 0a scaffold.

### Rejects

- Using Bun as the kernel runtime without measurement evidence.

### Future amendments

- Phase 1 Thread B stdio cold-start numbers.
- End-of-Phase-0b baseline re-evaluation.

## References

### Internal

- Research plan §22.2
- Decision ledger: `DECISIONS.md` entry D-002

### External

- `developers.openai.com/api/docs/guides/code-generation`
