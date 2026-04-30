---
title: GitHub and Version-Control Agentic Surface Investigation
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-29
tags: [phase-1, github, git, ssh, mcp, gh-cli, actions, rulesets, credential-source, version-control, agentic]
priority: high
---

# GitHub and Version-Control Agentic Surface Investigation

First deeper intake after the shallow GitHub settings survey. This report is
Ring 3 planning evidence for HCS design. It does not change policy, schemas,
repo settings, GitHub settings, SSH keys, 1Password items, or MCP config.

## Scope and Safety

Observed at: `2026-04-29T21:46:09Z`.

Target ring: Ring 3, docs/research only.

Related decisions:

- ADR 0001: HCS repository boundary.
- ADR 0012: credential broker.
- ADR 0015: external control planes are typed evidence surfaces.
- DECISIONS Q-005: CI runner compatibility boundary and evidence model.
- This report queues DECISIONS Q-006: GitHub/version-control authority model.

Safety posture:

- No `op://` reference was resolved.
- No private key contents were read.
- No GitHub token values were requested.
- GitHub secret and variable checks were names-only.
- `gh auth status` can print masked token prefixes; this report intentionally
  does not preserve token-shaped substrings from that output.
- Process argv was not inspected because current MCP wrapper design can expose
  bearer tokens in argv.

## Executive Conclusion

GitHub is not one substrate surface. On this host it is at least seven distinct
authority planes that can disagree:

1. Git transport identity: SSH host aliases, `IdentityFile`, `IdentityAgent`,
   and remote URL shape.
2. Git authorship and signing identity: `user.email`, `user.signingkey`,
   `allowed_signers`, and the 1Password SSH signer.
3. `gh` CLI identity: five keyring accounts, one active account, broad token
   scopes, and `gh auth git-credential` helpers.
4. GitHub MCP identity: PAT-backed stdio wrappers, Codex bearer env auth,
   Windsurf OAuth, Copilot built-in auth, and tree-local overrides.
5. Repo governance: visibility, default branch, merge settings, branch
   protection, rulesets, PR review/check/signature requirements.
6. Actions/checks: workflow permissions, allowed actions, runners, secrets,
   variables, status check source identity.
7. Local workspace state: dirty worktrees, ahead/behind status, path-based
   conditional Git includes, and local remotes that may not match their intended
   identity.

HCS should not collapse these into "GitHub auth" or "the current Git user."
Every agentic GitHub operation needs a typed binding across principal,
workspace, execution context, credential source, local Git state, remote repo,
and intended control-plane surface.

## Evidence Summary

### Account and CLI State

| Surface | Observation |
|---|---|
| `gh` accounts | Five accounts are present in the keyring. `verlyn13` is active. |
| `gh` protocol | `git_protocol=ssh`. |
| Active `gh` token authority | Active account has broad scopes including repo, org/admin, key-admin, user, gist, project, and delete-repo authority. |
| Secondary `gh` accounts | `hubofwyn`, `jjohnson-47`, `happy-patterns`, and `hubofaxel` are present but inactive. One fine-grained token status line did not print scope details. |
| Credential helper | `~/.gitconfig` installs `gh auth git-credential` for `https://github.com` and `https://gist.github.com`. |

Design read: `gh` is a powerful human-interactive control plane. It should not
be treated as a safe ambient tool for agents just because it is locally logged
in. Endpoint, repo, account, and mutation class must be explicit evidence.

### Git Config and Signing

