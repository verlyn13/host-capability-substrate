---
title: HCS Evidence and Planning Synthesis
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-30
tags: [research, synthesis, hcs, diagnostics, worktree, cleanup, docs, secrets, workspace-context]
priority: high
---

# HCS Evidence and Planning Synthesis

Source report:
`docs/host-capability-substrate/research/external/2026-04-30-hcs-evidence-planning-report-1.md`

## Status

This is an HCS synthesis of a user-submitted planning report based on Claude
macOS / Opus 4.7 work. It is useful design evidence, but not host-authoritative
runtime evidence. Terminology has been normalized to HCS standards: the report's
ad hoc labels are treated as candidate capability areas, not accepted package
boundaries, roles, or interface names.

The binding HCS implementation model remains the four-ring charter:

```text
Ring 0: ontology and schemas
Ring 1: kernel services
Ring 2: adapter surfaces
Ring 3: agent/human workflows
```

For planning purposes, map the report's runtime, credential, workspace,
Git/GitHub, cleanup, docs, and claim-tracking ideas onto those rings.

## Core Lesson

The report consolidates several already-observed HCS failure families into one
operational requirement:

```text
Agents should not have to infer host reality from raw shell symptoms. HCS should
provide typed, redacted, provenance-carrying diagnostics for runtime health,
secrets, workspace ownership, Git/GitHub authority, process inspection, docs
classification, cleanup authority, and claim tracking.
```

The design goal is not to make each target repo smarter. It is to move repeated
host-level assumptions behind shared HCS evidence contracts.

## Relationship to Existing Decisions

### D-025: Deletion Authority

The report extends D-025 from filesystem cleanup to branch, doc, planning, and
project-state cleanup:

- ignored does not mean disposable;
- remote-gone does not mean merged;
- unreferenced does not mean stale;
- absent from a planning index does not mean inactive;
- no output does not mean success.

This strengthens existing cleanup planning without changing the accepted
decision.

### D-026: Runtime Claim Provenance

The report generalizes D-026 beyond config files. Claims about shell reliability,
`op` behavior, `direnv`, Claude/Codex MCP config loading, GitHub auth, and exact
Git operations all need provenance:

- source class;
- observed time;
- installed version;
- authority order;
- matching execution context.

### D-027: Host Hygiene Boundary

The report is aligned with D-027: pre-launch host-config validation stays in
host hygiene / system-config, while HCS exposes runtime diagnostics after an
agent session can start.

Potential boundary:

- Host hygiene owns shell/bootstrap/agent-config lint and MCP config shape before
  startup.
- HCS owns post-start runtime evidence, diagnostics, brokered secrets, policy
  classification, and cleanup planning.

### D-028 and ADR 0012: Credential Plane

The report strongly supports the existing `host_secret_*` caller-facing contract
and the future `HCS_BROKER_SOCKET` broker path. It argues against target-repo
`.envrc` timeout logic and for a shared bounded secret interface.

No new credential namespace should be accepted from this report. D-028 remains
the authority.

## Candidate Capability Areas

The report's non-secret command labels are normalized here into candidate HCS
operation surfaces. Only `host_secret_*` is already accepted as a shell
compatibility contract through D-028.

| Candidate area | Candidate HCS surface | Likely HCS owner | Existing relationship |
| --- | --- | --- | --- |
| Runtime diagnostics | `system.runtime.diagnose.v1` | Ring 1 kernel, Ring 2 CLI/MCP adapter | Shell research P06/P08/P09, Q-007, Q-008 |
| Secret diagnostics/read/export | `host_secret_*`; future `system.secret.*` broker surfaces | Ring 1 credential broker, Ring 2 CLI | D-028, ADR 0012 |
| Git/GitHub diagnostics | `system.git.diagnose.v1` | Ring 1 evidence service, Ring 2 CLI/MCP adapter | Q-006, Q-008 |
| Workspace diagnostics | `system.workspace.diagnose.v1` | Ring 0 `WorkspaceContext`, Ring 1 workspace service | Q-003, Q-008 |
| Safe process inspection | `system.process.inspect_safe.v1` | Ring 1 typed process-inspection operation | Trap #37, Q-008 |
| Docs/reference diagnostics | `system.docs.diagnose.v1` | Ring 1 evidence/cleanup classifier plus workspace manifest inputs | Q-003, Q-009 candidate |
| Cleanup planning | `system.cleanup.plan.v1` | Ring 1 policy/gateway and cleanup classifier | D-025, trap #16, trap #41 |
| Claim reconciliation | `system.claims.reconcile.v1` or a coordination/evidence view | Ring 1 evidence/coordination service | Q-003, Q-008 |

