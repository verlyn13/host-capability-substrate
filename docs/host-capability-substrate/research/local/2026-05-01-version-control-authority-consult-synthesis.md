---
title: Version-Control Authority Consult Synthesis
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-05-01
tags: [research, synthesis, github, git, slsa, version-control, branch-protection, actions, rulesets, credentials, evidence]
priority: high
---

# Version-Control Authority Consult Synthesis

Source note:
`docs/host-capability-substrate/research/external/2026-05-01-version-control-authority-consult.md`

## Status

This is a Q-006-focused synthesis of a user-submitted version-control authority
consult. It is planning evidence, not a live audit and not a GitHub mutation
plan. It refines HCS goals and schema vocabulary while preserving the repo's
existing four-ring discipline.

No repo settings, GitHub settings, workflows, CODEOWNERS entries, branch
protections, rulesets, credentials, policy tiers, hooks, adapters, or runtime
state changed from this intake.

## Core Lesson

The consult aligns strongly with the existing Q-006 posture:

```text
Version control is an authority surface. It is not just Git commands, GitHub
settings, `gh` auth, MCP tool availability, or CI status names.
```

HCS should model source-control authority through typed, freshness-bound
evidence that binds:

- local repository and worktree state;
- remote identity and ref state;
- branch/ruleset protection;
- check-run source identity;
- workflow permissions and runner class;
- Git authorship/signing/SSH routing;
- `gh`, MCP, GitHub App, Actions, OIDC, and agent-app credentials;
- PR/review/merge provenance;
- branch deletion and cleanup proof.

## Relationship To Existing Work

### Q-006: GitHub/version-control authority

The consult strengthens Q-006 and makes it more concrete. The existing local
investigation already proved that GitHub on this host spans SSH aliases,
authorship/signing config, `gh` keyring sessions, GitHub MCP PAT/OAuth/Copilot
auth, per-workspace env overrides, repo settings/rulesets/Actions, check status
sources, and local worktree/remote state. This consult adds source-control
continuity and expected-source requirements as explicit design inputs.

### Q-005: CI runner/check evidence

Actions and required checks should be shared vocabulary between Q-005 and Q-006.
HCS should not consume a green check name as gate evidence unless it knows the
expected source app/integration, commit SHA, workflow path, runner class, and
freshness.

### Q-008: destructive Git hygiene

The consult reinforces that branch deletion is a typed mutating operation.
Remote-gone, UI-invisible, or apparently merged is not enough. `BranchDeletionProof`
belongs in Q-008/Q-006 reconciliation before branch cleanup becomes ordinary.

### Q-009: diagnostic surfaces

The suggested dashboard view fits Q-009: expose Git/GitHub posture as typed
diagnostics before a mutation lane exists.

## High-Value Intake

### 1. Evidence Subtypes First

Do not build a large standalone GitHub ontology immediately. Start with
`Evidence` subtypes and receipts that can later be promoted if policy depends on
them repeatedly.

Candidate receipts:

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

### 2. Required Checks Need Source Identity

A check name and green conclusion are not enough. HCS needs the commit SHA,
check name, app/source identity, workflow path or provider object, conclusion,
observed time, and freshness. Required-check decisions should consume
`StatusCheckSourceObservation` or a similar receipt.

### 3. Branch Deletion Needs Proof

Minimum `BranchDeletionProof` inputs:

- repository identity: path, remote URL, HEAD SHA, observed time;
- worktree attachment: no worktree has the branch checked out;
- fresh remote state: fetch/prune receipt or remote-ref observation;
- ancestry or equivalence: target base contains branch tip, or patch-equivalence
  / zero-diff proof;
- dirty state: working tree and index checked for the affected worktree;
- PR state: merged, closed, or explicitly abandoned;
- lease state: no active human/agent lease or coordination fact;
- review: required for force delete, remote delete, protected/default/release
  branch, or ambiguous proof.

This complements existing trap #41 and should not be implemented as a raw
script before the schema and policy contract exists.

### 4. Credentials Must Stay Split

The consult sharpens the `CredentialSource` model for GitHub:

- human interactive `gh`;
- SSH transport identity;
- Git authorship/signing identity;
- GitHub App installation token;
- Actions `GITHUB_TOKEN`;
- OIDC-issued external token;
- GitHub MCP PAT;
- GitHub MCP OAuth;
- Copilot/GitHub app session;
- Claude/Codex web PR/autofix app identity.

An operation must identify which authority surface is used. A working `gh` probe
does not prove MCP authority, SSH authority, Actions authority, or app/autofix
authority.

### 5. Actions Is A Separate Authority Surface

Candidate `WorkflowPolicyObservation` fields:

- workflow path and triggers;
- top-level and job-level permissions;
- use of `pull_request_target`;
- third-party action pinning mode;
- runner labels and hosted/self-hosted class;
- environment protection and secret usage;
- OIDC use;
- automation PR creation/approval settings;
- check names and expected sources.

This should feed Q-005 runner compatibility and Q-006 GitHub authority.

### 6. Source-Control Continuity Matters

SLSA Source vocabulary maps cleanly to HCS:

- source repository identity;
- source revision identity;
- named references such as branches and tags;
- protected named references;
- branch history continuity;
- actor identity;
- technical-control continuity;
- contemporaneous provenance.

HCS does not need to claim a SLSA source level now. It should borrow the
continuity model: once a control is introduced, HCS should know the start
revision for the claim and should reset or downgrade the claim if the control is
disabled or bypassed.

## Candidate Operation Shapes

These names are planning vocabulary only:

```text
scm.pull_request.create.v1
scm.pull_request.update_body.v1
scm.branch.delete_local.v1
scm.branch.delete_remote.v1
scm.branch.force_update.v1
scm.remote.push.v1
github.ruleset.update.v1
github.workflow.update.v1
github.check.consume.v1
github.mcp.call.v1
```

Each operation should carry repository identity, workspace identity, execution
context, principal, credential source, target ref, expected remote, and evidence
IDs used for the decision.

## Policy Candidate Queue

Do not add tier entries until Q-006 and policy review.

Likely forbidden/non-escalable candidates:

- universal shell-based GitHub mutation;
- force-push to `main`, release, or protected branches;
- delete protected/default/release branches;
- default `GITHUB_TOKEN: write-all`;
- public/untrusted PR code on a MacBook self-hosted runner;
- green-check-name-only gate consumption;
- conflating GitHub MCP PAT/OAuth authority with `gh` CLI authority;
- token/scopes/secrets in process/env diagnostics.

Likely approval-required candidates:

- add/remove/relax branch protection or rulesets;
- add bypass actors;
- change required checks or expected check source;
- add GitHub MCP mutation toolsets;
- widen PAT scopes;
- enable web PR/autofix automation for Claude/Codex/Copilot-style agents;
- delete local or remote branches after complete `BranchDeletionProof`.

Likely read-only candidates:

- observe repo settings, rulesets, branch protection, check source metadata;
- resolve Git config, remotes, worktrees, current ref;
- read PR state, check runs, workflow runs, branch ancestry;
- produce non-mutating cleanup plans.

## Dashboard Expectations

A first version-control posture view should be read-only and should show:

- repository identity and default branch;
- protection evidence freshness;
- active rulesets and branch-protection state;
- required checks with expected source and last observed SHA;
- CODEOWNERS coverage for sensitive paths and CODEOWNERS self-protection;
- Actions posture: token permissions, pinned actions, runner labels,
  `pull_request_target`, OIDC, environments;
- secret posture where observable;
- credential surfaces separated: `gh`, SSH, MCP, GitHub App, Actions, OIDC,
  web/agent app sessions;
- worktrees, attached branches, locks, leases;
- cleanup proposals with proof status.

## Regression Trap Candidates

Queue as candidates only. Some overlap existing seeds and should be reconciled
before adding rows.

- `check-source-spoofing`: agent trusts a green check name without expected
  GitHub App/source identity.
- `github-mcp-gh-credential-conflation`: agent treats GitHub MCP auth as the
  same authority as `gh` CLI auth.
- `actions-write-all-default`: agent adds or tolerates default broad workflow
  token write permissions.
- `ruleset-bypass-as-normal-path`: agent treats admin/bypass path as ordinary
  merge authority.
- `branch-deletion-without-source-continuity`: agent deletes a branch without
  ancestry/equivalence, worktree, PR, lease, and remote freshness evidence.

Trap #35 already covers auth-surface conflation. Trap #41 already covers
remote-gone branch deletion without proof. Prefer extending or specializing
those before adding duplicate trap rows.

## Planning Recommendation

Update Q-006 to explicitly include:

1. evidence-subtype-first posture for Git/GitHub facts;
2. source-control continuity as a first-class source-authority concept;
3. expected-source identity for check consumption;
4. typed `BranchDeletionProof`;
5. split GitHub credential authority surfaces;
6. Actions workflow posture as separate evidence;
7. dashboard-visible read-only source-control posture before mutation.

Do not perform GitHub hardening mutations from this consult. Those belong after
the evidence model, policy tier review, dashboard view, approval grants, audit,
and leases are in place, or through a separate human-directed GitHub governance
task outside HCS mutation lanes.

## Change Log

| Version | Date | Change |
|---|---:|---|
| 1.0.0 | 2026-05-01 | Initial synthesis of the inline version-control authority consult. |
