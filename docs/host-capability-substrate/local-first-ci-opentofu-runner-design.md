---
title: Local-first CI and self-hosted runner compatibility report
category: planning-report
component: host_capability_substrate
status: draft
version: 1.1.0
last_updated: 2026-04-26
tags: [ci, github-actions, self-hosted-runners, opentofu, pac, iac, citadel, agentic-workflow]
priority: high
---

# Local-First CI and Self-Hosted Runner Compatibility Report

Planning report for a local-first validation architecture that uses GitHub
Actions for coordination, self-hosted runners for most compute, hosted runners
for small clean-room checks, and The Nash Group's OpenTofu / Policy-as-Code
stack for durable configuration.

This is a Ring 3 docs/research artifact. It does not change ontology, runtime
policy, HCS code, GitHub workflows, or OpenTofu resources.

## Status

Date: 2026-04-26

Companion external input:
`docs/host-capability-substrate/research/external/2026-04-26-proposed-runner-architecture.md`.
That report reinforces this compatibility boundary: Proxmox/Linux x64 is the
trusted self-hosted appliance class; GitHub owns scheduling/checks; Citadel
owns desired runner/workflow policy; MacBook runner use stays manual-only; HCS
records typed evidence and resource pressure rather than owning CI execution.

Recommendation:

```text
Adopt local-first validation + GitHub-orchestrated self-hosted runners +
small hosted clean-room sentinel checks, but treat runner infrastructure as
Citadel-owned IaC/PaC and treat runner observations as HCS typed evidence.
```

The design is compatible with HCS if these boundaries hold:

- GitHub is the event, check, branch-protection, and merge-gating surface.
- The Citadel owns desired CI infrastructure state through OpenTofu and PaC.
- HCS does not become a parallel CI control plane.
- HCS models CI operations, evidence, resource budgets, credentials, and
  approvals without turning shell strings or workflow YAML into primary intent.
- Public-source repos do not run untrusted fork pull requests on self-hosted
  runners.

## Source-of-truth context

HCS source-of-truth documents consulted:

- `docs/host-capability-substrate/implementation-charter.md`
- `docs/host-capability-substrate/ontology.md`
- `docs/host-capability-substrate/tooling-surface-matrix.md`
- `docs/host-capability-substrate/adr/0001-repo-boundary.md`
- `docs/host-capability-substrate/adr/0007-hook-call-pattern.md`
- `docs/host-capability-substrate/adr/0010-mcp-primitive-mapping.md`
- `docs/host-capability-substrate/adr/0011-public-private-boundary.md`
- `docs/host-capability-substrate/adr/0012-credential-broker.md`
- `docs/host-capability-substrate/adr/0015-external-control-plane-automation.md`
- `PLAN.md`
- `IMPLEMENT.md`
- `DECISIONS.md`

Nash/Citadel context inspected:

- `/Users/verlyn13/Organizations/the-nash-group/AGENTS.md`
- `/Users/verlyn13/Organizations/the-nash-group/.org/standards/agentic-workflow.md`
- `/Users/verlyn13/Organizations/the-nash-group/.org/standards/semantic-governance.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/AGENTS.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/OPENTOFU-SPECIFICATION.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/MIGRATION-MANIFEST.md`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/.github/workflows/opentofu.yml`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/.github/workflows/terraform-shield.yml`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/.github/workflows/drift-detection.yml`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/.github/workspace-registry.json`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/terraform/modules/github-rulesets/`
- `/Users/verlyn13/Organizations/the-nash-group/the-citadel/terraform/orgs/the-nash-group/`

External docs checked on 2026-04-26:

- GitHub self-hosted runners: control over hardware/tools, use existing
  machines, free Actions usage but self-maintained machines.[^github-self-hosted]
- GitHub runner labels and groups: default labels, custom labels, cumulative
  label matching, and group+label routing.[^github-labels]
- GitHub protected branches: required status checks must pass before merging
  and can be tied to a source app.[^github-status-checks]
- GitHub self-hosted runner security: no clean VM guarantee, public repo risk,
  runner group boundaries, environment and network exposure concerns.[^github-secure-use]
- GitHub ephemeral runners: one-job registration with `--ephemeral`, external
  log preservation, and environment wipe automation.[^github-ephemeral]
- GitHub runner scale set client and ARC relationship: scale set client is a
  non-Kubernetes autoscaling path; ARC remains the Kubernetes reference
  implementation.[^github-scale-set]
- OpenTofu S3 backend: state keys, S3 locking via `use_lockfile`, versioning and
  lifecycle implications.[^opentofu-s3]

## Existing Citadel posture

The Nash Group already has most of the governance pattern needed for this CI
architecture:

- The Covenant defines policy and principles.
- The Citadel enforces infrastructure through OpenTofu and OPA.
- The Nexus operates services and runtime tooling.
- Citadel has migrated from Terraform/HCP Terraform to OpenTofu/Hetzner S3.
- Citadel uses per-org OpenTofu roots under `terraform/orgs/<org>/`.
- State lives in Hetzner S3 at per-org keys with `use_lockfile = true`.
- OpenTofu CLI is pinned through `.mise.toml` as `opentofu = "1.11"`.
- GitHub provider is pinned to `integrations/github` `6.6.0`.
- Cloudflare provider is pinned to `cloudflare/cloudflare` `5.18.0`.
- The active CI workflows already use a self-hosted runner with labels
  `[self-hosted, linux, x64, iac]`.
- The Forge (`opentofu.yml`) runs matrix OpenTofu plan/apply.
- The Shield (`terraform-shield.yml`) runs OPA checks over OpenTofu plan JSON.
- The Watcher (`drift-detection.yml`) runs scheduled drift detection.
- `citadel-config` is private, which is the correct place for privileged
  self-hosted IaC jobs.
- `the-covenant` and `.github` are public, which means privileged self-hosted
  execution must not be applied indiscriminately across all repos.

The important finding: this proposal should extend an existing Citadel runner
pattern. It should not create a separate HCS-owned CI system.

## Desired target state

```text
MacBook M3 Max
  - developer workstation
  - fast local checks
  - pre-push validation
  - manual reproduction
  - rare macOS/ARM workflow_dispatch checks only

Proxmox Beelink SER9
  - CI appliance, not personal dev box
  - Linux x64 self-hosted runner classes
  - disposable job VMs/containers over time
  - controlled package/build caches
  - no personal credentials or broad LAN reachability

GitHub
  - webhook/event source
  - Actions job scheduler
  - check/status source
  - branch protection and rulesets
  - hosted clean-room smoke checks

Citadel OpenTofu / PaC
  - GitHub repositories, rulesets, environments, variables, workflow policy
  - runner groups/access where provider coverage exists
  - Proxmox runner host definitions if and when Proxmox IaC is added
  - OPA checks over IaC and workflow policy

HCS
  - typed evidence and resource-budget substrate
  - policy/gateway for local host operations
  - operation-proof discipline for mutating proposals
  - audit, leases, dashboard, and broker integration when execute lane exists
```

## Compatibility principle

The CI system should not ask machines to "imitate GitHub Actions." It should
ask each job to run from a pinned, reproducible environment, regardless of
whether the scheduler places it on a laptop, a Proxmox VM, or GitHub-hosted
compute.

For each repo, the validation contract should be repo-owned scripts:

```text
scripts/ci.sh
scripts/ci-fast.sh
scripts/lint.sh
scripts/typecheck.sh
scripts/test.sh
scripts/build.sh
scripts/smoke.sh
```

or the repo's equivalent existing command surface (`just verify`, `make plan`,
`make validate-all`, etc.). GitHub YAML, local hooks, and agent workflows call
those scripts. YAML coordinates; it does not become the build system.

## HCS-side design

### Ring and ADR compatibility

This design touches Ring 3 now. It points to later Ring 0 and Ring 1 work only
if HCS needs first-class CI evidence entities or resource-budget enforcement.

Existing ADR coverage is sufficient for planning:

| Concern | Existing decision |
|---|---|
| HCS repo boundary | ADR 0001 |
| Hook call pattern and local guardrails | ADR 0007 |
| MCP resource/tool/prompt split | ADR 0010 |
| Public source, private deployment boundary | ADR 0011 |
| Credential broker and no universal secret read | ADR 0012 |
| GitHub/OpenTofu as external control planes | ADR 0015 |

A new ADR is not required for this report. A future ADR may be needed only if
HCS adopts CI coordination as a first-class knowledge/evidence plane rather
than treating it as ordinary external-control-plane evidence under ADR 0015.

### What HCS should own

HCS should own:

- semantic operation proposals for local host actions
- provenance, freshness, and authority for runner-related observations
- resource-budget observations for laptop and Proxmox pressure
- policy decisions about local host capabilities
- typed credential references and broker receipts
- leases for scarce local resources when execution broker exists
- audit trail for HCS-mediated local actions
- dashboard views summarizing local capability and runner health

HCS should not own:

- GitHub branch protection desired state
- GitHub runner group desired state
- OpenTofu state
- GitHub Actions workflow desired state
- Citadel OPA policy files
- GitHub-hosted status checks
- arbitrary shell execution of CI jobs

Those belong to GitHub/Citadel/repo-local contracts.

### CI as typed evidence

Runner-related data should become evidence, not untyped prose:

```text
RunnerHostObservation
  host, OS, architecture, labels, runner version, last_seen, group, repo access

