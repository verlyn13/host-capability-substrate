---
title: HCS Phase 1 Shell/Env Direct-Test Runbook
category: runbook
component: host_capability_substrate
status: active
version: 1.5.1
last_updated: 2026-05-01
tags: [phase-1, shell, environment, execution-context, direct-test, operation-proof]
priority: high
---

# HCS Phase 1 Shell/Env Direct-Test Runbook

Executable plan for the W4 shell/environment direct tests from
[`shell-environment-research.md`](./shell-environment-research.md) v2.7.0.

Target ring: **Ring 3 measurement/eval harness + docs**. This runbook does not
change Ring 0 schemas, policy, hooks, Codex profiles, or system-config managed
MCP definitions. ADR 0016/0017/0018 remain synthesis outputs after the direct
tests; do not pre-implement their schema conclusions here.

## Current Host Evidence

Observed locally on 2026-04-26T19:10:20Z:

| Surface | Evidence |
|---|---|
| macOS | `sw_vers` -> `ProductVersion 26.4.1`, `BuildVersion 25E253` |
| Codex CLI | `/Users/verlyn13/.npm-global/bin/codex`, `codex-cli 0.125.0` |
| Codex app | `/Applications/Codex.app`, bundle id `com.openai.codex`, app version `26.422.30944`, build `2080` |
| Codex app entitlements probe | `codesign -d --entitlements :- /Applications/Codex.app` did not emit entitlements; it reported an invalid entitlements blob warning. P13 must follow up with stricter signing/profile inspection. |
| Claude Code CLI | `/Users/verlyn13/.local/bin/claude`, `2.1.119 (Claude Code)` |
| Local tool paths | `codesign=/usr/bin/codesign`, `security=/usr/bin/security`, `launchctl=/bin/launchctl`, `plutil=/usr/bin/plutil`, `osascript=/usr/bin/osascript` |

Historical preflight consequence at that time: direct-test item "Claude Code
#18692 does NOT repro on 2.1.120" was blocked because local Claude Code was
2.1.119. That version blocker is superseded by the current overlay below.

Current overlay as of 2026-04-30:

| Surface | Evidence |
|---|---|
| macOS | `ProductVersion 26.4.1`, `BuildVersion 25E253` |
| Git | `main` at `a4f6ee3`, five local commits ahead of `origin/main` after the P08/P09/P11/P12 commits |
| Codex CLI | `codex-cli 0.128.0`; above baseline `0.125.0`; emitted sandbox PATH warning during `--version` but returned successfully |
| Claude Code CLI | `2.1.123`; above baseline `2.1.120` |
| Managed tools | `node 24.15.0`, `shellcheck 0.11.0`, `shfmt 3.13.1`, `just 1.50.0`, `bun 1.3.13`, `python 3.13.13`, `uv 0.11.8`, `pnpm 10.33.2` |

The old Claude Code #18692 version blocker is cleared by the installed
`2.1.123` CLI. Any actual #18692 non-repro check still needs its own
secret-safe operation proof because it touches MCP auth/config behavior.

## Evidence Rules

- Use synthetic markers only: `HCS_*_MARKER` values with no credential shape.
- Never run broad `env`, `printenv`, `ps aux`, `ps -Ao ... command`, `pgrep -fl`,
  or `security ... -g` during these tests.
- Keychain checks must prove metadata or existence only. They must not reveal
  password data or OAuth token material.
- Runtime logs live under `.logs/phase-1/shell-env/<YYYY-MM-DD>/` and stay
  gitignored. Commit only curated memos or golden fixtures after redaction.
- Every host-writing operation needs a separate operation proof and explicit
  human approval. Installing `/usr/local/bin/hcs-shell-logger`, changing
  launchd env, launching GUI apps, and editing system-config are not implicit.
- GUI tests must distinguish Terminal launch, `open(1)` launch, and
  Spotlight/Dock/Finder launch. Do not collapse them into one result.

## Wave 1 Order

1. **P02 — Terminal vs Spotlight GUI env inheritance.** Highest value, low
   runtime cost. Use a synthetic marker and a Codex-app observation path that
   records presence/absence only.
2. **P01 — Codex auth reuse smoke.** Confirm metadata for shared
   `CODEX_HOME`/Keychain reuse. Operational migration off `GITHUB_PAT` remains
   a system-config task after evidence is captured.
