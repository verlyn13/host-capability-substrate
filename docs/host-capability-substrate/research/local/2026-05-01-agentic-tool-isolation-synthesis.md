---
title: Agentic Tool Isolation and Compatibility Synthesis
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-05-01
tags: [research, synthesis, phase-1, agent-tools, isolation, sandbox, worktree, cloud-agents, execution-context, boundary-uncertainty]
priority: high
---

# Agentic Tool Isolation and Compatibility Synthesis

Source report:
`docs/host-capability-substrate/research/external/2026-05-01-agentic-coding-tool-isolation-report.md`

SHA-256:
`3a54065b5511bee42990657cf29932f94fd343b58f0a8c8e1214873518870aeb`

## Status

This is an HCS synthesis of a user-submitted report on agentic coding tools as
of 2026-05-01. The report is broad and useful, but it is not written against
this repository's four-ring architecture, policy boundary, or schema-change
workflow.

Treat this intake as Ring 3 planning evidence. It does not change schema,
policy, adapters, hooks, repo settings, remote-agent settings, or live tool
configuration. Any schema work must still move through the HCS schema workflow:
Zod source, generated JSON Schema, ontology docs, tests, and review together.

## Core Lesson

The report's strongest value is the separation of ideas that agents often
collapse:

```text
permission gating != worktree/file isolation != kernel sandboxing !=
container/VM isolation != remote cloud execution
```

HCS should preserve those as separate evidence dimensions. An agent client can
have strong prompts and permissions while still running with ordinary local user
process authority. A tool can use Git worktrees while still sharing the same
process, network, Keychain, Docker socket, package-manager cache, and host user.
A remote VM can isolate the laptop while still needing explicit evidence about
snapshot secrets, repo checkout state, firewall policy, setup scripts, and PR
authority.

## What Not To Import

The report proposes a normalized `SharedAgentPolicySchema` plus vendor adapter
schemas. Do not copy that shape into HCS as a canonical policy or adapter layer.

Reasons:

- It starts from vendor configuration normalization, while HCS starts from
  Ring 0 evidence and semantic operations.
- It mixes policy posture, execution containment, workspace identity, tool
  allowlists, file patterns, secrets posture, and audit settings into one object.
- It risks making adapters own policy facts, which violates the charter.
- It treats some approximate UI/workflow mappings as schema-like fields.
- It could encourage false cross-tool equivalence between surfaces that need
  separate `ExecutionContext` evidence.

The useful part is the vocabulary. The implementation path is to express the
same distinctions as evidence carried by `ExecutionContext`, `AgentClient`,
`ToolInstallation`, `ResolvedTool`, `WorkspaceContext`, `ResourceBudget`,
`CredentialSource`, and future `BoundaryObservation` / `QualityGate`
candidates.

## Compatibility Taxonomy

Use these as candidate evidence values or taxonomy labels, not as accepted
schema enums yet:

| Dimension | Meaning | HCS implication |
|---|---|---|
| `permission_gate` | Tool asks/allows/denies by rule or UI mode. | Useful posture evidence, never proof of OS containment. |
| `workspace_write_scope` | Writes are limited to the open workspace or configured roots. | Evidence must name the surface and writable roots. |
| `worktree_file_isolation` | Parallel work is separated by Git worktree or branch. | Not process, network, or credential isolation. Compose with `WorkspaceContext` and `Lease`. |
| `kernel_sandbox` | Local process constrained by Seatbelt, bubblewrap, seccomp, Windows sandbox, or equivalent. | Needs installed-runtime or host-observed proof per surface/version. |
| `container_isolation` | Execution runs inside a devcontainer, Docker container, or self-hosted worker container. | Needs image, mount, socket, secret, network, and lifecycle evidence. |
| `vm_isolation` | Execution runs in a VM snapshot or per-task VM. | Needs snapshot, secret injection, reset/rollback, and egress evidence. |
| `remote_cloud_execution` | Execution happens on vendor or managed cloud infrastructure. | Treat as external control-plane evidence, not local host evidence. |
| `terminal_inheritance` | Tool uses the user's live shell/PTY/env. | Strong compatibility, weak containment; must bind to `EnvProvenance`. |
| `app_managed_bundle` | Tool ships its own Node/Python/runtime bundle. | Treat as `ToolInstallation` / `ResolvedTool` evidence separate from host PATH. |

