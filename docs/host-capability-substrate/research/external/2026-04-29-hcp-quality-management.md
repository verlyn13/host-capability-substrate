# Quality-Management Requirements for the Host Capability Substrate (HCS) on macOS Tahoe

## 1. Executive Summary

The Host Capability Substrate (HCS) sits at the intersection of three poorly bounded surfaces: macOS Tahoe's evolving sandbox/TCC system, Git/GitHub's deeply pluggable identity and signing model, and the package-manager-and-shim ecosystem around Homebrew, mise/asdf, npm/pnpm/bun, pip/uv, and cargo. Each of these surfaces resolves the same question — "who is this process, what files can it see, and what credential will it present to GitHub?" — differently depending on whether the calling process was launched from Finder, from a terminal, from launchd, by a GitHub App, or by an MCP client. The dominant finding is that **none of these layers expose a single canonical truth**: Git config precedence cascades across at least six layers with conditional includes (official-doc); credential helpers can be silently overridden by Xcode CLT or Homebrew system gitconfigs (source-code-observation); GUI apps and terminal apps inherit different `PATH`, `HOME`, `SSH_AUTH_SOCK`, and TCC contexts (official-doc + inference); and `gh`'s multi-account keyring does not automatically rewrite the OS credential helper on `gh auth switch` (source-code-observation).

For HCS this means quality gates must be **evidence-backed bindings** between observable artifacts (worktree path, remote URL, SSH alias, signing key fingerprint, credential-helper invocation), not text inferences. Most agentic GitHub mutations should be **block** or **require-approval** by default, because (a) the active gh account, the credential helper that Git will actually invoke, and the SSH identity that 1Password's agent will choose can drift independently, and (b) for child/student/family-managed identities, account-creation and contractual constraints (Apple Developer Program age 18; Apple Family Sharing for under-18 since iOS/macOS 26; GitHub minimum age 13; Apple Developer Program for legal entity required for sole-proprietor/LLC; Texas SB2420 age-confirmation in effect since 2026-01-01) further constrain what HCS may safely do on behalf of the user.

The recommended Phase 1 schema centers on typed entities for hosts, accounts, repositories, worktrees, credential bindings, signing identities, package-manager provenance, and TCC/sandbox status, and on a quality-gate model with four policy tiers: observe, warn, block, require-approval.

## 2. Source and Evidence Method

This report uses only public/official documentation, vendor docs, and open-source code, per the user's scope. No machine inspection was performed. Where vendor-current documentation conflicts with older third-party guides, the vendor documentation is treated as authoritative. Each substantive claim is tagged with one of: `official-doc`, `source-code-observation`, `inference`, or `unverified`. The `installed-runtime-observation` and `local-config-observation` tags are intentionally not used. Versions referenced (current at research date 2026-04-29): macOS Tahoe 26.x (26.1, with 26.4/26.4.1 referenced in vendor articles); Git 2.x (2.40+ for SSH signing features, 2.33+ for 1Password Windows integration baseline); gh CLI 2.40+ for multi-account; Homebrew 4.x; 1Password 8.x with `op-ssh-sign`; mise current (2026.x); MCP authorization spec 2025-06-18 / 2025-11-25 draft.

## 3. macOS Filesystem and App-Layer Findings

**APFS behavior.** The macOS startup volume on Tahoe 26.1 is APFS in its case-insensitive (but case-preserving) variant by default; APFS also supports a case-sensitive variant, with iOS/Time Machine using case-sensitive (official-doc — Apple/Eclectic Light summary of macOS 26.1 file-system support). For Git this means renames that differ only in case can fail to register in the working tree on the default volume, producing false-clean working trees and surprising case-collision pulls (inference, widely documented in third-party sources). APFS supports cloning (copy-on-write), snapshots, sparse files, and extended attributes; it does **not** support directory hard links, which is relevant only for Time Machine (official-doc). Git worktrees on APFS will preserve symlinks, file modes, and most xattrs, but quarantine and provenance xattrs (`com.apple.quarantine`, `com.apple.macl`, `com.apple.provenance`) can be propagated through archive utilities and affect later launch behavior (official-doc — Apple developer forums/Eclectic Light on quarantine and translocation).

**Sandbox, TCC, Full Disk Access on Tahoe.** macOS Tahoe continues the sandbox/TCC model. App Sandbox is mandatory for Mac App Store apps and is opt-in for developer-ID-signed apps; entitlements are baked into the signature (official-doc — Apple App Sandbox, AppleInsider summary). TCC ("Transparency, Consent, Control") protects Documents, Desktop, Downloads, removable storage, and other categories, gating reads via `kTCCServiceSystemPolicyDocumentsFolder`, `kTCCServiceSystemPolicyAllFiles` (Full Disk Access), and per-folder Files & Folders entries (official-doc / source-code-observation — Apple TCC + Eclectic Light log analysis on Tahoe 26.4). Two non-obvious behaviors for HCS: (a) TCC's folder protections cover **directory listing and reads** but not POSIX-permitted writes (the eclecticlight April 2026 series demonstrates that an app without Documents access can still write into Documents if POSIX allows); and (b) once a user expresses intent through an Open/Save panel, the sandbox grant for that path is added out-of-band of the visible Files & Folders list (official-doc behavior; the article describes the discrepancy as expected per Apple's bug-report response).

**App container paths, group containers, Keychain access groups, LaunchServices, launchd.** Sandboxed apps run inside per-app containers under `~/Library/Containers/<bundle-id>/Data/`; explicit shared state uses Group Containers under `~/Library/Group Containers/<team-id>.<group-id>/` (official-doc). Keychain entries can be scoped to access groups defined in entitlements; this is how 1Password exposes its agent socket at `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` (official-doc — 1Password Developer Docs). LaunchServices is the binding mechanism Finder uses to open files/apps; an app launched through LaunchServices vs. directly via `exec` differs in TCC attribution chain and in whether App Translocation activates (official-doc — Apple Developer Forums / lapcatsoftware on App Translocation). Launchd jobs receive environment from the `EnvironmentVariables` dict in their `.plist`, not from interactive shell rc files (official-doc — Apple Developer Forums response).