RunnerIsolationObservation
  persistent VM, ephemeral VM, container, snapshot rollback, JIT runner,
  workspace cleanup result, cache mounts

WorkflowRunReceipt
  workflow, job, run_id, check name, conclusion, source app, commit SHA,
  runner labels, artifact ids, log retention

CleanRoomSmokeReceipt
  hosted runner label, script invoked, dependency install mode,
  result, artifact hash

ResourceBudgetObservation
  host load, memory pressure, runner queue depth, local cache pressure,
  network egress class, concurrency lease state

PolicyPlanReceipt
  OpenTofu plan hash, conftest result, policy ids evaluated, workspace,
  provider versions, state backend key
```

These can start as `Evidence` subtypes. Do not add new Ring 0 entities until
Phase 1 schema reconciliation decides whether these are entities or evidence
specializations.

### Operation shapes, not shell strings

The following are operation candidates, not canonical shell commands:

- register self-hosted runner
- deregister runner
- rotate runner registration token
- create or move runner group
- change runner-group repository access
- update workflow required checks
- approve production environment deployment
- run local CI fast path
- run Proxmox CI full path
- run hosted smoke sentinel
- roll back runner VM snapshot
- purge cache namespace
- collect runner diagnostics

Rendered shell commands or API calls are downstream `CommandShape` or provider
request renderings. HCS must not register a universal "run CI shell" capability.

### Policy posture

Policy belongs in Ring 1 and Citadel PaC, not in adapters or hooks.

HCS policy should reason about local host operations, for example:

| Operation | Suggested posture |
|---|---|
| Read runner status | read-only, allowed with provenance |
| Read workflow run status | read-only, allowed with provenance |
| Local fast validation | allowed, resource-budget aware |
| Proxmox full CI request | proposed operation; GitHub dispatch owns execution |
| MacBook manual ARM check | manual only; resource-budget aware |
| Runner registration/deregistration | mutating external-control-plane operation; approval required |
| Runner group access change | mutating external-control-plane operation; approval required |
| Running public fork code on self-hosted runner | forbidden/non-escalable policy candidate |
| Persisting personal credentials on CI host | forbidden/non-escalable policy candidate |
| Exposing Docker socket to untrusted workflow code | forbidden unless isolated by a stronger typed environment contract |

Actual tier entries should be drafted later through the HCS policy-tier workflow
and reviewed by the HCS policy reviewer before landing in system-config.

### Resource budgets

Runner jobs are a natural use case for `ResourceBudget`.

HCS should track:

- laptop CPU/memory pressure before local pre-push checks
- laptop battery/thermal state before optional heavy checks
- Proxmox runner concurrency
- per-runner-class queue depth
- package cache size and eviction age
- database/service container pressure
- network class and allowed egress
- GitHub Actions job queue age
- branch-criticality to decide whether to spend hosted minutes

Budget decisions should be advisory in the early stages. They become gate inputs
only after the policy/gateway path exists.

### Credential model

CI credentials must align with ADR 0012 and charter invariant 5:

- Store references, not secret values.
- Prefer GitHub App installation tokens over personal tokens.
- Prefer OIDC or short-lived delegated credentials where a provider supports
  them.
- Do not put personal SSH keys, 1Password sessions, or shell-exported personal
  tokens on runner hosts.
- Do not echo environment values during diagnostics.
- Do not pass secrets through command-line arguments where process inspection
  can expose them.
- Keep runner registration tokens ephemeral and out of OpenTofu state.

HCS broker integration can eventually support typed "credential needed for this
operation" decisions, but CI jobs should not gain direct access to a universal
secret-read tool.

## Citadel/OpenTofu/PaC-side design

### What Citadel should own

The Citadel is the correct owner for:

- GitHub repository definitions
- branch protection/rulesets
- GitHub environments and environment protection
- repository variables and action permissions
- runner group access policies where provider/API coverage permits
- workflow policy tests
- OpenTofu state/backend definitions
- Proxmox VM/container definitions if Proxmox IaC is adopted
- OPA policies that validate infrastructure plans and workflow posture

HCS can consume Citadel evidence. HCS should not become the desired-state store
for GitHub or Proxmox.

### Current gaps in Citadel

Inspected Citadel state already has self-hosted runner workflows, but the
planning report should account for these gaps:

- No Proxmox OpenTofu root/module was found in the inspected tree.
- Existing GitHub ruleset modules enforce reviews, linear history, commit
  patterns, and tags, but do not yet model required CI status checks.
- Existing PaC checks focus on OpenTofu plans for SEC-003/SEC-004 and do not
  yet validate GitHub workflow YAML safety rules.
- The current privileged IaC runner label is generic: `iac`.
- The workflows use `actions/checkout@v5`; current GitHub docs examples show
  `actions/checkout@v6`, but changing action versions should be a separate
  Citadel PR with compatibility evidence.
- The migration manifest notes credentials stored in gopass, while parent
  AGENTS says gopass is legacy migration residue. The runner design should
  prefer the current managed secret backend and treat any gopass dependency as
  migration debt.

### IaC target artifacts

Likely Citadel artifacts, staged over time:

```text
the-citadel/
  terraform/
    modules/
      github-rulesets/          # extend for required status checks
      github-actions-policy/    # if provider coverage is sufficient
      proxmox-runner-host/      # future, if Proxmox joins IaC scope
      runner-network-policy/    # future, provider-dependent
    orgs/
      the-nash-group/
        rulesets.tf
        repositories.tf
        actions.tf              # if split from repo definitions
      jefahnierocks/
        ...
  policies/
    opa/
      github-actions-workflow.rego
      self-hosted-runner-access.rego
      ci-cache-boundary.rego
  .github/
    workflows/
      opentofu.yml
      terraform-shield.yml
      drift-detection.yml
      runner-sentinel.yml        # optional, hosted clean-room sentinel