3. **P05 — Claude Desktop auth boundary.** Confirm the docs-level result with a
   smoke test that does not expose API keys.
4. **P13 — Codex app sandbox characterization.** Continue from the app bundle
   evidence above; characterize entitlements, Keychain access, file scope, and
   env injection behavior.
5. **P06 — Shell provenance validation.** Wrapper validation is complete for
   PATH-routed controls, and both Codex/Claude observed surfaces used absolute
   `/bin/zsh`. Execute
   `research/shell-env/2026-04-27-P06-provenance-experiment-plan.md` for the
   remaining tool-native, startup-sentinel, and host-telemetry proof lanes.

## Current Prompt Status

| Prompt | Status on 2026-04-30 | Current artifact |
|---|---|---|
| P01 | Migration blocked; GitHub MCP OAuth dynamic registration failed, so PAT/broker decision remains open. | `research/shell-env/2026-04-26-P01-codex-auth-metadata.md` |
| P02 | Validated locally for Finder-origin Codex app launch: terminal-only marker absent. | `research/shell-env/2026-04-26-P02-codex-app-gui-launch-env.md` |
| P05 | Runtime smoke complete for Claude Desktop auth boundary. | `research/shell-env/2026-04-26-P05-claude-desktop-auth-boundary.md` |
| P06 | Closed for Codex CLI and Claude Code CLI through host telemetry; app/IDE surfaces remain separate prompts. | `research/shell-env/2026-04-28-P06-host-telemetry-rerun.md` |
| P08 | Initial Codex CLI tool-call subprocess snapshot committed as a fixture. | `research/shell-env/2026-04-30-P08-provenance-snapshot.md` |
| P09 | Terminal fixtures committed for blocked/untrusted and isolated allowed/trusted paths; GUI/IDE matrix remains open. | `research/shell-env/2026-04-30-P09-direnv-mise-baseline.md`; `research/shell-env/2026-04-30-P09-direnv-mise-terminal-matrix.md` |
| P11 | LaunchAgent/user-session env policy design memo committed; not an accepted ADR. | `research/shell-env/2026-04-30-P11-launchagent-env-policy-table.md` |
| P12 | Repo-local secret-safe env-inspect prototype and fixture landed. | `research/shell-env/2026-04-30-P12-env-inspect-prototype.md` |
| P13 | Open/narrowed; needs reachable GUI app-server control path or human-run sterile Codex app UI probe. | `research/shell-env/2026-04-26-P13-codex-app-bundle-signing.md` |

## Output Contract

Each prompt gets two artifacts:

- Raw local evidence: `.logs/phase-1/shell-env/<YYYY-MM-DD>/<prompt>.jsonl`
- Curated memo: `docs/host-capability-substrate/research/shell-env/<YYYY-MM-DD>-<prompt>.md`

Raw JSONL shape:

```json
{
  "ts": "2026-04-26T00:00:00Z",
  "prompt_id": "P02",
  "surface": "codex_app",
  "test_case": "spotlight_launch_marker_absence",
  "observed": "absent",
  "evidence_kind": "existence_only",
  "redaction": "no_secret_values_collected",
  "tool_versions": {
    "codex_cli": "0.125.0",
    "codex_app": "26.422.30944 (2080)",
    "macos": "26.4.1 25E253"
  }
}
```

## Operation Proofs

These are proposals for later runs. A proof marked `not ready` must not be run
until its missing preflight is resolved.

### Operation
P13 inspect Codex app bundle metadata

### Host context
- OS: macOS 26.4.1 25E253
- cwd: `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate`
- Workspace: `host-capability-substrate`
- Shell mode: non_interactive
- Resolved tool: `/usr/bin/plutil`@system, `/usr/bin/codesign`@system