**App translocation and quarantine.** Newly-downloaded `.app` bundles bearing the `com.apple.quarantine` xattr are translocated by LaunchServices to a randomized read-only path under `/private/var/folders/.../AppTranslocation/...` until the user moves the bundle in Finder; translocation does not happen for direct `exec` launches (official-doc — Apple TN; Eclectic Light analysis). For HCS, an "app-bundled agent" running under translocation may have a working directory bearing no resemblance to the user's `/Applications` path, breaking any heuristics that infer trust from path location.

**Finder-launched vs terminal-launched processes.** The two have materially different environments. Finder/LaunchServices launches inherit only what is configured at the system level (`/etc/paths`, `/etc/paths.d`, launchd plist `EnvironmentVariables`) and **do not** read `~/.zshrc`, `~/.zprofile`, `~/.bash_profile`, etc. (official-doc — Apple Developer Forums on launchd env; corroborated widely). Therefore: GUI apps generally do **not** see the same `PATH`, `HOME` is the same but `SSH_AUTH_SOCK` is set only if 1Password (or another agent) explicitly publishes a launchd-visible socket; `GITHUB_TOKEN`/`GH_TOKEN`/`GITHUB_PAT`/`GITHUB_PERSONAL_ACCESS_TOKEN` set in shell rc files are **invisible** to GUI apps (inference from launchd environment behavior). Terminal-launched commands, conversely, inherit Terminal.app's TCC attribution: granting Full Disk Access to Terminal effectively grants it to every script executed inside it (official-doc — Apple/ernw hardening guide).

**What HCS should require before trusting a GUI/agent's filesystem claims.** The minimum evidence set:
- Bundle identity: code-signing team ID, signing authority chain, hardened-runtime status, notarization status (official-doc — Apple Gatekeeper docs).
- Translocation status: real path vs. apparent path; presence and value of `com.apple.quarantine` xattr.
- Sandbox status: whether `App Sandbox` entitlement is present, what file/folder entitlements are declared, what TCC services have been granted (kTCCServiceSystemPolicyAllFiles, kTCCServiceSystemPolicyDocumentsFolder, etc.).
- Container scope: whether writes are reaching the real target path or a per-app container redirect.
- Launch context: PID's parent process and launchd job label, to distinguish Finder/LaunchServices vs. terminal vs. ssh vs. cron vs. agent socket.
- Effective environment: actual `PATH`, `HOME`, `SSH_AUTH_SOCK`, `GIT_*` envs at the moment of the claim.

## 4. GitHub/Git Toolchain Findings

**Git config precedence on macOS.** The official precedence order is: system (`$(prefix)/etc/gitconfig`), XDG global (`$XDG_CONFIG_HOME/git/config`, defaulting to `~/.config/git/config` if `XDG_CONFIG_HOME` is unset), user global (`~/.gitconfig`), repo local (`.git/config`), worktree config (`.git/config.worktree` when `extensions.worktreeConfig` is enabled), and `-c` overrides; later files win (official-doc — `git-config(1)`). `include.path` and `includeIf` are evaluated inline, so an include placed at the bottom of a file effectively overrides earlier values (official-doc). `includeIf` conditions include `gitdir:`, `gitdir/i:` (case-insensitive matcher relevant on default APFS), `onbranch:`, and (forward-compatible) `hasconfig:remote.*.url:` (official-doc).

**Multiple Git binaries.** macOS workstations commonly host several distinct Git binaries: Apple's Xcode CLT git at `/Applications/Xcode.app/Contents/Developer/usr/bin/git` (with system gitconfig at `/Applications/Xcode.app/Contents/Developer/usr/share/git-core/gitconfig`), Homebrew git at `/opt/homebrew/bin/git` on Apple Silicon or `/usr/local/bin/git` on Intel (with system gitconfig at `/opt/homebrew/etc/gitconfig` or `/usr/local/etc/gitconfig`), and possibly mise/asdf-shimmed git or app-bundled gits inside GitHub Desktop, IDEs, and Tower (source-code-observation — `lowply.github.io` analysis; official-doc — Homebrew Installation page on prefixes). Each has its own system-level config that can silently set `credential.helper = osxkeychain` or other defaults (source-code-observation).

**Credential helpers on macOS.**
- `osxkeychain`: stores HTTPS credentials in the macOS Keychain as Internet passwords keyed on `github.com`; ships with Git built into Xcode CLT and is set as the system-level credential helper in both Xcode CLT's and Homebrew's `gitconfig` (official-doc — git-scm credential-helpers; source-code-observation — lowply analysis).
- Git Credential Manager (GCM): cross-platform helper that stores in Keychain on macOS and Credential Manager on Windows, supports OAuth and 2FA (official-doc — git-scm Credential Storage; GitHub Docs).
- `gh auth git-credential` (the gh CLI integrating itself as a Git credential helper): set up via `gh auth setup-git`; reads from `gh`'s own keyring entry for the active account (official-doc — gh CLI multi-accounts.md).
- `cache`/`store` (in-memory cache or plain-text file): rarely correct on a developer workstation but possible (official-doc).

Multiple helpers can be configured simultaneously; Git asks each in turn, and the **first** to return credentials wins on read; **all** receive store/erase on write (official-doc — git-scm Credential Storage). This is the subtle failure mode: with both `osxkeychain` and `gh` configured, the keychain entry can outlive `gh auth logout` because gh only deletes its keyring entry, not the OS Keychain entry (source-code-observation — lowply).

**SSH host aliases and Git remotes.** OpenSSH's `ssh_config` allows arbitrary `Host` aliases that override `HostName`, `User`, `IdentityFile`, and `IdentityAgent`; a remote URL like `git@github-personal:owner/repo.git` selects the `github-personal` block (official-doc — `ssh_config(5)`). Combined with Git's `url.<base>.insteadOf`, this is the standard mechanism for binding a directory tree to a particular SSH identity (corroborated by 1Password and Xebia documentation; inference for HCS).

