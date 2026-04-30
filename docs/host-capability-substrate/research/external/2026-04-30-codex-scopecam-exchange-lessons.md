# Lessons from the Codex / ScopeCam Exchange

Source: user-submitted evidence report, delivered to HCS on 2026-04-30.

Status: external evidence. This report is preserved as input to HCS design and
planning. It is not first-party HCS decision authority. The original ScopeCam
transcript/log bundle is not stored in this repository.

## Executive summary

According to the April 30, 2026 evidence report, the central lesson is that the
agent repeatedly converted tool symptoms into environment explanations before
proving the environment state. The audit later corrected that: this was not just
a Git problem, not just a network problem, and not just a 1Password problem. It
was a layered failure involving Codex execution mode, worktree topology,
SSH/GitHub auth assumptions, branch-flow drift, and insufficient safeguards
around destructive cleanup.

The agent did useful work in several places: it kept the design worktree mostly
separate, ran relevant verification checks, identified the branch-flow problem
between `origin/main` and `origin/development`, and eventually performed the
requested sandbox reality audit. The quality issue was premature interpretation.

| Area | Early interpretation | Later-corrected reality |
| --- | --- | --- |
| Shell / sandbox | Fetch or Git was hanging because of restricted network sandboxing. | Normal shell execution itself was failing; even `pwd`, `/bin/pwd`, `id`, and local Git commands returned no output in normal mode, while escalated mode worked. |
| Git lock | No-output Git commands were explained by a stale `.git/index.lock`. | The supposed lock file was not present when checked; later audit found no `.lock` files, and non-Git commands also failed. |
| SSH / 1Password | `ssh -T` success meant SSH auth was healthy. | `ssh-add -l` reported no identities; `ssh -T` authenticated but exited 1, and the exact Git operation still needed separate testing. |
| Branch cleanup | Remote-gone branches were safe to delete because they were merged or superseded. | The audit did not prove each deleted branch's patch equivalence or merge ancestry. Remote-gone is not the same as safely merged. |
| Branch-flow health | Development was current enough for feature/design work. | `origin/main` and `origin/development` were not ancestors of each other; development still lacked main ancestry despite tree-equivalent dependency content. |
| Secret handling | Process inspection was harmless diagnostics. | A GitHub PAT-bearing MCP command appeared in process output, creating a log-level secret exposure risk. |

The broad lesson: the agent should not be optimized merely to "keep moving." It
should be optimized to stop at uncertainty boundaries, produce a ledger of
claims, and only then continue.

## Reported environment shape

The later audit reportedly found the following approximate environment:

| Component | Observed configuration |
| --- | --- |
| OS / user | macOS / Darwin, user `verlyn13`. |
| Shell | `/bin/zsh`. |
| Git | `/opt/homebrew/bin/git`, Git 2.54.0. |
| Repo root | `/Users/verlyn13/Organizations/happy-patterns/apps/scopecam`. |
| SSH agent socket | `SSH_AUTH_SOCK=/var/run/com.apple.launchd.../Listeners`. |
| Git remote | `origin git@github.com-happy-patterns:happy-patterns-org/scopecam.git`. |
| GitHub host alias | `github.com-happy-patterns`. |
| 1Password SSH key path seen in failure | `/Users/verlyn13/.ssh/id_ed25519_happy_patterns.1password.pub`. |
| Worktrees after cleanup / audit | Main worktree on `feature/backmerge-main-to-development-2026-04-30`; design worktree on `feature/design-component-architecture-pr3-2026-04-30`. |
| Repo operation state | No merge, rebase, cherry-pick, unresolved conflict, or lock file observed during the audit. |
| Normal shell mode | Unreliable: commands returned no output / tool-level failure. |
| Escalated mode | Reliable enough for local Git, SSH, and fetch during the audit. |
| Auth state | Escalated SSH/GitHub operations worked, but `ssh-add -l` showed no identities. |
| Branch-flow state | `origin/main` was not an ancestor of `origin/development`, and `origin/development` was not an ancestor of `origin/main`. |

The report's strongest finding is that normal shell mode and escalated shell
mode were materially different execution environments. Their results should not
be mixed as interchangeable evidence.

## Observation, inference, action discipline

The exchange showed this failure pattern:

1. A command returned no output.
2. The agent searched for a familiar explanation.
3. The agent stated that explanation as though it were the cause.
4. The agent moved to corrective action.
5. Later evidence weakened or contradicted the explanation.

The problematic step was not running diagnostics. The problematic step was
narrating a cause before isolating the layer.

A better pattern is:

```text
Observation: command X returned no output.
Unknowns: shell wrapper, cwd, timeout, sandbox mode, Git state, auth, network.
Evidence collected so far: ...
Possible causes: ...
Disproving checks: ...
Safe next action: ...
```

## Codex environment lessons

### Distinguish tool failure from command failure

