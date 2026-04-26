I would make the CI runner design **Proxmox-first, Linux-first, GitHub-orchestrated, policy-described, and only later ephemeral/autoscaled**.

Your uploaded planning report already has the right governing principle: local-first validation plus GitHub-orchestrated self-hosted runners plus a small hosted clean-room sentinel, with Citadel/OpenTofu/PaC owning desired infrastructure state and HCS consuming runner/check results as typed evidence rather than becoming a second CI control plane.  The companion research-plan document also supports treating this as source-bound planning first, with resource pressure, host capability, and evidence semantics verified before hard policy gates are introduced.

## The compatible runner architecture

Use this as the target model:

```text
GitHub
  event source, workflow scheduler, check/status surface, branch/ruleset gate

Citadel / OpenTofu / PaC
  desired runner access policy, repo trust class, rulesets, workflow policy

Proxmox / Beelink SER9
  canonical Linux x64 CI execution appliance

MacBook M3 Max / macOS Tahoe 26.4.1
  local dev validation, OrbStack parity checks, optional manual macOS/ARM lane

HCS
  observes runner health, run receipts, resource pressure, cache state,
  credential references, and approvals; does not execute arbitrary CI
```

The reason the Proxmox machine should be canonical is compatibility: GitHub workflows that use Docker container actions, job containers, or service containers require a **Linux** runner with Docker when self-hosted. GitHub documents this requirement directly for self-hosted runners and workflow container jobs. ([GitHub Docs][1])

That means the MacBook should not be the default CI runner, even though it is powerful. It should be the **developer-side reproduction and macOS/ARM compatibility lane**.

## First major design decision: VM runner, not Mac runner

For your hardware, I would build the first serious runner as:

```text
Proxmox VM: gha-proxmox-fast-01
  OS: Ubuntu LTS or Debian stable
  Arch: x64
  Runtime: Docker installed
  GitHub runner: organization-level or repo-level, restricted by runner group
  Labels: proxmox-ci-fast, linux, x64, trusted
  Purpose: lint, typecheck, unit tests, ordinary builds

Proxmox VM: gha-proxmox-iac-01
  OS: Ubuntu LTS or Debian stable
  Runtime: Docker installed only if needed
  Labels: proxmox-ci-iac, linux, x64, iac
  Purpose: OpenTofu plan/apply, OPA/Conftest, privileged Citadel jobs

Optional later:
Proxmox ephemeral runner template
  one job per VM/container
  runner registers with --ephemeral or JIT config
  logs forwarded externally
  VM destroyed or rolled back after job
```

GitHub supports self-hosted runners on Linux, Windows, and macOS, and supports `x64`, `ARM64`, and `ARM32` depending on OS, but it also explicitly says containerized workflows need Linux plus Docker. ([GitHub Docs][1]) So the MacBook can run the GitHub runner app, but it is not the compatible default for the kind of CI you likely want.

## The MacBook role

Your MacBook M3 Max on Tahoe should be treated as:

```text
local-fast-check host
manual macOS/ARM runner
OrbStack/devcontainer parity host
not the normal trusted CI appliance
```

GitHub’s self-hosted runner requirements support macOS 11.0 or later and ARM64, so a Tahoe/M3 Max self-hosted runner is plausible from GitHub’s runner-support standpoint. ([GitHub Docs][1]) But macOS is the wrong place for your main CI because container jobs and service containers require Linux/Docker in GitHub Actions, and because your personal workstation has ambient trust: SSH keys, browser sessions, editor state, personal files, 1Password or equivalent, and LAN access.

OrbStack is excellent for local reproduction. Its official docs expose CPU and memory controls, state that memory is released when no longer used, and document a default memory limit of no more than 8 GB. ([OrbStack Docs][2]) That makes OrbStack a good **developer mirror** for CI images, but not the durable organizational runner substrate.

A Mac runner should be manual-only:

```yaml
name: macOS ARM manual check

on:
  workflow_dispatch:

permissions: read-all

jobs:
  macos-arm:
    runs-on:
      group: tng-macos-manual
      labels: macbook-m3max-tahoe
    steps:
      - uses: actions/checkout@v6
      - run: ./scripts/ci-macos.sh
```

I would not make that check required for ordinary merges unless the repository truly ships macOS/ARM artifacts.

## Runner groups and labels

Use **runner groups for access control** and **labels for capability routing**.

GitHub documents that jobs can target runners by labels, by group membership, or by both; labels are cumulative, meaning the runner must match all labels requested. ([GitHub Docs][3]) It also recommends using runner groups to limit the blast radius of self-hosted runner compromise across repositories and workflows. ([GitHub Docs][4])

Recommended groups:

| Runner group             | Access                     | Purpose                                       |
| ------------------------ | -------------------------- | --------------------------------------------- |
| `tng-proxmox-private-ci` | private trusted repos      | normal full CI                                |
| `tng-proxmox-iac`        | Citadel/private IaC only   | OpenTofu, OPA, drift, apply                   |
| `tng-proxmox-agentic`    | private agentic repos only | heavier automation with no production secrets |
| `tng-macos-manual`       | selected repos only        | manual macOS/ARM verification                 |
| no self-hosted group     | public fork PRs            | hosted-only checks                            |

Recommended labels:

```text
proxmox-ci-fast
proxmox-ci-build
proxmox-ci-db
proxmox-ci-iac
proxmox-ci-agentic
macbook-m3max-tahoe
ephemeral
persistent
trusted
```

Avoid workflows that say only:

```yaml
runs-on: self-hosted
```

Use group plus an explicit capability label:

```yaml
runs-on:
  group: tng-proxmox-private-ci
  labels: proxmox-ci-fast
```

That expresses both trust boundary and execution capability.

## Canonical workflow pattern

For most repos, I would use this shape:

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main, dev]

permissions: read-all

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  hosted-smoke:
    name: hosted-smoke
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - run: ./scripts/smoke.sh

  proxmox-full:
    name: proxmox-full
    if: >
      github.event_name != 'pull_request' ||
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on:
      group: tng-proxmox-private-ci
      labels: proxmox-ci-fast
    container:
      image: ghcr.io/the-nash-group/ci-base@sha256:REPLACE_WITH_DIGEST
      options: --cpus 6
    steps:
      - uses: actions/checkout@v6
      - run: ./scripts/ci.sh
```

There are several intentional choices here.

First, `hosted-smoke` is cheap and hosted. GitHub-hosted runners are fresh VMs for normal hosted runner labels, and GitHub maintains the runner image and installed tools. ([GitHub Docs][5]) This check catches “works only on my Proxmox box” failures.

Second, the Proxmox job is skipped for fork PRs by default. GitHub warns that self-hosted runners do not provide the same clean ephemeral VM guarantee as hosted runners, can be persistently compromised by untrusted workflow code, and should almost never be used for public repositories. ([GitHub Docs][4])

Third, the Proxmox job runs inside a pinned container image. The runner host should be boring: GitHub runner app, Docker, logging, metrics, firewall. The job environment should be the reproducible part.

Fourth, `permissions: read-all` makes the default token posture explicit. GitHub recommends granting the `GITHUB_TOKEN` the minimum required permissions and notes that workflow/job `permissions` can be used to narrow access. ([GitHub Docs][6])

Fifth, the `concurrency` key prevents one branch from stacking redundant expensive local jobs. GitHub documents workflow/job concurrency as a way to ensure only one run or job in a group runs at a time and to cancel in-progress runs when a newer one starts. ([GitHub Docs][3])

## Public repo posture

For public-source repos, the safe design is:

```text
PR from fork:
  hosted-smoke required
  hosted lint/typecheck subset required
  no self-hosted runner

PR from trusted branch:
  hosted-smoke required
  proxmox-full allowed

