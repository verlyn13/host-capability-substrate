# Host Capability Substrate (HCS) on macOS — Long‑Term Environment, Secrets, and MCP Policy

**Target date of consult:** Thursday, April 23, 2026  
**Scope:** macOS Tahoe 26.4.1, Codex CLI + Codex macOS app, Claude Code CLI + Claude Desktop, GitHub MCP, and next‑generation agentic workflows in the GPT‑5.x / Opus 4.x class.

---

## 0. Executive Recommendation (TL;DR)

1. **Do not treat inherited shell environment variables as the substrate‑level contract for MCP authentication.** The substrate should assume GUI launches *never reliably inherit a shell environment* on macOS and should design accordingly. ([Apple Developer – LSEnvironment](https://developer.apple.com/documentation/bundleresources/information_property_list/lsenvironment), [Apple Developer – Launch Services Keys](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html))
2. **Prefer tool‑native auth over environment‑variable auth wherever the tool supports it:** Codex `codex mcp login` (OAuth 2.1 + PKCE with Keychain/keyring storage) and Claude Code `/mcp` OAuth are the first‑choice mechanisms for any MCP server that advertises OAuth. ([Codex MCP docs](https://developers.openai.com/codex/mcp), [Codex Configuration Reference](https://developers.openai.com/codex/config-reference), [Claude Code MCP docs](https://code.claude.com/docs/en/mcp))
3. **For the specific GitHub MCP warning (`GITHUB_PAT … is not set`) — change now:** replace the env‑var‑dependent `bearer_token_env_var` configuration with `codex mcp login github` against the remote GitHub MCP server (`https://api.githubcopilot.com/mcp/`), which is GA with OAuth 2.1 + PKCE. ([GitHub Changelog — Remote GitHub MCP Server GA](https://github.blog/changelog/2025-09-04-remote-github-mcp-server-is-now-generally-available/), [GitHub install‑codex.md](https://github.com/github/github-mcp-server/blob/main/docs/installation-guides/install-codex.md))
4. **Classify `bearer_token_env_var` as CLI‑convenient, GUI‑unsafe, transitional.** It is fine as a *fallback* when a server does not yet offer OAuth (e.g., self‑hosted GHES local stdio server, some private HTTP servers) but must not be the default contract for a GUI‑capable substrate. ([Codex Configuration Reference](https://developers.openai.com/codex/config-reference), [github‑mcp‑server #600 — local stdio PAT only](https://github.com/github/github-mcp-server/issues/600))
5. **Defer, do not build now, a substrate broker.** Tool‑native OAuth + 1Password `op run` for the narrow set of genuinely env‑only secrets is sufficient for 2026. Reserve the broker pattern for a second phase if Codex, Claude Code, or a future agent ships a stable credential‑helper IPC interface (as Claude Code already has via `apiKeyHelper`/`awsCredentialExport`/`awsAuthRefresh`). ([Claude Code settings schema](https://code.claude.com/docs/en/settings), [Claude Code complete settings reference](https://claudefa.st/blog/guide/settings-reference))
6. **For the Claude Code boolean‑string validation failure:** it is a real, observed regression surface in Claude Code — the schema requires real JSON primitives (booleans are booleans, integers are integers) and there have been repeated cases where strings are silently accepted or invalid‑type `env` values cause runtime errors. Substrate policy must validate settings.json against the published JSON Schema before deploying config. ([SchemaStore – claude‑code‑settings.json gist](https://gist.github.com/xdannyrobertsx/0a395c59b1ef09508e52522289bd5bf6), [anthropics/claude‑code #5886 — validation regression](https://github.com/anthropics/claude-code/issues/5886))

---

## 1. Source Hierarchy and Conflict‑Resolution Policy

HCS governs every claim by evidence label, applied in this order. When sources disagree, the *higher‑numbered* source is authoritative for the stated concern, and substrate policy must be re‑verified at the listed retest triggers.

| Rank | Source | Authority over |
|---|---|---|
| 1 | Apple official documentation (developer.apple.com, support.apple.com) | macOS runtime, launch semantics, Keychain, launchd |
| 2 | OpenAI Codex official docs (developers.openai.com/codex), `openai/codex` repo `docs/` | Codex CLI, IDE extension, Codex app config shared surface |
| 3 | Anthropic Claude Code official docs (code.claude.com, docs.anthropic.com), `anthropics/claude‑code` `CHANGELOG.md` | Claude Code CLI + Claude Desktop config surface |
| 4 | 1Password Developer docs (developer.1password.com) | `op run`, secret references, SSH agent |
| 5 | MCP specification (modelcontextprotocol.io, spec drafts) | MCP transport/auth semantics |
| 6 | Installed‑runtime behavior and reproducible tests | final arbiter when docs are ambiguous |
| 7 | Repo README / vendor installation guides (e.g., `github/github‑mcp‑server`) | server‑specific setup |
| 8 | Third‑party write‑ups, community blogs | corroboration only |

**Conflict‑resolution rule:** official‑doc vs. installed runtime → flag as an *unresolved / requires direct test* claim and prefer installed‑runtime behavior for policy while filing the divergence. Never silently smooth over the conflict.

---

## 2. macOS 2026 Environment: What the OS Actually Guarantees

**Verified as of April 2026:** Current installed macOS release is **macOS Tahoe 26.4.1**, shipped 2026‑04‑09 (bug‑fix update on top of 26.4, released 2026‑03‑24). Tahoe is the last macOS with Intel support; macOS 27 will be Apple‑silicon‑only. ([Apple Support – What's new in macOS Tahoe 26](https://support.apple.com/en-us/122868), [MacRumors – macOS Tahoe 26.4.1 release](https://www.macrumors.com/2026/04/09/apple-releases-macos-tahoe-26-4-1/), [Apple Developer – macOS Tahoe 26.4 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-26_4-release-notes)) — **Apple‑doc‑backed**

### 2.1 GUI vs. Terminal environment

| Launch path | What is inherited | Substrate implication |
|---|---|---|
| Terminal‑launched process (`zsh`, `bash`, etc.) | Full shell environment as configured in `.zshrc`/`.zprofile`/`.zshenv` | Shell env is viable for CLI agents started from a terminal |
| Finder / Dock / Spotlight / LaunchServices | **Does not inherit the interactive shell environment.** Launch Services sets environment only from the app's `Info.plist` `LSEnvironment` dictionary, and the per‑user `~/.MacOSX/environment.plist` file has been **unsupported since OS X 10.8 Lion / was deprecated years ago** | Substrate must not assume GUI apps see `$GITHUB_PAT` |
| `launchctl setenv` (ephemeral) | Sets variables only for the current `launchd` user domain until reboot | Ephemeral, not suitable as contract |
| LaunchAgent plist in `~/Library/LaunchAgents` running `launchctl setenv …` at `RunAtLoad` | Persistent across reboots at user login | Works, but globally exports a secret to every GUI process — *policy‑hostile for raw tokens* |
| `SMAppService` (macOS 13+) registered agent/daemon | Apple's current supported programmatic path to register LaunchAgents/LaunchDaemons; bundles plists inside the app | Preferred modern mechanism if HCS ever needs a broker |

Primary sources:
- [LSEnvironment – Apple Developer](https://developer.apple.com/documentation/bundleresources/information_property_list/lsenvironment): "Environment variables to be set before launching this app … These environment variables are set only for apps launched through Launch Services. If you run your executable directly from the command line, these environment variables are not set."
- [Launch Services Keys – Apple Developer Archive](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html) confirms the same LSEnvironment semantics.
- Community confirmation that `~/.MacOSX/environment.plist` stopped being supported in Lion/Mountain Lion and that `launchctl setenv` is the only session‑wide workaround ([Apple Community thread](https://discussions.apple.com/thread/253877043), [Omnis Technical Note](https://www.omnis.net/developers/resources/technotes/tnsq0025.jsp)). — **inference from multiple sources** corroborating Apple's deprecation record.
- SMAppService (macOS 13 Ventura+) is the modern API for registering helpers/agents ([Apple: SMAppService article — theevilbit blog](https://theevilbit.github.io/posts/smappservice/)). — **Apple‑doc‑backed via secondary summary**

**Policy conclusion (Apple‑doc‑backed):** GUI app correctness must never depend on shell startup. Any substrate contract that would require `GITHUB_PAT` to be inherited by a Finder‑launched Codex app is structurally broken on macOS.

### 2.2 Keychain and credential storage

macOS Keychain Services (via the Security framework) is Apple's official mechanism for storing small sensitive values — passwords, tokens, keys — per‑user and access‑controlled by code signature / access group. ([Keychain services – Apple Developer](https://developer.apple.com/documentation/security/keychain-services), [Keychain data protection – Apple Support](https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web)) — **Apple‑doc‑backed**

Codex and Claude Code both use Keychain on macOS as their *native* credential store (see §3 and §4). This makes Keychain the correct substrate‑layer default, not environment variables or dotfiles.

---

## 3. Codex: CLI, IDE, and macOS App — Shared and Client‑Specific Layers

**Current Codex CLI at time of report:** `@openai/codex@0.121.0` released 2026‑04‑15; the Codex macOS app received its major update on 2026‑04‑16 (added Computer Use plugin, Intel Mac build, in‑app browser, memory). Current recommended model in the Codex model picker is **GPT‑5.5**, with GPT‑5.4 as fallback; Codex docs explicitly tell users to use GPT‑5.4 if GPT‑5.5 is not yet available. ([Codex Changelog](https://developers.openai.com/codex/changelog), [Codex Models page](https://developers.openai.com/codex/models), [MacRumors – OpenAI Codex Mac update April 16 2026](https://www.macrumors.com/2026/04/16/openai-codex-mac-update/)) — **release‑note‑backed**

### 3.1 Configuration layers: *what is shared, what is client‑specific*

Codex's official docs are explicit: **"The CLI and the IDE extension share the same configuration layers."** Both read `~/.codex/config.toml` with project‑scoped `.codex/config.toml` override in trusted projects. ([Codex Config basics](https://developers.openai.com/codex/config-basic), [Codex MCP page](https://developers.openai.com/codex/mcp)) — **official‑doc‑backed**

Codex precedence, highest wins:
1. `-c/--config` command‑line overrides
2. `CODEX_*` environment overrides
3. Project `.codex/config.toml` (trusted only, walked from project root down to CWD)
4. User `~/.codex/config.toml`
5. System‑level team config
6. Built‑in defaults

**What is shared across Codex CLI and the Codex macOS/Windows app:**
- `mcp_servers.*` definitions (including OAuth‑logged‑in credentials, because MCP OAuth credentials are stored outside `config.toml` in Keychain/keyring)
- Model and provider selection
- Approval and sandbox policies
- `shell_environment_policy`
- `AGENTS.md` / `AGENTS.override.md` at user and project scope
- Skills and plugin marketplaces

**What is client‑specific:**
- Bundled plugins (e.g., the April 2026 `computer-use` plugin is Apple‑Silicon‑only per the reported Intel bug — [openai/codex #18404](https://github.com/openai/codex/issues/18404))
- **Codex app "Local environments" (project‑pane setup scripts + actions)** — an app‑only feature; the CLI has no equivalent first‑class "actions" UI
- `app-server` WebSocket auth (CLI TUI remote, app‑server specific)
- The interactive Codex app browser and memory UI controls ([Codex app docs](https://developers.openai.com/codex/app))

### 3.2 MCP semantics (schema‑backed)

From the [Codex MCP page](https://developers.openai.com/codex/mcp), the [Configuration Reference](https://developers.openai.com/codex/config-reference), and the [CLI Reference](https://developers.openai.com/codex/cli/reference):

| Field (in `[mcp_servers.<name>]`) | Takes | Meaning |
|---|---|---|
| `command`, `args`, `cwd` | literal strings | Stdio launcher |
| `url` | literal URL | Streamable HTTP server |
| `env` | map of literal key=value | Literal env passed to stdio child |
| `env_vars` | list of *names* | Parent env names to forward into the child (can carry `source = "local"` / `source = "remote"`) |
| `bearer_token_env_var` | **name of an env var** (not a value) | For HTTP servers, value of that env var is sent as `Authorization: Bearer …` |
| `http_headers` | literal header → literal value | Static HTTP headers |
| `env_http_headers` | header name → env var name | HTTP headers whose values are pulled from the environment |
| `enabled` | boolean | Set `false` to disable without removing |
| `required` | boolean | Set `true` to make startup fail if this server can't initialize |
| `startup_timeout_sec` (alias `startup_timeout_ms`) | number | Default 10 s |
| `tool_timeout_sec` | number | Default 60 s |
| `enabled_tools` / `disabled_tools` | list | Tool allowlist/denylist (deny applied after allow) |
| `scopes`, `oauth_resource` | OAuth config | Used by `codex mcp login` |
| `mcp_oauth_callback_port` / `mcp_oauth_callback_url` | top‑level | OAuth callback binding |
| `mcp_oauth_credentials_store` | `keyring` / `file` / `auto` (default `auto`) | **keyring (macOS Keychain) or `CODEX_HOME/.credentials.json`** |
| `cli_auth_credentials_store` | `keyring` / `file` / `auto` | Where Codex's own ChatGPT/API key auth lives |

Naming trap (important): fields ending in `_env_var` take *names*, not values. Setting `bearer_token_env_var = "$GITHUB_PAT"` or `bearer_token_env_var = "ghp_…"` is wrong in both directions; it must be `bearer_token_env_var = "GITHUB_PAT"`. ([Codex MCP docs; confirmed by Medium/JP Caparas explainer](https://jpcaparas.medium.com/codex-mcp-configuration-using-env-vars-the-right-way-164e8135aa77)) — **schema‑backed + observed‑runtime‑backed**

### 3.3 OAuth semantics and credential storage

- `codex mcp login <server>` performs OAuth 2.1 + PKCE against servers that advertise OAuth. OAuth login is **only** supported on streamable HTTP servers. ([Codex CLI `mcp` subcommand reference](https://mintlify.wiki/openai/codex/cli/mcp); [Codex CLI options](https://developers.openai.com/codex/cli/reference)) — **official‑doc‑backed**
- If the server advertises `scopes_supported`, Codex prefers the server's scopes during login; otherwise falls back to `scopes = […]` in `config.toml`.
- OAuth credentials land in Keychain (`apple-native` keyring service name `"Codex Auth"`, key derived from SHA‑256 of `codex_home`) when `mcp_oauth_credentials_store = "keyring"` or `"auto"` on macOS, or in `CODEX_HOME/.credentials.json` for `file`. ([Codex Authentication docs](https://developers.openai.com/codex/auth); [Codex core config source](https://fossies.org/linux/codex-rust/codex-rs/core/src/config/mod.rs)) — **official‑doc‑backed + schema‑backed**
- **Credentials are shared across Codex clients that share the same `CODEX_HOME`.** The CLI and the IDE extension share config (official) and, by extension, Keychain keys derived from that `CODEX_HOME`. The Codex macOS app uses the same `~/.codex` tree on macOS. ([Codex MCP: "The CLI and the IDE extension share this configuration. Once you configure your MCP servers, you can switch between the two Codex clients without redoing setup."](https://developers.openai.com/codex/mcp)) — **official‑doc‑backed**
- Known pain point: Keychain ACLs on macOS mean Codex CLI run over SSH against a headless Mac can fail to see MCP OAuth creds if the keychain isn't unlocked for that session. ([openai/codex #16728](https://github.com/openai/codex/issues/16728)) — **observed‑runtime‑backed** — file as HCS *requires‑direct‑test* when the agent runs headless.
- Codex has a known `enabled = true`, `required = true` semantics: `enabled = false` disables without deletion; `required = true` makes startup fail if the server can't initialize. This is what surfaces a hard failure like the `GITHUB_PAT … is not set` message the user observed. ([Codex Configuration Reference](https://developers.openai.com/codex/config-reference)) — **schema‑backed**
- Dynamic Client Registration (RFC 7591): Codex's OAuth path effectively requires the MCP server's authorization server to support DCR. If a remote MCP server's AS does not support DCR, Codex App currently cannot complete OAuth login. ([openai/codex #15818](https://github.com/openai/codex/issues/15818)) — **observed‑runtime‑backed**

### 3.4 Startup order and where project‑local configuration can and can't help

Codex MCP servers are started at session start, before the model begins reasoning. Official guidance: *"Make sure your environment is already set up before launching Codex so it doesn't spend tokens probing what to activate."* ([Codex CLI features](https://developers.openai.com/codex/cli/features)) — **official‑doc‑backed**

Which means:

- **`.envrc` (direnv):** Works only if the *parent shell* running `codex` has already been re‑hooked by direnv. Does not help Finder/Dock/Spotlight‑launched Codex app. Also does not propagate into Codex's sandboxed child processes unless allowed by `shell_environment_policy`. Multiple third‑party tools (Cursor) have explicit bugs filed for not inheriting direnv‑set env vars. ([Cursor community — direnv not inherited](https://forum.cursor.com/t/cursor-agent-does-not-inherit-from-direnv/154356)) — **observed‑runtime‑backed**
- **`.mise.toml`:** Same CLI‑only caveat. mise can integrate with `op`, sops/age, or direct env secrets via `_.file`, `_.source`, or hooks, but the secret only enters the environment of a *shell that mise has activated*, not a Finder‑launched GUI. ([mise Environments](https://mise.jdx.dev/environments/), [mise Secrets](https://mise.jdx.dev/environments/secrets/)) — **official‑doc‑backed**
- **Project‑local `.codex/config.toml`:** Trusted projects only; read at Codex startup. It *can* hold `[mcp_servers.github] bearer_token_env_var = "GITHUB_PAT"`, but the env var still has to come from *somewhere the process can see*. So project config solves the "where is this MCP declared" problem, not the "where does the secret come from" problem.
- **Codex app Local Environments (setup scripts + actions):** The Codex app stores this under the project's `.codex` folder and runs setup scripts when Codex creates a new worktree at the start of a new thread. It is worktree/bootstrap scoped, not startup‑auth scoped. Secrets needed by MCP servers at session start are *already required* before setup scripts ever run. ([Codex app – Local environments](https://developers.openai.com/codex/app/local-environments)) — **official‑doc‑backed**. In short: **Codex app Local Environments are suitable for worktree bootstrap, not for MCP startup auth.**

Corroborating gap — there is an open OpenAI community request to carry `.env` files into worktrees ([openai/codex #10528](https://github.com/openai/codex/issues/10528)) and another to inject worktree/root path env vars into setup scripts ([openai/codex #13576](https://github.com/openai/codex/issues/13576)). This is a known area of active development, so HCS policy should be revisited at every Codex release.

### 3.5 `shell_environment_policy` realities

The `shell_environment_policy` table controls env passed to *subprocesses Codex spawns* (i.e., model‑proposed shell commands and stdio MCP launches). Defaults include a built‑in filter that drops env var names containing KEY/SECRET/TOKEN unless `ignore_default_excludes = true` and patterns are allowlisted. ([Codex Advanced Configuration](https://developers.openai.com/codex/config-advanced), [Codex Sample Configuration](https://developers.openai.com/codex/config-sample)) — **schema‑backed**

Observed gotcha: on Windows, some Codex builds strip core env (PATH, USERPROFILE, etc.) from subprocesses, breaking dotnet/NuGet and git networking ([openai/codex #18248](https://github.com/openai/codex/issues/18248)). Also, a previously reported bug where `include_only = ["GH_TOKEN"]` plus `inherit = "all"` *did not* surface `GH_TOKEN` in the VS Code extension session ([openai/codex #13426](https://github.com/openai/codex/issues/13426)). HCS must treat `shell_environment_policy` as *policy‑backed with observed‑runtime anomalies* and re‑test after each Codex upgrade.

---

## 4. Claude Code and Claude Desktop

**Current Claude Code CLI:** iterating at ~daily cadence in April 2026. As of the current Claude API release notes, Opus 4.7 is GA (launched 2026‑04‑16) with 1M context, adaptive thinking, new `xhigh` effort level, high‑resolution image input, file‑system‑based memory, and task budgets (beta header `task-budgets-2026-03-13`). Claude Code added auto mode for Max users on Opus 4.7 and a `/ultrareview` command. ([Anthropic — What's new in Claude Opus 4.7](https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7), [Claude API release notes](https://platform.claude.com/docs/en/release-notes/overview), [Claude Code changelog](https://code.claude.com/docs/en/changelog)) — **official‑doc‑backed**

Claude Desktop has separately shipped a desktop Code interface (macOS and Windows; Linux unsupported), including Cowork, integrated terminal, diff review, live preview, and PR monitoring. ([Claude Code Desktop Quickstart](https://code.claude.com/docs/en/desktop-quickstart)) — **official‑doc‑backed**

### 4.1 settings.json schema and the "boolean‑like strings" failure

Claude Code settings live in a hierarchy (highest wins): enterprise/managed → command‑line flags → project local (`.claude/settings.local.json`) → project shared (`.claude/settings.json`) → user (`~/.claude/settings.json`). ([Claude Code settings](https://code.claude.com/docs/en/settings), [claudefa.st reference](https://claudefa.st/blog/guide/settings-reference)) — **official‑doc‑backed**

The published JSON schema (`https://json.schemastore.org/claude-code-settings.json`) declares many fields as `boolean` or `integer` types. A string like `"true"` is *not* a valid boolean per the schema, and `anthropics/claude-code` issue #5886 documents multiple scenarios where invalid types slip past validation but cause runtime failures later:

```json
{
  "cleanupPeriodDays": "thirty",      // string instead of number
  "includeCoAuthoredBy": "yes",       // string instead of boolean
  "permissions": "should be an object",
  "enabledMcpjsonServers": "memory",
  "env": ["wrong", "type"]
}
```

→ These pass some validation paths and fail at runtime. ([Issue #5886](https://github.com/anthropics/claude-code/issues/5886), [Full schema gist](https://gist.github.com/xdannyrobertsx/0a395c59b1ef09508e52522289bd5bf6)) — **schema‑backed + observed‑runtime‑backed**

The `env` object specifically is `"additionalProperties": { "type": "string" }` — so values must be strings, but it is *not* a place to put real JSON booleans. For booleans like `"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"` you must write `"1"` (string) because env vars are inherently strings, but the surrounding *settings keys* outside `env` must use real booleans. This is the exact failure class the user encountered.

**Policy:** HCS must validate every settings.json against the live schema (`$schema` reference + a local JSON Schema validator) before commit, and the substrate may not generate settings that ship boolean‑like strings where JSON booleans are required. Classify this as **schema‑backed, observed‑runtime‑backed, requires‑direct‑test after every Claude Code minor version bump.**

Additional recent, relevant changelog entries confirm schema drift continues to happen:
- "JSON schema validation for permissions.defaultMode: 'auto'" — released in Claude Code v2.1.x. ([claudefa.st changelog](https://claudefa.st/blog/guide/changelog))
- CHANGELOG notes tool‑input validation fixes and "JSON validation failed" error message improvements. ([anthropics/claude-code CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))
- Settings keys explicitly stored in `~/.claude.json` (not settings.json) will trigger schema validation errors if added to settings.json. ([Claude Code settings docs](https://code.claude.com/docs/en/settings))

### 4.2 MCP precedence and env expansion in Claude Code

Claude Code MCP scopes (highest wins): **local** (stored in `~/.claude.json` per project‑path, private) → **project** (`.mcp.json` at repo root, checked in) → **user** (`~/.claude.json`, global). ([Connect Claude Code to tools via MCP](https://code.claude.com/docs/en/mcp), [builder.io write‑up](https://www.builder.io/blog/claude-code-mcp-servers)) — **official‑doc‑backed**

Claude Code expands `${VAR}` and `${VAR:-default}` in `.mcp.json` at startup from the parent shell environment. Known bugs:
- `claude mcp add` has written *resolved* secret values back into `.mcp.json` instead of preserving `${VAR}` ([anthropics/claude-code #18692](https://github.com/anthropics/claude-code/issues/18692)) — **observed‑runtime‑backed**.
- Env expansion does not fire in plugin‑provided `.mcp.json` ([#9427](https://github.com/anthropics/claude-code/issues/9427)).
- Env substitution in headers sometimes does not reach the wire ([#6204](https://github.com/anthropics/claude-code/issues/6204)).
- Env substitution works in Cursor but not in VS Code's Claude Code extension ([#14032](https://github.com/anthropics/claude-code/issues/14032)).
- Bearer token configured in headers registers as *"Auth: ✗ not authenticated"* in the `/mcp` UI even though it works ([#17152](https://github.com/anthropics/claude-code/issues/17152)).
- Background subagents spawned via the Agent tool cannot access OAuth‑authenticated MCP servers inherited from the parent session ([#46228](https://github.com/anthropics/claude-code/issues/46228)).

→ Treat Claude Code's env‑variable MCP auth as **CLI‑only and structurally brittle**. For any Claude Code MCP server that supports OAuth, prefer OAuth via `/mcp` authenticate and do not rely on `${VAR}` in `.mcp.json`.

### 4.3 AGENTS.md vs. CLAUDE.md, project memory

- **CLAUDE.md** is Claude Code's primary project‑memory file. Loaded at session start from user + project + subdirectory.
- **AGENTS.md** is the cross‑tool convention that Codex, Gemini CLI, and others read. Codex walks from project root down to CWD, with `AGENTS.override.md` overrides and configurable fallback filenames. Gemini uses `GEMINI.md`. ([DeployHQ overview](https://www.deployhq.com/blog/ai-coding-config-files-guide), [Codex config.md](https://github.com/openai/codex/blob/main/docs/config.md)) — **official‑doc‑backed**

Policy: HCS should own `AGENTS.md` as the portable project memory across agents and keep `CLAUDE.md` as Claude‑specific overlay; never duplicate content.

### 4.4 Credential helpers (the real substrate interface)

Claude Code's settings schema already defines **tool‑native credential‑helper hooks**:

| Setting | Purpose | Call semantics |
|---|---|---|
| `apiKeyHelper` | Dynamic API key generation | Executes the command; stdout is the credential |
| `awsCredentialExport` | Dynamic AWS credentials | Must output JSON with standard AWS keys |
| `awsAuthRefresh` | Refresh AWS creds | Called periodically |
| `otelHeadersHelper` | OTel headers | For enterprise tracing |

([Claude Code settings reference](https://code.claude.com/docs/en/settings), [claudefa.st complete reference](https://claudefa.st/blog/guide/settings-reference)) — **official‑doc‑backed + schema‑backed**

These are the **correct substrate integration points** for an eventual HCS broker. They already express the broker pattern in a tool‑native form.

### 4.5 Claude Desktop MCP config location

Claude Desktop (separate from Claude Code) reads MCP servers from `~/Library/Application Support/Claude/claude_desktop_config.json` on macOS. Remote OAuth connectors are added via Settings → Connectors; GitHub's remote MCP currently requires configuring a GitHub App/OAuth App per host, which is *not* pre‑supported in Claude Desktop, so Claude Desktop documentation recommends the Docker‑based local stdio github‑mcp‑server with PAT via environment. ([github/github-mcp-server install-claude.md](https://github.com/github/github-mcp-server/blob/main/docs/installation-guides/install-claude.md), [toolradar Claude Desktop MCP setup 2026 guide](https://toolradar.com/blog/claude-desktop-mcp-server-setup)) — **official‑doc‑backed**

Claude Desktop Extensions (`.mcpb`) provide OS‑native secure storage: fields marked `"sensitive": true` in `manifest.json` are encrypted via Keychain on macOS. ([Getting Started with Local MCP Servers on Claude Desktop — Claude Help Center](https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop)) — **official‑doc‑backed**

---

## 5. The GitHub MCP Specifically

- **Remote GitHub MCP server is GA (Sept 4, 2025) at `https://api.githubcopilot.com/mcp/` with OAuth 2.1 + PKCE, automatic token refresh, and short‑lived credentials.** ([GitHub Changelog](https://github.blog/changelog/2025-09-04-remote-github-mcp-server-is-now-generally-available/), [Setting up the GitHub MCP Server — GitHub Docs](https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp-in-your-ide/set-up-the-github-mcp-server)) — **release‑note‑backed + official‑doc‑backed**
- The remote server also accepts PAT via `Authorization: Bearer` header (documented for hosts that haven't integrated OAuth yet). ([github-mcp-server README](https://github.com/github/github-mcp-server))
- The **local stdio github‑mcp‑server** currently only accepts a PAT via environment. Its maintainers state, per the MCP authorization spec, *"Implementations using an STDIO transport SHOULD NOT follow this specification, and instead retrieve credentials from the environment."* — this is a spec‑level recommendation. ([MCP Authorization draft spec — modelcontextprotocol.io](https://modelcontextprotocol.io/specification/draft/basic/authorization); [github/github-mcp-server #600](https://github.com/github/github-mcp-server/issues/600)) — **schema‑backed (spec)**

**Correct HCS policy for GitHub MCP from Codex CLI, Codex macOS app, and Claude Code:**

```toml
# ~/.codex/config.toml  — trusted user scope
[mcp_servers.github]
url = "https://api.githubcopilot.com/mcp/"
enabled = true
# No bearer_token_env_var. Auth via:
#   codex mcp login github
# which stores tokens in Keychain (mcp_oauth_credentials_store = "auto" default).
```

Equivalent for Claude Code: `claude mcp add --transport http github https://api.githubcopilot.com/mcp/` then `/mcp` authenticate. ([Composio — GitHub MCP with Claude Code](https://composio.dev/toolkits/github/framework/claude-code), [builder.io Claude Code MCP guide](https://www.builder.io/blog/claude-code-mcp-servers)) — **official‑doc‑backed**

Fallback only when OAuth is not available (e.g., self‑hosted GHES without remote server support, local stdio server for air‑gapped work):

```toml
[mcp_servers.github_enterprise]
url = "https://copilot-api.your-ghes-subdomain.ghe.com/mcp"
bearer_token_env_var = "GITHUB_ENTERPRISE_PAT"
enabled = false              # off by default, profile‑gated on explicit opt‑in
required = false             # do not block session startup
```

With `GITHUB_ENTERPRISE_PAT` sourced via `op run --env-file .env.github -- codex` *only* for the CLI, and profile‑gated behind an explicit user choice — never as default substrate behavior.

---

## 6. MCP Authorization: Spec‑Level Facts Driving HCS Policy

The MCP authorization spec makes three facts that anchor HCS policy:

1. **Stdio transports SHOULD retrieve credentials from environment** — i.e., env vars are the *spec‑sanctioned* channel for stdio server credentials (local subprocesses). ([MCP Authorization spec](https://modelcontextprotocol.io/specification/draft/basic/authorization)) — **schema‑backed**
2. **HTTP transports MUST use OAuth 2.1 with PKCE**, with Protected Resource Metadata (RFC 9728), Authorization Server Metadata (RFC 8414), Resource Indicators (RFC 8707), and, as of the Nov 2025 spec revision, Client ID Metadata Documents (CIMD) and mandatory PKCE. ([Stack Overflow Blog: Is that allowed? — MCP authorization](https://stackoverflow.blog/2026/01/21/is-that-allowed-authentication-and-authorization-in-model-context-protocol/), [WorkOS: MCP Authorization in 5 easy OAuth specs](https://workos.com/blog/mcp-authorization-in-5-easy-oauth-specs), [TrueFoundry: Understanding MCP Authentication](https://www.truefoundry.com/blog/mcp-authentication)) — **schema‑backed**
3. **Dynamic Client Registration (RFC 7591) support is optional for servers** but *effectively required* for Codex/Claude Code to complete OAuth with an arbitrary AS — if the AS does not support DCR, Codex App cannot currently log in. ([openai/codex #15818](https://github.com/openai/codex/issues/15818)) — **observed‑runtime‑backed**

These three together mean HCS can *legitimately* rely on env‑var auth for local stdio servers (the spec says so), and *must* treat HTTP MCP auth as an OAuth problem (the spec says so), and *must* treat DCR as a live compatibility risk for some private MCP servers behind corporate IdPs.

---

## 7. Compatibility Policies

### 7.1 Codex CLI (bare `codex` launch in Terminal)

- Codex CLI login in Keychain, OAuth or `CODEX_API_KEY`/`OPENAI_API_KEY` piped via `codex login --with-api-key`. ([Codex Authentication](https://developers.openai.com/codex/auth)) — **official‑doc‑backed**
- MCP: `codex mcp login <server>` for HTTP+OAuth servers; `env = {…}` for stdio literals; `env_vars = […]` for forwarded names. `shell_environment_policy` controls which env vars propagate to child processes; Codex's default filter drops names containing KEY/SECRET/TOKEN. — **schema‑backed**
- Project config: `.codex/config.toml` (trusted), `AGENTS.md`, and optionally direnv/mise for language runtimes and *non‑secret* project env.

### 7.2 Codex macOS App (Finder/Dock/Spotlight launch)

- Same `~/.codex/config.toml`, same Keychain‑resident OAuth credentials as CLI. ([Codex MCP page](https://developers.openai.com/codex/mcp)) — **official‑doc‑backed**
- **Must not depend on shell env** for MCP auth. The only supported way to give the app access to a secret *at MCP startup* is:
  - OAuth via `codex mcp login` (Keychain), or
  - `LSEnvironment` in `Info.plist` (not recommended — requires modifying the signed app bundle), or
  - a user‑global LaunchAgent running `launchctl setenv` at login (policy‑hostile for raw tokens), or
  - Codex app "Local environments" setup scripts (worktree/bootstrap scope, *not* startup‑auth scope).
- `shell_environment_policy` with `inherit = "core"` is the sane default for subprocesses the app spawns.

### 7.3 Claude Code CLI (bare `claude` launch)

- `~/.claude/settings.json` controls env for every session; `.mcp.json` holds project MCP; `/mcp` handles OAuth.
- Validate settings.json against the published schema. Never write boolean‑like strings where the schema expects `boolean`/`integer`.
- Use `apiKeyHelper` / `awsCredentialExport` / `awsAuthRefresh` as the substrate‑facing credential hooks rather than inventing a parallel broker. ([Claude Code settings](https://code.claude.com/docs/en/settings)) — **official‑doc‑backed**

### 7.4 Claude Desktop (macOS)

- MCP via `~/Library/Application Support/Claude/claude_desktop_config.json` or Desktop Extensions (`.mcpb`).
- Sensitive fields in `.mcpb` manifests are Keychain‑encrypted automatically. ([Claude Help Center — getting started with local MCP servers](https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop)) — **official‑doc‑backed**
- HCS policy: prefer built‑in Connectors (OAuth) or `.mcpb` extensions over hand‑rolled JSON with PATs; do not commit secrets.

---

## 8. Classification of Each Mechanism

(HCS labels per task brief. Columns: Universal baseline / CLI‑only / GUI‑compatible / Project‑local / Profile‑scoped / Transitional workaround / Discouraged / Unsafe for secrets / Requires direct runtime test.)

| Mechanism | HCS class | Why |
|---|---|---|
| Inherited env var `GITHUB_PAT` via shell rc | **CLI‑only, transitional, unsafe for secrets as *default*** | Not seen by Finder/Dock/Spotlight‑launched GUI apps; widely leaks across unrelated projects if put in shell rc |
| `op run --env-file … -- codex` | **CLI‑only, GUI‑incompatible for startup‑auth, supported fallback** | Process‑scoped env; ideal for CLI fallback where tool supports only env‑var auth |
| Shell alias / wrapper launcher | **CLI‑only, discouraged as primary contract** | Hidden terminal‑only magic; not the substrate contract |
| Terminal profile env injection (e.g., iTerm2 profile env) | **Discouraged** | Per‑terminal, not reproducible, terminal‑only |
| `launchctl setenv` (ephemeral) | **Transitional workaround** | Does not persist across reboots |
| LaunchAgent plist with `RunAtLoad` → `launchctl setenv` | **GUI‑compatible but unsafe for raw secrets** | Globally exports secret to every GUI process for the user |
| `Info.plist` `LSEnvironment` | **Apple‑doc‑backed, GUI‑compatible, discouraged for secrets** | Requires modifying the signed app bundle; breaks code signing unless the app is re‑signed; unmaintainable |
| Static tokens in `config.toml` / `.mcp.json` | **Unsafe for secrets, discouraged** | Violates "no raw secrets in dotfiles" |
| Codex `codex mcp login` (OAuth) | **Universal baseline for HTTP MCP** | Stored in Keychain, shared CLI/IDE/app |
| Claude Code `/mcp` OAuth | **Universal baseline for HTTP MCP** | Same model |
| OS Keychain / keyring‑backed storage | **Universal baseline** | Apple‑native secure storage; already the Codex + Claude Code default |
| 1Password `op run`, secret references, `op inject` | **CLI‑only, strong fallback** | Works cleanly in terminal; the moment you need it in a GUI launch path, it breaks |
| 1Password SSH agent | **Universal baseline for SSH + Git** | Biometric unlock, key never leaves 1Password; excellent substrate for signing/Git auth specifically |
| Local substrate broker (LaunchAgent/local HTTP/Unix socket/CLI daemon) | **Requires direct runtime test, deferred** | Useful only once there is a stable tool‑native IPC (Codex external auth command / Claude Code `apiKeyHelper`); see §10 |
| Per‑project identity through Codex profiles | **Project‑local, supported** | Codex profiles switch model/provider/approvals; combine with project `.codex/config.toml` |
| `.envrc` (direnv) | **CLI‑only, project‑local, not for secrets directly** | Good for project env; pair with `op run`/sops/age for secrets |
| `mise.toml` | **CLI‑only, project‑local** | Good for runtimes + non‑secret env; supports sops/age and hooks for secrets |
| Project `.codex/config.toml` | **Project‑local, trusted projects only** | MCP definitions, profiles, approval policy; no secrets |
| Codex app Local Environments (setup scripts + actions) | **Project‑local, worktree/bootstrap scope only** | Not usable as startup‑auth for MCP |
| `AGENTS.md` | **Project‑local, universal across Codex/Gemini** | Project memory, not config |
| `.mcp.json` (Claude Code project MCP) | **Project‑local, GUI‑compatible (Claude Desktop via import), secret‑substitution risky** | Known env‑expansion bugs; prefer OAuth |
| Wrapper scripts that wrap `codex`/`claude` in `op run` | **CLI‑only, transitional** | Fine until tool‑native OAuth catches up |

---

## 9. Long‑Term Layer Ownership — Policy Matrix

| Layer | Owns | May support | Should not own | Transitional |
|---|---|---|---|---|
| **macOS / OS session** | Login session, Keychain, LaunchServices, SMAppService registrations | LaunchAgent plists for substrate‑owned services | Exporting raw tokens to all GUI processes | `launchctl setenv` fallbacks |
| **Shell** | Interactive developer environment, direnv/mise activation, CLI‑scoped `op run` | Non‑secret project env loading via mise/direnv | GUI app correctness; MCP startup auth for GUI apps | Shell aliases that hide authentication semantics |
| **Terminal** | Terminal‑specific display/locale (TERM, LANG, colors) | Per‑profile *non‑secret* context | Secret injection that bypasses the shell contract | — |
| **User‑global tool config** (`~/.codex/config.toml`, `~/.claude/settings.json`) | Tool defaults, managed settings, model selection, `mcp_servers.*` declarations, `mcp_oauth_credentials_store = "keyring"` | Keychain‑resident tokens via OAuth; `apiKeyHelper` / `awsCredentialExport` pointing to HCS helpers | Literal secrets; boolean‑like strings; undocumented keys | `bearer_token_env_var` for HTTP MCP pending OAuth support |
| **Project config** (`.codex/config.toml`, `.claude/settings.json`, `.mcp.json`, `AGENTS.md`) | MCP server identity per project, project AGENTS memory, approval policy overrides, tool versions | Profile gating; project‑specific subagent roles | Raw secrets, tokens | `${VAR}` substitution patterns until OAuth is universal |
| **Worktree / bootstrap** (`.codex/` setup scripts, Codex app Local Environments, `.mise.toml` hooks, direnv `.envrc`) | Dev dependency install, venvs, bootstrap of local tooling | Loading non‑secret env for local dev | Producing secrets at MCP startup time (too late) | `.env.local` loaded by `op inject` for local app runtime |
| **Secret resolution** | 1Password vault + biometric unlock (resolver of record); Keychain (sink for OAuth tokens) | Codex `auth.json` (`file` mode) only where keyring is unavailable | Persistent resolved secrets at rest in dotfiles | `op run --env-file` wrappers for CLI tools that still require env |
| **MCP authentication** | OAuth 2.1 + PKCE via tool‑native flows (Codex `mcp login`, Claude Code `/mcp`) | PAT via `bearer_token_env_var` / header env expansion for servers without OAuth; env credentials for stdio | Inheritance of user‑wide env as the default contract | Profile‑gated PAT flows for GitHub Enterprise / air‑gapped |
| **Substrate broker / adapter** (deferred) | Eventually: a single `apiKeyHelper`‑style helper surface; a local macOS helper (`SMAppService`) that resolves 1Password references on demand and writes *process‑scoped* env for spawned CLI children | Unix‑socket local IPC for observability | Policy decisions (those live at the user‑global + project layer); persistent resolved secrets | — |

---

## 10. Tradeoff Table: Auth / Secret / Broker Patterns

| Pattern | GUI‑safe? | Secrets at rest? | Revocable? | Per‑project? | Tool‑native? | Failure mode if misused |
|---|---|---|---|---|---|---|
| Inherited shell env (`GITHUB_PAT`) | ❌ not reliably | In shell rc (bad) | Low | Hard | No | Silent GUI breakage; leaks across projects |
| `op run --env-file -- codex` | ❌ (CLI only) | No (process‑scoped) | Yes | Yes (per command) | Partial | Fails for GUI launches; stdout/stderr PTY quirks ([NSHipster — op run](https://nshipster.com/1password-cli/)) |
| Wrapper launcher / shell alias | ❌ | Depends | Varies | Possible | No | Hidden magic; easy to bypass |
| Terminal‑profile env injection | ❌ | In profile (bad) | Low | No | No | Invisible coupling to terminal choice |
| `launchctl setenv` (ephemeral) | ✅ until reboot | In memory only | Yes | No | No | Non‑persistent; inconsistent with login items |
| LaunchAgent + `launchctl setenv` at login | ✅ | Token in plist / helper | Yes (unload) | No | No | Secret globally visible to all GUI processes |
| LSEnvironment in Info.plist | ✅ | In the app bundle | Low | No | Apple‑doc | Breaks code signing unless re‑signed; unmaintainable |
| Static token in config | ✅ | Yes, bad | Low | Yes | Partial | Violates HCS constraint #1 |
| Tool‑native OAuth (Codex/Claude) | ✅ | Encrypted in Keychain | Yes (tool `logout`) | Per‑server | **Yes** | DCR requirement may block private IdPs ([#15818](https://github.com/openai/codex/issues/15818)); headless SSH Keychain quirks ([#16728](https://github.com/openai/codex/issues/16728)) |
| OS Keychain / keyring | ✅ | Yes, encrypted | Yes | Per‑service | Yes | Needs unlocked login keychain; sudo contexts diverge ([Apple Dev Forums](https://developer.apple.com/forums/thread/699701)) |
| 1Password op‑run / secret refs | CLI ✅ / GUI ❌ at startup | No (on disk: refs only) | Yes | Yes | Semi (via helpers) | Can't service GUI startup auth; biometric prompt latency |
| 1Password SSH agent | ✅ | No (vault) | Yes | Per‑host | Yes (OpenSSH contract) | Scoped to SSH/Git; needs biometric unlock |
| Local substrate broker (LaunchAgent/Unix socket) | ✅ | Only in memory | Yes | Yes | Via `apiKeyHelper`/aux command hooks | Complex; another moving part; security review required |
| Per‑project profile + broker | ✅ | As broker | Yes | Yes | Via profile names | Over‑engineered if tool‑native OAuth already suffices |

---

## 11. Near‑Term Recommendation for the GitHub MCP Warning

The observed error — `MCP client for github failed to start: Environment variable GITHUB_PAT for MCP server 'github' is not set` — indicates Codex saw a config entry like:

```toml
[mcp_servers.github]
url = "https://api.githubcopilot.com/mcp/"
bearer_token_env_var = "GITHUB_PAT"
required = true           # or default, hence startup failure
```

and `GITHUB_PAT` was missing from the Codex process environment. **Action:**

1. **Remove** `bearer_token_env_var = "GITHUB_PAT"` from `~/.codex/config.toml` for `github`.
2. **Run `codex mcp login github`** against `https://api.githubcopilot.com/mcp/`. Codex will store the OAuth tokens in Keychain via `mcp_oauth_credentials_store = "auto"` default. ([Codex MCP docs](https://developers.openai.com/codex/mcp))
3. **Leave `enabled = true` and `required = false`** so a temporary OAuth failure does not crash Codex startup.
4. **Both Codex CLI and Codex macOS app will now see the credentials**, because they share `~/.codex/config.toml` and share Keychain keys derived from `CODEX_HOME`.
5. For Claude Code, mirror with `claude mcp add --transport http github https://api.githubcopilot.com/mcp/` + `/mcp` authenticate. ([GitHub install‑codex.md](https://github.com/github/github-mcp-server/blob/main/docs/installation-guides/install-codex.md))

If a PAT is still truly required (GitHub Enterprise Server without remote MCP, or a locked‑down corporate gateway), treat it as a **profile‑scoped opt‑in**, not substrate default:

```toml
[profiles.ghe_pat]
# pull this profile only with --profile ghe_pat
[profiles.ghe_pat.mcp_servers.github_enterprise]
url = "https://copilot-api.corp.ghe.com/mcp"
bearer_token_env_var = "CORP_GHE_PAT"
enabled = true
required = false
```

and run `op run --env-file ~/.config/hcs/ghe.env -- codex --profile ghe_pat` only when needed from terminal. The GUI app remains unaffected.

---

## 12. Long‑Term Substrate Architecture

**Phase 0 (now — do immediately):**
- Standardize tool‑native OAuth for all MCP servers that support it (GitHub, Linear, Sentry, Notion, Stripe, etc.). All of these are GA on OAuth 2.1 + PKCE in 2026.
- Store CLI credentials in Keychain (`cli_auth_credentials_store = "keyring"`) and MCP OAuth credentials in Keychain (`mcp_oauth_credentials_store = "keyring"` or `"auto"`).
- Validate every Claude Code settings.json against `https://json.schemastore.org/claude-code-settings.json` in CI and pre‑commit.
- Classify env‑var MCP auth as transitional; gate each remaining env‑var server behind a Codex profile.
- Move all raw secrets into 1Password; use `op read` / `op run` / `op inject` *only* for CLI‑scoped flows.

**Phase 1 (3‑6 months — change now if Codex/Claude/MCP stabilize further):**
- Adopt Claude Code's `apiKeyHelper` / `awsCredentialExport` pattern to front HCS: the helper is a *substrate‑owned executable* that, when invoked, either returns a token from Keychain or triggers `op read` with biometric unlock.
- For Codex, use the `[model_providers.<id>.auth] command = "…"` / `args = […]` / `refresh_interval_ms` mechanism for custom providers whose tokens HCS wants to manage. ([Codex Advanced Configuration](https://developers.openai.com/codex/config-advanced)) — **schema‑backed**
- Keep project‑local `.mcp.json` / `.codex/config.toml` for MCP *identity*, never secrets.
- Replace `wrapper → codex` scripts with a single documented `hcs run <tool>` that is just `op run --env-file` + the tool, used only in CLI.

**Phase 2 (defer — reserve for 2026‑H2+):**
- A substrate *broker* (local HTTP or Unix socket) that speaks an HCS protocol, registered via `SMAppService.agent(plistName:)` so it runs at user login. It resolves secret references on demand, never persists them, fronts tool‑native credential helpers, and logs all secret resolutions to a privacy‑local audit trail.
- The broker should **fail closed** (no token → tool sees `apiKeyHelper` exit nonzero → tool falls back to its own re‑auth flow) and must **not** hold policy — that stays in `config.toml`/`settings.json`.
- Broker scope is credential resolution and refresh only. MCP transport, OAuth flow state, and model choice remain tool‑native.

---

## 13. "Change Now" vs. "Defer"

### Change now

1. ✅ Replace env‑var GitHub MCP auth with `codex mcp login` against the remote GitHub MCP server (§11).
2. ✅ Set `cli_auth_credentials_store = "keyring"` and `mcp_oauth_credentials_store = "keyring"` or `"auto"` in `~/.codex/config.toml`.
3. ✅ Validate every settings.json and `.mcp.json` against the published JSON Schemas in pre‑commit.
4. ✅ Remove every raw secret from persistent dotfiles; move to 1Password with secret references.
5. ✅ Mark Codex profiles that need PATs as explicit opt‑in, `enabled = false` by default.
6. ✅ Stop using `~/.MacOSX/environment.plist` (long deprecated).
7. ✅ Stop using shell aliases and wrapper launchers as the *primary* contract for tool invocation; reserve them for documented CLI fallbacks.
8. ✅ Adopt `AGENTS.md` as the portable project memory; keep `CLAUDE.md` as Claude‑specific overlay.
9. ✅ Treat Codex app "Local environments" as worktree bootstrap only, not startup auth.

### Defer

- ⏸ Do not build a custom substrate broker until tool‑native `apiKeyHelper`/`[model_providers.auth].command` patterns prove insufficient for two or more real flows.
- ⏸ Do not adopt LaunchAgent‑exported env as HCS policy for raw tokens. Reserve it only for situations where a specific GUI app cannot be fixed otherwise and the token is already low‑privilege and revocable.
- ⏸ Do not pre‑build OAuth flows for MCP servers that don't yet have OAuth. The spec is moving fast — let the servers catch up.
- ⏸ Do not try to make GUI apps inherit `.envrc` or `.mise.toml`. It is not what those tools are for, and macOS will not cooperate.

---

## 14. Open Questions Requiring Official Confirmation or Direct Runtime Tests

1. **Is `mcp_oauth_credentials_store` Keychain service keyed by `CODEX_HOME` alone, or also by the Codex client binary identity?** Codex source suggests the keyring service name is `"Codex Auth"` with keys derived from `codex_home` only. Needs runtime test: CLI `codex mcp login` → open Codex macOS app → confirm `/mcp` shows authenticated. — **requires direct test**
2. **Does the Codex macOS app honor project‑scoped `.codex/config.toml` MCP definitions if the project is trusted?** Docs say yes, but runtime behavior should be verified. — **requires direct test**
3. **Are there conditions under which Codex app treats the `GITHUB_PAT` env as available when the app was launched from Spotlight?** Expected: no. — **requires direct test**
4. **Does the Claude Code desktop app use the same `~/.claude/settings.json` and `.mcp.json` resolution as the CLI, including `/mcp` OAuth state?** Docs strongly imply yes via `/desktop` handoff. — **requires direct test**
5. **Does Claude Code env‑expansion bug `#18692` (writing resolved secrets back into `.mcp.json`) still reproduce on the latest 2.1.x?** — **requires direct test after every upgrade**
6. **Does Codex `shell_environment_policy.include_only = ["GH_TOKEN"]` reliably expose GH_TOKEN to subprocesses on macOS CLI and macOS app in current builds?** — **requires direct test** (per [#13426](https://github.com/openai/codex/issues/13426))
7. **Does Anthropic plan to promote `apiKeyHelper` / credential‑helper model to cover MCP server credentials (not just Anthropic API keys)?** As of April 2026, these helpers are scoped to the LLM API key path. — **unresolved, monitor changelog**
8. **Are GPT‑5.x / Opus 4.x model choices affecting config resolution?** Per official docs they do not — model choice is orthogonal to MCP/config surface. Verify quarterly. — **official‑doc‑backed, re‑test on model release**

---

## 15. Verification Checklist for Future Updates

Run on each of these events:

**Every Codex release (CLI ≥ 0.121.0 baseline):**
- [ ] `mcp_oauth_credentials_store` default and keyring service name unchanged
- [ ] `bearer_token_env_var`, `env_http_headers`, `enabled`, `required` semantics unchanged
- [ ] `shell_environment_policy` inheritance works as documented on macOS
- [ ] `codex mcp login <server>` against `https://api.githubcopilot.com/mcp/` still succeeds
- [ ] Codex macOS app sees CLI‑created OAuth credentials

**Every Claude Code release (CLI ≥ 2.1.x baseline):**
- [ ] Run schema validation on `~/.claude/settings.json` and project `.claude/settings.json`
- [ ] Re‑test `${VAR}` expansion in `.mcp.json` for headers and args
- [ ] Re‑test `claude mcp add` does not re‑serialize resolved secret values into `.mcp.json` (bug #18692)
- [ ] Background subagents can see parent MCP OAuth (bug #46228)

**Every macOS minor update (26.5+):**
- [ ] LSEnvironment semantics unchanged
- [ ] `launchctl setenv` survives reboots only with LaunchAgent
- [ ] SMAppService registrations still load correctly
- [ ] Keychain ACLs for `"Codex Auth"` and Claude Code credentials unchanged after upgrade

**Every GPT‑5.x (5.4 → 5.5 → 5.6…) and Opus 4.x (4.6 → 4.7 → 4.8…) release:**
- [ ] Model picker behavior unchanged (Codex `/model`, Claude `/model`)
- [ ] No config keys gated on model version
- [ ] Task budgets / effort levels don't introduce new required config keys

**Every MCP specification revision:**
- [ ] Re‑read authorization section: is OAuth 2.1 + PKCE + CIMD + RFC 8707 still the mandatory pattern?
- [ ] Has DCR been promoted from SHOULD to MUST in more places?
- [ ] Has stdio transport credential guidance changed?

---

## 16. Final Answer to the Smallest Critical Judgment

> **"Is `GITHUB_PAT` inherited from shell environment the right substrate‑level contract at all?"**

**No.** On macOS 26.x, inherited shell environment is an artifact of the Terminal launch path, not a substrate guarantee. Finder, Dock, Spotlight, LaunchServices, and `launchd` user‑domain launches do not honor shell rc files, and the only Apple‑sanctioned ways to inject env into a GUI app (`LSEnvironment`, LaunchAgent plist, `launchctl setenv`) are either per‑app code‑sign‑breaking, globally over‑scoped, or ephemeral. Meanwhile, GitHub's remote MCP server has been GA on OAuth 2.1 + PKCE since September 2025, and Codex + Claude Code both implement OAuth with Keychain‑backed credential storage that is *already* the substrate‑correct pattern. The substrate contract is therefore **OAuth 2.1 + macOS Keychain as the baseline, env‑var MCP auth as a clearly labelled, profile‑gated, CLI‑only fallback, and `op run` wrappers as the CLI bridge for tools that have not yet adopted OAuth.** Everything else — direnv, mise, LaunchAgents, shell aliases, wrapper launchers — has a legitimate place inside that contract, but none of them is the contract.

---

### Appendix A — Key URLs (access date: April 23, 2026)

- https://developer.apple.com/documentation/macos-release-notes/macos-26_4-release-notes
- https://support.apple.com/en-us/122868
- https://www.macrumors.com/2026/04/09/apple-releases-macos-tahoe-26-4-1/
- https://developer.apple.com/documentation/bundleresources/information_property_list/lsenvironment
- https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html
- https://developer.apple.com/documentation/security/keychain-services
- https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web
- https://developers.openai.com/codex/config-basic
- https://developers.openai.com/codex/config-reference
- https://developers.openai.com/codex/config-advanced
- https://developers.openai.com/codex/config-sample
- https://developers.openai.com/codex/mcp
- https://developers.openai.com/codex/cli/reference
- https://developers.openai.com/codex/cli/features
- https://developers.openai.com/codex/auth
- https://developers.openai.com/codex/changelog
- https://developers.openai.com/codex/app
- https://developers.openai.com/codex/app/local-environments
- https://developers.openai.com/codex/app-server
- https://developers.openai.com/codex/models
- https://github.com/openai/codex/blob/main/docs/config.md
- https://github.com/openai/codex/issues/16728
- https://github.com/openai/codex/issues/15818
- https://github.com/openai/codex/issues/13426
- https://github.com/openai/codex/issues/18248
- https://github.com/openai/codex/issues/18404
- https://github.com/openai/codex/issues/10528
- https://github.com/openai/codex/issues/13576
- https://code.claude.com/docs/en/settings
- https://code.claude.com/docs/en/mcp
- https://code.claude.com/docs/en/changelog
- https://code.claude.com/docs/en/overview
- https://code.claude.com/docs/en/desktop-quickstart
- https://code.claude.com/docs/en/troubleshooting
- https://platform.claude.com/docs/en/release-notes/overview
- https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7
- https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop
- https://support.claude.com/en/articles/12611117-deploy-claude-desktop-for-macos
- https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
- https://github.com/anthropics/claude-code/issues/5886
- https://github.com/anthropics/claude-code/issues/6204
- https://github.com/anthropics/claude-code/issues/14032
- https://github.com/anthropics/claude-code/issues/17152
- https://github.com/anthropics/claude-code/issues/18692
- https://github.com/anthropics/claude-code/issues/46228
- https://gist.github.com/xdannyrobertsx/0a395c59b1ef09508e52522289bd5bf6
- https://github.com/github/github-mcp-server
- https://github.com/github/github-mcp-server/blob/main/docs/installation-guides/install-codex.md
- https://github.com/github/github-mcp-server/blob/main/docs/installation-guides/install-claude.md
- https://github.blog/changelog/2025-09-04-remote-github-mcp-server-is-now-generally-available/
- https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp-in-your-ide/set-up-the-github-mcp-server
- https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp/enterprise-configuration
- https://github.com/github/github-mcp-server/issues/600
- https://modelcontextprotocol.io/specification/draft/basic/authorization
- https://modelcontextprotocol.io/docs/develop/connect-local-servers
- https://developer.1password.com/docs/cli/secret-references/
- https://developer.1password.com/docs/cli/secrets-environment-variables/
- https://developer.1password.com/docs/cli/secrets-scripts/
- https://developer.1password.com/docs/cli/reference/commands/run/
- https://developer.1password.com/docs/ssh/agent/
- https://developer.1password.com/docs/ssh/get-started/
- https://mise.jdx.dev/environments/
- https://mise.jdx.dev/environments/secrets/
- https://mise.jdx.dev/environments/secrets/sops.html
- https://direnv.net/
