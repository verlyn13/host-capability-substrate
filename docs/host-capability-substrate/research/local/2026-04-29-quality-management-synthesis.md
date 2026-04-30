---
title: Quality Management Synthesis from macOS/GitHub Boundary Research
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-29
tags: [phase-1, quality-management, macos, github, git, tcc, package-managers, boundary-uncertainty, evidence]
priority: high
---

# Quality Management Synthesis from macOS/GitHub Boundary Research

Synthesis of two volatile research reports delivered under `/private/tmp/`:

| Source | Preserved copy | SHA-256 |
|---|---|---|
| `/private/tmp/github-boundaries-research.md` | `docs/host-capability-substrate/research/external/2026-04-29-github-boundaries-research.md` | `9a9f6ec45ad39f7be78f9f711ed30eb65f85860d3389d397b5ea50bee4727193` |
| `/private/tmp/hcp-quality-management.md` | `docs/host-capability-substrate/research/external/2026-04-29-hcp-quality-management.md` | `b5efcc662d9174896ba4f1ec421a00b3ea529ac9e2228adf13f16decd732edef` |

This synthesis is Ring 3 planning evidence. It does not change schema, policy,
repo settings, GitHub settings, SSH keys, Git config, package-manager state, or
1Password state.

## Source Roles

The two reports have different authority shapes:

- `github-boundaries-research.md` is mostly a reusable research-method
  blueprint. Its direct value for HCS is not new macOS/GitHub facts; it
  strengthens how HCS should ingest future research: source ladders, extraction
  templates, credibility scoring, explicit contradictions, and claim-to-source
  discipline.
- `hcp-quality-management.md` is the substantive quality-management report. It
  is document/source-code research only, with no installed-runtime or
  local-config observations. It proposes concrete HCS gates, entities, policies,
  dashboard views, and traps for macOS Tahoe, Git/GitHub, package managers, and
  multi-account use.
- The prior local report
  `docs/host-capability-substrate/research/local/2026-04-29-github-version-control-agentic-surface.md`
  remains the stronger authority where it directly observed this host. The new
  quality-management report adds breadth and candidates, not final local truth.

## Common Themes

Both reports converge with existing HCS posture on these points:

1. Quality management is a decision-support pipeline, not a checklist. Every
   important claim needs source type, freshness, credibility, and decision
   implication.
2. Boundaries are not stable enough to infer. macOS app/TCC/sandbox behavior,
   Git config precedence, package-manager shims, credential helpers, and GitHub
   account state can all change under an agent without looking like a code
   change.
3. The substrate must represent bindings, not isolated facts. The load-bearing
   unit is a chain such as `worktree -> Git config -> remote -> SSH alias ->
   signing identity -> credential helper -> GitHub account -> repo gate`.
4. The answer to "can this process read or write the repo?" is contextual. It
   depends on launch source, app sandbox, TCC grant, app translocation,
   filesystem path/volume, environment, and credential source.
5. Package managers are provenance surfaces. Homebrew, npm/pnpm/bun, pip/uv,
   cargo, mise/asdf shims, Xcode CLT, and app bundles can all put different
   binaries and configs on the execution path.
6. GitHub is a family of surfaces. Git remotes, `gh`, SSH auth, commit signing,
   MCP auth, GitHub Apps, deploy keys, Actions, rulesets, checks, branch
   protection, environments, and repo settings must be modeled separately.
7. Human identity, account class, and credential source matter. Personal,
   business, school, organization, child/dependent, and automation identities
   have different acceptable operations.

## Differences and Tensions

The strongest design value comes from preserving the areas of mismatch:

| Topic | Research report posture | Local/current HCS posture | Design implication |
|---|---|---|---|
| Source authority | `hcp-quality-management.md` is doc/source-code only. | HCS charter v1.2.0 ranks installed-runtime/local observation above docs for current behavior. | Treat the report as candidate taxonomy. Require local probes before policy gates. |
| Scope breadth | Report includes Apple family/age/developer-program constraints. | Current HCS docs focus on host substrate, GitHub, MCP, CI, and credentials. | Account-class constraints may belong in `Principal` / `CredentialSource`, but should not bloat Phase 1 unless a real workflow needs them. |
| Policy strictness | Report proposes many block defaults. | HCS already defers mutating execution until approval/audit/dashboard/leases; Phase 1 is mostly schema/evidence. | Keep strict policies as candidates; do not add tier entries until policy review and concrete operations exist. |
| GitHub gates | Report suggests branch protection/rulesets as expected quality gates. | HCS and `system-config` currently have weak GitHub-side enforcement compared with local `just verify`. | Q-006/Q-007 should decide whether HCS expects GitHub enforcement now or waits for Citadel/OpenTofu governance. |
| App/filesystem evidence | Report calls for TCC/translocation/sandbox evidence. | Shell-env work already queues `ExecutionContext` and provenance snapshots, but not full TCC/app-bundle modeling. | Add a quality-management synthesis item rather than silently expanding shell-env scope. |
| Research method | Blueprint asks for extraction matrices and credibility scoring. | Existing HCS research dirs have narrative READMEs and reconciled conclusions. | Adopt the method for future intakes: claim/source/confidence tables for source-heavy reports. |

## Boundary Strain

The user's takeaway is correct: the boundaries are loose because the underlying
systems are loose. HCS should not aim to make macOS, GitHub, Git, or package
managers look cleaner than they are.

The design should instead make boundary uncertainty first-class:

- `unknown`, `stale`, `contradictory`, and `not-observable-from-this-context`
  are valid evidence states, not errors to paper over.