## Tool-Class Intake

### Local OS Sandbox Surfaces

The report identifies Claude Code, Codex, and Cursor terminal sandboxing as the
clearest documented local macOS sandbox stories. HCS should not generalize that
claim across every product surface.

Planning implications:

- Keep Codex CLI, Codex app, Codex IDE extension, Claude Code CLI, Claude
  Desktop, Claude Code IDE extension, and Cursor terminal/cloud modes as
  separate `ExecutionContext` surfaces if HCS ever targets them directly.
- Record sandbox mechanism as evidence about a specific installed version,
  launch source, and tool subprocess, not as a vendor-wide fact.
- Continue P13-style app sandbox characterization for Codex app before treating
  app Keychain/filesystem/network behavior as known.
- Treat Docker socket, browser-debugging, local DB, and Unix-socket failures as
  boundary evidence rather than immediate tool bugs or command failures.

### Permissioned Local Agents

VS Code local agents, Windsurf local Cascade, Amp, OpenCode, Augment/Auggie, and
similar tools may expose useful permission systems, approval modes, rules, MCP
controls, or project guidance. The report did not establish built-in local
kernel/container isolation for these surfaces.

Planning implications:

- Model them as `permissioned_local_execution` until a stronger runtime proof
  exists.
- Do not treat their rule files as HCS policy locations.
- If HCS later supports them, prefer thin adapter observations that feed Ring 1
  policy rather than tool-local policy duplication.
- High-autonomy use on sensitive work should require an outer boundary:
  devcontainer, VM, remote runner, or separate account posture.

### Worktree and Workspace Isolation

The report reinforces a current HCS theme: worktrees are useful workflow
boundaries, but they are not process boundaries.

Planning implications:

- `WorkspaceContext` should represent worktree/branch/root identity, but not
  imply filesystem, credential, or process containment by itself.
- `Lease` and future coordination facts should guard worktree ownership before
  cleanup, branch deletion, merge, push, or rebase.
- Q-008 branch/worktree hygiene should explicitly reject "separate worktree"
  as deletion or safety proof.
- Q-009 workspace manifest work should distinguish search/lint/docs exclusions
  from execution containment.

### Remote VM, Container, and Cloud Agents

Devin, GitHub Copilot cloud agent, Codex cloud, Cursor cloud agents, Warp Oz,
and self-hosted cloud/container workers belong in the external-control-plane and
runner compatibility space. They can reduce local laptop risk, but they add
their own authority surfaces.

Planning implications:

- Fold remote/cloud execution into Q-005, Q-006, Q-008, Q-009, and the new
  Q-010 rather than treating it as local sandbox evidence.
- Candidate evidence should include environment snapshot id, base image,
  setup-script receipt, firewall/egress posture, checked-out commit, branch/PR
  authority, secret injection mode, build-only secret handling, and artifact
  return path.
- Remote execution receipts should not satisfy local `ExecutionContext` claims.
- Hosted/cloud status checks need source/app identity evidence before HCS uses
  them as gate inputs.

## Ring Mapping

| HCS ring | Intake value |
|---|---|
| Ring 0 schemas | Candidate fields/evidence for containment kind, permission posture, workspace isolation, remote environment, app bundle/runtime, and secret injection. |
| Ring 1 kernel | Tool-resolution, boundary-quality gates, evidence freshness, and policy decisions consume the typed facts. |
| Ring 2 adapters | Adapters may translate tool/app observations into HCS evidence, but must not decide policy or normalize away uncertainty. |
| Ring 3 workflows | AGENTS/skills/runbooks can warn agents not to equate tool capability with execution containment. |

## Candidate Shape Refinements

These are planning notes for Phase 1 schema reconciliation, not accepted schema
changes.

### `ExecutionContext`

Consider fields or evidence references for:

- `execution_location`: local host, local container, local VM, remote cloud,
  self-hosted remote.
- `containment_kind`: none, permission gate only, worktree, kernel sandbox,
  container, VM, vendor cloud.
- `containment_mechanism`: Seatbelt, bubblewrap, seccomp, Windows sandbox,
  devcontainer, Docker worker, VM snapshot, hosted Actions runner, vendor
  sandbox.
- `launch_source`: terminal, Finder, IDE, app desktop, web session, background
  worker, MCP child, setup script.
