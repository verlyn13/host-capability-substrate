---
title: P13 Codex App Bundle, Signing, and Process Sandbox Inspection
category: research
component: host_capability_substrate
status: partial
version: 1.3.0
last_updated: 2026-04-26
tags: [phase-1, p13, codex-app, execution-context, sandbox, signing]
priority: high
---

# P13 Codex App Bundle, Signing, and Process Sandbox Inspection

Partial read-only evidence for shell/environment research prompt P13:
Codex app sandbox as a distinct `ExecutionContext`.

This memo records app-bundle, signing, and live process evidence. It does
**not** claim the full sandbox boundary is characterized. No app-internal
Keychain, filesystem, or network capability probe was run.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26T19:10:20Z to 2026-04-27T01:09Z |
| macOS | 26.4.1, build 25E253 |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| Codex CLI | `/Users/verlyn13/.npm-global/bin/codex`, `codex-cli 0.125.0` |
| Codex app | `/Applications/Codex.app` |
| Finder-cold-start app PID | `53495` |

## Evidence Summary

| Probe | Result |
|---|---|
| Bundle path discovery | `/Applications/Codex.app` exists. |
| `CFBundleIdentifier` | `com.openai.codex` |
| `CFBundleShortVersionString` | `26.422.30944` |
| `CFBundleVersion` | `2080` |
| `CFBundlePackageType` | `APPL` |
| URL scheme | `codex` |
| App category | `public.app-category.developer-tools` |
| `LSEnvironment` | Only `MallocNanoZone=0` observed. No credential/env injection keys observed in `Info.plist`. |
| Signing display | Hardened runtime flag present; TeamIdentifier `2DC432GLL2`; notarization ticket reported as stapled. |
| Signing verification | `codesign --verify --verbose=4 /Applications/Codex.app` failed: invalid signature / code or signature modified, arm64. |
| Entitlements extraction | `codesign -d --entitlements :-` did not emit entitlement XML; warning said the binary contains an invalid entitlements blob and the OS will ignore these entitlements. |
| Helper entitlements extraction | `Codex Helper`, `Codex Helper (Renderer)`, `Codex Helper (GPU)`, and `Codex Helper (Plugin)` all produced the same invalid-entitlements warning and no entitlement XML. |
| Resource executable entitlements | `Contents/Resources/codex` and `Contents/Resources/node_repl` produced the same invalid-entitlements warning and no entitlement XML. |
| Resource executable signing display | `codex` and `node_repl` have hardened runtime flags and TeamIdentifier `2DC432GLL2`, but `codesign --verify` failed for both with invalid signature / code modified. |
| Sandbox-profile files | No `.sb`, `*sandbox*`, `*.entitlements`, or `*profile*` files found under `Contents` at max depth 5; only the app `Info.plist` matched the narrow plist search. |
| Helper bundle ids | `Codex Helper`, `Codex Helper (Renderer)`, `Codex Helper (GPU)`, and `Codex Helper (Plugin)` all reported `com.openai.codex.helper`. |
| Current process tree | Finder-launched main PID `53495` has parent PID `1`; children include GPU helper, network utility helper, app-server, and renderer helper. |
| Process sandbox flags | GPU and network helpers include `--seatbelt-client`; network helper includes `--service-sandbox-type=network`; renderer includes `--enable-sandbox` and `--seatbelt-client`; `codex app-server` showed no visible `--seatbelt-client` flag. |
| App-server children | The app-server launched `node_repl` and MCP child processes. Full argv values were not persisted in this memo because process argv can carry sensitive material. |
| GUI env inheritance cross-reference | P02 Finder-origin cold start found `p02_gui_marker_present=false`; GUI launch does not inherit the synthetic terminal-only marker. |
| App-server protocol schema | `codex app-server generate-json-schema --out /tmp/hcs-p13-app-server-schema` succeeded. Generated schema includes `command/exec`, `thread/shellCommand`, filesystem RPCs (`fs/readFile`, `fs/readDirectory`, `fs/writeFile`, `fs/remove`, `fs/watch`, etc.), permission profiles with filesystem and network controls, account status shapes, and MCP status/OAuth notifications. |
| App-server GUI control socket | `codex app-server proxy` failed because `/Users/verlyn13/.codex/app-server-control/app-server-control.sock` did not exist. No GUI app-server control connection was available through that path. |
| Temporary stdio app-server initialize | `codex app-server --listen stdio://` initialized successfully and returned user-agent, `codexHome`, and platform fields. Account/status requests were not used. |
| MCP status typed request | `mcpServerStatus/list` returned status and tool/resource inventory, including auth-status classifications. The full response is intentionally not pasted because it includes large tool schemas and connector metadata. |
| `command/exec` status probe | A typed `command/exec` request for `/usr/bin/true` in the repo cwd returned `exitCode: 0`, empty stdout, and empty stderr. |
| Temporary server cleanup | The stdio app-server exited cleanly on EOF after the probe. |

## Interpretation

The app-bundle evidence supports modeling Codex app separately from Codex CLI:

- It is an Electron app bundle with GUI launch surfaces, URL scheme handling,
  helper apps, a distinct app `CFBundleIdentifier`, and helper bundle ids under
  `com.openai.codex.helper`.
- The `Info.plist` does not show explicit environment injection beyond
  `MallocNanoZone=0`; P02 now confirms a Finder-origin cold launch did not
  inherit a synthetic terminal-only marker.
