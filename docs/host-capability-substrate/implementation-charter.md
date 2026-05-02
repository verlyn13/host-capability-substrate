---
title: Host Capability Substrate — Implementation Charter
category: charter
component: host_capability_substrate
status: active
version: 1.3.0
last_updated: 2026-05-02
tags: [substrate, kernel, adapters, ontology, policy, four-rings, non-import, skills, deployment-boundary]
priority: critical
---

# Host Capability Substrate — Implementation Charter

Binding rule for everyone (human and agent) touching HCS. Citable from every PR. Violations block merge.

Parent research plan: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`. Boundary decision: [`adr/0001-repo-boundary.md`](./adr/0001-repo-boundary.md). Tooling surface matrix: [`tooling-surface-matrix.md`](./tooling-surface-matrix.md).

## The four rings

The substrate has four rings. **No lower ring may import from a higher ring.**

```text
Ring 0: Ontology and schemas
  Versioned entities, operation shapes, command shapes, evidence, decisions,
  approval grants, runs, leases, artifacts.

Ring 1: Kernel services
  Host state, tool resolution, capability registry, policy/gateway,
  session ledger, evidence/cache, audit, lease manager, execution broker.

Ring 2: Adapter surfaces
  MCP stdio, MCP Streamable HTTP, dashboard HTTP, CLI, Claude hooks,
  Codex hooks, future A2A, future MCP Apps.

Ring 3: Agent/human workflows
  Skills (.agents/skills/ canonical), AGENTS.md, CLAUDE.md, PLAN.md,
  runbooks, eval prompts, dashboard review flows.
```

## Non-negotiable invariants

1. **No policy decision may live in an adapter.** Tier classification, destructive-pattern matching, approval logic, forbidden-operation checks — all belong in Ring 1's policy/gateway service. Adapters translate, they do not classify.

2. **No shell command is an ontology object; it is only a rendered `CommandShape`.** `CommandShape` is downstream of `OperationShape`. Agents propose operations; the kernel renders commands against the current resolved toolchain.

3. **No agent can reach across rings to shortcut a layer.** If Ring 3 wants host state, it calls Ring 2 which calls Ring 1 which reads Ring 0. Layer skipping is a design smell that manifests as coupling in the audit log.

4. **Audit logging is an internal side effect, never an agent-callable tool.** External testimony (when added) uses a separate endpoint and a separate table, typed as untrusted.

5. **Secrets never live in Ring 0 or Ring 1 at rest.** References (`op://` URIs) yes. Values no.

6. **`forbidden` tier is non-escalable.** No approval grant, no policy exception, no human override at the gateway level. Forbidden operations are not registered as capabilities.

7. **Execute lane does not ship before the full approval/audit/dashboard/lease stack is live.** Approval grants, dashboard review, tamper-evident audit, lease manager — all four must exist together before any capability with `mutation_scope != "none"` is callable.

8. **Sandbox observations cannot be promoted to host-authoritative evidence.** `authority: sandbox-observation` is a schema-level value, lower than any host-origin authority.

9. **Skills are canonical at `.agents/skills/`.** *(added in v1.1.0)* The cross-tool workflow home is `.agents/skills/<skill-name>/SKILL.md`. `.claude/skills/` is reserved for Claude-specific wrappers only, and exists only when Claude Code requires a wrapper that cannot be expressed in the canonical skill body. Skill content is not duplicated.

10. **Public source, private deployment boundary.** *(added in v1.1.0)* The repo contains source, schemas, generated JSON Schema, test fixtures with redacted data, docs, ADRs, regression prompts, and policy schemas. The repo does **not** contain: live policy YAML (that lives in `system-config/policies/host-capability-substrate/`), SQLite runtime state, materialized facts cache, audit archives, dashboard tokens, resolved secret values, or host-specific runtime configuration. Runtime state lives under `~/Library/Application Support/host-capability-substrate/`, logs under `~/Library/Logs/host-capability-substrate/`, secrets in 1Password.

11. **Operations never use deprecated syntax when a modern replacement exists.** *(added in v1.1.0)* `launchctl load`/`unload` are deprecated; use `bootstrap`/`bootout`. The capability registry refuses to render deprecated verbs. Rule generalizes to any tool whose docs mark a syntax as deprecated.

12. **Tool version baseline is explicit.** *(added in v1.1.0; amended in v1.2.0)* Early-phase HCS work is pinned to public CLI semver strings: Claude Code CLI ≥ `2.1.120` with Claude Opus 4.7 and Codex CLI ≥ `0.125.0` with GPT-5.5/GPT-5.4-compatible HCS profiles. App build identifiers are tracked separately because app build numbers and CLI semver are different authority surfaces. Subsequent minor updates are acceptable; re-baseline after material version changes.

