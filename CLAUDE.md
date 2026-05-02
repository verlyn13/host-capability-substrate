@AGENTS.md

# CLAUDE.md — HCS implementation behavior

You are helping build a host operations substrate. Favor boundary clarity over speed.

## Tool baseline

Early-phase HCS work assumes Claude Code CLI `2.1.120` minimum with Opus 4.7 (`opus` in `.claude/settings.json`). Claude app build identifiers are tracked separately from CLI semver. Subsequent minor updates acceptable; see `DECISIONS.md` D-029.

## When asked to implement

- First identify the ring being changed (Ring 0/1/2/3).
- Prefer schemas and tests before service code.
- Use subagents for review, not for simultaneous edits to the same files.
- Never add convenience shell execution.
- Never move policy into hooks or adapters.
- When uncertain about a CLI behavior, add a fixture/evidence path rather than guessing.
- Honor the implementation charter at `docs/host-capability-substrate/implementation-charter.md` (v1.3.0+).

## When reviewing

Look for:

- adapter leakage (policy or kernel logic in an adapter)
- policy duplication (tier rules outside canonical policy source)
- shell-string shortcuts (strings where `OperationShape` belongs)
- missing provenance (facts without source/observed_at/authority)
- missing schema versions
- dashboard drift (kernel output that dashboard can't render usably)
- audit-write endpoints exposed as agent-callable
- forbidden-tier operations made approvable
- approval grants with overly broad scope
- skills content drifted into `.claude/skills/` without a canonical at `.agents/skills/`
- cleanup claims that use `.gitignore` as deletion authority
- host config values written from stale docs rather than installed-runtime parser evidence
- GUI/app/IDE credential plans that assume terminal shell env inheritance
- env/process inspection that prints secret-shaped values into transcripts

Return objections before fixes. Blocking issues first, non-blocking second.

## Claude-specific notes for this repo

- Prefer specialized tools (Read, Edit, Grep, Glob) over Bash equivalents.
- `zsh` is the only managed interactive shell on this host per parent system-config policy; do not introduce fish-specific patterns.
- Use subagents scoped by tool and MCP server rather than the full toolbox.
- When proposing a Bash command: include the argv decomposition and the resolved tool path in your response, not just the shell string.
- When reviewing a Bash command proposal: if the proposer did not include argv + resolved path, that alone is a blocking comment.
- **Skills canonical location is `.agents/skills/`** (cross-tool). `.claude/skills/` is reserved for Claude-specific wrappers only, and is empty at Phase 0a. Add a wrapper only if Claude Code fails to discover the canonical; the wrapper references the canonical body, never copies it.
- Claude skills do not grant permissions — deny rules belong in `.claude/settings.json`.

## Settings posture

Harness-level enforcement (Claude Code settings) is layered with substrate-level policy. Both apply. Client-side scoping does not replace substrate policy.

- Managed/local settings deny broad unsafe patterns (see `.claude/settings.json`).
- HCS MCP server will be allowlisted once it exists; other MCP servers behind explicit per-repo opt-in.
- Hooks in this repo delegate to `.claude/hooks/hcs-hook` — a small helper. Hook bodies remain tiny because Claude command hooks run with full user permissions.

## Subagent table

Six project-scoped subagents in `.claude/agents/`, all Opus 4.7, no Bash in any tool list:

| Subagent | Tools | Role |
|----------|-------|------|
| `hcs-architect` | Read, Grep, Glob, Edit | ADR + boundary review; drafts ADRs |
| `hcs-ontology-reviewer` | Read, Grep, Glob | Schema/entity/provenance drift review |
| `hcs-policy-reviewer` | Read, Grep, Glob | Policy duplication, escalation holes, forbidden leaks |
| `hcs-security-reviewer` | Read, Grep, Glob | Secrets, sandbox, audit, forbidden operations |
| `hcs-hook-integrator` | Read, Grep, Glob, Edit | Wires hooks without owning policy |
| `hcs-eval-reviewer` | Read, Grep, Glob, Edit | Regression trap quality |

## Reference

Parent research plan (in system-config): `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` (v0.3.0+).

Charter: `docs/host-capability-substrate/implementation-charter.md` (v1.3.0+).
Tooling surface matrix: `docs/host-capability-substrate/tooling-surface-matrix.md`.
Boundary decision: see `docs/host-capability-substrate/adr/0001-repo-boundary.md` in this repo (master document lives in system-config).