| Surface | Observation |
|---|---|
| Loaded global configs | Git loads both `~/.config/git/config` and `~/.gitconfig` as global config. |
| Effective later file | `~/.gitconfig` appears after XDG config and overrides many defaults. |
| Config drift | The two files disagree on editor, pager, pull rebase, push default, excludes file, aliases, merge/diff tools, and directory includes. |
| Provenance | No chezmoi-managed `dot_gitconfig` source was found under `system-config/home/`; `~/.gitconfig` appears user-local or managed outside the visible chezmoi tree. |
| Signing | `gpg.format=ssh`, `commit.gpgsign=true`, `gpg.ssh.program=/Applications/1Password.app/Contents/MacOS/op-ssh-sign`, and `user.signingkey=/Users/verlyn13/.ssh/id_ed25519_personal.1password.pub`. |
| Current repo signature | Latest local HCS commit verifies with a good SSH signature. At investigation time, local `main` was already one commit ahead of `origin/main`. |
| `system-config` signature | Latest `system-config` commit verifies with a good SSH signature. Its worktree had one pre-existing modified file unrelated to this report. |

Design read: Git config itself is an evidence surface with precedence, not a
single file. HCS needs an observed `GitConfigResolution` or equivalent, with
source paths and override order, before it can claim a repo is using a given
identity or signing posture.

### SSH Identity and Allowed Signers

| Surface | Observation |
|---|---|
| 1Password SSH agent | The 1Password agent socket exists, and `ssh -G` resolves GitHub aliases through that `IdentityAgent`. `ssh-add -l` was blocked in sandbox with `Operation not permitted`, so loaded-key inventory was not proven. |
| GitHub aliases | `github.com`, `github.com-personal`, and `github.com-happy-patterns` use 1Password-backed public-key `IdentityFile` paths. |
| On-disk GitHub alias keys | `github.com-work`, `github.com-business`, `github.com-hubofaxel`, `github.com-hubofwyn`, and `github.com-nash-group` still use on-disk private-key paths. |
| Broader private-key inventory | `~/.ssh` contains many private-key-shaped files beyond the five GitHub aliases. This report did not inspect contents. |
| Allowed signers | `~/.ssh/allowed_signers` has 7 lines, but only 4 non-comment signer records. The shallow report's "7 entries" should be corrected to "4 signer records plus 3 header/comment lines." |
| Chezmoi state | `.chezmoidata.yaml` has `ssh.host_migrations` for `github_personal`, `github_happy_patterns`, and `runpod_inference`, but not for work/business/hubofaxel/hubofwyn/nash-group GitHub aliases. |

Design read: on-disk key presence, SSH alias selection, signing key, and GitHub
account identity are separate facts. HCS should model them separately and never
infer one from another.

### MCP and GitHub Remote Tooling

| Surface | Observation |
|---|---|
| Cursor config | Contrary to the shallow report, `~/.cursor/mcp.json` now exists. It has `mcpServers.github` as a stdio wrapper and 10 managed servers total. |
| Sync dry-run | `scripts/sync-mcp.sh --dry-run` reports Claude Code, Claude Desktop, Cursor, and Windsurf would receive 10 global servers; Copilot would receive 9; Codex would replace the managed TOML block. |
| Claude Code | `~/.claude.json` has GitHub as `type=stdio`, command `~/.local/bin/mcp-github-server`. |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` has GitHub as a command-only stdio wrapper and preserves app-managed `globalShortcut` / `preferences`. |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` uses native `serverUrl=https://api.githubcopilot.com/mcp/`. |
| Codex | `~/.codex/config.toml` uses native remote HTTP, `bearer_token_env_var="GITHUB_PAT"`, and the 17-toolset `X-MCP-Toolsets` header. It also has a hand-added GitHub tool subtable outside the managed block. |
| Copilot | `~/.copilot/mcp-config.json` exists with 9 managed servers and no GitHub entry; Copilot uses its built-in GitHub MCP. |
| Secret split | `op://Dev/github-dev-tools/token` serves general `gh` CLI/dev tooling, while `op://Dev/github-mcp/token` serves GitHub MCP. The happy-patterns tree overrides `GITHUB_PAT`, `GH_TOKEN`, `GITHUB_TOKEN`, and `GITHUB_PERSONAL_ACCESS_TOKEN` from `op://Dev/github-happy-patterns/token`. |
| Toolset source | The curated GitHub MCP toolset list is duplicated in `scripts/sync-mcp.sh` and `home/dot_local/bin/executable_mcp-github-server.tmpl`. |
| Stale comments | `scripts/mcp-servers.json` says GitHub MCP is rendered as a stdio wrapper for Windsurf, but live sync renders Windsurf native OAuth. The GitHub wrapper says it exists only for Cursor and that Claude Code uses native remote config, but live config uses the wrapper for Claude Code and Claude Desktop too. |
| Argv exposure | The GitHub wrapper executes `mcp-remote` with `--header "Authorization: Bearer ${GITHUB_PAT}"`. Per the existing 2026-04-23 Claude Desktop field report, this puts the bearer in child process argv for the lifetime of the MCP session. |

