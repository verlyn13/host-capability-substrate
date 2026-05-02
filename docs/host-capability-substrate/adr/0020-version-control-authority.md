---
adr_number: 0020
title: Version control is a typed authority surface
status: accepted
date: 2026-05-01
charter_version: 1.2.0
tags: [github, git, version-control, source-control, evidence, rulesets, actions, credentials, phase-1]
---

# ADR 0020: Version control is a typed authority surface

## Status

accepted

## Date

2026-05-01

## Charter version

Written against charter v1.2.0.

## Context

Q-006 records that GitHub and local version control are not one authority
surface. The 2026-04-29 local investigation showed that this host has distinct
planes for SSH transport aliases, Git authorship/signing, `gh` keyring
sessions, GitHub MCP PAT/OAuth/Copilot auth, per-workspace env overrides, repo
settings/rulesets/Actions, check status sources, and local worktree/remote
state.

The 2026-05-01 version-control authority consult made the design pressure more
concrete:

- green check names are not gate evidence without expected source identity;
- `gh` login state is not GitHub MCP, SSH, Actions, GitHub App, OIDC, or
  web-agent authority;
- branch deletion needs proof, not "remote gone" or UI absence;
- Actions workflows are a separate authority surface with their own token,
  runner, trigger, and action-pinning posture;
- source-control continuity matters: branch/tag protection, actor identity,
  technical-control continuity, and provenance all have freshness and start
  points.

ADR 0015 already says external control planes are typed evidence surfaces. This
ADR specializes that rule for Git/GitHub/source-control authority. It does not
configure GitHub, create workflows, create CODEOWNERS, add policy tiers, or
enable mutation endpoints.

ADR number note: ADR 0019 is already reserved in Q-003 planning for the HCS
knowledge and coordination store, so this Q-006 ADR uses ADR 0020.

## Options considered

### Option A: Treat Git and GitHub as shell/CLI operations

**Pros:**
- Minimal new schema work.
- Matches normal developer muscle memory.
- Existing `git`, `gh`, and MCP tools can already perform most operations.

**Cons:**
- Violates the charter rule that shell strings are rendered outputs, not
  semantic operation authority.
- Lets broad human `gh` or PAT authority become ambient agent authority.
- Cannot safely distinguish read-only diagnostics from mutations such as push,
  ruleset edits, workflow edits, PR merge, or branch deletion.
- Repeats the ScopeCam failure family: remote-gone and command symptoms become
  cleanup authority without proof.

### Option B: Treat GitHub repository settings as the source of truth

**Pros:**
- Branch protection, rulesets, checks, CODEOWNERS, and Actions settings are
  important remote controls.
- Easy for humans to inspect in GitHub UI.
- Aligns with normal GitHub governance vocabulary.

**Cons:**
- GitHub settings do not describe local worktree state, leases, dirty state,
  effective Git config, SSH routing, signing identity, or MCP credential state.
- GitHub can show a check name as green while HCS still lacks expected source,
  workflow, runner, or commit binding.
- Personal-account constraints and admin bypass behavior can make a setting
  weaker than it appears.
- Repository settings are themselves external-control-plane observations with
  freshness and authority, not policy data inside HCS.

### Option C: Build a large GitHub/Git standalone ontology immediately

**Pros:**
- Gives every concept a first-class type from the start.
- Makes dashboard and policy wiring explicit.
- Could eventually support rich GitHub governance workflows.

**Cons:**
- Too large for Phase 1 before schema reconciliation.
- Risks duplicating ADR 0015 provider-control-plane concepts and Q-005 runner
  concepts.
- Forces premature entity boundaries before we know which facts become
  repeated policy inputs.
- Could distract from the immediate need: safe read-only evidence receipts and
  mutation blockers.

### Option D: Start with evidence subtypes and source-control continuity receipts

**Pros:**
- Fits ADR 0015: external control planes produce typed evidence before
  mutation.
- Lets HCS model local, remote, GitHub, Actions, MCP, credential, and worktree
  facts without committing to a large standalone ontology.
- Makes dashboard read-only posture possible before mutation endpoints.
- Gives policy/gateway work concrete receipts for check source identity,
  branch deletion proof, credential splits, and source-control continuity.

**Cons:**
- Some facts may later need promotion into first-class Ring 0 entities.
- Requires careful naming so GitHub evidence does not duplicate generic
  `Evidence`, `Run`, `Artifact`, `Lease`, `WorkspaceContext`, and
  `CredentialSource` concepts.
- Requires dashboard and policy work to tolerate missing, stale, or
  contradictory observations.

## Decision

HCS treats version control as a typed authority surface and
start with evidence subtypes / receipts rather than immediate GitHub-specific
core entities. Git, GitHub, GitHub Actions, GitHub MCP, `gh`, SSH, signing,
rulesets, branch protection, PR/review state, checks, and worktrees remain
separate observations until reconciled by Ring 1 services. Mutating operations
such as push, branch deletion, ruleset update, workflow update, PR merge, or
GitHub MCP mutation require typed `OperationShape` inputs and evidence IDs; raw
shell strings or ambient logged-in tools are not authority.