```

Provider coverage should be verified before promising a specific resource
shape. If OpenTofu provider coverage is missing for runner groups or access
policies, use a narrow bootstrap tool that emits receipts, then codify the
receipt and revisit provider support later. Do not hide long-lived imperative
scripts inside "IaC."

### PaC checks to add

OPA/workflow checks should eventually enforce:

- self-hosted runners only on private repos or explicitly trusted branches
- self-hosted workflows do not trigger on untrusted fork pull requests
- `pull_request_target` is not combined with untrusted checkout/execution
- self-hosted jobs declare group/labels instead of generic `self-hosted`
- privileged IaC jobs use a dedicated runner group and labels
- actions are pinned to approved major versions or immutable SHAs per policy
- workflow permissions are least-privilege and explicit
- production applies require GitHub environment protection
- PR plans cannot apply
- hosted smoke check exists for public-source repos
- Docker socket usage is either absent or isolated by a declared environment
- workflow scripts call repo-owned scripts instead of encoding build logic in YAML
- caches are scoped by repo, lockfile hash, OS, architecture, and trust level
- artifacts and plans have retention policies
- no secret-shaped values are written into logs, artifacts, argv, or state

### OpenTofu state constraints

OpenTofu state must not become a secret store.

For runner infrastructure:

- Store stable desired-state metadata in OpenTofu.
- Keep runner registration tokens out of state.
- Keep one-time runner bootstrap material out of state.
- Avoid storing private keys in `TF_VAR_*` values that persist to plan/state.
- Use repository or environment secrets only where unavoidable.
- Prefer GitHub App/OIDC flows for automation.
- Keep state versioning and lifecycle policy aligned with OpenTofu's S3 locking
  behavior.

The existing Hetzner S3 backend with `use_lockfile = true` is directionally
correct. The report's caution is that lock objects and state versions can
accumulate, so lifecycle and recovery policies need to be explicit.

## Repository trust classes

Treat repos differently by trust class.

| Class | Example | Self-hosted runner posture |
|---|---|---|
| Private privileged IaC | `citadel-config` | allowed with runner group, environment gate, no fork PRs |
| Public governance/docs | `the-covenant`, `.github` | hosted checks first; self-hosted only for trusted branches/manual if needed |
| Public HCS source | `host-capability-substrate` | do not run untrusted PRs on self-hosted runners |
| Private app/service | future private service repos | allowed after runner group and secret posture review |
| Public app/service | public website/library | hosted clean-room checks required; self-hosted optional for trusted branches |

The HCS repo is public-source by design. That makes a branch-protection design
that always requires a self-hosted check risky unless PRs are limited to trusted
branches. For public fork contributions, require hosted checks and run local
self-hosted checks only after a maintainer has moved or mirrored the change
into a trusted branch.

## Runner classes

Recommended labels and intent:

| Runner class | Labels | Purpose | Isolation target |
|---|---|---|---|
| `proxmox-ci-fast` | `self-hosted, linux, x64, proxmox-ci, fast` | lint, typecheck, unit tests | clean container or disposable workspace |
| `proxmox-ci-build` | `self-hosted, linux, x64, proxmox-ci, build` | builds, package tests | pinned image, controlled cache mounts |
| `proxmox-ci-db` | `self-hosted, linux, x64, proxmox-ci, db` | Postgres/Redis/integration tests | disposable compose stack or VM snapshot |
| `proxmox-ci-iac` | `self-hosted, linux, x64, iac` | OpenTofu plan/apply | private repos only, environment protection |
| `proxmox-ci-agentic` | `self-hosted, linux, x64, agentic` | heavier agent automation | separate VM, no production secrets |
| `macos-arm-manual` | `self-hosted, macOS, ARM64, macbook-manual` | rare macOS/ARM checks | manual `workflow_dispatch` only |

GitHub labels are cumulative, so every label in `runs-on` must match. Use that
property to separate runner intent instead of using one overloaded runner.

## Runner isolation

Minimum viable stage:

```text
one private Proxmox VM
restricted runner user
private repo access only
dedicated runner group
no personal SSH keys
no 1Password desktop/session dependency
no broad LAN access
no persistent workspace as an authority source
hosted smoke check required for clean-room proof
```

Target stage:

```text
GitHub job queued
  -> provision clean VM/container
  -> register ephemeral runner or JIT runner
  -> run one job
  -> upload logs/artifacts
  -> preserve runner app logs externally
  -> destroy VM/container or roll back snapshot
