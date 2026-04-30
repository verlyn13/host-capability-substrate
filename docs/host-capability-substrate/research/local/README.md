---
title: HCS local research artifacts
category: research
component: host_capability_substrate
status: active
version: 1.1.0
last_updated: 2026-04-29
tags: [research, local, host-evidence, github, version-control, quality-management]
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

## Change Log

| Version | Date | Change |
|---|---:|---|
| 1.1.0 | 2026-04-29 | Added quality-management synthesis from the two `/private/tmp` reports and linked Q-007. |
| 1.0.0 | 2026-04-29 | Initial local research index. |