**SSH commit signing and 1Password.** Git's SSH signing format is enabled by `gpg.format = ssh` and `user.signingkey = <pubkey>`; signature verification is governed by `gpg.ssh.allowedSignersFile` (official-doc — `git-config(1)`/`gitformat-signature(5)`). 1Password's flow injects `gpg.ssh.program = /Applications/1Password.app/Contents/MacOS/op-ssh-sign` and provides the signing key via the 1Password SSH agent socket at `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` (official-doc — 1Password Developer SSH/Git docs). For GUI Git clients (GitHub Desktop, Tower, etc.), `SSH_AUTH_SOCK` must be exported to the GUI launch context — most often via launchd plist or app-specific environment plist — because Finder-launched apps do not inherit `~/.zshrc` (official-doc — Tower blog; inference). On a remote host accessed by SSH agent forwarding, `op-ssh-sign` is **not** present and signing fails unless reconfigured (official-doc — 1Password community thread).

**GitHub side: branch protection, rulesets, required signatures.** Two parallel mechanisms exist: classic branch protection rules (per-branch, single-rule-per-branch) and rulesets (multiple, layered, can target branches/tags/pushes; available at organization scope on GitHub Team/Enterprise) (official-doc). Both can require signed commits, required reviews, required status checks, linear history, restricted actors, and code-scanning gating; required commits-signing relies on GitHub's `verified_signature?` check, which depends on the registered SSH/GPG/S/MIME signing keys for the author (official-doc). Push rulesets cover the entire fork network and are inherited by forks (official-doc).

**Recommended typed binding for HCS.** The smallest sufficient binding to avoid wrong-account commits and unsigned/wrong-signed pushes connects: `worktree path → effective Git config (resolved through full include chain) → remote URL → SSH alias (if any) → resolved hostname/user/IdentityFile/IdentityAgent → active SSH key fingerprint(s) presented by agent → signing program (`gpg.ssh.program`) → signing key fingerprint → GitHub account that has registered that key as a signing key → which credential helper(s) are configured and in what order → which credential helper actually responded for the last HTTPS exchange → GitHub repository owner/name and current branch protection/ruleset state including required-signatures and required-checks → GITHUB_TOKEN/GH_TOKEN environment overrides currently in scope`. This entire chain is the canonical "GitHub identity provenance" that HCS must materialize as typed evidence, not as prose or shell-string output.

## 5. Terminal and Package-Manager Findings

**Homebrew.** On Apple Silicon the prefix is `/opt/homebrew`; on Intel it is `/usr/local`; on Linux/WSL `/home/linuxbrew/.linuxbrew` (official-doc). The prefix is required for binary bottles. Homebrew is enabled by `eval "$(/opt/homebrew/bin/brew shellenv)"`, normally in `~/.zprofile`, which sets `HOMEBREW_PREFIX`, `HOMEBREW_CELLAR`, `HOMEBREW_REPOSITORY`, `PATH`, `MANPATH`, `INFOPATH` (official-doc). Homebrew's per-prefix `etc/gitconfig` sets `credential.helper = osxkeychain` (source-code-observation). Homebrew is single-user and refuses sudo (official-doc).

**mise / asdf shims.** mise's data directory is `~/.local/share/mise` with shims at `~/.local/share/mise/shims`, cache at `~/Library/Caches/mise`, config at `~/.config/mise/config.toml`, state at `~/.local/state/mise` (official-doc — mise.jdx.dev FAQ + `mise doctor` output samples). With `mise activate`, mise mutates `PATH` on prompt-display via `mise hook-env`; in non-interactive contexts (cron, agents, GUI launches) `PATH` will not be updated unless `mise x` is used or shims are explicitly added to `PATH`; `shims_on_path: no` is the default unless the user has added `~/.local/share/mise/shims` directly (source-code-observation — multiple GH discussions). asdf installs to `$ASDF_DATA_DIR` (default `~/.asdf`) with shims at `~/.asdf/shims`; same prompt-hook caveat (official-doc — asdf-vm.com).

**npm/pnpm/bun, pip/uv, cargo.** Configs and caches live in well-known paths (official-doc):
- npm: config at `~/.npmrc`, cache at `~/.npm`, global prefix per `npm config get prefix`.
- pnpm: store at `~/Library/pnpm/store` (macOS) or `~/.pnpm-store`; config at `~/.npmrc` and `~/.config/pnpm`.
- bun: install at `~/.bun`, config at `~/.bunfig.toml`.
- pip: config at `~/Library/Application Support/pip/pip.conf` (macOS) or `~/.pip/pip.conf`; cache under `~/Library/Caches/pip`.
- uv: cache `~/.cache/uv` (or `~/Library/Caches/uv`), config under `~/.config/uv`.
- cargo: home `~/.cargo`, config `~/.cargo/config.toml`, cache under `~/.cargo/registry` and `~/.cargo/git`.

**Credential surfaces in package managers.** `npm` and `pnpm` use bearer `_authToken` lines in `.npmrc` (per registry); pip uses keyring integration when configured; cargo uses `~/.cargo/credentials.toml` (official-doc — respective package manager docs). Some tools (Homebrew, certain CLIs) use keychain for OAuth tokens; many do not. Browser-OAuth flows are common for `gh`, certain Claude/Anthropic CLIs, and various cloud SDKs (official-doc).

**What package-manager tools can and do mutate.** Numerous CLIs mutate global Git config (e.g., installation hooks adding `core.hooksPath`, `init.defaultBranch`, or credential helpers); install or modify Git hooks under `core.hooksPath` or `.git/hooks/`; create or modify `.npmrc`, `.python-version`, `.tool-versions`, `mise.toml`; and write env files (`.envrc` for direnv) at repo root. Some CLIs explicitly call GitHub APIs (the gh CLI itself, `act`, release helpers), can create releases, modify Actions secrets, or change branch protection if given sufficient token scopes (official-doc — gh manual; inference for "third-party CLI behavior is heterogeneous").

