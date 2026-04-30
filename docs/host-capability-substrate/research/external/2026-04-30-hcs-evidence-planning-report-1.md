# Evidence and Planning for HCS

Source: user-submitted evidence and planning report, delivered to HCS on
2026-04-30. The report was based on work by Opus 4.7 in Claude macOS.

Status: external evidence. This report is preserved as input to HCS design and
planning. It is not first-party HCS decision authority. The original Claude
macOS transcript/log bundle is not stored in this repository.

Terminology note: the submitted report used several labels from an agent that
did not know the current HCS charter vocabulary. This staged version normalizes
those labels to HCS terms. The accepted architecture remains the four-ring HCS
charter; candidate operation names below are planning inputs, not accepted
interfaces.

## Executive Summary

HCS should become the shared, project-agnostic layer that answers these
questions for every agent before it edits code:

- Where am I?
- Which project/worktree owns this task?
- Is the shell reliable?
- Are secrets available?
- Is GitHub/network auth available?
- Are refs fresh?
- Which files are load-bearing state?
- Which cleanup actions are safe?
- Which docs/plans are authoritative?
- What must be redacted before the agent sees it?

The evidence does not support solving these problems independently inside each
app repo. The logs show that agents keep misdiagnosing environment symptoms as
repo problems: no-output shell commands were treated as Git lock issues, SSH
auth probes were treated as proof that Git fetch would work, remote-gone
branches were treated as safe to delete, and process inspection leaked a GitHub
PAT-bearing command line.

HCS should therefore provide stable contracts that all target repos consume.
Only `host_secret_*` is accepted today through D-028; the other names below are
normalized candidate HCS operation surfaces:

- `host_secret_*`
- `system.runtime.diagnose.v1`
- `system.git.diagnose.v1`
- `system.workspace.diagnose.v1`
- `system.process.inspect_safe.v1`
- `system.docs.diagnose.v1`
- `system.cleanup.plan.v1`
- `system.claims.reconcile.v1`

HCS's job is not to make every agent clever. Its job is to make unsafe
assumptions hard to make.

## Evidence Already Present in System-Config Decisions

### D-025: Cleanup Requires Deletion Authority

D-025 says the cleanup classifier must distinguish "derivable from source" from
"load-bearing state", and that gitignore status is not sufficient deletion
authority. The decision came from a Codex incident where `.logs/` was active soak
state even though it was gitignored.

That maps directly onto later branch-cleanup problems. The agent treated
remote-gone local branches as disposable without proving each branch was merged,
patch-equivalent, or intentionally throwaway.

The same principle applies:

- Ignored does not mean disposable.
- Remote-gone does not mean merged.
- No open PR does not mean safe to delete.
- No output does not mean success.

### D-026: Runtime and Config Claims Need Provenance

D-026 defines a config authority hierarchy: observed runtime plus matching
changelog outranks static docs and published schema when resolving config-spec
claims. It was motivated by a harness drift incident where Claude Code rejected
a string `"verbose": "true"` even though docs/schema sources disagreed.

This is important for HCS design because agents should not make config claims
such as:

- `op` has no timeout flag.
- `direnv` behaves this way.
- Claude reads this MCP file.
- GitHub auth is healthy.

unless the claim records:

```json
{
  "source": "observed_runtime | installed_tool | official_doc | schema | changelog",
  "observed_at": "timestamp",
  "installed_version": "version",
  "authority_order": "why this source wins"
}
```

### D-027: Harness Startup Lint Belongs to Host Hygiene

D-027 says pre-launch host-config type validation belongs at the chezmoi /
host-hygiene layer, not inside HCS rings, because if the harness cannot start,
nothing below it can help.

That gives HCS a boundary:

Host hygiene:

- validates shell config
- validates agent config
- validates JSON/YAML types
- validates MCP config shape
- validates direnv support

HCS runtime:

- provides runtime capabilities after startup
- exposes diagnostics
- brokers secrets
- bounds operations
- classifies cleanup

### D-028: Credential Plane Contract Already Exists

D-028 is the most important design anchor. It defines the `host_secret_*` shell
contract:

- `host_secret_read`
- `host_secret_export`
- `use_host_secrets`
- `host_secret_diag`

and the `HCS_SECRET_*` namespace:

- `HCS_SECRET_ACCOUNT`
- `HCS_SECRET_TIMEOUT`
- `HCS_BROKER_SOCKET`