Design read: GitHub MCP is already an external control-plane surface under ADR
0015. Toolset headers and PAT scopes are not sufficient policy boundaries for
agentic mutation. The broker/proxy work from ADR 0012 should remove bearer
tokens from argv and env crossings.

### Remote Repo Governance Checked Via GitHub API

Checked repositories: `verlyn13/host-capability-substrate` and
`verlyn13/system-config`.

| Setting | HCS | system-config |
|---|---|---|
| Visibility | Public | Public |
| Default branch | `main` | `main` |
| Viewer permission | Admin | Admin |
| Merge methods | Merge, squash, and rebase all allowed | Merge, squash, and rebase all allowed |
| Viewer default merge method | Merge commit | Merge commit |
| Delete branch on merge | Disabled | Disabled |
| Security policy | Disabled | Disabled |
| Rulesets | None | None |
| Branch protection | Present on `main` | Absent on `main` |
| HCS `main` protection details | Linear history required; force pushes and deletions disallowed; admin enforcement disabled; no required signatures; no required status checks; no required reviews; no required conversation resolution | N/A |
| Actions enabled | Yes | Yes |
| Allowed actions | All | All |
| Default workflow token permissions | Read | Read |
| Repo Actions secrets | 0 | 0 |
| Repo Actions variables | 0 | 0 |
| Environments | 0 | 0 |
| Repo self-hosted runners | 0 | 0 |
| Local workflows | No `.github/workflows` in HCS | One hosted `ubuntu-latest` validation workflow |

Design read: HCS has local verification rules, but GitHub does not yet enforce
the same definition of done. Required signed commits, required checks, PR review
requirements, and conversation resolution are not currently GitHub gates for
HCS. `system-config`, which owns live host config and policy-adjacent material,
has no branch protection on `main`.

### Broader GitHub Estate and Local Remotes

`gh repo list verlyn13 --limit 200` returned 109 repositories:

| Metric | Count |
|---|---:|
| Public | 61 |
| Private | 48 |
| Archived | 22 |
| Forks | 13 |
| Empty/default-branch missing | 6 |
| Default branch `main` | 94 |
| Default branch `master` | 7 |
| Default branch `develop` | 1 |
| Default branch `bleed` | 1 |

Local Git roots under `~/Organizations`, `~/Repos`, and `~/ai` resolved to 85
origin remotes. Host alias counts:

| Remote host alias | Count |
|---|---:|
| `github.com` | 63 |
| `github-work` | 7 |
| `github.com-nash-group` | 6 |
| `github.com-hubofwyn` | 4 |
| `github.com-work` | 2 |
| `github.com-hubofaxel` | 2 |
| `github.com-happy-patterns` | 1 |

Notable local remote drift:

- `github-work` appears in seven remotes but no matching SSH host alias was
  found in `~/.ssh/config` or `~/.ssh/conf.d/`. The managed alias is
  `github.com-work`.
- Several org-specific repos use `git@github.com:` rather than a role-specific
  alias, including some `happy-patterns-org`, `The-Nash-Group`, and `jjohnson-47`
  paths.
- `~/Organizations/the-nash-group/` Git config include selects the business
  signing identity, while most sibling remotes authenticate through
  `github.com-nash-group`.