**Provenance facts HCS should capture before trusting a CLI.** For each CLI invocation HCS treats as load-bearing:
- Source backend: Homebrew formula (with version, bottle hash, tap), npm/pnpm/bun package + version + integrity hash, pip/uv distribution + hash, cargo crate + version + checksum, mise/asdf plugin + version, vendor `.pkg`, Mac App Store, or app bundle.
- Real binary path resolved through any shim chain; whether that path is shim-managed and which shim resolved it.
- Code-signing identity for binaries inside `.app` bundles or signed Mach-O binaries.
- Quarantine/translocation status.
- Whether the CLI is configured to read a credential or an env var, and which.
- Whether the CLI mutates global Git config, Git hooks, GitHub repo settings, GitHub Actions, or releases.

## 6. Multiple-GitHub-Identity Findings

**Multiple gh accounts.** Since gh 2.40, `gh auth login` is additive across accounts on the same host; `gh auth status`, `gh auth switch`, `gh auth token --user`, `gh auth logout --user` operate on the active account or a specified one (official-doc — cli/cli `multiple-accounts.md`). Tokens are stored in the OS keyring (Keychain on macOS) when available. Critically, `gh auth switch` does **not** automatically rewrite the OS-level Git credential helper's stored token: if the user has both `osxkeychain` and `gh` configured, an `osxkeychain` entry from a prior account can keep authenticating Git HTTPS as the wrong user (source-code-observation — cli/cli issue #8875). There is no built-in env-var-driven multi-account switch comparable to `AWS_PROFILE` (`GH_USER` is a requested feature, not implemented as of the referenced issue; source-code-observation — cli/cli issue #12145).

**Multiple SSH identities and host aliases.** Users typically declare per-tenant aliases (`Host github-personal`, `Host github-work-acme`, etc.) in `~/.ssh/config`, each with its own `IdentityFile` and possibly its own `IdentityAgent`. Combined with `url.git@github-work-acme:org/.insteadOf = git@github.com:org/`, this binds repository URLs to identities (official-doc — `ssh_config(5)`; corroborated by 1Password and Xebia guides). 1Password's SSH agent provides up to six keys to a server before hitting OpenSSH's authentication-attempt limit; bookmarks/`IdentityFile` constraints are required to disambiguate when more keys are configured (official-doc).

**Multiple GitHub MCP identities.** The Model Context Protocol authorization spec (2025-06-18, refined 2025-11-25 draft) treats MCP servers as OAuth 2.1 resource servers with discovery via `.well-known/oauth-protected-resource` (RFC 9728) and authorization via separate authorization servers; HTTP-based transports SHOULD use OAuth, while STDIO transports should use credentials from the environment (official-doc — modelcontextprotocol.io). GitHub's MCP registry supports two GitHub-backed flows: GitHub OAuth (browser) and GitHub Actions OIDC (source-code-observation — modelcontextprotocol/registry GitHub authentication). Each MCP client maintains separate registration state per authorization server (official-doc).

**Workspace `.envrc` overrides.** `direnv` and similar tools can set `GH_TOKEN`, `GITHUB_TOKEN`, `GITHUB_PAT`, `GITHUB_PERSONAL_ACCESS_TOKEN` per directory. Both `gh` and most third-party tooling honor these env vars over keyring contents; with `direnv`, a stale token bound to a different identity is a regression-trap (inference; `gh` documents that env tokens override stored tokens — official-doc).

**`includeIf gitdir` for per-tree author identity.** Per-tree author email and signing key are commonly set by adding `[includeIf "gitdir:~/code/work/"] path = ~/.gitconfig-work` to global config, with the include file overriding `user.email`, `user.signingkey`, `core.sshCommand`, `gpg.ssh.program`, etc. (official-doc — `git-config(1)` Conditional includes; corroborated widely).

