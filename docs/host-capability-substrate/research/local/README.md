---
title: HCS local research artifacts
category: research
component: host_capability_substrate
status: active
version: 1.6.0
last_updated: 2026-05-01
tags: [research, local, host-evidence, github, version-control, quality-management, codex, worktree, branch-cleanup, diagnostics, workspace-context, isolation, ontology]
priority: medium
---

# Local research artifacts

This directory preserves first-party host investigations that inform HCS design.
These reports are observed evidence and planning intake, not accepted
architecture decisions. Reconciled decisions belong in `DECISIONS.md`, ADRs,
the implementation charter, and schemas.

## Status discipline

Local research can include runtime observations, installed config shapes,
command output summaries, and repo state. Treat each observation as freshness
bounded. If runtime state changes, the newer probed evidence wins.

Do not commit resolved secret values, private key material, or raw process
arguments that contain credential-shaped strings. Use secret references,
existence-only checks, names-only lists, hashes, or classified/redacted
summaries.

## Contents

| File | Source date | Scope |
|---|---:|---|
| `2026-04-29-github-version-control-agentic-surface.md` | 2026-04-29 | Deeper local and GitHub API investigation of GitHub, Git, SSH, MCP, repo settings, Actions, and local remote identity surfaces. Queues Q-006 for the GitHub/version-control authority model. |
| `2026-04-29-quality-management-synthesis.md` | 2026-04-29 | Synthesis of two `/private/tmp` reports on research method and HCS quality-management needs across macOS filesystem/app boundaries, Git/GitHub, package managers, multiple identities, and boundary uncertainty. Queues Q-007. |
| `2026-04-30-codex-scopecam-exchange-synthesis.md` | 2026-04-30 | Synthesis of a user-submitted Codex/ScopeCam exchange report covering tool-symptom diagnosis, execution-mode conflation, destructive branch cleanup, worktree ownership, branch-flow drift, auth probes, PR body quoting, and secret-safe diagnostics. Queues Q-008. |
| `2026-04-30-hcs-evidence-planning-synthesis.md` | 2026-04-30 | Synthesis of a user-submitted HCS evidence/planning report covering runtime diagnostics, the D-028 secret contract, workspace manifests, safe process inspection, docs cleanup classification, and claim reconciliation. Queues Q-009. |
| `2026-05-01-agentic-tool-isolation-synthesis.md` | 2026-05-01 | Synthesis of a user-submitted agentic coding tool isolation report. Separates permission gating, worktree/file isolation, local kernel sandboxing, container/VM isolation, and remote cloud execution. Queues Q-010. |
| `2026-05-01-version-control-authority-consult-synthesis.md` | 2026-05-01 | Synthesis of a user-submitted version-control authority consult. Refines Q-006 around source-control continuity, expected check source identity, branch deletion proof, Actions posture, and split GitHub credential surfaces. |
| `2026-05-01-ontology-promotion-receipt-dedupe-plan.md` | 2026-05-01 | Cross-Q planning document for ontology promotion buckets, candidate receipt dedupe, naming discipline, and dependency order before additional Ring 0 schema work. Queues Q-011. |

## Change Log

| Version | Date | Change |
|---|---:|---|
| 1.6.0 | 2026-05-01 | Added ontology promotion and receipt dedupe plan and linked Q-011. |
| 1.5.0 | 2026-05-01 | Added version-control authority consult synthesis and Q-006 refinement. |
| 1.4.0 | 2026-05-01 | Added agentic tool isolation synthesis and linked Q-010. |
| 1.3.0 | 2026-04-30 | Added HCS evidence/planning synthesis and linked Q-009. |
| 1.2.0 | 2026-04-30 | Added Codex/ScopeCam exchange synthesis and linked Q-008. |
| 1.1.0 | 2026-04-29 | Added quality-management synthesis from the two `/private/tmp` reports and linked Q-007. |
| 1.0.0 | 2026-04-29 | Initial local research index. |