- `~/Repos/happy-patterns-org/` uses the business include, but that include does
  not install a URL rewrite to `github.com-happy-patterns`; the separate
  `~/.gitconfig-happy-patterns` rewrite only applies under
  `~/Organizations/happy-patterns/`.

Design read: local path, remote owner, SSH host alias, Git author/signing
identity, and `gh`/MCP identity are not currently guaranteed to line up. HCS
needs an explicit identity resolution surface before letting agents push,
create PRs, edit repo settings, or make control-plane claims.

## Issues and Risks

### 1. Ambient GitHub authority is too broad for default agent use

The active `gh` account has broad human-level authority, including destructive
repo authority. Agents can often reach `gh` from the shell. HCS must not equate
"`gh` is logged in" with "operation is allowed."

Planning implication: GitHub CLI operations need typed classification by
endpoint, repo, principal, credential source, and mutation scope. Generic
`gh api` is equivalent to a provider-specific universal control-plane tool and
needs strict policy treatment.

### 2. GitHub MCP currently exposes bearer material through child argv

The wrapper's `mcp-remote --header "Authorization: Bearer ..."` pattern leaks
the bearer to same-user process inspection. This is already captured in the
2026-04-23 Claude Desktop report, but GitHub should be explicitly carried into
the Git/version-control model because agents are likely to inspect process
state while debugging MCP.

Planning implication: brokered MCP proxying should be a concrete ADR 0012
acceptance item. Until then, any process-inspection operation must redact argv
before transcript persistence and should default to pid/name-only fields.

### 3. GitHub MCP has write-capable repository and Actions scope

The documented fine-grained PAT grants write access to contents, issues, pull
requests, Actions, workflows, discussions, code scanning alerts, and security
advisories for target repos, plus org/project/admin read surfaces. The curated
toolset header reduces exposed tool categories but is not a complete policy
boundary.

Planning implication: split read-only GitHub MCP from mutating GitHub MCP, or
make mutation through GitHub MCP require a gateway decision. Treat toolset
selection as exposure reduction, not authorization.

### 4. Identity planes are conflated by environment variables

The happy-patterns override is elegant but proves the deeper point:
`GITHUB_PAT`, `GH_TOKEN`, `GITHUB_TOKEN`, and `GITHUB_PERSONAL_ACCESS_TOKEN`
can all be rebound by workspace. Codex picks up `GITHUB_PAT`; wrappers honor
it; `gh` may use keyring state or env depending on invocation; Git SSH uses a
different identity channel.

Planning implication: model `CredentialSource` and `ExecutionContext` together.
An operation must say whether it is using `gh` keyring, env PAT, MCP wrapper
PAT, Windsurf OAuth, Copilot built-in auth, SSH key auth, or GitHub App/OIDC.

### 5. Git config provenance is split and unmanaged

Two global Git configs are loaded. One appears stale and contains older
`~/Development/...` includes; the other contains current signing, URL rewrites,
and conditional includes. No source template was found under visible chezmoi
state.

Planning implication: either bring the effective Git config under `system-config`
or explicitly label it user-local. HCS should record the observed global config
chain with origins, not just the final value.

### 6. Local remote aliases contain drift and likely broken entries

Seven local remotes use `github-work`, but the configured SSH alias is
`github.com-work`. Some org repos use `github.com` instead of their intended
role alias. Some directory include rules set one signing identity while the
remote uses a different SSH identity.

Planning implication: add a Git remote identity audit before any agentic
multi-repo work. A repo-local `WorkspaceContext` should include expected GitHub
owner, expected SSH alias, expected signing principal, and expected mutation
credential.

### 7. SSH key migration is mixed-state

Two GitHub identities use 1Password-backed public-key paths. Five GitHub
aliases still use on-disk private keys, and there are many non-GitHub
private-key-shaped files in `~/.ssh`.