For the accepted limited posture, five names are the load-bearing minimum for Q-006
ordering and dashboard planning:

- `GitConfigResolution`
- `GitIdentityBinding`
- `BranchDeletionProof`
- `StatusCheckSourceObservation`
- `SourceControlContinuityReceipt`

The broader Phase 1 candidate inventory remains deferred to ontology review:

- `GitRepositoryObservation`
- `GitRemoteObservation`
- `GitWorktreeObservation`
- `GitRefObservation`
- `GitBranchAncestryObservation`
- `GitHubRepositorySettingsObservation`
- `GitHubRulesetObservation`
- `BranchProtectionObservation`
- `WorkflowPolicyObservation`
- `CheckRunReceipt`
- `GitHubCredentialObservation`
- `GitHubMcpSessionObservation`
- `PullRequestReceipt`
- `PullRequestReviewReceipt`

All names remain candidates until Q-006 follow-up and ontology review settle evidence
subtype, receipt, proof-composite, or standalone-entity shape. These may later
become standalone Ring 0 entities if ontology review shows that policy,
dashboard, and kernel code repeatedly depend on them.

## Consequences

### Accepts

- Q-006 schema work starts with evidence subtypes and receipts.
- ADR 0020 acceptance would not commit all listed receipt names as schemas; it
  commits only the version-control authority posture and the near-term review
  order.
- Required-check consumption needs check name, source app/integration, commit
  SHA, workflow path or provider object, observed time, and freshness.
- `BranchDeletionProof` is required before local or remote branch cleanup can
  become a rendered mutating operation.
- GitHub credential authority is split by source: `gh`, SSH transport,
  signing, GitHub App, Actions `GITHUB_TOKEN`, OIDC, MCP PAT/OAuth, Copilot or
  agent-app sessions, and web PR/autofix app identity.
- GitHub Actions posture is evidence: triggers, permissions, runner labels,
  action pinning, `pull_request_target`, environments, OIDC, and automation PR
  approval settings.
- Source-control continuity is evidence: protected named refs, branch/tag
  history, actor identity, control start revision, and control lapse/restart
  observations.
- The first dashboard work should be read-only: show repository identity,
  protection freshness, required checks with expected source, Actions posture,
  credentials split by surface, worktrees/leases, and cleanup proof state.

### Rejects

- Universal shell-based GitHub mutation.
- Treating `gh auth status`, SSH banner auth, MCP tool availability, or a green
  check name as sufficient authority for mutation.
- Treating remote-gone branch state, UI absence, or "merged somewhere" as
  branch deletion proof.
- Treating workflow YAML as policy source for HCS.
- Treating GitHub repo settings or rulesets as HCS live policy; live HCS policy
  remains canonical in `system-config`.
- Adding GitHub mutation endpoints before approval grants, audit, dashboard
  review, and leases exist.

### Future amendments

- Reopen if Q-005 decides runner/check evidence should own check-source and
  workflow-policy receipts instead of Q-006.
- Reopen if Q-003 coordination facts provide the authoritative lease/worktree
  ownership layer for branch cleanup.
- Reopen if GitHub MCP read/mutation split becomes a separate ADR or broker
  requirement.
- Reopen if the repo moves to organization-owned governance and new ruleset,
  security manager, bypass, or app-installation authority changes the baseline.
- Promote specific receipts to standalone entities only after ontology review
  and repeated policy/dashboard dependence.
- Reconcile the receipt inventory with the ontology promotion/dedupe plan
  before any Ring 0 schema changes.

## References

### Internal

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.2.0,
  invariants 1, 2, 5, 7, 8, 10, 13, 14, and 15
- Decision ledger: `DECISIONS.md` Q-006, Q-005, Q-008, Q-009
- ADR 0015:
  `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
- GitHub/version-control local investigation:
  `docs/host-capability-substrate/research/local/2026-04-29-github-version-control-agentic-surface.md`
- Version-control authority consult synthesis:
  `docs/host-capability-substrate/research/local/2026-05-01-version-control-authority-consult-synthesis.md`
- Version-control authority source note:
  `docs/host-capability-substrate/research/external/2026-05-01-version-control-authority-consult.md`
- Ontology promotion/dedupe plan:
  `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md`
- Codex/ScopeCam execution-reality synthesis:
  `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`
- Regression corpus: `packages/evals/regression/seed.md` #35, #39-#44
- Research plan:
  `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`

### External

- Git `git-branch` documentation:
  <https://git-scm.com/docs/git-branch>
- GitHub protected branches:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>
- GitHub rulesets:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>
- GitHub CODEOWNERS:
  <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners>
- GitHub personal access tokens:
  <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens>
- GitHub Actions workflow syntax:
  <https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax>
- GitHub Actions secure use:
  <https://docs.github.com/en/actions/reference/security/secure-use>
- SLSA Source requirements v1.2:
  <https://slsa.dev/spec/v1.2/source-requirements>