### Evidence
- Source: local `plutil` and `codesign` probes run 2026-04-26T19:10:20Z
- Observed at: 2026-04-26T19:10:20Z
- Parser version: runbook-v1.0.0
- Cache status: miss
- Confidence: high

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "/usr/bin/plutil",
  "argv": ["plutil", "-extract", "CFBundleIdentifier", "raw", "/Applications/Codex.app/Contents/Info.plist"],
  "env_profile_id": "none",
  "lane": "inspect"
}
```

### Risk
- Mutation scope: none
- Target resources: `/Applications/Codex.app/Contents/Info.plist`
- Policy tier: read-only-inspect

### Preflight
`/Applications/Codex.app/Contents/Info.plist` exists and is readable.

### Preview
Expected output is one bundle identifier string, no secret material.

### Rollback
not available: read-only operation.

### Verification
Curated P13 memo records bundle id, app version, build number, and any
entitlements-inspection warnings.

### Operation
P01 inspect Codex Keychain metadata for shared CODEX_HOME auth

### Host context
- OS: macOS 26.4.1 25E253
- cwd: `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate`
- Workspace: `host-capability-substrate`
- Shell mode: non_interactive
- Resolved tool: `/usr/bin/security`@system

### Evidence
- Source: `shell-environment-research.md` v2.1.0 §1.3; local Codex CLI
  `0.125.0`
- Observed at: 2026-04-26T19:10:20Z
- Parser version: runbook-v1.1.0
- Cache status: miss
- Confidence: high for expected service/account shape; best-effort for local
  Keychain state until the operation runs

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "/usr/bin/security",
  "argv": ["security", "find-generic-password", "-s", "Codex Auth"],
  "env_profile_id": "none",
  "lane": "inspect"
}
```

### Risk
- Mutation scope: none
- Target resources: macOS login Keychain metadata for service `Codex Auth`
- Policy tier: read-sensitive-metadata

### Preflight
Confirm the invocation does not include `-g`; `-g` may print secret material.

### Preview
Expected output is Keychain item metadata. Password data must not be requested
or persisted.

### Rollback
not available: read-only operation.

### Verification
Curated P01 memo records only service name, account shape, CODEX_HOME hash
relationship if derivable, and whether item metadata exists.

### Operation
P02 validate Codex app GUI env marker inheritance

### Host context
- OS: macOS 26.4.1 25E253
- cwd: `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate`
- Workspace: `host-capability-substrate`
- Shell mode: interactive GUI plus non_interactive helper
- Resolved tool: not available: GUI observation path not selected yet

### Evidence
- Source: `shell-environment-research.md` v2.1.0 §1.4 and §3.4
- Observed at: 2026-04-26T19:10:20Z
- Parser version: runbook-v1.1.0
- Cache status: miss
- Confidence: likely expected outcome; local host behavior not yet measured

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "not-ready",
  "argv": [],
  "env_profile_id": "synthetic-marker-only",
  "lane": "interactive"
}
```

### Risk
- Mutation scope: write-host if `launchctl setenv` is used; none if only
  terminal-local markers are used
- Target resources: Codex app process environment, temporary synthetic marker
- Policy tier: interactive-host-probe

### Preflight
not available: choose the Codex-app observation mechanism that can report only
marker presence/absence without exposing environment values.

### Preview
Expected result: terminal-local marker is absent when Codex app is launched from
Spotlight/Dock/Finder; launchd-set marker may be visible depending on app
restart timing.

### Rollback
If `launchctl setenv` is used, run an explicit unset operation for the same
synthetic marker after capture. Do not use credential-shaped variable names.

### Verification
Curated P02 memo records launch method, marker name, observed
present/absent-only result, and whether the app was fully restarted.

### Operation
P05 confirm Claude Desktop ignores apiKeyHelper/API-key env

### Host context
- OS: macOS 26.4.1 25E253
- cwd: `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate`
- Workspace: `host-capability-substrate`
- Shell mode: interactive GUI plus non_interactive helper
- Resolved tool: not available: Claude Desktop app path not resolved in this
  runbook pass

### Evidence
- Source: `shell-environment-research.md` v2.1.0 §2.3
- Observed at: 2026-04-26T19:10:20Z
- Parser version: runbook-v1.1.0
- Cache status: miss
- Confidence: authoritative for docs-level boundary; local smoke not captured

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "not-ready",
  "argv": [],
  "env_profile_id": "synthetic-marker-only",
  "lane": "interactive"
}
```

### Risk
- Mutation scope: none unless GUI app state is changed
- Target resources: Claude Desktop auth surface
- Policy tier: interactive-host-probe

### Preflight
Resolve Claude Desktop app path and version. Use synthetic marker names only;
do not set `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN` to real values.

### Preview
Expected result: Claude Desktop continues to use app OAuth and does not call
Claude Code `apiKeyHelper`.

