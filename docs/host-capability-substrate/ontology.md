---
title: HCS Ontology
category: reference
component: host_capability_substrate
status: partial
version: 0.4.0
last_updated: 2026-05-01
tags: [ontology, entities, schemas, execution-context, isolation, github, version-control]
priority: high
---

# HCS Ontology

Authoritative human-facing reference for HCS Ring 0 entities. The 20 core
entities remain the Milestone 1 target; the first Phase 1 shell/env schema
slice has landed for ADRs 0016, 0017, and 0018.

Canonical research plan sketch: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` §2 (Ontology) and §Appendix A.

## Entities (20 core)

```
HostProfile          canonical host identity + stable facts
WorkspaceContext     project/workspace identity (workspace.toml-derived)
Principal            a human or automated actor with an identity
AgentClient          connected MCP/A2A/hook client with version + identity
Session              one agent-client connection with declared/measured context
ToolProvider         a source of tools: mise, brew, system, project-local
ToolInstallation     a specific instance of a tool on this host
ResolvedTool         the authoritative answer for "what tool X in this context"
Capability           a declared kernel operation (e.g., service.activate)
OperationShape       semantic operation proposal with target + mutation scope
CommandShape         argv vector + env profile + execution lane (rendered from Operation)
Evidence             a fact with provenance, freshness, authority, confidence
PolicyRule           a tier/destructive-pattern/approval rule (YAML or Rego)
Decision             gateway output: allowed | requires_approval | denied
ApprovalGrant        scoped, expiring, replay-resistant authorization
Run                  one execution of an approved operation through the broker
Artifact             a run's structured output (diff, log chunks, exit code, signed summary)
Lease                exclusive or shared resource lock
Lock                 coarser mutex (e.g., "package-manager global")
SecretReference      op:// URI, never the value
ResourceBudget       per-session CPU/memory/network/sandbox-concurrency allocation
```

Each entity carries a `schema_version`. Entity schema versions are independent of adapter tool-name versions (MCP tool names follow `system.{namespace}.{verb}.v{N}` in adapter surfaces).

## Phase 1 Shell/Env Entities

The first committed Zod schemas are additive Ring 0 entities that make shell
and credential boundary claims explicit. They do not add kernel policy,
adapter behavior, hooks, or execution endpoints.

Generated JSON Schema lives in `packages/schemas/generated/` and is checked by
`just generate-schemas --check`.

### `ExecutionContext`

Source: `packages/schemas/src/entities/execution-context.ts`

Describes a named runtime surface and startup phase. Initial `surface` values
include `codex_cli`, `codex_app_sandboxed`, `codex_ide_ext`,
`claude_code_cli`, `claude_desktop`, `claude_code_ide_ext`,
`zed_external_agent`, `warp_terminal`, `mcp_server`, `setup_script`, and
`app_integrated_terminal`.

Key fields:

- `surface`, `kind`, and `phase` identify the context being described.
- `shell` records carrier, shell path, argv flags, startup files, and marker
  visibility for that phase.
- `sandbox` records coarse filesystem, network, and Keychain capability status
  as `observed_allowed`, `observed_denied`, `pending`, `unknown`, or
  `not_applicable`.
- `env_inheritance` records whether terminal shell inheritance was observed or
  rejected for that surface.
- `evidence_refs` is required; CLI evidence must not satisfy GUI app or IDE
  claims unless the evidence names that exact surface.

### `EnvProvenance`

Source: `packages/schemas/src/entities/env-provenance.ts`

Records why an environment variable name is present, absent, classified, or
hashed for a specific `ExecutionContext`. It adopts the devcontainer timing
classes `baked`, `runtime_applied`, and `probed`, plus Codex operator-policy
terms such as `inherit`, `include_only`, `exclude`, `set`, `overrides`, and
`ignore_default_excludes`.

The schema intentionally has no raw `value` field. Acceptable observation
modes are `name_only`, `existence_only`, `classified`, `hash_only`, `absent`,
and `not_observed`.

### `CredentialSource`

Source: `packages/schemas/src/entities/credential-source.ts`

Describes durable credential authority without exposing credential material.
Initial `source_type` values include `macos_keychain`, `codex_home_file`,
`claude_credentials_file`, `oauth_device_flow`, `subscription_oauth`,
`api_key_env`, `api_key_helper`, `onepassword`, `infisical`, `vault`,
`devenv_secretspec`, `long_lived_setup_token`, `service_account`, and
`brokered_secret_reference`.

Key fields:

- `storage_plane`, `durability`, `scope`, `rotation`, and `health` capture the
  operational posture of the source.
- `secret_ref` is an opaque reference only, such as an `op://` or `hcs://`
  reference. It is not secret material.
- `env_var_name` may describe a compatibility rendering, but shell env is not
  the durable source unless evidence says so for that surface.

### `StartupPhase`

Source: `packages/schemas/src/entities/startup-phase.ts`

Defines the 14-phase temporal ordering from ADR 0016:

1. `boot`
2. `launchd_user_session`
3. `gui_app_exec`
4. `terminal_emulator_launch`
5. `shell_login_init`
6. `shell_interactive_init`
7. `direnv_chpwd`
8. `mise_activate`
9. `agent_launch`
10. `agent_env_policy_apply`
11. `agent_session_hook`
12. `mcp_server_init`
13. `subagent_spawn`
14. `tool_call_subprocess`

The Zod schema validates that `order` matches the named phase. This protects
P03/P04/P09 reasoning from treating setup scripts, MCP startup, and tool-call
subprocesses as interchangeable timing points.

## Compatibility and Isolation Vocabulary

The 2026-05-01 agentic tool isolation intake does not add schema by itself. It
does refine the vocabulary that Milestone 1 schema reconciliation should
consider.

HCS must not collapse these concepts:

- permission gating: ask/allow/deny/autopilot/bypass modes and tool rules;
- workspace write scope: open-workspace or configured-root filesystem bounds;
- worktree/file isolation: Git worktree or branch separation;
- kernel sandboxing: Seatbelt, bubblewrap, seccomp, Windows sandbox, or
  equivalent local process containment;
- container or VM isolation: devcontainer, Docker worker, VM snapshot, or
  self-hosted runner boundary;
- remote cloud execution: vendor or managed infrastructure executing the task;
- terminal inheritance: live shell/PTY/env coupling;
- app-managed dependency bundle: bundled Node/Python/toolchain separate from
  host PATH.

Candidate schema reconciliation points:

- `ExecutionContext` may need explicit containment and execution-location
  evidence, not only `surface`, shell, sandbox, and env inheritance fields.
- `AgentClient` should distinguish product family, surface, app build,
  dependency bundle, permission mode, and containment mechanism.
- `ToolInstallation` and `ResolvedTool` should represent app-bundled
  dependencies, cloud setup/runtime tools, devcontainer tools, and host PATH
  tools as separate authority surfaces.
- `WorkspaceContext` and `Lease` should represent worktree identity and
  ownership without implying process, network, or credential isolation.
- `CredentialSource` should distinguish session-only, build-only,
  disk-persisted, app-managed OAuth/Keychain, brokered secret reference, and
  environment compatibility renderings.
- Future `BoundaryObservation` / `QualityGate` work should decide whether
  containment posture is modeled directly on `ExecutionContext`, as `Evidence`
  subtypes, or through a separate boundary envelope.

Do not copy vendor adapter schemas into Ring 0. Vendor config and UI settings
are observation sources; HCS schemas describe host facts, evidence,
capabilities, and decisions.

## Version-Control Authority Vocabulary

The 2026-05-01 version-control authority consult refines Q-006 but does not add
schema by itself. It strengthens the Milestone 1 goal that Git/GitHub facts
should be modeled as typed evidence before they become mutation authority.

HCS must not collapse these concepts:

- local repository state: path, repo root, `.git` location, current branch,
  `HEAD`, dirty state, sparse/partial clone state;
- worktree state: linked worktree path, attached branch, lock status, owning
  lease/session;
- remote/ref state: remote URL, fetch/push URL, remote `HEAD`, last fetch time,
  branch/tag/ref existence;
- Git identity: effective author email, signing key, signing program, config
  source and include order;
- SSH transport: host alias, identity source, agent/socket, known-host
  authority;
- GitHub credential source: human `gh`, SSH, GitHub App, Actions
  `GITHUB_TOKEN`, OIDC-issued token, MCP PAT/OAuth, app/web automation session;
- GitHub governance: rulesets, branch protection, required reviews, bypass
  actors, required checks, expected check source;
- Actions authority: workflow triggers, token permissions, runner labels,
  third-party action pinning, `pull_request_target`, environments, OIDC use;
- source-control continuity: protected named references, branch history,
  control start revision, and control lapse/restart evidence.

Candidate evidence/receipt names for Phase 1 reconciliation:

- `GitRepositoryObservation`
- `GitRemoteObservation`
- `GitConfigResolution`
- `GitIdentityBinding`
- `GitWorktreeObservation`
- `GitRefObservation`
- `GitBranchAncestryObservation`
- `BranchDeletionProof`
- `GitHubRepositorySettingsObservation`
- `GitHubRulesetObservation`
- `BranchProtectionObservation`
- `WorkflowPolicyObservation`
- `CheckRunReceipt`
- `StatusCheckSourceObservation`
- `GitHubCredentialObservation`
- `GitHubMcpSessionObservation`
- `PullRequestReceipt`
- `PullRequestReviewReceipt`
- `SourceControlContinuityReceipt`

Candidate `BranchDeletionProof` should include repository identity, worktree
attachment, fresh remote state, ancestry or patch-equivalence proof, dirty-state
check, PR state, lease state, and human review for force/remote/protected or
ambiguous deletion.

Check results should not be gateable from name and conclusion alone. Gateable
check evidence should include source app/integration, commit SHA, workflow path
or provider object, observed time, and freshness.

Do not turn these names into operation endpoints or policy tiers before Q-006
decides evidence subtype versus standalone entity shape.

## Provenance on every fact

Every `Evidence` record:

```json
{
  "value": "...",
  "source": "...",
  "observed_at": "...",
  "valid_until": "...",
  "authority": "project-local | workspace-local | user-global | system | derived | sandbox-observation",
  "cwd": "...",
  "parser_version": "...",
  "confidence": "authoritative | high | best-effort | stale | unknown",
  "host_id": "...",
  "session_id": "..."
}
```

## Populated by

- `hcs-ontology-reviewer` subagent catches schema drift
- `hcs-schema-change` skill enforces "schema + docs + JSON Schema + tests move together"
- Phase 1 Thread D delivers remaining Zod schemas + JSON Schema + full entity
  docs

## References

- Research plan §2, §Appendix A
- Charter invariant 5 (secrets as references), 8 (sandbox authority downgrade), 9 (skills location)

## Change log

| Version | Date | Change |
|---------|------|--------|
| 0.4.0 | 2026-05-01 | Added version-control authority vocabulary from the Q-006 consult synthesis. |
| 0.3.0 | 2026-05-01 | Added compatibility/isolation vocabulary from the agentic tool isolation intake as Phase 1 schema reconciliation guidance. |
| 0.2.0 | 2026-05-01 | Added first shell/env Ring 0 schema docs for `ExecutionContext`, `EnvProvenance`, `CredentialSource`, and `StartupPhase`. |
| 0.1.0 | 2026-04-22 | Initial stub. Lists 20 entities; points to research plan for shape details. |