- The signing/entitlements evidence is not clean enough to derive a precise
  sandbox capability matrix. Hardened runtime and a stapled notarization ticket
  were visible, but verification failed and entitlements were not extractable
  from the app, helper, or resource executables.
- Live Electron helper process arguments show Chromium/Electron sandbox markers
  (`--seatbelt-client`, `--enable-sandbox`, and
  `--service-sandbox-type=network`) on helpers, but not enough to infer the
  effective macOS Seatbelt profile for app-server child processes.
- The generated app-server protocol schema is a better P13 probe candidate than
  raw process argv. It exposes typed command, filesystem, network-permission,
  account, and MCP-status surfaces. It does not expose a Keychain-specific probe
  in the generated schema inspected here.
- The typed stdio app-server path is usable for status-code probes even when
  the GUI control socket is absent. The first live `command/exec` status probe
  proved the protocol can return exit status without command output.
- `mcpServerStatus/list` is useful but noisy: it can emit large tool schemas and
  connector metadata. Future evidence should summarize status fields and avoid
  pasting full response bodies.

Do not infer Keychain access, file-system scope, or network scope from this
memo alone. Those still require app-internal runtime probes or a reliable
signing/profile source.

## Follow-Up

1. Re-run signing verification after any Codex app update or reinstall.
2. Locate a reliable source for the active Seatbelt/sandbox profile, if one is
   embedded or derivable. The narrow bundle search did not find one.
3. Extend the app-server protocol probe to filesystem and network status-code
   checks only. Avoid `thread/shellCommand` for HCS probes because the schema
   says it runs unsandboxed with full access; prefer `command/exec` with an
   explicit permission profile where possible.
4. Run a P13 Keychain-access probe only if a metadata/existence-only method is
   available. The generated schema did not expose a Keychain-specific request.
   Do not request or print credential values.
5. Feed P13 findings into ADR 0017 once runtime probes are complete.

## Commands Used

Key commands were metadata-only or status-code probes. The app-server probe
used `/usr/bin/true` and returned only exit status plus empty output:

```json
[
  {
    "file": "/usr/bin/plutil",
    "argv": ["plutil", "-extract", "CFBundleIdentifier", "raw", "/Applications/Codex.app/Contents/Info.plist"]
  },
  {
    "file": "/usr/bin/plutil",
    "argv": ["plutil", "-extract", "CFBundleShortVersionString", "raw", "/Applications/Codex.app/Contents/Info.plist"]
  },
  {
    "file": "/usr/bin/plutil",
    "argv": ["plutil", "-extract", "CFBundleVersion", "raw", "/Applications/Codex.app/Contents/Info.plist"]
  },
  {
    "file": "/usr/bin/codesign",
    "argv": ["codesign", "-dv", "--verbose=4", "/Applications/Codex.app"]
  },
  {
    "file": "/usr/bin/codesign",
    "argv": ["codesign", "--verify", "--verbose=4", "/Applications/Codex.app"]
  },
  {
    "file": "/usr/bin/codesign",
    "argv": ["codesign", "-d", "--entitlements", ":-", "/Applications/Codex.app/Contents/MacOS/Codex"]
  },
  {
    "file": "/usr/bin/find",
    "argv": ["find", "/Applications/Codex.app/Contents", "-maxdepth", "5", "(", "-iname", "*.sb", "-o", "-iname", "*sandbox*", "-o", "-iname", "*.entitlements", "-o", "-iname", "*profile*", ")", "-print"]
  },
  {
    "file": "/usr/bin/codesign",
    "argv": ["codesign", "-d", "--entitlements", ":-", "/Applications/Codex.app/Contents/Frameworks/Codex Helper.app/Contents/MacOS/Codex Helper"]
  },
  {
    "file": "/usr/bin/codesign",
    "argv": ["codesign", "-d", "--entitlements", ":-", "/Applications/Codex.app/Contents/Resources/codex"]
  },
  {
    "file": "/usr/bin/pgrep",
    "argv": ["pgrep", "-P", "53495", "-fl", "."]
  },
  {
    "file": "/Users/verlyn13/.npm-global/bin/codex",
    "argv": ["codex", "app-server", "generate-json-schema", "--out", "/tmp/hcs-p13-app-server-schema"]
  },
  {
    "file": "/usr/bin/rg",
    "argv": ["rg", "-n", "keychain|network|file|sandbox|fs|filesystem|path|read|write|exec|shell|auth|mcp|status|capab|capability", "/tmp/hcs-p13-app-server-schema"]
  },
  {
    "file": "/Users/verlyn13/.npm-global/bin/codex",
    "argv": ["codex", "app-server", "proxy"]
  },
  {
    "file": "/Users/verlyn13/.npm-global/bin/codex",
    "argv": ["codex", "app-server", "--listen", "stdio://"]
  },
  {
    "file": "app-server JSON-RPC",
    "argv": ["command/exec", "command=/usr/bin/true", "outputBytesCap=1024"]
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.3.0 | 2026-04-26 | Added approved app-server live probe: GUI control socket absent, temporary stdio server initialized, MCP status inventory returned, and typed `command/exec` `/usr/bin/true` returned exit code 0 with empty output. |
| 1.2.0 | 2026-04-26 | Added generated app-server protocol schema evidence and narrowed the next P13 live-probe design toward typed protocol requests rather than process-argv inspection. |
| 1.1.0 | 2026-04-26 | Added helper/resource signing checks and live process sandbox flag evidence. |
| 1.0.0 | 2026-04-26 | Initial partial P13 app-bundle and signing memo. |