Planning implication: finish the migration or document retention reasons per
identity. For HCS, on-disk private-key presence is evidence that the host has a
high-risk ambient credential surface even when the active repo uses a 1Password
key.

### 8. Allowed-signers counts are easy to overclaim

The shallow report said "7 entries"; the file has 7 lines but 4 signer records.

Planning implication: evidence parsers must count records semantically, not
lines. This is the same authority-class problem as "gitignore is deletion
authority": convenient file facts are not necessarily operational facts.

### 9. MCP source-of-truth drift already exists

The GitHub toolset list is duplicated in two code paths. Comments in
`scripts/mcp-servers.json` and the deployed GitHub wrapper disagree with the
current sync behavior.

Planning implication: move shared GitHub MCP constants into one source, then
generate wrapper and sync config from it. Comments that describe auth shape need
the same provenance/freshness treatment as executable config.

### 10. GitHub repo governance does not yet match HCS definition of done

HCS has no GitHub workflow, no PR template, no required status checks, no
required signatures, no required reviews, and no rulesets. `system-config` has
no branch protection on `main`. HCS `main` requires linear history but still has
merge commit as the viewer default merge method and all merge methods enabled.

Planning implication: before agentic push/merge workflows become normal, decide
the GitHub-side gate baseline for HCS and `system-config`. GitHub should enforce
at least the gates HCS relies on for source authority, or HCS must clearly mark
GitHub state as advisory.

### 11. Actions is permissive enough to matter later

Both checked repos allow all Actions, default workflow token permission is read,
and there are no repo secrets, variables, environments, or self-hosted runners.
That is acceptable now, but it becomes dangerous when workflows, environments,
or self-hosted runners are introduced without a ruleset/runner policy.

Planning implication: Q-005 runner design and Q-006 GitHub governance should
share `WorkflowPolicyObservation`, `CheckRunReceipt`, and `StatusSource`
concepts. Required checks must include source identity, not just check name.

### 12. Local and remote repo state diverge

At investigation time, HCS local `main` was already ahead of `origin/main`, and
`system-config` had an unrelated modified file. The remote GitHub API state is
not the same thing as local worktree state.

Planning implication: HCS should model `WorktreeStateObservation` and
`RemoteRefObservation` separately. Agents should not infer release/merge state
from either one alone.

## Ring 0 / Evidence Candidates

Do not implement these from this report alone. Reconcile during Phase 1 schema
work after Q-006.

Candidate entities or `Evidence` subtypes:

- `GitRepositoryObservation`
- `GitRemoteObservation`
- `GitConfigResolution`
- `GitIdentityBinding`
- `CommitSignatureEvidence`
- `AllowedSignerObservation`
- `SshIdentityObservation`
- `GitHubAuthSessionObservation`
- `GitHubCredentialSource`
- `GitHubMcpSurfaceObservation`
- `GitHubRepoSettingsObservation`
- `BranchProtectionObservation`
- `RulesetObservation`
- `WorkflowPolicyObservation`
- `CheckRunReceipt`
- `StatusSourceObservation`
- `ActionsRunnerObservation`
- `WorktreeStateObservation`
- `RemoteRefObservation`

Candidate relationship:

```text
WorkspaceContext
  -> GitRepositoryObservation
  -> GitRemoteObservation
  -> GitIdentityBinding
       auth: SshIdentityObservation | GitHubCredentialSource
       signing: CommitSignatureEvidence | AllowedSignerObservation
       control_plane: gh | mcp | web | actions | app | oidc
  -> GitHubRepoSettingsObservation
  -> BranchProtectionObservation / RulesetObservation
  -> WorkflowPolicyObservation / CheckRunReceipt
```

## Policy Candidates

Do not add tier entries until policy review.

- `gh api` mutating calls require explicit provider operation shape; generic
  shell-rendered endpoint mutation should be denied.
- GitHub settings writes require repo target, intended owner, account identity,
  preflight read, preview diff, and rollback plan.