- `network_posture`: inherited, denied, allowlisted, proxy-only, vendor managed,
  unknown.
- `filesystem_posture`: workspace-only, configured roots, read-only broad read,
  full-user access, app sandboxed, unknown.
- `interactive_terminal`: none, integrated terminal, live PTY steering, full
  terminal use.

### `AgentClient`

Consider separating:

- product family from surface: for example Codex CLI vs Codex app vs Codex
  cloud.
- version semver from app bundle/build id from dependency bundle version.
- permission mode from containment mechanism.
- cloud/local execution mode from UI/control-plane location.

### `ToolInstallation` / `ResolvedTool`

The report reinforces that app-managed dependency bundles, devcontainer images,
cloud base images, setup-script-installed tools, Homebrew/mise shims, and PATH
tools are different authority surfaces. A `ResolvedTool` should point to the
surface that resolved it, not just a binary name.

### `CredentialSource`

Remote and cloud agents need credential-source distinctions beyond local env:

- session-only secret injection;
- build-only secret injection;
- disk-persisted secret file;
- app-managed OAuth/keychain;
- brokered `SecretReference`;
- environment compatibility rendering.

Do not infer durable credential safety from "remote" or "cloud"; snapshot and
setup-script receipts still matter.

### `Evidence` / `BoundaryObservation`

The report strengthens Q-007's case for a boundary evidence envelope. Useful
fields include observed surface, version/build, authority order, valid-until,
containment kind, observed allowed/denied effects, and whether the observation
is local-host, remote-control-plane, or sandbox-observation.

## Open Design Questions

1. Should containment be represented directly on `ExecutionContext`, as an
   `Evidence` subtype, or through a future `BoundaryObservation`?
2. Should `permission_posture` and `containment_posture` be two separate
   objects so UI approval modes cannot masquerade as sandboxing?
3. Should remote/cloud execution receipts extend Q-005 runner evidence, Q-006
   GitHub/control-plane evidence, or become a separate Q-010 taxonomy?
4. What minimum evidence lets HCS trust a remote agent's test result: checkout
   commit, base image, setup receipt, secret posture, network posture, and
   check-run identity?
5. Which products, if any, become first-class HCS target surfaces versus
   compatibility-only entries in the tooling matrix?
6. How should daily tool updates invalidate sandbox/containment evidence when
   the version changes but the product name stays the same?

## Regression Trap Candidates

Queue these for future consideration. Do not scaffold until a concrete observed
failure or human-approved fixture exists.

- `permission-mode-treated-as-sandbox`: agent treats ask/auto/allowlist mode as
  OS containment.
- `worktree-treated-as-process-isolation`: agent assumes separate worktree means
  separate network, credentials, package cache, or process tree.
- `remote-agent-result-without-environment-receipt`: agent trusts a cloud result
  without checkout, setup, image, secret, and check-source evidence.
- `sandbox-socket-failure-misdiagnosed`: agent treats Docker/Unix-socket failure
  in a local sandbox as package or app misconfiguration before classifying the
  boundary.
- `app-bundle-dependency-confused-with-host-path`: agent treats app-managed
  Node/Python/tool bundles as host PATH truth.
- `terminal-full-access-conflated-with-integrated-terminal`: agent treats live
  PTY/full-terminal steering as a normal non-interactive tool call.

## Planning Recommendation

Add Q-010 for the cross-agent isolation and compatibility taxonomy. Q-010 should
not displace Q-005/Q-006/Q-007/Q-008/Q-009:

- Q-005 owns CI runner/check evidence.
- Q-006 owns GitHub/version-control authority.
- Q-007 owns quality gates and boundary uncertainty.
- Q-008 owns execution reality and destructive Git hygiene.
- Q-009 owns HCS diagnostic surfaces and workspace manifest shape.
- Q-010 should reconcile agent-client surfaces, containment taxonomy, remote
  agent environment receipts, and how version updates invalidate compatibility
  evidence.

The next schema step is not to add vendor adapter schemas. The next schema step
is to decide how containment, permission posture, worktree isolation, and
remote-execution receipts compose with the core Milestone 1 entities.

## Change Log

| Version | Date | Change |
|---|---:|---|
| 1.0.0 | 2026-05-01 | Initial HCS synthesis of the agentic coding tool isolation report. |