### Rollback
Unset any synthetic marker set for the smoke test and quit/reopen Claude
Desktop only with human approval.

### Verification
Curated P05 memo records app version, launch method, and absence of helper/API
key usage evidence.

### Operation
P06 provenance experiment

### Host context
- OS: macOS 26.4.1 25E253
- cwd: `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate`
- Workspace: `host-capability-substrate`
- Shell mode: non_interactive controls; host telemetry run pending
- Resolved tool: not available: host telemetry tool and action-time runner are
  not selected yet

### Evidence
- Source: `shell-environment-research.md` v2.1.0 §P06 and
  `research/shell-env/2026-04-27-P06-provenance-experiment-plan.md`
- Observed at: 2026-04-27T05:45:01Z
- Parser version: runbook-v1.1.0
- Cache status: miss
- Confidence: high for need; runtime shape is observed, but host-level
  `execve` argv, startup-file effects, and parent provenance remain open

### Proposed invocation
not available: the provenance experiment needs a fresh action-time operation
proof once the host telemetry mechanism is selected.

### Risk
- Mutation scope: inspect-host for process telemetry; write-local for ignored
  `.logs/` artifacts
- Target resources: `.logs/phase-1/shell-env/**`, temporary `ZDOTDIR`,
  process telemetry stream
- Policy tier: not available: substrate classifier is not implemented yet

### Preflight
`just shell-logger-fixture` must pass, local zsh sentinel controls must pass,
and the selected host telemetry command must have an action-time approval proof.
The run must not collect environment values, raw command payloads, or real
startup-file contents.

### Preview
Expected artifacts are lane-separated tool-native, sentinel, host-telemetry,
parsed, and report files under ignored `.logs/phase-1/shell-env/**`. Published
docs should contain only redacted summaries and payload hashes.

### Rollback
Remove the temporary run directory under `.logs/phase-1/shell-env/**` only after
confirming it is not load-bearing evidence. Stop any telemetry process started
for the run. Do not remove `/usr/local/bin/hcs-shell-logger` without a separate
operation proof because the wrapper is already installed host state.

### Verification
Wrapper-log fixture proves redaction and argv preservation for controlled
wrapper routes. Live PATH-routed probes captured `bash`, `sh`, and `zsh` by
name, but Codex CLI used an absolute `/bin/zsh -lc` path and bypassed the
wrapper. P06 closure now depends on the provenance experiment plan, not on
additional PATH wrapper runs.

## Blockers

- Claude Code version is no longer the #18692 blocker; local CLI is now
  `2.1.123`. The check remains unrun and still needs a separate operation proof.
- P05 approved GUI observation is complete for the Finder-origin synthetic
  marker path; terminal `open -b` propagated the marker and is not a clean GUI
  proxy.
- P06 CLI evidence is closed for Codex CLI and Claude Code CLI; do not reopen
  the old PATH-wrapper route except as a negative control.
- P03/P04 and the GUI/IDE portion of P09 remain Wave 2 work. P08 has an initial
  Codex CLI tool-call fixture, but app/IDE snapshots should wait for direct
  execution-context probes.
- P09 terminal fixtures do not prove GUI launch or IDE extension behavior.
- P12 is a repo-local prototype only; the final Ring 1 operation surface waits
  for ontology/policy schema work.
- P11 is a design memo only; do not treat it as live LaunchAgent policy or an
  accepted ADR.

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.5.1 | 2026-05-01 | Corrected the referenced shell research version and current git overlay after the P11 commit. |
| 1.5.0 | 2026-04-30 | Added P11 LaunchAgent/user-session env policy design memo status. |
| 1.4.0 | 2026-04-30 | Added P09 isolated allowed/trusted terminal fixture status. |
| 1.3.0 | 2026-04-30 | Added P09 non-mutating direnv/mise baseline status. |
| 1.2.0 | 2026-04-30 | Added current toolchain overlay, prompt status table, P08/P12 fixture status, and cleared the stale Claude Code version blocker while keeping #18692 unrun. |
| 1.1.0 | 2026-04-27 | Updated P06 from wrapper-log validation to provenance closure and linked the three-lane provenance experiment plan. |
| 1.0.0 | 2026-04-26 | Initial W4 shell/env direct-test runbook with local host evidence, artifact contract, Wave 1 order, and operation-proof stubs. |