push to main/dev by trusted actor:
  proxmox-full allowed
  hosted-smoke still required

manual maintainer check:
  proxmox-full may be run after review
```

Do not require a self-hosted check on public fork PRs unless you have a safe trusted-branch mirroring process. Otherwise, you create either a security problem or an impossible required check.

GitHub branch protections and rulesets can require status checks before merge and can restrict a required status check to an expected GitHub App/source. ([GitHub Docs][7]) Use that to make the hosted sentinel mandatory everywhere, and make self-hosted checks mandatory only where the trust class permits them.

## Private Citadel/IaC posture

For Citadel-style private IaC repos, I would use a stricter dedicated lane:

```yaml
name: citadel-iac

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: write
  id-token: write

concurrency:
  group: citadel-iac-${{ github.ref }}
  cancel-in-progress: false

jobs:
  plan:
    runs-on:
      group: tng-proxmox-iac
      labels: proxmox-ci-iac
    steps:
      - uses: actions/checkout@v6
      - run: ./scripts/iac/plan.sh
      - run: ./scripts/iac/policy.sh

  apply:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    needs: plan
    environment: production
    runs-on:
      group: tng-proxmox-iac
      labels: proxmox-ci-iac
    steps:
      - uses: actions/checkout@v6
      - run: ./scripts/iac/apply.sh
```

The dedicated `iac` runner group matters because self-hosted organization runners can be shared across repositories unless access is constrained, and GitHub specifically recommends runner groups to reduce compromise scope. ([GitHub Docs][4])

I would also keep registration tokens, one-time bootstrap secrets, SSH keys, and secret material out of OpenTofu state. Model stable desired state in Citadel; generate short-lived runner registration material at execution time.

## Persistent first, ephemeral later

The best final architecture is ephemeral, but the best first architecture is not.

Start with:

```text
one hardened persistent Proxmox VM runner
private/trusted repos only
no personal credentials
no broad LAN access
hosted smoke required
clean checkout
pinned CI container
controlled caches
aggressive cleanup
```

Then graduate to:

```text
GitHub workflow_job queued
  -> small runner manager provisions Proxmox VM from template
  -> VM obtains short-lived registration/JIT config
  -> runner processes exactly one job
  -> logs and artifacts are forwarded
  -> VM is destroyed or rolled back
```

GitHub supports ephemeral self-hosted runners with `--ephemeral`, automatically deregistering the runner after one job, and its docs recommend preserving runner logs externally for ephemeral production setups. ([GitHub Docs][1]) GitHub also documents JIT runners and warns that reused hardware still needs automation to ensure a clean environment. ([GitHub Docs][4])

For autoscaling, do not start with Kubernetes. GitHub documents Actions Runner Controller as the recommended Kubernetes solution for teams that already have Kubernetes expertise, while the newer Runner Scale Set Client is positioned for custom autoscaling across VMs, containers, on-prem infrastructure, and cloud services. ([GitHub Docs][1]) For your Proxmox/IaC style, the Scale Set Client or a small Proxmox-specific runner manager is the more natural later target.

## Proxmox VM sizing

Given 12 cores / 24 threads, 32 GB memory, and 4 TB fast SSD, I would start conservatively:

```text
gha-proxmox-fast-01
  8 vCPU
  14-16 GB RAM
  150 GB root
  500 GB cache/docker volume
  concurrency: 1 active job

gha-proxmox-iac-01
  4 vCPU
  6-8 GB RAM
  80-120 GB root
  no broad cache sharing
  concurrency: 1 active job

host reserve
  4-8 GB RAM
  enough CPU headroom for Proxmox/ZFS/networking
