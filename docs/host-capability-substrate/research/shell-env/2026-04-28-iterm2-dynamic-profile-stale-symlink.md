---
title: iTerm2 Dynamic Profile Stale Symlink Field Note
category: research
component: host_capability_substrate
status: observed
version: 1.0.0
last_updated: 2026-04-28
tags: [phase-1, shell-env, iterm2, dynamic-profiles, host-adapter, compatibility]
priority: medium
---

# iTerm2 Dynamic Profile Stale Symlink Field Note

First-party host observation for HCS shell/environment research. This records
an iTerm2 adapter failure caused by stale host-managed presentation state after
the managed shell surface had already moved to zsh-only.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-28 after fresh reboot |
| Host repo | `/Users/verlyn13/Organizations/jefahnierocks/system-config` |
| Dynamic profiles dir | `/Users/verlyn13/Library/Application Support/iTerm2/DynamicProfiles` |
| Managed profile source | `system-config/iterm2/profiles` |
| Shell policy | zsh-only managed interactive shell; fish not managed |

## Observation

iTerm2 showed a Dynamic Profiles error on startup:

```text
Could not read Dynamic Profile from file
/Users/verlyn13/Library/Application Support/iTerm2/DynamicProfiles/03-human-fish.json:
The file "03-human-fish.json" couldn't be opened because there is no such file.
```

Local inspection found a broken symlink:

```text
03-human-fish.json -> /Users/verlyn13/Organizations/jefahnierocks/system-config/iterm2/profiles/03-human-fish.json
```

The target profile had been removed from the repo, consistent with the
system-config rule that fish is not a managed shell surface. The deployed
symlink remained in iTerm2's DynamicProfiles directory, so iTerm2 treated it as
a profile read failure at launch.

## Immediate Fix

`system-config/scripts/install-iterm2-profiles.sh` was updated so its stale
managed-symlink cleanup loop handles broken symlinks. The prior loop checked
`-e` before `-L`, which skipped broken symlinks because their target no longer
existed.

The current host should keep only these system-config-managed dynamic profile
links:

- `00-base.json`
- `01-dev-zsh.json`
- `02-agentic-zsh.json`
- `10-servers.json`

`OrbStack.json` remains app-owned and should not be modified by
system-config.

## Interpretation

This is an adapter-state drift issue, not a shell-runtime issue. The shell
policy was already correct: zsh is the only managed interactive shell, bash is
runtime/script-only, and fish is out of scope. The failure came from iTerm2
loading stale presentation metadata that referenced a deleted repo artifact.

For HCS design, model terminal apps and GUI launchers as host adapters with
their own durable caches and symlinked/generated state. They can preserve old
references across reboots even when the source repo has moved on.

## Design Considerations

- HCS host-state collection should distinguish managed source state from
  deployed adapter state.
- Terminal profile health checks should verify symlink targets, JSON parse
  status, GUID uniqueness, and shell command compatibility.
- Removed shell surfaces require deployed-state cleanup receipts, not just
  source deletion.
- Adapter diagnostics should avoid treating iTerm2 profile commands as policy.
  Profiles are entrypoints and presentation; shell policy remains in
  system-config and, later, HCS policy/evidence.

## Related

- `system-config/AGENTS.md` shell policy
- `system-config/iterm2/README.md`
- `system-config/scripts/install-iterm2-profiles.sh`
- HCS `ExecutionContext` and shell/environment research work