**Mixed-account scope (personal + business + school + org/automation + child/dependent).**
- Personal and sole-proprietor/LLC business: GitHub treats both as user accounts; LLC-owned repos typically belong to a separate Organization. Business workflows should prefer GitHub App installations or fine-grained PATs scoped to the org for automation, not user PATs (official-doc — github.blog "Introducing fine-grained PATs"; bmterra "Time to move to Github Apps").
- School/student accounts: GitHub Education/Student Developer Pack requires the user to be ≥13 (or local minimum age), enrolled, and to use the account for non-commercial purposes during studies (official-doc — docs.github.com Education). Student status is verified for two years and revalidates.
- Organization/automation accounts: GitHub Apps are the recommended automation mechanism (own identity, fine-grained permissions, short-lived installation tokens, dedicated rate limits) over user PATs or "machine users" (official-doc — docs.github.com "Deciding when to build a GitHub App"). Deploy keys are read-only by default, single-repo, no expiry, not tied to a user; suitable for narrow CI deploy paths but not for cross-org automation (official-doc — docs.github.com "Managing deploy keys"). For CI-to-cloud authentication, GitHub Actions OIDC trust policies issue short-lived JWTs with claims (`repo`, `sub`, `ref`, `actor`, `environment`) that downstream systems exchange for cloud credentials, eliminating long-lived secrets (official-doc — docs.github.com OpenID Connect docs).
- Child/dependent accounts under family management: Apple's Family Sharing model in macOS Tahoe 26 / iOS 26 requires Apple Accounts for children under 13 to be created by a Family Sharing organizer or parent/guardian and to remain part of a Family Sharing group (official-doc — support.apple.com 102617, 102033, 119854). New accounts for users under 18 are joined to Family Sharing by default in regulated regions (official-doc — Apple newsroom 2025-06; Apple Developer news on Texas SB2420 effective 2026-01-01 confirming this behavior is enforced for new Texas accounts and that parents/guardians must consent to App Store transactions). The Apple Developer Program contractually requires legal age of majority (commonly 18 in U.S. states); minors aged 13–17 may use a parent/guardian's developer account under supervision per the Registered Apple Developer Agreement, and a parent/guardian may submit on behalf of a developer 13+ for things like the Swift Student Challenge (official-doc — Apple Developer Forums thread referencing the Registered Apple Developer Agreement and forum #728084). GitHub's minimum age for an account is 13 (or local minimum); the GitHub Student Developer Pack mirrors that (official-doc — education.github.com/pack/join). Together, the practical implication is that a child-managed device may have an Apple Account that cannot legally hold an Apple Developer Program membership in its own name, but **can** hold a GitHub user account ≥13 with a Student Developer Pack — and HCS must not assume Apple-developer-equivalent capabilities track GitHub-account capabilities for family-managed identities.

**What HCS should treat as forbidden / approval-required / evidence-required for agentic GitHub mutations.**
- **Forbidden by default**: pushing to a default branch directly; force-pushing to any protected branch; modifying branch protection or rulesets; modifying repo visibility; deleting branches/tags marked protected; rotating SSH or signing keys in 1Password or Keychain; writing to MCP server config; changing `gh` active account; modifying Actions workflow files in protected branches; creating Actions secrets, environments, or deploy keys; creating releases; modifying CODEOWNERS; modifying `SECURITY.md`; creating/regenerating PATs; modifying `~/.ssh/config`; modifying global `~/.gitconfig` (only repo-local mutations may be candidate-allowed).
- **Require approval**: opening a PR; pushing a feature branch; commenting on PRs/issues that mention security; merging a PR; running a workflow_dispatch; running `gh repo create`; creating issues that reference secrets or vulnerabilities; any operation against repos owned by a child/dependent's account; any operation against a school-owned org by a student-pack account that is not the user's own personal repo.
- **Evidence-required (block until HCS has fresh provenance)**: any push or PR creation must have current evidence of (a) the active gh account, (b) the resolved Git author email, (c) the resolved signing key fingerprint with verification it is registered as a signing key for that account, (d) the Git remote owner/repo, (e) the credential helper that will respond, (f) current branch protection/ruleset state including required-signatures and required-checks, (g) Actions permissions for that token, (h) absence of `.envrc`/env-var token shadowing inconsistent with the active gh identity.

## 7. Quality-Management Requirements for HCS

**Local quality gates HCS must model:**
- Identity-binding gate: every load-bearing GitHub action presents a complete typed binding from worktree path to GitHub account, signed by the credential helper that will actually respond.
- Credential-shadow gate: detect any case where two helpers can answer for the same host, where keychain-stored credentials disagree with `gh`'s active account, or where env-var tokens shadow keyring credentials.
- Signing-identity gate: detect any case where `user.signingkey`, `gpg.ssh.program`, `gpg.ssh.allowedSignersFile`, and the active 1Password agent's published keys are not internally consistent with the configured Git author email and the GitHub account that owns it.
- Filesystem-trust gate: refuse to act on filesystem claims from a process whose translocation, sandbox, container, and TCC status have not been observed.
- Mutation-class gate: classify the proposed mutation against the policy tier matrix.
- Freshness gate: refuse to act on stale evidence beyond per-type windows (see §11).

**GitHub-side gates HCS should expect or verify:**
- Branch protection or ruleset on `main`/release branches with: required PR, required reviews (≥1), required signatures, required status checks (named), restrict force-push, restrict deletions, optionally require linear history, optionally require deployment to environment.
- Required signatures aligned with the user's signing key registered on GitHub (official-doc — required_signatures REST endpoint).
- Actions permissions: minimum required `permissions:` block per workflow; `id-token: write` only where OIDC is used; `GITHUB_TOKEN` scoped least-privilege.
- Environments with deployment protection rules (required reviewers, wait timers, branch restrictions) for production deploys.
- CODEOWNERS file present, with security-sensitive paths covered.
- Secret scanning enabled (push protection where Advanced Security is licensed); Dependabot alerts and version updates enabled; SECURITY.md present with reporting policy.
- For organization-managed repos, organization-level rulesets with bypass list limited to dedicated GitHub Apps.

**Local preflight checks before agentic GitHub work:** identity-binding present and fresh; credential-shadow clean; signing-identity consistent; filesystem-trust adequate for the worktree path; remote owner/repo state recently fetched; branch-protection/ruleset state recently fetched; mutation classified and approved per policy tier.

**HCS-specific lens — what HCS can safely observe:** read-only file presence and metadata (existence, mtime, mode, xattr names without values), the resolved value of Git config keys via `git config --show-origin` semantics (read-only), structural facts about `~/.ssh/config` (host blocks, no key material), the names of Keychain items and their service/account fields (no secret values), the names of 1Password items and their fingerprints (no secret values), the set of `gh` accounts present in keyring and which is active (names only), GitHub API responses for repo state, branch protection, rulesets, and Actions permissions, MCP server discovery metadata (no tokens), `mise doctor`-style structural facts, Homebrew prefix and tap manifests.

**What HCS must never infer:** a credential helper's behavior from its name alone (must observe what helper Git actually invokes), an SSH key's owner from its filename, a signing key's GitHub registration from local config alone (must verify against GitHub), a child/dependent account's developer-program eligibility from its GitHub age field alone, the freshness of any GitHub-side state beyond its observed `Last-Modified`/`ETag`.

**What requires typed provenance:** every binding listed in §4's "GitHub identity provenance" chain; every package-manager-installed CLI's source backend; every TCC/sandbox grant.

**What requires human approval:** every mutation classified `require-approval` in §6.

**What should be forbidden:** the items listed under "Forbidden by default" in §6.

**What should be delegated to GitHub / Citadel / system-config rather than owned by HCS:** branch protection and rulesets (GitHub); required signatures enforcement (GitHub); secret-storage (Keychain, 1Password); SSH agent (1Password or system ssh-agent); credential helper choice (system-level Git config or user choice); MCP authorization (per the MCP spec, delegated to authorization servers); long-lived secret rotation (Keychain/1Password/Citadel); Apple Family Sharing parental controls (Apple); Apple Developer Program contractual identity (Apple); GitHub Education student verification (GitHub).

**What should become Phase 1 schema work:** the named entity/evidence types in §8 and the policy-tier matrix in §9.

## 8. Candidate Evidence/Entity Model

Named entity/evidence types with brief field lists only. No relations, no freshness windows, no pseudocode, no example records.

**Host entities**
- `Host`: hostname, hardware UUID, macOS version, build, architecture, SIP status, Gatekeeper status.
- `Volume`: mountpoint, filesystem, APFS role, case-sensitivity flag, encryption status.
- `User`: short name, UID, primary group, home directory, default shell.
- `LaunchContext`: launchd job label, parent PID, launch source (Finder, Terminal, ssh, cron, agent), inherited env keys (names only).

**App and process entities**
- `Bundle`: bundle ID, version, signing team ID, signing authority chain, hardened-runtime flag, notarization status, real path, apparent path, translocation status, quarantine xattr presence.
- `SandboxContext`: app sandbox flag, declared file/folder entitlements, container path, group-container memberships, Keychain access groups.
- `TCCGrant`: service name, granted target bundle/path, allow/deny, source (consent/intent/FDA), last-modified observation.
- `Process`: PID, executable real path, parent PID, EUID, working directory, env-var key set (names only), SSH_AUTH_SOCK presence.

**Filesystem entities**
- `Path`: absolute path, parent, name, kind (file/dir/symlink), POSIX mode, owner, group, xattr name set (names only), is-on-protected-folder flag.
- `Worktree`: root path, .git path, is-bare flag, is-worktree-of-shared-repo flag, `extensions.worktreeConfig` flag.

**Git/GitHub entities**
- `GitInstall`: binary real path, version, source (Xcode CLT, Homebrew, mise, vendor), system gitconfig path.
- `GitConfigLayer`: scope (system, XDG, global, local, worktree, command-line), source path, included-via path (if from include/includeIf), condition expression (if includeIf).
- `GitConfigEffectiveValue`: key, value, winning layer, full layer chain (names only).
- `GitRemote`: name, fetch URL, push URL, host, owner, repo, transport (https/ssh/git), inferred SSH alias (if any).
- `SshHostBlock`: alias, hostname, user, identity files, identity agent socket, proxy commands (presence only).
- `SshAgentClaim`: agent socket path, key fingerprint, key comment, key type.
- `SigningIdentity`: key fingerprint, key type, signing program path (`gpg.ssh.program`), allowed-signers-file path, registered-on-github flag, registered-account.
- `CredentialHelper`: helper command, declaring config layer, order in helper chain.
- `CredentialBinding`: host, account name, helper that responded, response source (keychain item name, gh keyring user, env-var name), response was-fresh flag.
- `GhAccount`: hostname, username, active flag, token-source (keyring/env), token-scopes (names), git-protocol preference.
- `GitHubAccount`: login, account-type (user/org/educational/family-managed), age-bracket-flag (≥18, 13–17, <13 if known), signing keys registered (fingerprints), authentication keys registered (fingerprints), is-org-member-of (orgs).
- `GitHubApp`: app slug, owner, installation ID, repository scope, permission set, installation token issuer.
- `GitHubRepo`: owner, name, default branch, visibility, fork flag, parent (if fork), branch-protections (summary), rulesets (summary), required-checks (names), required-signatures flag, Actions permissions, environments (names), CODEOWNERS presence, SECURITY.md presence, secret-scanning enabled flag, push-protection enabled flag, Dependabot alerts/security/version-updates enabled flags.
- `Branch`: repo, name, head SHA, protection status, ruleset matches, last-fetched-at observation.
- `Commit`: SHA, author, committer, signature presence, signature key fingerprint, signature verified-by-GitHub flag.
- `PR`: repo, number, head, base, author, mergeability, required-checks status, required-reviews status, signed-commits status.
- `MCPServer`: server URL or stdio command, transport, authorization-server discovery URL, scopes-required, current-account binding, token-source.

**Package-manager and tool entities**
- `Pkg`: backend (brew/npm/pnpm/bun/pip/uv/cargo/mise/asdf/vendor-pkg/MAS/app-bundle), name, version, integrity hash (where backend provides one), source registry/tap, install path.
- `Shim`: shim path, shim-managing tool, target binary path, resolution rule.
- `ToolConfig`: tool, config path, scope (user/repo/system), watched keys (names only).
- `ToolMutationClaim`: tool, target (global gitconfig / repo gitconfig / hooks / repo files / GitHub API), claim source (docs/observed call), risk class.

**Quality and policy entities**
- `EvidenceClaim`: subject entity, predicate (typed), value, source kind, freshness observation.
- `QualityGate`: name, evidence inputs, success predicate, failure tier.
- `PolicyDecision`: gate, mutation class, tier (observe/warn/block/require-approval), bypass actor (if any).
- `ApprovalRequest`: mutation, evidence bundle (entity references), requesting agent identity, human approver, decision.
- `RegressionTrap`: monitored entity field set, expected-value contract, last-observed value.

## 9. Candidate Policy Rules and Forbidden Patterns

Concise rules. Tiers: **observe** (record-only), **warn** (visible to user), **block** (refuse), **require-approval** (human-in-the-loop).

**Forbidden (block):**
- Any direct push to a default or release branch.
- Any force-push to a protected branch or branch matched by an active push ruleset.
- Any modification of branch protection, rulesets, required checks, required signatures, repo visibility, default branch, repo deletion, archive, or transfer.
- Any creation, modification, deletion, or rotation of: SSH keys (in 1Password, Keychain, or `~/.ssh/`), signing keys, deploy keys, GitHub Apps, MCP server credentials, Actions secrets, environment secrets, organization secrets, fine-grained or classic PATs.
- Any modification of `~/.ssh/config`, `~/.gitconfig` (global), launchd plists, `/etc/paths`, `/etc/paths.d`, system-level Homebrew or Xcode CLT gitconfigs.
- Any operation that would cause a commit to be authored or signed under an identity not bound to the resolved worktree per `includeIf`.
- Any operation that depends on a credential helper response that did not come from the helper currently expected to win.
- Any operation against a repository owned by a child/dependent account that was created under Family Sharing parental control.
- Any operation against an Apple-Developer-Program-bound asset performed under a child/dependent account (Apple Developer Program requires legal age of majority).
- Any printing or transmission of secret values; secrets are referred to by names, fingerprints, hashes, classifications, or existence flags only.

**Require approval:**
- Push to any non-default branch from an agentic context.
- PR open, PR merge, PR review approval, PR comment that references credentials or vulnerabilities.
- Workflow dispatch.
- `gh repo create`, `gh repo fork`, `gh release create`, label/milestone administration.
- Switching the active `gh` account; modifying repo-local Git config keys that affect identity (`user.email`, `user.signingkey`, `core.sshCommand`).
- Any cross-tenant operation (e.g., personal-account agent acting on a business or school org).
- Any operation that would write under `~/Library/Application Support/<vendor>` for security-relevant vendors (1Password, gh, Keychain client apps, MCP clients).

**Warn:**
- Drift between `gh` active account and `osxkeychain`-stored github.com credential.
- Missing `gpg.ssh.allowedSignersFile`, missing or stale `allowed_signers` entries.
- Missing CODEOWNERS, missing SECURITY.md, missing Dependabot config in repos with default-branch protection.
- Mismatch between `user.email` and any registered email of the resolved GitHub account.
- Workflow file granting more permissions than required (e.g., `permissions: write-all`).
- Worktree on a case-insensitive APFS volume containing files differing only in case.
- Bundle running under app translocation when claiming filesystem stability.
- A direnv-loaded `GH_TOKEN`/`GITHUB_TOKEN` in scope when the user-bound `gh` account is different.

**Observe:**
- New tool installations via any package-manager backend.
- New `gh` accounts added to the keyring.
- New TCC grants.
- New bundle quarantine clearings.
- All branch-protection and ruleset changes (recorded for regression-trap comparison).

**Forbidden patterns regardless of tier:**
- Authoring, displaying, or logging any secret value, even partially.
- Reading or writing files in a TCC-protected folder without observed grant.
- Executing shell strings as the primary intent of an action; intent must be expressed as a typed mutation.
- Using `installed-runtime-observation` or `local-config-observation` evidence tags in Phase 1 outputs (per scope).
- Using a long-lived PAT for automation when a GitHub App, deploy key (read-only single-repo), or OIDC-federated short-lived credential is feasible.

## 10. Dashboard and Human Review Needs

- Identity-binding view: per worktree, the resolved chain (Git config layers → remote → SSH alias → signing key → GitHub account → credential helper → token freshness), with red-amber-green per link.
- Account inventory view: all `gh` accounts, all SSH identities, all 1Password signing keys, all GitHub Apps, all OIDC trust relationships, with cross-links to which repos use which.
- Repo posture view: branch protection / ruleset / required checks / required signatures / Actions permissions / CODEOWNERS / SECURITY.md / secret-scanning / Dependabot, per repo, with diff-from-policy markers.
- Mutation queue: pending agent-proposed mutations, classified by tier, with full evidence bundle attached and approve/deny controls.
- Freshness view: which evidence types are stale per source, with refresh actions.
- Drift alerts: `gh` active vs. keychain helper; `user.email` vs. GitHub-registered emails; signing key vs. 1Password vs. allowed_signers vs. GitHub-registered signing keys.
- Cross-tenant view: per agent session, which tenant identities are reachable; warns when a session has multiple tenants in scope.
- Family/educational view: which accounts are flagged child/dependent or student; which mutations are forbidden purely by account-class policy.
- Tool provenance view: every CLI on PATH with its backend, version, integrity hash, mutation-risk class.
- TCC/sandbox view: which agents have FDA, which have Documents/Desktop/Downloads, which apps are translocated.

## 11. Regression Trap Candidates

- Default branch changes from protected to unprotected.
- Required-signatures flag flips off on a protected branch.
- A new credential helper is prepended to the helper chain on any Git config layer.
- A new include/includeIf entry appears in global gitconfig.
- The `gh` active account changes outside an approved flow.
- `osxkeychain` adds a new github.com Internet password whose username does not match any active `gh` account.
- 1Password agent socket path changes or `gpg.ssh.program` no longer points at `op-ssh-sign`.
- `~/.ssh/config` gains a Host alias for a github hostname.
- A new launchd agent or daemon publishes `SSH_AUTH_SOCK`.
- `mise.toml`/`.tool-versions` adds a tool that would shadow a critical binary (`git`, `gh`, `ssh`, `op`).
- Homebrew prefix changes or a non-system `git` is now first on `PATH`.
- A repo's CODEOWNERS, SECURITY.md, `.github/workflows/*`, `dependabot.yml`, `.github/secret_scanning.yml`, or branch-protection JSON drifts from baseline.
- A workflow gains `permissions: write-all` or adds `id-token: write` without an OIDC consumer step.
- A new GitHub App installation is added to an org the user belongs to.
- A new fine-grained or classic PAT is created.
- A repo's visibility flips from private to public.
- A new deploy key is added to a repo, especially with write access.
- A new MCP server registration appears.
- Any TCC grant for a security-sensitive bundle is added or revoked.
- A bundle's quarantine xattr clears unexpectedly.
- A child/dependent account is added to a Family Sharing group, or moves out of one.
- An Apple Developer Program membership is added to or removed from an account that HCS associates with a child/dependent identity.

## 12. Open Questions

These could not be resolved at doc level and would require local observation later (and were therefore deferred per scope).

- Exact precedence outcome when both Xcode CLT system gitconfig and Homebrew system gitconfig declare `credential.helper`: which `git` binary executes determines the system-config path used; documented behavior is `--system` reads "the system-wide gitconfig", but workstations with both installed effectively run two systems. Need observation of which binary's resolution dominates per shell context.
- Whether macOS Tahoe 26.4.1 has fully restored the TCC consent prompt for newly-installed apps in VM vs. real-device contexts (eclecticlight's April 2026 article reports inconsistency).
- The current default behavior of `app translocation` on Tahoe 26.x for app bundles distributed via DMG vs. ZIP, signed and notarized vs. only signed, given Apple's stated policy that "exact circumstances are not documented and have changed over time" (Apple Developer Forums).
- Behavior of `gh auth switch` when the user has a non-`gh` credential helper: documented as a known limitation requiring update of the credential helper out-of-band (cli/cli #8875), but the precise UI on current gh versions was not verified.
- Whether the current MCP authorization spec version (2025-11-25 draft was referenced) has stabilized DCR proxying for GitHub-as-IdP for non-test deployments.
- Whether a sole-proprietor/LLC umbrella account is treated by GitHub differently from a personal account for billing, fine-grained PAT scope, and Education eligibility — GitHub docs distinguish only user vs. organization accounts in Phase-1-relevant places.
- Whether macOS Tahoe applies new restrictions on direct binary additions to Full Disk Access (Apple Discussions thread reports a regression; not confirmed in Apple official docs).
- Whether direnv, mise, and bun's exec-time env mutations interact deterministically with `gh`'s precedence rules for `GH_TOKEN`/`GITHUB_TOKEN` across non-interactive contexts.
- The current set of registered signing keys for an account is observable via the GitHub API, but the binding rule "signature verified iff key registered AND key matches commit author email" needs canonical citation to GitHub docs language for Phase 1; vendor-side the rule is well-known but the exact verification predicate string varies between docs versions.

## 13. Source List

**Apple — macOS Tahoe, sandbox, TCC, file system, launchd, Family Sharing, Developer Program**
- https://developer.apple.com/documentation/security/app_sandbox
- https://developer.apple.com/forums/thread/681550 (launchd EnvironmentVariables)
- https://developer.apple.com/forums/thread/72518 (App Translocation and quarantine xattr)
- https://developer.apple.com/forums/thread/732370 (Gatekeeper, quarantine, translocation)
- https://developer.apple.com/forums/thread/728084 (Apple Developer Program minimum age)
- https://developer.apple.com/forums/thread/85235 (under-18 developer account)
- https://developer.apple.com/forums/thread/128800 (parent/guardian developer account)
- https://developer.apple.com/news/?id=btkirlj8 (Texas SB2420 / age-assurance)
- https://developer.apple.com/support/age-assurance/
- https://support.apple.com/en-us/102617 (create Apple Account for child)
- https://support.apple.com/en-us/102033 (Family Sharing parental consent for existing child account)
- https://support.apple.com/en-us/119854 (Family Sharing for kids and teens)
- https://www.apple.com/legal/privacy/en-ww/parent-disclosure/
- https://www.apple.com/legal/privacy/data/en/age-range-for-apps/
- https://www.apple.com/newsroom/2025/06/apple-expands-tools-to-help-parents-protect-kids-and-teens-online/
- https://eclecticlight.co/2025/11/18/which-local-file-systems-does-macos-26-support/
- https://eclecticlight.co/2025/11/08/explainer-permissions-privacy-and-tcc/
- https://eclecticlight.co/2026/04/07/privacy-protected-folders/
- https://eclecticlight.co/2026/04/08/privacy-files-folders-or-full-disk-access/
- https://eclecticlight.co/2026/04/10/why-you-cant-trust-privacy-security/
- https://eclecticlight.co/2022/09/09/app-first-run-quarantine-and-translocation/
- https://lapcatsoftware.com/articles/app-translocation.html
- https://github.com/ernw/hardening/blob/master/operating_system/osx/26/Hardening_Guide-macOS_26_Tahoe_1.0.md

**Git, GitHub, gh CLI**
- https://git-scm.com/docs/git-config
- https://git-scm.com/doc/credential-helpers
- https://git-scm.com/book/en/v2/Git-Tools-Credential-Storage
- https://docs.github.com/en/get-started/git-basics/updating-credentials-from-the-macos-keychain
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository
- https://docs.github.com/en/rest/branches/branch-protection
- https://docs.github.com/en/code-security/getting-started/github-security-features
- https://docs.github.com/en/code-security/getting-started/quickstart-for-securing-your-repository
- https://docs.github.com/en/get-started/learning-about-github/about-github-advanced-security
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-security-and-analysis-settings-for-your-repository
- https://docs.github.com/en/code-security/dependabot/working-with-dependabot/configuring-access-to-private-registries-for-dependabot
- https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys
- https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/deciding-when-to-build-a-github-app
- https://docs.github.com/en/actions/concepts/security/openid-connect
- https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-cloud-providers
- https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
- https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure
- https://docs.github.com/actions/security-guides/automatic-token-authentication
- https://docs.github.com/en/github-cli/github-cli/using-multiple-accounts
- https://cli.github.com/manual/gh_auth_switch
- https://github.com/cli/cli/blob/trunk/docs/multiple-accounts.md
- https://github.com/cli/cli/issues/8875
- https://github.com/cli/cli/issues/12145
- https://github.blog/security/application-security/introducing-fine-grained-personal-access-tokens-for-github/

**GitHub Education**
- https://education.github.com/pack
- https://education.github.com/pack/join
- https://docs.github.com/en/education/about-github-education/github-education-for-students/apply-to-github-education-as-a-student
- https://docs.github.com/en/education/about-github-education/github-education-for-students/github-terms-and-conditions-for-the-student-developer-pack

**1Password — SSH agent and Git signing**
- https://developer.1password.com/docs/ssh/
- https://developer.1password.com/docs/ssh/get-started/
- https://developer.1password.com/docs/ssh/agent/
- https://developer.1password.com/docs/ssh/git-commit-signing/

**Homebrew**
- https://docs.brew.sh/Installation
- https://docs.brew.sh/FAQ

**mise / asdf**
- https://mise.jdx.dev/dev-tools/
- https://mise.jdx.dev/faq.html
- https://asdf-vm.com/guide/getting-started.html
- https://asdf-vm.com/manage/configuration.html

**Model Context Protocol**
- https://modelcontextprotocol.io/specification/draft/basic/authorization
- https://github.com/modelcontextprotocol/modelcontextprotocol/issues/205
- https://github.com/modelcontextprotocol/modelcontextprotocol/discussions/64
- https://deepwiki.com/modelcontextprotocol/registry/4.1-github-authentication

**Third-party / supporting**
- https://lowply.github.io/blog/2022/08/gcm-gh/ (gh vs GCM credential management on macOS)
- https://xebia.com/blog/organizing-git-access-per-customer-with-1password-ssh-agent/
- https://www.git-tower.com/blog/1password-ssh-tower
- https://www.kenmuse.com/blog/automatic-ssh-commit-signing-with-1password/
- https://bmterra.eu/articles/010625-using-github-apps/ (PATs vs GitHub Apps)