It also states that the current backend is direct
`timeout "$HCS_SECRET_TIMEOUT" op read`, while the future backend should let the
same callers talk to `$HCS_BROKER_SOCKET`. The reason given is a reproduced
1Password IPC queue deadlock and lack of a client-side `op` timeout flag in the
observed `op 2.32.1` environment.

That means the architecture is already pointing in the right direction:

- Do not put ad hoc timeout wrappers in each repo.
- Put bounded secret reads behind `host_secret_*`.
- Later replace direct `op` calls with a broker without changing project
  callers.

## Evidence From ScopeCam Agent Failures

### Normal Shell and Escalated Shell Behaved Differently

The sandbox audit found that normal shell commands such as `pwd`, `/bin/pwd`,
`id`, and local Git commands produced no output, while escalated execution
returned normal output and exit codes. The audit directive explicitly required
comparing normal versus escalated behavior and not treating no-output commands
as successful.

Design implication:

Every host command must report:

- mode: `normal | escalated`
- cwd
- command
- exit code
- tool status
- elapsed time
- stdout bytes
- stderr bytes
- redaction status

A command that never prints an explicit `EXIT=` marker should be classified as a
runner failure or shell-path anomaly, not a command success.

### The Agent Invented a Git Lock Explanation

The agent claimed the primary worktree had a stale `.git/index.lock`, then
immediately ran `ls -l .git/index.lock && lsof .git/index.lock`, which returned
"No such file or directory." Despite that, it continued toward branch cleanup.

Design implication:

HCS needs claim reconciliation over typed evidence:

- observed fact
- inferred cause
- contradicting evidence
- confidence
- allowed next action

This would prevent "no output" from becoming "Git lock" without evidence.

### SSH Auth Was Treated as Broader Proof Than It Was

The audit requirements separated `ssh -T`, `ssh-add -l`, and exact Git
operations, because `ssh -T` does not prove `git fetch`, `git push`, or
`gh pr create` will work.

Design implication:

The candidate `system.git.diagnose.v1` surface should test the exact operation
class:

- read refs: `git ls-remote origin refs/heads/main refs/heads/development`
- fetch: `git fetch --dry-run` or bounded fetch where available
- push permission: non-mutating permission probe when possible
- `gh` auth: `gh auth status`, redacted

### Process Inspection Leaked a Token-Bearing Command

The process listing exposed an MCP command with an authorization bearer token in
its arguments. This report does not reproduce the token. The evidence shows that
raw `pgrep -fl` and `ps` output is unsafe for agent transcripts.

Design implication:

The candidate `system.process.inspect_safe.v1` surface should be the only
approved process-inspection path. Raw `ps`, `pgrep -fl`, `env`, `printenv`, and
shell history must be blocked or redacted before model exposure.

The redactor should catch at least:

- GitHub PAT-like token prefixes
- `Authorization: Bearer ...`
- `op://...` values if they reveal item/vault structure beyond policy
- `DATABASE_URL=...`
- `*_TOKEN=...`
- `*_SECRET=...`
- `*_KEY=...`

## Evidence From ScopeCam Design Planning

The design work itself also offers useful substrate lessons. The design branch
was deliberately created from current `origin/development` after PR #201 merged;
checks passed for design-token lint, token parity, and docs lint except an
expected ADR-016 Proposed warning; the SDK worktree was explicitly not modified.

That is a good pattern for all projects:

1. identify the correct worktree,
2. identify ownership,
3. prove branch freshness,
4. run the relevant lightweight gates,
5. state what was not touched.

The ScopeCam design plan also emphasized classification-driven movement rather
than blind component moves. It noted that some apparent "atoms" were actually
domain-bound because they depended on camera capability, capture state, or
safety state.

HCS lesson:

Cleanup and reorganization need semantic classifiers, not filename heuristics.
The same applies to docs, branches, tasks, and worktrees.

## Evidence From Budget Triage

Budget Triage shows that the substrate must handle larger multi-surface apps
with substantial docs, routes, runtime state, and nested agent artifacts.

### Worktree Inflation and Search Contamination

The Budget Triage audit found a nested `.claude/worktrees/eager-turing` worktree
containing a full project copy of roughly 4,086 files, inflating `.claude/` file
counts and causing grep/glob searches to return duplicate results if the nested
worktree is not excluded.

Design implication:

The candidate `system.workspace.diagnose.v1` surface must identify nested
worktrees and automatically exclude them from:

- search
- lint
- docs inventory
- stale-file detection
- cleanup classification

### Duplicate MCP Config

Budget Triage had both `.mcp.json` and `.claude/mcp.json` with byte-identical
content, with uncertainty about which is canonical. The audit notes that Claude
Code CLI reads root `.mcp.json`, making `.claude/mcp.json` redundant.

Design implication:

MCP config must have one canonical source per target repo. HCS should report
duplicates and refuse to infer silently.

### Stale Directives and Large Docs Surface

The Budget Triage audit found stale directive references to deleted files and
nonstandard scripts, while also noting that `docs/` contained around 40
subdirectories, many not referenced by active governance/rules/instruction
files.

Design implication:

The candidate `system.docs.diagnose.v1` surface should classify docs as:

- canonical
- referenced support
- planning artifact
- archived
- orphan candidate
- stale directive
- generated/derivable

It should not delete simply because a file is old, unreferenced, or absent from
a planning index.

### Product and Domain Complexity Requires Project-Aware Adapters

Budget Triage has implemented surfaces for setup, login, Plaid OAuth callback,
documents, transactions, accounting, goals, triage, cross-source review, admin,
and settings, plus query-state navigation for accounting, tax center, settings,
and admin.

It also has identity/domain entities for users, authenticated auth context,
sessions, API keys, tenants, memberships, passkeys, accounts, transactions,
documents, goals, attention items, credentials, and business entities.

Design implication:

HCS should not try to understand every target-repo domain deeply. It should
provide generic evidence tools, then let each target repo declare:

- canonical routes
- canonical docs
- domain entities
- planning state
- runtime dependencies
- safe cleanup rules

## HCS Capability-Area Proposal

### Proposed Capability Areas

The report originally proposed additional "rings." Normalized to HCS terms,
these are capability areas that map onto the binding four-ring charter rather
than new architecture rings:

| Capability area | HCS mapping |
| --- | --- |
| Host hygiene | Outside HCS runtime; system-config / chezmoi validates agent config before harness startup. |
| Runtime reality | Ring 0 schemas plus Ring 1 kernel services prove cwd, shell, user, OS, PATH, Git, and execution-mode behavior. |
| Credential plane | Ring 1 credential broker plus the D-028 `host_secret_*` compatibility contract. |
| Workspace plane | Ring 0 `WorkspaceContext` / `Lease`; Ring 1 workspace evidence and ownership service. |
| Git/GitHub plane | Ring 1 evidence service and future typed Git/GitHub operations, gated by Q-006/Q-008. |
| Cleanup and planning classification | Ring 1 policy/gateway and cleanup classifier; Ring 3 runbooks and evals. |
| Target-repo workspace profiles | Ring 3 manifest/runbook inputs consumed by Ring 1; not Ring 2 protocol adapters. |

### Candidate Operation Surfaces

Candidate surfaces:

- `system.runtime.diagnose.v1`
- `host_secret_diag`
- `host_secret_read`
- `host_secret_export`
- `system.git.diagnose.v1`
- `system.workspace.diagnose.v1`
- `system.process.inspect_safe.v1`
- `system.docs.diagnose.v1`
- `system.cleanup.plan.v1`
- `system.claims.reconcile.v1`

Each surface should be machine-readable first, Markdown-friendly second:

```json
{
  "project": "scopecam",
  "cwd": "...",
  "mode": "normal",
  "command": "pwd",
  "exit_code": null,
  "tool_status": -1,
  "elapsed_ms": 1200,
  "stdout_bytes": 0,
  "stderr_bytes": 0,
  "classification": "shell_body_not_observed",
  "safe_next_action": "retry escalated; do not mutate"
}
```

### Candidate Workspace Manifest Inputs

Each target repo may need a small HCS workspace manifest or generated
`WorkspaceContext` source:

```json
{
  "project": "budget-triage",
  "canonical_mcp_config": ".mcp.json",
  "protected_paths": [
    ".logs",
    "data",
    "infrastructure/database/migrations",
    "docs/planning",
    "docs/audits"
  ],
  "exclude_from_search": [
    ".claude/worktrees",
    "node_modules",
    "dist",
    "build"
  ],
  "worktree_policy": {
    "nested_worktrees_allowed": false,
    "branch_deletion_requires": [
      "ancestor_or_patch_equivalence",
      "not_attached_to_worktree"
    ]
  },
  "secret_contract": "host_secret_*",
  "verify_commands": [
    "pnpm test",
    "pnpm lint",
    "pnpm typecheck"
  ]
}
```