- A boundary claim should name the execution context that observed it. Finder,
  Terminal, launchd, IDE extension, MCP child, package-manager shim, and app
  helper observations are not interchangeable.
- Quality gates should degrade deliberately. A read-only report can continue
  with warnings; a push, settings write, ruleset edit, credential change, or
  workflow mutation should stop or require approval when boundary evidence is
  stale or contradictory.
- HCS should expect surprise. Version updates, TCC resets, app translocation,
  Git credential-helper changes, package-manager shims, `gh auth switch`, and
  repo ruleset changes can invalidate previously true facts.

This is a candidate charter v1.3.0 principle, but not yet a charter amendment:

> Boundary claims are freshness-bound and execution-context-bound. HCS must
> model contradictory or missing boundary evidence explicitly and must not
> promote a boundary inference across macOS app, shell, package-manager,
> Git/GitHub, or MCP surfaces without a matching observed context.

## High-Value Ideas to Carry Forward

### Quality Gates

The report's best gate candidates are:

- Identity-binding gate: require a resolved chain from worktree to GitHub
  account before pushes, PRs, workflow dispatches, releases, or settings writes.
- Credential-shadow gate: detect multiple credential helpers or env tokens that
  can answer for the same GitHub host.
- Signing-identity gate: bind `user.email`, `user.signingkey`,
  `gpg.ssh.program`, `allowed_signers`, 1Password SSH agent, and GitHub
  registered signing key evidence.
- Filesystem-trust gate: capture launch context, sandbox/TCC/translocation, and
  resolved path/volume facts before trusting GUI/app-bundled agent claims.
- Tool-provenance gate: resolve shim chain and install source before trusting
  load-bearing CLI output.
- Mutation-class gate: classify GitHub/Git/filesystem/package-manager changes
  before rendering any command or API call.

### Candidate Evidence and Entity Work

Useful Phase 1 candidate concepts:

- `BoundaryObservation`: common envelope for a contextual boundary fact.
- `QualityGate`: named gate with evidence inputs, decision outputs, and
  freshness requirements.
- `GitConfigResolution`, `GitIdentityBinding`, `CredentialBinding`,
  `SigningIdentity`, `GitHubRepoSettingsObservation`,
  `BranchProtectionObservation`, `RulesetObservation`,
  `WorkflowPolicyObservation`.
- `BundleObservation`, `SandboxContext`, `TCCGrantObservation`,
  `LaunchContext`, `VolumeObservation`, `WorktreeStateObservation`.
- `ToolProvenance`, `ShimResolution`, `PackageManagerObservation`,
  `ToolMutationClaim`.

Do not commit these as schema changes from this synthesis alone. Reconcile them
with existing `Evidence`, `ExecutionContext`, `CredentialSource`,
`ResourceBudget`, and Q-006 GitHub/version-control candidates.

### Dashboard Views

High-value dashboard candidates:

- Worktree identity binding view.
- Credential shadow/drift view.
- Repo quality posture view: rulesets, branch protection, required signatures,
  checks, CODEOWNERS, SECURITY.md, Actions permissions, environments.
- Tool provenance view for `git`, `gh`, `ssh`, `op`, package managers, and
  shims.
- macOS boundary view: bundle identity, sandbox, TCC grants, translocation,
  protected-folder access.
- Mutation queue with evidence bundle and freshness markers.

### Regression Trap Families

Good trap families to queue, not yet scaffold:

- Credential helper precedence changes.
- `gh` active account changes outside approved flow.
- Env token shadows expected `gh` or SSH identity.
- `gpg.ssh.program` or 1Password agent socket path changes.
- New GitHub SSH alias appears.
- New package-manager shim shadows `git`, `gh`, `ssh`, or `op`.
- Repo ruleset/branch-protection/signature requirement drifts.
- Workflow gains `permissions: write-all` or unjustified `id-token: write`.
- New deploy key, PAT, GitHub App installation, MCP server, or Actions secret
  appears.
- TCC grants change for an agent host app.
- App quarantine clears or translocation state changes unexpectedly.

## Areas of Uncertainty to Preserve

These should stay visible in planning:

- Exact macOS Tahoe TCC behavior around protected-folder writes versus reads
  needs local observation; the report cites supporting sources but does not
  prove this host.
- App translocation behavior is intentionally underdocumented and version
  sensitive.
- Multiple Git binaries mean "Git system config" is not singular; the active
  binary decides which system config matters.
- `gh auth switch` and non-`gh` credential helpers can diverge; current local
  behavior should be probed before relying on docs or issue threads.
- MCP OAuth/DCR behavior for GitHub remains unstable across clients and specs;
  HCS already saw Codex GitHub MCP OAuth migration fail.
- Family/child/dependent and Apple Developer Program constraints are important
  if those principals are in scope, but their first landing should probably be
  account-class evidence, not broad policy.

## Planning Integration

Recommended integration path:

1. Preserve both source reports verbatim under `research/external/`.
2. Treat this synthesis as the local HCS interpretation and link it from
   `PLAN.md`.
3. Add Q-007 for quality-management/boundary-accommodation so it does not get
   collapsed into Q-006's GitHub-only scope.
4. Keep Q-006 focused on GitHub/version-control authority.
5. Keep Q-005 focused on CI runner/check evidence.
6. Reconcile Q-006 and Q-007 during Phase 1 schema synthesis before adding any
   entities or policy tiers.
7. Do not add regression traps from this report until a concrete observed
   failure or human-approved trap expansion exists.

## Change Log

| Version | Date | Change |
|---|---:|---|
| 1.0.0 | 2026-04-29 | Initial synthesis of the two `/private/tmp` quality-management research reports. |