```

Persistent runners are acceptable only as a transitional stage. Persistent
workspaces, hidden home-directory state, global language installs, and shared
database state must not become reasons a job "passes."

## Caching

Good caches:

- package manager cache by lockfile hash
- OCI layer cache by image digest
- compiler cache by toolchain and source hash
- test fixture cache by fixture version
- local registry mirror with explicit retention

Risky caches:

- persistent repository workspaces
- shared `node_modules`
- database state reused across jobs
- mutable global language installs
- unscoped Docker volumes
- home-directory state shared across trust classes

HCS should model cache status as evidence with authority and freshness. A cache
hit can explain performance; it cannot prove correctness.

## Branch and status strategy

For HCS public-source work:

| Event | Required checks | Optional/trusted checks |
|---|---|---|
| local feature work | `just verify` or `scripts/ci-fast.sh` | full local suite |
| PR from fork | GitHub-hosted smoke / lint / typecheck subset | no self-hosted runner |
| PR from trusted branch | hosted smoke plus self-hosted full suite | Proxmox integration |
| push to dev | self-hosted integration if trusted | hosted smoke |
| PR to main | hosted smoke required, self-hosted full required only if trusted-source routing is solved | manual macOS/ARM if relevant |
| push to main | release/build/deploy checks | drift/sentinel checks |

For private Citadel/IaC:

| Event | Required checks |
|---|---|
| PR | hosted config validation plus self-hosted OpenTofu plan and OPA checks |
| push to main | environment-gated self-hosted apply |
| schedule | self-hosted drift detection |
| workflow_dispatch | scoped manual plan/drift/apply with approval |

Branch protection/rulesets should require named status checks from the expected
source app where possible. Avoid a check name that public fork PRs cannot ever
produce unless the repo intentionally blocks fork-based merging.

## Hosted clean-room sentinel

Every protected mainline should have at least one cheap hosted runner check.

Purpose:

- prove the repo is not dependent on local runner state
- prove a fresh checkout works
- catch missing files and uncommitted generated artifacts
- catch overly broad local assumptions about PATH, shell env, tools, or cache

For HCS this could be:

```yaml
jobs:
  hosted-smoke:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
      - run: ./scripts/ci/smoke.sh