```

Do not try to use all threads immediately. CI reliability is usually better when the machine is undercommitted and predictable. Your 15 Gbps USB-C network is useful for local package mirrors, registry caching, and artifact movement, but the runner itself only needs outbound HTTPS to GitHub plus whatever package registries your workflows require. GitHub’s self-hosted runner communication requirements specify outbound HTTPS over port 443 and list required GitHub domains for actions, logs, artifacts, caches, and updates. ([GitHub Docs][1])

## Cache design

Use caches for speed, but do not let caches become correctness evidence.

Good:

```text
package manager cache by lockfile hash
OCI image/layer cache by digest
compiler cache by toolchain version
test fixture cache by fixture version
local GHCR/Docker registry mirror
OpenTofu plugin cache by provider/version
```

Avoid:

```text
persistent working directories as source of truth
shared node_modules across repos
shared database state
unscoped Docker volumes
mutable global toolchains
home-directory state shared across trust classes
```

In workflows, prefer:

```yaml
container:
  image: ghcr.io/the-nash-group/ci-base@sha256:REPLACE_WITH_DIGEST
```

over “install all tools directly on the runner host.” GitHub’s workflow syntax supports job containers and Docker resource options, but again those require Linux/Docker for self-hosted runners. ([GitHub Docs][3])

## Policy-as-code rules worth adding early

These are the highest-value PaC rules for the runner design:

```text
1. No workflow may use runs-on: self-hosted alone.
2. Self-hosted jobs must specify an approved runner group and approved label.
3. Public fork PRs may not route to self-hosted runners.
4. pull_request_target may not check out and execute untrusted PR code.
5. permissions must be explicit; default posture is read-all.
6. Privileged IaC jobs must use the iac runner group.
7. Apply/deploy jobs must require a protected environment.
8. Workflow YAML should call repo-owned scripts rather than embed build logic.
9. Container images for CI base environments must be pinned by digest for required checks.
10. Caches must be scoped by repo, OS/arch, lockfile/toolchain hash, and trust class.
11. Secrets must not appear in argv, logs, artifacts, OpenTofu state, or generated plans.
12. MacBook/macOS runner jobs must be workflow_dispatch only unless separately approved.
```

This aligns with your uploaded design: Citadel owns the desired policy shape, while HCS records evidence, resource observations, receipts, and policy-relevant facts rather than becoming the CI executor.

## HCS-compatible evidence model

For compatibility with your broader system, I would have every runner emit or make discoverable these facts:

```yaml
RunnerHostObservation:
  host_id:
  substrate: proxmox_vm | macos_host | ephemeral_vm
  os:
  arch:
  runner_version:
  group:
  labels:
  last_seen:
  repo_access_class:

RunnerIsolationObservation:
  runner_lifecycle: persistent | ephemeral | jit
  job_environment: host | container | disposable_vm
  workspace_cleanup:
  cache_namespaces:
  docker_socket_exposure:
  network_zone:

WorkflowRunReceipt:
  repository:
  workflow:
  job:
  run_id:
  commit_sha:
  event:
  actor:
  runner_group:
  runner_labels:
  conclusion:
  artifacts:
  log_location:

ResourceBudgetObservation:
  host:
  cpu_pressure:
  memory_pressure:
  disk_pressure:
  active_jobs:
  queue_depth:
  cache_size:
  observed_at:
```

The second uploaded document’s emphasis on resource pressure is directly relevant here. Your MacBook and Proxmox runners should not just run jobs; they should report enough resource information to explain why a job was allowed, delayed, capped, or skipped.

## Rollout order

I would stage it this way.

### Stage 1: Contract before infrastructure

Every repo gets boring validation entrypoints:

```text
scripts/smoke.sh
scripts/ci-fast.sh
scripts/ci.sh
scripts/ci-macos.sh
scripts/iac/plan.sh
scripts/iac/policy.sh
scripts/iac/apply.sh
```

GitHub YAML and local hooks call the same scripts.

### Stage 2: First hardened Proxmox runner

Create `gha-proxmox-fast-01`.

Minimum requirements:

```text
Linux VM
Docker installed
GitHub runner service
dedicated runner user
no personal SSH keys
no 1Password desktop/session dependency
outbound-only network
private/trusted repo access only
explicit runner group
explicit labels
log retention
cache retention
hosted smoke still required
```

### Stage 3: Dedicated IaC runner

Create `gha-proxmox-iac-01`.

This one gets stronger restrictions:

```text
Citadel/private IaC repos only
environment-gated apply
no public repo access
no general build/test jobs
no broad Docker volume sharing
no credentials outside managed secret flow
```

### Stage 4: Workflow PaC

Add rules that reject unsafe workflow shapes before expanding runner access.

The first hard blocks should be:

```text
public fork -> self-hosted
generic self-hosted label
implicit broad permissions
privileged job outside iac group
MacBook runner on non-manual trigger
secret-shaped env/log/state patterns
```

### Stage 5: Ephemeral runner pilot

Build a Proxmox template that can:

```text
boot
register runner with --ephemeral or JIT config
run exactly one job
ship logs
destroy itself or roll back
```

GitHub’s docs say jobs targeting unavailable self-hosted runner types queue rather than fail immediately and time out after 24 hours, so your ephemeral manager should include monitoring for queue depth and stale jobs. ([GitHub Docs][1])

### Stage 6: Autoscale only after boring reliability

Only after the one-runner path is boring should you consider:

```text
Runner Scale Set Client + Proxmox provisioning
or
ARC + k3s/Kubernetes
```

For your setup, I would prefer Runner Scale Set Client or a small Proxmox-specific runner manager before Kubernetes.

## The main compatibility traps

The traps I would explicitly prevent:

```text
MacBook becomes always-on org CI.
Public fork PRs run on Proxmox self-hosted runners.
Workflow requires a self-hosted check that fork PRs cannot safely produce.
Runner host accumulates hidden state that makes builds pass.
Docker socket is exposed to untrusted code.
OpenTofu state stores runner registration tokens.
A generic iac runner becomes available to non-IaC repos.
Hosted smoke is removed after self-hosted CI starts passing.
Workflow YAML becomes the build system instead of calling repo scripts.
```

## My concrete recommendation

Build this first:

```text
1. Proxmox VM: gha-proxmox-fast-01
   group: tng-proxmox-private-ci
   label: proxmox-ci-fast
   use: private/trusted full CI

2. Proxmox VM: gha-proxmox-iac-01
   group: tng-proxmox-iac
   label: proxmox-ci-iac
   use: Citadel/OpenTofu/OPA only

3. GitHub-hosted job: hosted-smoke
   required for all protected public/default branches

4. MacBook runner: macbook-m3max-tahoe
   group: tng-macos-manual
   trigger: workflow_dispatch only
   use: macOS/ARM compatibility, never ordinary CI

5. Citadel PaC:
   reject unsafe workflow/routing/permission patterns

6. HCS:
   record runner, workflow, resource, cache, and credential-reference evidence
```

That gives you most of the speed and cost savings immediately, while preserving the main correctness and security property: **GitHub remains the check authority, Proxmox does the heavy trusted work, hosted runners keep you honest, and the MacBook stays a powerful developer tool rather than an ambient-credential CI server.**

[1]: https://docs.github.com/en/actions/reference/runners/self-hosted-runners "Self-hosted runners reference - GitHub Docs"
[2]: https://docs.orbstack.dev/settings "Settings · OrbStack Docs"
[3]: https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions "Workflow syntax for GitHub Actions - GitHub Docs"
[4]: https://docs.github.com/en/enterprise-cloud%40latest/actions/reference/security/secure-use "Secure use reference - GitHub Enterprise Cloud Docs"
[5]: https://docs.github.com/actions/using-github-hosted-runners/about-github-hosted-runners "GitHub-hosted runners - GitHub Docs"
[6]: https://docs.github.com/en/actions/reference/security/secure-use "Secure use reference - GitHub Docs"
[7]: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets "Available rules for rulesets - GitHub Docs"