### Timeout Policy

Timeouts should be layered, not scattered:

- Secret read timeout: `HCS_SECRET_TIMEOUT` through
  `host_secret_read/export`.
- Network/Git timeout: `system.git.diagnose.v1` uses bounded SSH/Git options.
- Agent command timeout: command runner records elapsed time, tool status, and
  output capture.
- CI timeout: project workflows set job/step limits.
- Long-running watch timeout: `gh pr checks --watch` and similar commands must
  be bounded or manually classified.

The ScopeCam and timeout discussions show why raw `.envrc` edits are the wrong
abstraction. The `.envrc` should call a stable host secret interface, not
implement project-specific timeout behavior. D-028 already defines that
interface.

## Planning Model for Target Repos

HCS should distinguish five kinds of state:

| State type | Example | Deletion rule |
| --- | --- | --- |
| Source of truth | migrations, ADRs, accepted decisions, domain schema | never delete by heuristic |
| Load-bearing local state | `.logs/`, soak output, planning database, generated-but-active artifacts | requires explicit authority |
| Derivable generated state | build cache, compiled output | may clean if generator is known |
| Planning artifact | task specs, active lane docs, design plans | archive only with planning-state reconciliation |
| Stale candidate | duplicate MCP file, deleted-file directive, broken deep link | report first; fix separately |

This model is directly supported by D-025's deletion-authority principle and by
the Budget Triage audit's finding that gitignored or unreferenced state may still
be meaningful.

## Acceptance Criteria for HCS

HCS is not ready for these surfaces until it passes these scenario tests:

1. 1Password locked: `host_secret_diag` distinguishes locked app from missing
   secret.
2. 1Password IPC deadlock: `host_secret_read` times out and returns a typed
   timeout, not a hang.
3. `timeout`/`gtimeout` missing: `host_secret_diag` reports missing bounded
   execution support.
4. Normal shell broken: `system.runtime.diagnose.v1` detects that normal mode
   cannot emit `EXIT=`.
5. Escalated shell works: `system.runtime.diagnose.v1` reports mode divergence
   without treating it as repo state.
6. Raw process output contains a token: `system.process.inspect_safe.v1` redacts
   it before the agent sees it.
7. Nested worktree exists: `system.workspace.diagnose.v1` excludes it from
   stale-file and docs scans.
8. Remote-gone branch exists: `system.cleanup.plan.v1` refuses deletion unless
   ancestry or patch equivalence is proven.
9. Stale directive references deleted files: `system.docs.diagnose.v1` reports
   stale references without deleting docs.
10. Project planning data omits active planning specs:
    `system.docs.diagnose.v1` reports projection drift, not stale files.

## Candidate HCS Work Areas

### PR / Task A: Runtime Reality Diagnostics

Deliver:

- `system.runtime.diagnose.v1`
- normal-vs-escalated comparison
- no-output anomaly classifier
- structured command telemetry

### PR / Task B: Secret Plane Hardening

Deliver:

- `host_secret_read`
- `host_secret_export`
- `host_secret_diag`
- `HCS_SECRET_TIMEOUT` support
- `timeout`/`gtimeout` detection
- redacted stderr
- typed failure categories

This should follow D-028 rather than adding one-off `.envrc` timeout logic.

### PR / Task C: Safe Process Inspection

Deliver:

- `system.process.inspect_safe.v1`
- token redactor
- policy banning raw `ps`/`pgrep`/`env` in agent sessions

### PR / Task D: Workspace Registry

Deliver:

- host-level workspace registry or accepted repo-local `WorkspaceContext`
  manifest
- nested worktree detection
- owner/protected flags
- search exclusions

### PR / Task E: Cleanup Classifier

Deliver:

- `system.cleanup.plan.v1`
- deletion authority model
- branch cleanup proof
- docs cleanup proof
- planning artifact classification

This should implement the D-025 principle that deletion requires an authority
source beyond gitignore or apparent staleness.

### PR / Task F: Workspace Profiles

Deliver workspace profile inputs for:

- ScopeCam
- Budget Triage
- system-config / HCS itself

Each profile should declare or derive canonical docs, canonical MCP config,
verify commands, protected paths, worktree policy, and cleanup policy.