```

The exact action version should follow the repo's version policy. Citadel
currently uses `actions/checkout@v5`, so any upgrade to v6 should be explicit.

## MacBook posture

The MacBook M3 Max is the right place for:

- fast local checks
- pre-push hooks
- manual reproduction
- macOS/ARM-specific validation
- OrbStack/devcontainer parity checks
- local agent experiments

It is the wrong place for:

- always-on persistent CI
- arbitrary PR execution
- privileged production secrets
- jobs that inherit personal browser/session/SSH/1Password state
- broad LAN-visible test execution

If a macOS/ARM runner exists, keep it:

```text
manual workflow_dispatch only
restricted labels
no default access by broad repos
no production secrets
resource-budget checked
logs/artifacts reviewed
```

## Network posture

Runner VM/network baseline:

- outbound HTTPS to GitHub domains required by runner functions
- outbound package registry access only where needed
- no public inbound exposure
- no broad access to home/admin VLANs
- no NAS access unless an explicit job requires it
- no SSH agent forwarding
- no personal SSH keys
- no mounted 1Password session
- no Docker socket to untrusted jobs
- separate runner users per runner class
- firewall labels/rules managed by IaC where possible
- logs shipped off-box before ephemeral destruction

GitHub self-hosted runners require outbound HTTPS over port 443 to communicate
with GitHub. Additional domains are needed for actions, logs, artifacts,
caches, OIDC, packages, and releases depending on workflow features.

## Agentic workflow compatibility

This design matches the Nash agentic workflow if:

- Parent-level agents write standards and orchestration, not repo internals.
- Repo agents modify only their repo.
- HCS work stays in HCS and does not mutate Citadel from this repo.
- Citadel changes reference Covenant principles and go through Citadel review.
- Agents run the same local scripts CI runs.
- Agents do not treat self-hosted runner success as stronger than hosted
  clean-room evidence.
- Agents preserve the distinction between retrieved docs, typed evidence,
  receipts, and human approval.

Agentic first principles for this design:

```text
Agents propose.
Scripts validate.
GitHub coordinates.
Citadel declares desired infrastructure.
PaC blocks known-bad shapes.
HCS records evidence and gates host capabilities.
Humans approve mutating authority.
```

## Implementation stages

### Stage 0 - Record decisions and inventory

Deliverables:

- this report
- Citadel runner inventory
- current workflow/ruleset gap list
- trust-class map for each repo
- no runtime changes

Exit criteria:

- human accepts or revises the target posture
- no self-hosted runner expansion before trust classes are documented

### Stage 1 - Repo-owned validation contracts

Deliverables:

- per-repo `scripts/ci*.sh` or equivalent `just`/`make` targets
- pre-push hooks call those scripts
- GitHub workflows call the same scripts
- hosted smoke sentinel exists for public-source repos

Exit criteria:

- local and hosted smoke paths agree on the same contract
- no YAML-only build logic

### Stage 2 - Citadel runner and ruleset modeling

Deliverables:

- runner group/access model in Citadel where possible
- required status checks in rulesets
- workflow PaC rules
- runner labels standardized
- action version policy clarified

Exit criteria:

- private privileged repos can require self-hosted checks
- public repos have a safe fork posture
- checks are tied to expected sources where practical

### Stage 3 - One hardened persistent Proxmox runner

Deliverables:

- dedicated VM
- restricted user
- network firewall baseline
- private repo runner group
- local cache policy
- log/artifact retention
- no personal credentials

Exit criteria:

- Citadel private IaC workflow works
- hosted smoke still required where appropriate
- drift detection remains reliable

### Stage 4 - Disposable environments

Deliverables:

- pinned CI base image
- disposable workspace/container/VM
- cache mounts by explicit keys
- snapshot rollback or one-job runner automation
- external runner app log forwarding

Exit criteria:

- repeated jobs produce same result from clean environment
- no persistent workspace authority

### Stage 5 - Ephemeral/JIT runners

Deliverables:

- ephemeral registration
- one-job lifecycle
- wipe/destroy automation
- token handling outside state
- runner logs preserved externally

Exit criteria:

- runner cannot receive a second job
- registration material is not retained
- cleanup receipt is visible

### Stage 6 - Autoscaling only if needed

Options:

- ARC if Kubernetes/k3s becomes a deliberate platform.
- GitHub Actions Runner Scale Set Client if Proxmox custom VM/container
  provisioning is preferred.
- Webhook-driven custom autoscaling only for low-volume transitional use.

Recommendation: do not start with Kubernetes. The scale set client is a better
long-term conceptual fit for Proxmox, but only after a normal runner is boring.

## Risks and controls

| Risk | Control |
|---|---|
| Public fork code compromises self-hosted runner | Do not route public fork PRs to self-hosted runners |
| Persistent workspace hides missing dependency | hosted smoke, clean checkout, disposable workspace |
| Runner host leaks secrets | no personal creds, no 1Password session, no secrets in argv/logs |
| GitHub token gains too much write access | explicit workflow permissions, GitHub App/OIDC preference |
| Branch protection requires impossible check | trust-class-specific required checks |
| Docker socket gives host root equivalent | remove socket or isolate with VM/container boundary |
| Cache poisoning | scoped cache keys and trust separation |
| OpenTofu state stores secret material | references only, no one-time tokens/private keys in state |
| Runner queue stalls indefinitely | class-specific capacity monitoring and timeout expectations |
| Self-hosted pass masks hosted failure | hosted sentinel required |
| MacBook CI inherits personal state | manual-only macOS/ARM runner |
| HCS duplicates Citadel policy | HCS consumes evidence; Citadel owns IaC/PaC desired state |

## Regression trap candidates

Potential HCS trap seeds if these failure modes appear in practice:

1. `public-fork-self-hosted-runner`
   Agent proposes a workflow where public fork PRs execute on self-hosted
   runners.

2. `macbook-ambient-credential-runner`
   Agent proposes always-on MacBook CI despite personal SSH/browser/1Password
   state.

3. `persistent-runner-workspace-authority`
   Agent treats a successful job on a reused workspace as stronger than hosted
   clean-room failure.

4. `ci-cache-promoted-to-evidence`
   Agent treats cache hit or local package state as correctness proof.

5. `runner-token-in-opentofu-state`
   Agent stores runner registration token or one-time bootstrap secret in IaC
   state.

6. `status-check-from-wrong-source`
   Agent accepts a status check name without verifying expected GitHub App or
   source.

7. `docker-socket-on-untrusted-runner`
   Agent exposes host Docker socket to arbitrary PR code.

8. `workflow-yaml-as-build-system`
   Agent duplicates repo validation logic into YAML instead of calling scripts.

These should not be added to the corpus until a concrete observed failure or
human-approved trap expansion justifies them.

## Compatibility matrix

| Layer | Desired owner | HCS compatibility rule |
|---|---|---|
| Covenant principles | The Covenant | HCS may cite as planning context, not subsidiary runtime inheritance |
| Citadel OpenTofu | The Citadel | HCS observes evidence; Citadel owns desired state |
| Citadel OPA | The Citadel | HCS does not duplicate PaC rules into hooks/adapters |
| GitHub Actions workflows | Each repo / Citadel for org standards | Workflows call repo-owned scripts |
| GitHub branch protection | Citadel OpenTofu | Required checks reflect trust class |
| GitHub self-hosted runners | Citadel/runner appliance | HCS treats runner state as external-control-plane evidence |
| Proxmox host | Future Citadel IaC or explicit ops runbook | HCS gates local host operations if mediated |
| MacBook checks | Local developer workflow | HCS resource-budget aware; manual runner only |
| Secrets | Managed secret authority and HCS broker refs | no values in repo, state, logs, argv |
| Audit/evidence | HCS runtime plus GitHub artifacts | typed receipts, source-ranked and freshness-aware |

## Recommendations

1. Adopt the paradigm, with the public-repo caveat.
   Self-hosted runners are a good fit for private trusted workloads and expensive
   local compute, not for arbitrary public fork code.

2. Treat Citadel's current `iac` runner as the first compatibility anchor.
   Do not build a second runner management plane in HCS.

3. Add hosted smoke checks before making self-hosted checks mandatory on public
   repos.

4. Extend Citadel rulesets to model required status checks before relying on
   branch protection for self-hosted gates.

5. Add workflow PaC before broad runner expansion.
   The first high-value rules are "no public fork to self-hosted," "explicit
   permissions," "trusted labels/groups," and "YAML calls scripts."

6. Harden one Proxmox runner before considering ARC, k3s, or scale-set client.

7. Move toward ephemeral/JIT runners as soon as the normal runner path is
   boring.

8. Keep the MacBook out of always-on CI.

9. Model runner and check results as HCS evidence, not as free-form memory.

10. Do not update action versions opportunistically.
    `actions/checkout@v6` appears in current GitHub docs examples, while
    Citadel currently uses v5. Upgrade through a normal Citadel PR with
    compatibility evidence.

## Open questions

1. Which repos should be allowed to consume the existing `iac` self-hosted
   runner group?

2. Should public HCS branch protection require only hosted checks, with
   self-hosted full CI as trusted-branch or maintainer-only?

3. Does Citadel want Proxmox managed by OpenTofu, or should Proxmox VM creation
   remain an explicit ops runbook until a provider/module is mature?

4. What is the current managed secret backend replacing gopass for Citadel CI
   secrets, and which references are canonical?

5. Should runner group and workflow safety policy land as Citadel OPA first or
   as HCS regression traps first?

6. Should HCS Phase 1 include CI-specific evidence subtypes, or wait until
   `ExecutionContext`, `ResourceBudget`, and external-control-plane entities are
   reconciled?

7. Should a GitHub App sentinel publish trusted status checks for self-hosted
   results, or should native Actions checks remain sufficient?

## Next concrete actions

For HCS:

- Keep this as planning input.
- Do not add schema entities yet.
- If a real failure occurs, add regression traps through the normal trap flow.
- When Phase 1 schema work begins, consider CI evidence as `Evidence` subtypes
  under ADR 0015 and ResourceBudget work.

For Citadel:

- Inventory existing runner host, labels, group, repo access, and secret
  posture.
- Decide trust classes for each repo.
- Add hosted smoke sentinel where public-source repos need clean-room proof.
- Draft workflow PaC checks.
- Extend GitHub rulesets for required status checks.
- Plan Proxmox runner host IaC only after deciding whether Proxmox belongs in
  Citadel's managed infrastructure scope.

For project repos:

- Ensure local scripts are the validation contract.
- Keep pre-push hooks and CI YAML calling the same scripts.
- Pin runtime/tooling versions in repo-owned files.
- Keep hosted smoke cheap but real.

## References

[^github-self-hosted]: GitHub Docs, "Self-hosted runners" - https://docs.github.com/en/actions/concepts/runners/self-hosted-runners

[^github-labels]: GitHub Docs, "Using self-hosted runners in a workflow" - https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/use-in-a-workflow

[^github-status-checks]: GitHub Docs, "About protected branches" - https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches

[^github-secure-use]: GitHub Docs, "Secure use reference" - https://docs.github.com/en/actions/reference/security/secure-use

[^github-ephemeral]: GitHub Docs, "Self-hosted runners reference" - https://docs.github.com/en/actions/reference/runners/self-hosted-runners

[^github-scale-set]: GitHub Changelog, "GitHub Actions: Early February 2026 updates" - https://github.blog/changelog/2026-02-05-github-actions-early-february-2026-updates/

[^opentofu-s3]: OpenTofu Docs, "Backend Type: s3" - https://opentofu.org/docs/language/settings/backends/s3/

## Change log

| Version | Date | Change |
|---|---|---|
| 1.1.0 | 2026-04-26 | Linked the staged proposed runner architecture report and made the HCS/Citadel/GitHub/Proxmox boundary explicit as companion input. |
| 1.0.0 | 2026-04-26 | Initial planning report for HCS/Citadel compatibility with local-first CI, GitHub self-hosted runners, OpenTofu IaC, and Policy-as-Code. |