The final public surface should use HCS versioned operation names and structured
schemas. Do not introduce standalone shell commands for these surfaces before the
Ring 0/1 contracts exist, except for the accepted `host_secret_*` compatibility
surface.

## New Planning Inputs

### Budget Triage Evidence

The Budget Triage observations add three concrete design pressures not fully
covered by the ScopeCam synthesis:

- nested agent worktrees can contaminate search, lint, docs inventory, and stale
  file detection;
- duplicate MCP config files need canonical-source resolution rather than silent
  inference;
- large docs trees require classification, not age/path heuristics.

Candidate trap families, not yet seeded:

- `nested-worktree-search-contamination`
- `duplicate-mcp-config-canonicality`
- `docs-planning-index-projection-drift`

These should wait for a redacted primary audit or human-approved fixture before
being added to the regression corpus.

### Workspace Manifest Inputs

The report proposes a small target-repo manifest. This is aligned with HCS, but
the file location and schema need a deliberate decision.

Candidate manifest fields:

- workspace identity;
- canonical MCP config;
- protected paths;
- search/lint/docs exclusions;
- worktree policy;
- secret contract;
- verification commands;
- docs taxonomy;
- target-repo cleanup rules.

Open design question: whether this becomes a repo-local manifest, host-level
workspace registry entry, `WorkspaceContext` source, or generated view from
existing target-repo governance files.

### Claim Reconciliation

The report's claim-ledger idea overlaps strongly with Q-003 and Q-008. It should
not become a general untyped memory. It should either:

- specialize `Evidence` / `DerivedSummary` / `CoordinationFact`, or
- become a view over typed `Evidence`, contradictions, and decisions.

The important rule is that inferred causes must not be promoted above observed
facts without contradicting-evidence handling.

## Acceptance Scenarios to Preserve

The report proposes ten readiness scenarios. Reconcile them into future evals
and integration tests:

1. 1Password locked: distinguish locked app from missing secret.
2. 1Password IPC deadlock: return typed timeout, not a hang.
3. `timeout`/`gtimeout` missing: report missing bounded execution support.
4. Normal shell broken: detect missing `EXIT=` marker / no-output anomaly.
5. Escalated shell works: report mode divergence without treating it as repo
   state.
6. Raw process output contains a token: redact before model exposure.
7. Nested worktree exists: exclude it from stale-file and docs scans.
8. Remote-gone branch exists: refuse deletion without ancestry or patch proof.
9. Stale directive references deleted files: report stale references without
   deleting docs.
10. Project planning data omits active planning specs: report projection drift,
    not stale files.

## Planning Recommendation

Add Q-009 for the HCS diagnostic surface and workspace manifest model. This
decision should reconcile:

- candidate operation namespace versus accepted HCS versioned tool names;
- shell compatibility wrappers versus MCP/CLI tools;
- repo-local manifests versus host-level workspace registry;
- ScopeCam and Budget Triage as target-repo workspace profiles;
- docs cleanup classification versus planning-index truth;
- claim reconciliation's relationship to Q-003 coordination facts.

Do not implement the proposed command list as shell scripts before the Ring 0/1
evidence contracts exist. The report is strongest as a Phase 1 synthesis input,
not as an immediate adapter implementation spec.

## Open Questions

- Does `system.runtime.diagnose.v1` belong before or after the first schema
  milestone? It needs `ExecutionContext` and command-capture evidence, but it is
  also a useful diagnostic bootstrap.
- Is the workspace manifest a source of truth or an index over existing source
  files? This matters for deletion authority.
- Should `system.docs.diagnose.v1` be part of HCS, or should HCS expose generic
  document-reference evidence while target-repo manifests own taxonomy?
- What is the minimum safe redactor for model-facing diagnostics, and does it
  differ from persistence redaction?
- How does claim reconciliation avoid becoming untyped agent memory?
