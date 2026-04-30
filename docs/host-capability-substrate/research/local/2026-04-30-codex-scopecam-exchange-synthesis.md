---
title: Codex / ScopeCam Exchange Synthesis
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-30
tags: [research, synthesis, codex, git, worktree, execution-context, cleanup, secrets]
priority: high
---

# Codex / ScopeCam Exchange Synthesis

Source report:
`docs/host-capability-substrate/research/external/2026-04-30-codex-scopecam-exchange-lessons.md`

## Status

This is an HCS synthesis of a user-submitted evidence report from a separate
ScopeCam exchange. It is useful design evidence, but not host-authoritative HCS
runtime evidence. The original transcript/log bundle is not committed here, so
regression-trap expansion remains seed-level until a redacted primary transcript
or equivalent fixture exists.

## Core Lesson

The failure class is not "Git was hard" or "network sandboxing was confusing."
The failure class is claim conversion: the agent converted a tool symptom into a
cause before proving the layer.

The report strengthens the HCS position that every operational claim must carry
provenance and context. It adds a sharper requirement: command execution itself
needs a receipt that separates tool/runtime status from command exit status.

Candidate principle:

```text
A command symptom is not a diagnosis. Before any mutating operation, agents must
separate observation, inference, disproving checks, and proposed action. If the
execution substrate is anomalous, implementation and cleanup stop until the
execution mode is classified.
```

## What It Strengthens

### ExecutionContext

Existing HCS planning already treats Codex CLI, Codex app, Claude Code, GUI app,
terminal, and sandbox observations as separate contexts. This report adds a
sub-context split inside the same session: normal shell mode and escalated shell
mode can differ enough that their outputs must not be merged without evidence.

Candidate evidence fields:

- `mode`: normal, escalated, host-approved, sandboxed, app-server, unknown
- `tool_status`: succeeded, failed, timed_out, no_capture, interrupted, unknown
- `exit_code`: nullable command-level exit status
- `stdout_bytes` / `stderr_bytes`
- `elapsed_ms`
- `cwd`
- `argv_redaction_status`
- `redactions_applied`

Candidate entity or evidence subtype:

- `ToolInvocationReceipt`
- `CommandCaptureReceipt`
- `ExecutionModeObservation`

### BoundaryObservation / QualityGate

Q-007 already covers boundary uncertainty. The ScopeCam report adds a concrete
gate rule: a no-output or no-exit-code anomaly is not merely "unknown"; it is a
quality boundary that should block branch deletion, merge, push, worktree
removal, and broad cleanup until a reality audit classifies the mode.

Candidate quality gates:

- `shell-basic-health`: `pwd`, `id`, `command -v git`, and repo root resolution
  must produce command-level receipts before mutation.
- `mode-equivalence`: normal and escalated observations cannot be treated as the
  same context unless a matching probe succeeds in both.
- `claim-ledger`: agent must label observations, inferences, and proposed
  actions separately after contradictory command evidence.

### Git / GitHub Authority Model

Q-006 already models GitHub as multiple authority planes. This report adds
three practical proof requirements:

- `ssh -T` is not fetch proof.
- `remote-gone` is not merge proof.
- tree-equivalence is not ancestry-equivalence for branch-flow health.

Candidate evidence subtypes:

- `AuthOperationProbe`: exact remote operation against exact refs, not generic
  SSH banner auth.
- `BranchDeletionProof`: branch exists, not current, not attached to a worktree,
  fresh prune result, ancestry or zero-diff/patch-equivalence proof.
- `BranchFlowObservation`: target branch ancestry invariant between integration
  branches.

### Worktree Coordination

The report provides a concrete worktree ownership gap. HCS already has
`WorkspaceContext` and `Lease`; this evidence suggests that multi-agent
worktree ownership may need an explicit registry or derived view before cleanup
and branch operations are permitted.

Candidate fields for `WorkspaceContext` or a derived coordination fact:

- `worktree_path`
- `repo_id`
- `role`
- `owner`
- `protected`
- `current_branch`
- `canonical_base`
- `may_cleanup`
- `active_lease_id`

### Secret-Safe Diagnostics

Trap #37 already covers process argv secret exposure. The ScopeCam report
confirms that this is not hypothetical and adds a useful rule: process and
environment diagnostics should be redacted before the model sees them, not only
before persistence.

Design implication:

- typed process inspection should default to pid/name-only;
- argv requires redaction receipt and, for raw output, explicit user approval;
- process termination remains a separate mutating operation.

## New Trap Seeds

The report justifies seed-level additions for these failure families:

- `tool-symptom-as-environment-diagnosis`
- `execution-mode-conflation`
- `remote-gone-branch-deletion-without-proof`
- `worktree-ownership-ignored`
- `branch-flow-ancestry-ignored`
- `inline-pr-body-shell-expansion`

Overlaps:

- `process-argv-secret-exposure` is already trap #37. The report strengthens it
  but does not require a new duplicate trap.
- `auth-surface-conflation` is already trap #35. The `ssh -T` lesson can be
  referenced there, while the operation-specific probe requirement can also feed
  Q-006.
- `ignored-but-load-bearing-deletion` is trap #16. The branch-deletion failure is
  related, but distinct enough to seed separately because proof is about Git
  ancestry/patch equivalence, not filesystem derivability.

## Planning Recommendations

1. Add Q-008 for the agent execution reality and destructive Git hygiene model.
2. Keep the new traps as seeds until a redacted ScopeCam transcript or equivalent
   fixture is available.
3. Fold `ToolInvocationReceipt` / `CommandCaptureReceipt` into Phase 1
   `Evidence`, `Run`, and `Artifact` schema design.
4. Treat `BranchDeletionProof` and `BranchFlowObservation` as Q-006 candidates,
   not immediate schema commitments.
5. Treat worktree ownership as a `WorkspaceContext` / `Lease` / coordination
   question, with Q-003 and Q-008 both relevant.
6. Prefer operational scripts in target repos only after HCS defines their
   evidence contracts. Do not copy these scaffolds blindly into HCS as policy.

## Uncertainties

- The report is a secondary evidence report. The original transcript is not in
  this repo, so detailed trap scaffolds should wait for primary citation or a
  human-approved redacted fixture.
- The ScopeCam branch-flow invariant (`main` must be represented in
  `development`) is repo-specific. HCS should model branch-flow invariants as
  repository policy evidence, not assume the same branch model for every repo.
- The normal-vs-escalated execution split may be Codex-version, sandbox-mode, or
  session-state dependent. HCS should model it as observed context, not a global
  Codex truth.
- `--body-file` for PR bodies is broadly sound, but the exact enforcement surface
  may belong in agent operating guidance, GitHub helper scripts, or future HCS
  GitHub operation renderers.

## Candidate Charter v1.3.0 Language

Queue only:

```text
Command symptoms are not diagnoses. Before a mutating operation, HCS-mediated
agents must distinguish tool/runtime failure from command failure, must not
promote execution evidence across unmatched execution modes, and must block
destructive Git cleanup unless branch/worktree safety is proven by typed
evidence.
```
