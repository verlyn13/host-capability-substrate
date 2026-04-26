---
title: HCS Phase 1 Shell/Env Direct-Test Runbook
category: runbook
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-26
tags: [phase-1, shell, environment, execution-context, direct-test, operation-proof]
priority: high
---

# HCS Phase 1 Shell/Env Direct-Test Runbook

Executable plan for the W4 shell/environment direct tests from
[`shell-environment-research.md`](./shell-environment-research.md) v2.0.0.

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

Preflight consequence: direct-test item "Claude Code #18692 does NOT repro on
2.1.120" is **blocked on this host** until Claude Code is updated from 2.1.119
to 2.1.120 or later. Do not record a pass/fail result for that item against
2.1.119.

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
5. **P06 — Shell wrapper-log validation.** Prepare the wrapper and routing
   plan, but do not install a host-wide wrapper until the proof is approved.

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
- Source: `shell-environment-research.md` v2.0.0 §1.3; local Codex CLI
  `0.125.0`
- Observed at: 2026-04-26T19:10:20Z
- Parser version: runbook-v1.0.0
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
- Source: `shell-environment-research.md` v2.0.0 §1.4 and §3.4
- Observed at: 2026-04-26T19:10:20Z
- Parser version: runbook-v1.0.0
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
- Source: `shell-environment-research.md` v2.0.0 §2.3
- Observed at: 2026-04-26T19:10:20Z
- Parser version: runbook-v1.0.0
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
P06 install shell wrapper logger

### Host context
- OS: macOS 26.4.1 25E253
- cwd: `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate`
- Workspace: `host-capability-substrate`
- Shell mode: non_interactive install; later interactive agent routing
- Resolved tool: `scripts/dev/hcs-shell-logger.sh`@repo, `scripts/dev/run-shell-logger-fixture.sh`@repo

### Evidence
- Source: `shell-environment-research.md` v2.0.0 §P06
- Observed at: 2026-04-26T19:10:20Z
- Parser version: runbook-v1.0.0
- Cache status: miss
- Confidence: high for need; wrapper implementation is fixture-tested, host
  routing still needs approval

### Proposed invocation
```json
{
  "command_mode": "argv",
  "file": "/usr/bin/install",
  "argv": ["install", "-m", "0755", "scripts/dev/hcs-shell-logger.sh", "/usr/local/bin/hcs-shell-logger"],
  "env_profile_id": "none",
  "lane": "execute"
}
```

### Risk
- Mutation scope: write-host
- Target resources: `/usr/local/bin/hcs-shell-logger`, wrapper log directory
- Policy tier: host-write-approval-required

### Preflight
Wrapper exists in-repo and `just shell-logger-fixture` must pass before host
installation. It logs only argv shape, interpreter path, cwd, pid/ppid, and
timestamp. It must not log environment values or shell command payloads.

### Preview
`scripts/dev/hcs-shell-logger.sh` would be copied to
`/usr/local/bin/hcs-shell-logger`; live surface routing remains a separate
operation.

### Rollback
Remove `/usr/local/bin/hcs-shell-logger` and restore any agent configuration
that routed through it. Destructive removal needs its own explicit approval.

### Verification
Wrapper-log fixture shows Codex CLI invocation form, Claude Code Bash
invocation form, and apiKeyHelper interpreter without any env value capture.

## Blockers

- Claude Code is currently 2.1.119, so the #18692 non-repro check against
  2.1.120 is blocked.
- P02 and P05 need approved GUI observation paths before execution.
- P06 wrapper implementation now exists in-repo and is fixture-tested; host
  install/routing still requires approval.
- P03/P04/P08/P09 are Wave 2 and should wait until Wave 1 memos establish the
  tested `ExecutionContext` surfaces.

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-04-26 | Initial W4 shell/env direct-test runbook with local host evidence, artifact contract, Wave 1 order, and operation-proof stubs. |
