---
title: Version-Control Authority Consult Source Note
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-05-01
tags: [research, external, github, git, slsa, version-control, branch-protection, actions, rulesets, credentials]
priority: high
---

# Version-Control Authority Consult Source Note

This source note preserves the substance of a user-submitted inline consult
report received on 2026-05-01. The original report was delivered in chat rather
than as a durable file, so this note records the normalized source context and
primary-source links instead of claiming byte-for-byte source preservation.

## Scope

The consult evaluated HCS version-control posture against the repo's existing
materials and current public GitHub/Git/SLSA documentation. It explicitly was
not a live audit of `verlyn13/host-capability-substrate` repository settings.

Core bottom line from the consult:

```text
HCS should treat version control as an authority surface, not merely as Git
commands or GitHub settings: protected source, typed evidence, no ambient
mutation, no credential conflation, and no destructive Git cleanup without
proof.
```

## Primary Sources Checked During Intake

The HCS intake checked the following primary sources on 2026-05-01 before
writing the local synthesis:

- Git `git-branch` documentation:
  <https://git-scm.com/docs/git-branch>
- GitHub ruleset available rules:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets>
- GitHub rulesets overview:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>
- GitHub protected branches:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>
- GitHub CODEOWNERS:
  <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners>
- GitHub personal access tokens:
  <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens>
- GitHub MCP Server setup:
  <https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp-in-your-ide/set-up-the-github-mcp-server>
- GitHub push protection:
  <https://docs.github.com/en/code-security/concepts/secret-security/about-push-protection>
- GitHub Actions workflow syntax:
  <https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax>
- GitHub Actions secure use:
  <https://docs.github.com/en/actions/reference/security/secure-use>
- GitHub merge queue:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue>
- SLSA Source requirements v1.2:
  <https://slsa.dev/spec/v1.2/source-requirements>

## Consult Value Preserved

The consult strengthens Q-006 with these concrete planning inputs:

- GitHub/Git facts should start as `Evidence` subtypes or receipts before HCS
  promotes any to standalone Ring 0 entities.
- Required check consumption must include source/app identity, not just check
  name and conclusion.
- Branch cleanup needs a typed `BranchDeletionProof` with worktree attachment,
  fresh remote state, ancestry or patch-equivalence proof, PR state, dirty state,
  lease state, and human-review requirements for ambiguous or forceful cases.
- Human `gh`, SSH transport, GitHub App installation tokens, Actions
  `GITHUB_TOKEN`, OIDC-issued credentials, GitHub MCP PAT/OAuth, and agent
  PR/autofix app identities are separate credential/authority surfaces.
- GitHub Actions are a separate authority surface. Workflow permissions, runner
  labels, third-party action pinning, `pull_request_target`, automation PR
  approval, OIDC, and required-check source identity all need observation.
- Rulesets can provide layered governance where available; branch protection is
  still relevant but cannot be treated as a complete source-control model by
  itself.
- SLSA Source reinforces the need for source-control continuity evidence:
  reliable branch history, controlled named references, protected tags, actor
  identity, contemporaneous provenance, and continuity after controls change.

## What Is Not Accepted

This source note does not accept or perform any GitHub mutation:

- no ruleset or branch-protection change;
- no CODEOWNERS change;
- no workflow addition;
- no required-check configuration;
- no credential or MCP configuration change;
- no branch deletion or cleanup;
- no policy-tier entry.

All implementation remains gated by Q-006, Q-005, Q-008, Q-009, and the
four-ring charter.

## Change Log

| Version | Date | Change |
|---|---:|---|
| 1.0.0 | 2026-05-01 | Initial normalized source note for the inline version-control authority consult. |