13. **Deletion authority is not gitignore state.** *(added in v1.2.0)* Cleanup operations must distinguish derivable-from-source, ephemeral cache, user scratch, and load-bearing state before proposing deletion. `.gitignore` only says whether Git tracks a path; it never proves that the path is safe to remove. Load-bearing measurement, audit, runtime, broker, policy-cache, or materialized-facts paths are non-escalable until a typed authority source says otherwise.

14. **Config-spec claims require authority provenance.** *(added in v1.2.0)* Runtime config assertions must carry `{source, observed_at, installed_version, authority_order}` provenance. Authority order is: observed runtime + matching changelog > static vendor docs > published schema > model memory. Agents must not write host-harness config from stale docs or model memory when a strict runtime parser can be checked first.

15. **GUI shell-env inheritance must not be assumed.** *(added in v1.2.0)* GUI apps, app-bundled agents, IDE extensions, and background workers have their own `ExecutionContext`. They do not automatically inherit terminal shell exports, direnv state, zsh rc files, or agent-session env hooks. Credential and env availability must be modeled through launchd/session env, Keychain/OAuth, explicit MCP auth, brokered secret references, or probed execution-context evidence.

16. **External-control-plane operations are evidence-first.** *(added in v1.3.0)* Operations against remote control planes must produce typed evidence before provider-side mutation is proposed or rendered. HCS must distinguish provider object references, public client IDs, policy selector values, secret references, and secret material. Where the provider exposes a separable validator surface, such as ADR 0015's `OriginAccessValidator` / `AudienceValidationBinding` precedent, HCS must model that validator binding before proposing mutations that depend on it. Rate-limit and backoff state are evidence rather than retry pressure. Typed evidence is necessary, not sufficient; it does not bypass policy/gateway decisions, `ApprovalGrant` consumption, broker finite-state-machine requirements, audit, dashboard review, or lease requirements.

17. **Execution context is declared, not inferred.** *(added in v1.3.0)* Every operation carries a resolved `ExecutionContext` surface reference. Agents must not assume a subprocess inherits any sandbox, capability, environment, or credential scope from a parent context unless that inheritance is intentionally represented by typed evidence bound to the target execution context and to the specific dimension being asserted. Surface-specific operators such as Codex `shell_environment_policy` `inherit` / `include_only` are environment-materialization evidence only for the named target context; they do not prove credential authority, sandbox scope, app/TCC permission, provider mutation authority, or HCS `ApprovalGrant` status.

## Package boundary enforcement

CI checks at merge time:

- `packages/adapters/**` cannot import from `packages/kernel/src/**` except through the declared public API surface (`packages/kernel/src/api/`).
- `packages/kernel/**` cannot import from `packages/adapters/**` at all.
- `packages/schemas/**` cannot import from anywhere above Ring 0 (no kernel, no adapter, no dashboard imports in schemas).
- Dashboard view contracts (`packages/dashboard/src/contracts/`) are importable by kernel for rendering; kernel modules other than rendering helpers must not import dashboard internals.
- No YAML policy file exists outside `system-config/policies/host-capability-substrate/` or the test fixture directory `packages/fixtures/policies/`.
- No `bash.run`, `shell.exec`, or equivalent universal-shell tool is registered in any capability manifest.
- Every `OperationShape` with `mutation_scope != "none"` has a documented gateway path, a decision-package contract, and a renderer; missing any of these blocks merge.
- *(added in v1.1.0)* No skill content exists only in `.claude/skills/`; every skill has a canonical file at `.agents/skills/<name>/SKILL.md`. `.claude/skills/<name>/SKILL.md` is permitted only when it adds Claude-specific frontmatter on top of the canonical body.
- *(added in v1.1.0)* No file in the repo matches the `$HCS_STATE_DIR` or `$HCS_LOG_DIR` layout — runtime state must never enter the repo.
- *(added in v1.1.0)* No committed file contains a resolved `op://` value or any string matching known secret patterns (gitleaks/forbidden-string scan).
- *(added in v1.2.0)* Cleanup capabilities must include a deletion-authority source before any renderer can produce recursive delete or `find -delete` command shapes.
- *(added in v1.2.0)* Config validators must prefer observed installed-runtime parsing where available before accepting schema/doc-only claims for host harness files.

## Authoring rules

When opening a PR:

- Identify the target ring (a single ring per PR is strongly preferred).
- If the PR changes ontology, schemas, JSON Schema, **and** docs must change together.
- If the PR changes policy, the `hcs-policy-reviewer` subagent must produce its objections before human review.
- If the PR changes any ontology entity or schema, the `hcs-ontology-reviewer` subagent must produce its objections before human review. *(v1.1.0)*
- If the PR changes adapter code, confirm no kernel or policy logic leaks in.
- If the PR changes kernel code, confirm no protocol or client-specific assumption leaks in.
- If the PR adds a capability, include the six-question surface boundary answers in the capability's schema description (see research plan §5).
- If the PR adds or edits a skill, the canonical file must be at `.agents/skills/<name>/SKILL.md`. *(v1.1.0)*

## Forbidden patterns (list, not exhaustive)

