# host-capability-substrate

**Host Capability Substrate (HCS)** — a horizontal operations kernel for this macOS workstation. Provides host ground-truth, toolchain resolution, capability exposure, policy/gateway, approval grants, audited runs, and human control for every agent on the host.

HCS is infrastructure. It is the substrate on which every agent's actions compose, not a feature of any one agent.

## Status

Phase 0b — 3-day measurement soak underway for April 23, 2026 through April 25, 2026. The governance scaffold is in place; kernel, adapters, and dashboard code are still intentionally unimplemented.

## Canonical governance

Authoritative documents live in [`system-config`](https://github.com/verlyn13/system-config) (`~/Organizations/jefahnierocks/system-config/`):

- Research plan — `docs/host-capability-substrate-research-plan.md` (v0.3.0+)
- Implementation charter — `docs/host-capability-substrate/implementation-charter.md` (v1.1.0+) — copy vendored here at `docs/host-capability-substrate/implementation-charter.md`
- Boundary decision — in-repo pointer: `docs/host-capability-substrate/adr/0001-repo-boundary.md` (v1.1.0+; master lives in `system-config`)
- Tooling surface matrix — `docs/host-capability-substrate/tooling-surface-matrix.md` (v1.0.0+) — copy vendored here
- Live runtime policy — `policies/host-capability-substrate/` (**canonical; not in this repo**)

Per charter invariant 10: this repo contains source, schemas, test fixtures, docs, and ADRs. Live policy, runtime state, audit archives, and tokens live outside the repo.

## Four rings

No lower ring may import from a higher ring. Enforced by CI from commit 1.

- **Ring 0 — Ontology & schemas** (`packages/schemas/`)
- **Ring 1 — Kernel services** (`packages/kernel/`)
- **Ring 2 — Adapter surfaces** (`packages/adapters/`, `packages/dashboard/`)
- **Ring 3 — Agent/human workflows** (`.agents/skills/`, `AGENTS.md`, `CLAUDE.md`, `PLAN.md`, `docs/`)

## Tool baseline (early phases)

- **Claude Code** ≥ `1.3883.0 (93ff6c)` with Opus 4.7
- **Codex** ≥ `26.417.41555 (1858)` with GPT-5.4

Subsequent minor updates acceptable. Re-evaluate at end of Phase 0b.

## Quick start

```bash
mise install       # Node LTS, shellcheck, shfmt, just
just verify        # lint + typecheck + tests + all boundary checks
just day1          # kickoff battery for the current Phase 0b soak
just measure       # daily partition capture during the soak window
just measure-brief # consolidated soak readout
```

## Project contract

Read in order:

1. `AGENTS.md` — canonical cross-tool contract
2. `CLAUDE.md` — imports `AGENTS.md` + Claude-specific notes
3. `docs/host-capability-substrate/implementation-charter.md` — binding invariants
4. `PLAN.md` — current milestone and acceptance criteria
5. `IMPLEMENT.md` — per-PR workflow rules
6. `DECISIONS.md` — human-readable decision ledger

## Runtime layout (not in this repo)

- **State:** `~/Library/Application Support/host-capability-substrate/`
- **Logs:** `~/Library/Logs/host-capability-substrate/`
- **LaunchAgent:** `~/Library/LaunchAgents/com.jefahnierocks.host-capability-substrate.plist`
- **Live policy:** `~/Organizations/jefahnierocks/system-config/policies/host-capability-substrate/`

## Subsidiary

Owned by **jefahnierocks** (Stronghold governance tier under The Nash Group).