In the reported log, "no output" sometimes meant the command succeeded quietly,
sometimes meant the shell failed before executing the command body, and
sometimes meant the agent lacked a captured exit code. The later audit recorded
tool-level failure for normal commands and `EXIT=0` for escalated equivalents.
That distinction is essential.

Recommended command transcript fields:

```text
mode: normal | escalated
cwd: ...
command: ...
exit_code: ...
tool_status: ...
elapsed_ms: ...
stdout_bytes: ...
stderr_bytes: ...
redactions_applied: yes/no
```

When the command body does not emit an exit code, the wrapper should say:

```text
Command body did not complete or output was not captured.
This is a tool/runtime failure, not a command-level exit status.
```

### Treat normal and escalated modes as different machines

The report says normal mode failed for trivial commands while escalated mode
succeeded. Escalation can keep work moving, but only after the task is
explicitly converted into an environment audit.

Recommended rule:

```text
If normal shell execution fails for pwd, id, or command -v git, the agent must
enter diagnostic mode. No branch deletion, merge, push, worktree removal, or
implementation work may proceed until the execution mode is classified.
```

### Expose sandbox capability state

Codex should expose a runtime banner or machine-readable status instead of
requiring agents to infer capabilities by watching commands fail:

```json
{
  "cwd": "/Users/verlyn13/Organizations/happy-patterns/apps/scopecam",
  "shell": "/bin/zsh",
  "network": "restricted|available|requires_escalation",
  "interactive_prompts": "available|not_available|unknown",
  "tty": "available|not_available",
  "secrets_redaction": "enabled",
  "mode": "normal|escalated"
}
```

## Workspace and worktree lessons

Git worktrees are a good fit for parallel agentic development because they allow
multiple working trees attached to one repository, so different branches can be
checked out at the same time. The exchange showed the coordination problem:
the agent started treating "the repo" as one thing while there were at least two
meaningful workspaces: the main SDK worktree and the design worktree.

Suggested registry shape:

```json
{
  "repo": "happy-patterns-org/scopecam",
  "canonical_base": "origin/development",
  "worktrees": [
    {
      "path": "/Users/verlyn13/Organizations/happy-patterns/apps/scopecam",
      "role": "primary-sdk",
      "owner": "sdk-agent",
      "branch": "development",
      "may_cleanup": false
    },
    {
      "path": "/Users/verlyn13/Organizations/happy-patterns/apps/scopecam-design-system",
      "role": "design-system",
      "owner": "design-agent",
      "branch": "feature/design-component-architecture-pr3-2026-04-30",
      "may_cleanup": true
    }
  ]
}
```

Recommended rule:

```text
A branch or worktree may not be deleted, switched, or rebased by an agent that
does not own that worktree unless the user explicitly grants that operation in
the current exchange.
```

## Branch cleanup lessons

The report identifies branch deletion as the most dangerous Git operation in
the exchange. `git branch -D` is the force form of branch deletion and permits
deletion regardless of merged status. It should not be the default cleanup tool
in an agentic environment.

The unsafe assumption was:

```text
remote-gone + appears superseded = safe to delete
```

A safer deletion proof should require checking that the branch exists, is not
attached to a worktree, has fresh remote state, and is either an ancestor of the
target or patch-equivalent to the target. For squash-merged branches, ancestry
can fail even when content is present, so patch equivalence or zero diff must be
explicitly shown. Remote-gone branches should go into a review queue, not the
trash.

## Branch-flow and GitHub configuration lessons

The ScopeCam repo reportedly had a branch-flow invariant: `development` should
not drift from `main`, or main-only dependency commits need to be backmerged
before new feature work continues. The agent found that `origin/main` and
`origin/development` were not ancestors of each other, and that `origin/main`
still had main-only dependency commits.

That branch-flow invariant should be automated rather than rediscovered by
agents. The report recommends a required status check or preflight proving that
`origin/development` contains `origin/main` ancestry when feature work targets
`development`, except for approved backmerge branches.

## SSH, 1Password, and auth lessons

The report separates three auth facts that were initially blurred:

1. `ssh -T` can authenticate successfully.
2. `ssh-add -l` can still report no identities.
3. A specific Git operation can still fail or behave differently.

Recommended rule:

```text
Do not use ssh -T as the only auth probe. Use a repo-specific Git operation
against the exact remote and exact branch refs.
```

Suggested stronger probe:

```bash
GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=2' \
  git ls-remote origin refs/heads/main refs/heads/development
```

The report notes that `git ls-remote --heads origin HEAD` is weaker than it
looks because `HEAD` is not a normal branch head ref under `refs/heads/*`.

## Secrets and process output lessons

The most urgent security issue is that a process listing exposed a GitHub
PAT-bearing MCP command line. The token is not reproduced here. The report
recommends treating that as a real secret exposure in the transcript/logging
layer.

Immediate actions recommended by the report:

1. Revoke or rotate the exposed token.
2. Audit where that token was used.
3. Replace command-line secret passing with a safer mechanism.
4. Add transcript redaction for GitHub token and bearer-token patterns.
5. Avoid `ps`, `pgrep -fl`, or `env` output unless passed through a redactor.

Secret scanning is not enough for this class because the leak happened through
process output, not necessarily a committed file.

## PR body and shell quoting lessons

The report says a PR body was corrupted because backticked Markdown was expanded
by the shell during `gh pr create`. The agent later corrected it, but the lesson
should be formalized.

Bad pattern:

```bash
gh pr create --body "Backmerges current `origin/main` into `development`..."
```

Good pattern:

```bash
cat > /tmp/pr-body.md <<'EOF'
## Summary

Backmerges current `origin/main` into `development`.
EOF

gh pr create \
  --base development \
  --head feature/backmerge-main-to-development-2026-04-30 \
  --title "chore(backmerge): sync main into development (2026-04-30)" \
  --body-file /tmp/pr-body.md
```

For agents, `--body-file` should be mandatory. It avoids command substitution,
improves reviewability, and leaves a local artifact for debugging.

## Recommended scaffolding

The report recommends:

- `scripts/agent/preflight.sh`: read-only, captures shell, git, worktree,
  remote, lock, and branch-flow state with exit code, elapsed time, and mode.
- `scripts/agent/reality-audit.sh`: read-only Markdown report for execution,
  repo, remote, auth, and safe-action classification after anomalous commands.
- `scripts/agent/branch-cleanup-plan.sh`: dry-run only branch classifier with
  classes like `SAFE_DELETE_BY_ANCESTRY`, `SAFE_DELETE_BY_ZERO_DIFF`,
  `REMOTE_GONE_BUT_UNPROVEN`, `LOCAL_ONLY_KEEP`, `ATTACHED_TO_WORKTREE_KEEP`,
  `CURRENT_BRANCH_KEEP`, and `UNKNOWN_KEEP`.
- `scripts/agent/apply-branch-cleanup.sh`: second-step apply script that
  prefers `git branch -d` and requires a cleanup plan.
- `.agent/worktrees.json`: worktree ownership registry with protected worktrees.
- `scripts/agent/ps-safe.sh`: redacts tokens by default and requires explicit
  approval for raw output.
- `scripts/check-branch-flow.sh`: fails when `origin/main` commits are not
  represented in `origin/development`, except for approved backmerge branches.

## Recommended operating-contract rules

```text
1. Evidence before cause.
   A command symptom is not a diagnosis. The agent must label observations,
   inferences, and actions separately.

2. No destructive Git operations after unexplained no-output commands.
   If pwd, git status, or git rev-parse returns no output without an exit code,
   the agent must stop and run a reality audit.

3. Remote-gone is not merged.
   Branches with deleted upstreams may not be deleted unless ancestry, zero-diff,
   or patch equivalence is proven.

4. No git branch -D by default.
   Agents must use git branch -d unless the user explicitly authorizes forced
   deletion after seeing the proof.

5. ssh -T is not a fetch proof.
   Agents must test the exact Git remote operation they intend to rely on.

6. Worktree ownership is binding.
   Agents may inspect all worktrees but may only switch, delete, rebase, or clean
   their assigned worktree unless explicitly instructed.

7. PR bodies must use --body-file.
   Agents may not pass Markdown PR bodies through shell-interpreted inline
   strings.

8. Secrets must be redacted before display.
   Process listings, environment dumps, and tool output must pass through a
   redactor.
```

## Highest-priority action list from the report

1. Rotate the exposed GitHub PAT seen in process output.
2. Add a secret redactor to process/environment diagnostics.
3. Create `scripts/agent/reality-audit.sh` and require it after no-output
   command anomalies.
4. Create `scripts/agent/branch-cleanup-plan.sh` and prohibit direct bulk
   `git branch -D`.
5. Add a branch-flow CI check proving `origin/main` ancestry is represented in
   `origin/development`.
6. Use `gh pr create --body-file` and `gh pr edit --body-file` only.
7. Track worktree ownership so design, SDK, and backmerge work cannot
   accidentally interfere.
8. Make Codex execution mode visible: normal vs escalated, network access,
   TTY/prompt capability, cwd, exit code, and tool status.

## Source links cited by the submitted report

- Git worktree documentation: https://git-scm.com/docs/git-worktree
- Git branch documentation: https://git-scm.com/docs/git-branch
- 1Password SSH agent: https://developer.1password.com/docs/ssh/agent/
- 1Password SSH client compatibility: https://developer.1password.com/docs/ssh/agent/compatibility/
- GitHub personal access tokens: https://docs.github.com/en/enterprise-cloud@latest/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- GitHub secret scanning: https://docs.github.com/code-security/secret-scanning/about-secret-scanning
- GitHub push protection: https://docs.github.com/en/code-security/concepts/secret-security/about-push-protection