- Copying tier classification into a hook body
- Hard-coding a `--help` string instead of invoking and caching with provenance
- Treating a shell string as the canonical operation representation
- Exposing `system.audit.log.v1` (or equivalent) as an agent-callable tool
- Registering `bash.run` or a universal shell wrapper
- Promoting sandbox evidence to `authoritative` confidence
- Adding an adapter that conditionally evaluates policy locally
- Writing secrets into any persistent config file
- Adding a capability whose description omits the six-question answers
- Registering an operation whose `forbidden` tier has an `approval_required_for` clause
- *(v1.1.0)* Duplicating a skill into `.claude/skills/` when no Claude-specific wrapper behavior is required
- *(v1.1.0)* Creating `WARP.md` during Phase 0a (Warp prioritizes `WARP.md` over `AGENTS.md`; if ever added post-Phase-0b, must be pointer-only referencing `AGENTS.md`)
- *(v1.1.0)* Duplicating forbidden-pattern literals across `.claude/settings.json`, `.cursor/rules/`, `.vscode/settings.json`, or agent docs — enforcement is `.claude/settings.json` + `.claude/hooks/hcs-hook`; other surfaces are pointers
- *(v1.1.0)* Adding `.windsurf/skills/` or `.windsurf/` project-scope config — Windsurf has no project scope; cross-tool skills live in `.agents/skills/`
- *(v1.1.0)* Committing resolved `op://` values or any secret-pattern match
- *(v1.1.0)* Writing any runtime state, loaded policy copy, or audit archive into the repo
- *(v1.2.0)* Treating `.gitignore` membership as deletion approval for `.logs/`, runtime state, materialized facts, audit partitions, or policy caches
- *(v1.2.0)* Writing boolean-like config as strings (for example `"verbose": "true"`) when the installed parser expects JSON booleans
- *(v1.2.0)* Assuming Codex app, Claude Desktop, IDE agents, or other GUI-launched surfaces inherit `GITHUB_PAT`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or shell-exported setup variables from a terminal session
- *(v1.2.0)* Echoing or enumerating secret-shaped environment values with `printenv | grep`, `env | grep`, `echo "$API_KEY"`, or argv-equivalent diagnostics

## How to cite this charter

In a PR description:

```markdown
Complies with implementation charter v1.3.0. Ring: {0|1|2|3}. No cross-ring imports added.
```

In a policy objection:

```markdown
Blocked per charter invariant {N}: {quoted invariant}.
```

## Change policy

This charter is amendable. Amendments require:

1. An ADR under `docs/host-capability-substrate/adr/` justifying the change.
2. `hcs-policy-reviewer` and `hcs-security-reviewer` subagent objections filed and addressed. *(v1.1.0: include `hcs-ontology-reviewer` if the amendment touches ontology.)*
3. Human approval.
4. Version bump. Breaking changes bump the major.

Do not amend the charter in the same PR as the change the amendment enables. Charter changes are their own PR.

## References

- Research plan: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` (v0.3.0+)
- Boundary decision: [`adr/0001-repo-boundary.md`](./adr/0001-repo-boundary.md)
- Tooling surface matrix: [`tooling-surface-matrix.md`](./tooling-surface-matrix.md) (v1.0.0+)
- Target-repo templates: [`./templates/`](./templates/)
- Existing governance precedents: `~/Organizations/jefahnierocks/system-config/policies/version-policy.md`, `~/Organizations/jefahnierocks/system-config/policies/opa/policy.rego`

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.3.0 | 2026-05-02 | Added invariants 16 (external-control-plane evidence-first) and 17 (execution-context declared, not inferred) per ADR 0021. Invariants 18-20 remain queued behind Q-003, Q-007, and Q-008. Boundary enforcement and forbidden-pattern entries that operationalize invariants 16 and 17 are deferred to follow-up PRs once supporting schema and CI shape exists. |
| 1.2.0 | 2026-04-26 | Added invariants 13-15 from Phase 0b closeout: deletion authority is not gitignore state, config-spec claims require authority provenance, and GUI shell-env inheritance must not be assumed. Amended invariant 12 to use public CLI semver with app-build identifiers tracked separately. Extended boundary enforcement and forbidden patterns for cleanup authority, config booleans, GUI env assumptions, and secret-value env inspection. |
| 1.1.0 | 2026-04-22 | Added invariants 9–12 (skills canonical location, public/private deployment boundary, deprecated-syntax refusal, tool version baseline). Extended boundary enforcement with skills-location, runtime-state-not-in-repo, and no-secrets checks. Added forbidden patterns covering skill duplication, WARP.md, cross-surface policy duplication, `.windsurf/` creation, secret commits, and runtime-state commits. Added authoring requirements for `hcs-ontology-reviewer` on schema changes and `.agents/skills/` for skill changes. |
| 1.0.0 | 2026-04-22 | Initial charter. Four rings, eight non-negotiable invariants, CI boundary enforcement, authoring rules, forbidden patterns. |
