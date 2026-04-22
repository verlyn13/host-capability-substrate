---
adr_number: 0004
title: Storage — SQLite with WAL
status: accepted
date: 2026-04-22
charter_version: 1.1.0
tags: [storage, sqlite, wal, audit]
---

# ADR 0004: Storage — SQLite with WAL

## Status

`accepted`

## Context

HCS needs a local persistent store for audit events (append-only, hash-chained), visible state (materialized facts, sessions, proposals, grants, runs, leases), and cache entries. Single writer, many readers. Must survive a power cut mid-write.

## Options considered

### Option A: SQLite with WAL

**Pros:** single-file, fast, ACID, WAL mode supports concurrent readers with one writer ([SQLite WAL](https://www.sqlite.org/wal.html)). Matches workload shape.
**Cons:** local-only (fine for HCS).

### Option B: DuckDB

**Pros:** OLAP strength for audit analysis.
**Cons:** less mature for concurrent OLTP; audit needs OLTP.

### Option C: Postgres

**Pros:** battle-tested.
**Cons:** overhead for a single-host single-user service; more moving parts.

## Decision

**Option A — SQLite with WAL.** DuckDB can be used for post-hoc analysis reading the SQLite file.

## Consequences

### Accepts

- WAL mode, journal_mode = WAL, synchronous = NORMAL for throughput.
- Single-writer discipline at kernel level.
- Quarterly vacuum, 90-day retention for audit primary, rolling compressed archives under `$HCS_LOG_DIR/archive/`.

### Rejects

- Postgres / multi-host storage (out of scope).
- Read-write promotion at WAL level (audit is append-only).

### Future amendments

- Switch if storage scale or durability needs exceed SQLite capacity (unlikely on a single host).

## References

### Internal

- Research plan §13 (visible state vs audit state), §17 (leases), Appendix D (DDL)
- Decision ledger: `DECISIONS.md` entry D-003

### External

- [SQLite WAL](https://www.sqlite.org/wal.html)
