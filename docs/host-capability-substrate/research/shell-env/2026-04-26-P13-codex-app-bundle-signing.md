---
title: P13 Codex App Bundle and Signing Inspection
category: research
component: host_capability_substrate
status: partial
version: 1.0.0
last_updated: 2026-04-26
tags: [phase-1, p13, codex-app, execution-context, sandbox, signing]
priority: high
---

# P13 Codex App Bundle and Signing Inspection

Partial read-only evidence for shell/environment research prompt P13:
Codex app sandbox as a distinct `ExecutionContext`.

This memo records app-bundle and signing evidence only. It does **not** claim
the full sandbox boundary is characterized. No GUI launch, Keychain probe, or
environment-inheritance probe was run.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-26T19:10:20Z to 2026-04-26T19:20Z |
| macOS | 26.4.1, build 25E253 |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| Codex CLI | `/Users/verlyn13/.npm-global/bin/codex`, `codex-cli 0.125.0` |
| Codex app | `/Applications/Codex.app` |

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
| Sandbox-profile files | No `.sb`, `*sandbox*`, or `.entitlements` files found under `Contents` at max depth 2; only `Info.plist` matched the narrow plist search. |

## Interpretation

The app-bundle evidence supports modeling Codex app separately from Codex CLI:

- It is an Electron app bundle with GUI launch surfaces, URL scheme handling,
  helper apps, and a distinct `CFBundleIdentifier`.
- The `Info.plist` does not show explicit environment injection beyond
  `MallocNanoZone=0`; shell-exported credentials still require P02/P04 runtime
  probes rather than assumption.
- The signing/entitlements evidence is not clean enough to derive a precise
  sandbox capability matrix. Hardened runtime and a stapled notarization ticket
  were visible, but verification failed and entitlements were not extractable.

Do not infer Keychain access, file-system scope, or network scope from this
memo alone. Those require runtime probes or a reliable signing/profile source.

## Follow-Up

1. Re-run signing verification after any Codex app update or reinstall.
2. Locate a reliable source for the active Seatbelt/sandbox profile, if one is
   embedded or derivable. The narrow bundle search did not find one.
3. Run P02 with synthetic markers to confirm GUI env inheritance behavior on
   this host.
4. Run a P13 Keychain-access probe using metadata/existence-only checks. Do not
   request or print credential values.
5. Feed P13 findings into ADR 0017 once runtime probes are complete.

## Commands Used

All commands were read-only:

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
  }
]
```

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-04-26 | Initial partial P13 app-bundle and signing memo. |