- GitHub MCP mutating tools require gateway review when target repo is public,
  policy/system config, or external-control-plane adjacent.
- Git pushes require clean identity binding: repo owner, remote alias, signing
  principal, and branch target must be consistent with workspace policy.
- Required-check decisions must include check source identity and freshness, not
  just a green name.
- Process inspection defaults to pid/name-only; argv capture requires redaction
  and separate justification.
- Public fork code never runs on self-hosted runners.
- Personal workstation SSH identities never become unattended machine
  identities.

## Near-Term Remediation Queue

1. Correct the stale GitHub MCP comments in `scripts/mcp-servers.json` and
   `~/.local/bin/mcp-github-server` template.
2. Move the GitHub MCP toolset list to one source, likely a chezmoi data value
   or generated MCP manifest consumed by both sync and wrapper rendering.
3. Decide whether `~/.gitconfig` and the include files become chezmoi-managed
   or explicitly user-local. Remove or reconcile stale XDG global Git config.
4. Run a focused local remote audit to fix `github-work` versus
   `github.com-work` and org repos that use `github.com` where a role alias is
   expected.
5. Finish 1Password SSH migration for work/business/hubofaxel/hubofwyn/nash
   identities, or document retention reasons in `.chezmoidata.yaml`.
6. Decide the GitHub ruleset/branch-protection baseline for HCS and
   `system-config`: signed commits, required checks, PR reviews, conversation
   resolution, admin enforcement, allowed merge methods, and branch deletion.
7. Add HCS GitHub workflow and PR template only after the desired gate model is
   chosen; do not let GitHub YAML become a second source of substrate policy.
8. Split GitHub MCP read and mutation authority, or require HCS gateway review
   for mutating GitHub MCP calls.
9. Treat `gh auth status` output itself as potentially credential-shaped. Any
   future diagnostics that persist CLI output need token-prefix redaction.

## Open Questions For Q-006

1. Should HCS and `system-config` get an immediate GitHub ruleset baseline, or
   should rulesets wait for Citadel/OpenTofu ownership?
2. Should agentic GitHub mutations use GitHub Apps/OIDC wherever possible,
   leaving human PATs and `gh` keyring sessions as interactive-only?
3. Should the GitHub MCP integration be split into read-only and mutating
   toolsets with separate credentials?
4. What is the intended identity mapping for `The-Nash-Group`,
   `happy-patterns-org`, `jjohnson-47`, `hubofwyn`, and `hubofaxel` local
   worktrees?
5. Should HCS model GitHub checks/statuses as gateable only when the expected
   GitHub App or workflow source matches?
6. Should GitHub repo settings/rulesets be read-only evidence for HCS while
   Citadel owns desired state, or should HCS have its own local-only planning
   model for repo governance?

## Commands Used

Representative commands, all value-safe:

```bash
scripts/sync-mcp.sh --dry-run
gh auth status
gh config list
gh repo view verlyn13/host-capability-substrate --json ...
gh repo view verlyn13/system-config --json ...
gh api repos/verlyn13/host-capability-substrate/rulesets --jq ...
gh api repos/verlyn13/host-capability-substrate/branches/main/protection --jq ...
gh api repos/verlyn13/host-capability-substrate/actions/permissions --jq ...
gh api repos/verlyn13/host-capability-substrate/actions/secrets --jq '{total_count,names:[.secrets[].name]}'
gh repo list verlyn13 --limit 200 --json ...
git config --show-origin --get-regexp ...
git log --show-signature -1
ssh -G github.com-work
find ~/.ssh -maxdepth 1 -type f -name 'id_*'
```

Redaction note: the persisted report excludes token-shaped substrings, raw
secret values, private key material, and raw process argv.

## Change Log

| Version | Date | Change |
|---|---:|---|
| 1.0.0 | 2026-04-29 | Initial local GitHub/version-control agentic surface investigation. |
