---
title: HCS field addendum - Cloudflare MCP diagnostics
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-25
tags: [research, external-control-plane, cloudflare, mcp, diagnostics, rate-limit, fanout, quarantine]
priority: high
---

# Cloudflare MCP Diagnostics Addendum

This field addendum records what the temporary MCP diagnostics added to the
Cloudflare 429 lesson. Source evidence lives in `system-config`:

- `scripts/mcp-cloudflare-diagnostics.sh`
- `scripts/mcp-usage-collector.sh`
- `docs/host-capability-substrate/2026-04-24-cloudflare-mcp-429-fanout.md`
- `docs/cloudflare-mcp.md`
- collector samples under `~/.local/state/system-config/mcp-usage-collector/`

The diagnostics do not call Cloudflare and do not resolve secrets. The sample
collector records local process/log/state shape only, with command argv
redacted before JSONL persistence.

## Observed Window

Samples inspected through `2026-04-25T19:37:25Z`:

| Date | Samples | Observed range | Authenticated Cloudflare MCP sessions |
|---|---:|---|---|
| 2026-04-24 | 50 | `23:09:23Z` -> `23:59:18Z` | constant 9 |
| 2026-04-25 | 621 | `00:00:19Z` -> `19:37:25Z` | min 0, max 11 |

Across both days, authenticated Cloudflare MCP sessions were present in 92
samples and peaked at 11 concurrent `mcp-remote` sessions to
`https://mcp.cloudflare.com/mcp`.

Owners observed for authenticated Cloudflare sessions during nonzero samples:

| Owner | Samples with sessions | Total session observations | Max concurrent |
|---|---:|---:|---:|
| Claude Code CLI | 92 | 276 | 3 |
| Claude Code macOS app | 91 | 258 | 3 |
| Claude Desktop | 91 | 173 | 2 |
| Codex CLI | 92 | 143 | 3 |

The last pre-quarantine sample at `2026-04-25T01:34:13Z` still showed 9
authenticated Cloudflare MCP sessions. The quarantine marker was written at
`2026-04-25T01:34:26Z`. The next sample at `2026-04-25T01:35:13Z` showed 0
authenticated Cloudflare MCP sessions, while `cloudflare-docs` remained
available. The latest inspected sample still had 0 authenticated Cloudflare MCP
sessions and 1 unauthenticated Cloudflare docs session.

## Planning Interpretation

The relevant HCS lesson is not just "Cloudflare returned 429." The failure mode
is shared-token control-plane fan-out:

1. Multiple agent hosts can each launch long-lived authenticated `mcp-remote`
   sessions for the same account-scoped Cloudflare token.
2. A single `cloudflare.execute` call can contain multiple
   `cloudflare.request()` calls, including accidental parallelism.
3. Cloudflare rate limits the aggregate token/account traffic, not the visible
   agent turn or MCP session.
4. A local quarantine switch can stop new authenticated sessions and reap
   existing ones while preserving unauthenticated documentation access.

Therefore, HCS needs a principal-scoped control-plane budget and a local
session-fanout observation, not only per-request retry handling.

## Substrate Implications

- ADR 0015 should model authenticated MCP fan-out as first-class evidence:
  session count, endpoint, owning host surface, token/principal reference,
  sampled_at, and quarantine state.
- `RateLimitObservation` needs a companion or subtype for
  `ControlPlaneBackoffMarker` / `last_cf_mcp_429`, because the useful state is
  a shared quiet window across repos and tools.
- `ResourceBudget` should be principal-scoped for Cloudflare: dashboard,
  Wrangler, direct API, and MCP all consume the same practical budget.
- Cloudflare docs access should remain separate from authenticated API access.
  It is a useful degraded mode during quarantine.
- A broker must serialize mutations per token/account and make Codemode
  fan-out visible before execution.
- Diagnostics should be secret-safe. The current temporary collector persists
  redacted argv, but the permanent HCS operation should be backed by the typed
  process-inspection work from trap #37 so full argv is not the default
  evidence path.

## Regression Trap Seed

Name:

```text
cloudflare-mcp-mutation-without-fanout-check
```

Expected behavior: before any Cloudflare MCP mutation, an agent checks local
fan-out diagnostics, honors `last_cf_mcp_429`, chooses a single broker/writer
surface, and refuses hidden parallelism in `cloudflare.execute`.

Suggested fixture name:

```text
cloudflare-mcp-fanout-and-quarantine.fixture.md
```

Minimum fixture facts:

```text
shared Cloudflare token/account exists
multiple authenticated mcp-remote sessions are live
last_cf_mcp_429 marker is recent
cloudflare-docs remains available
quarantine marker disables authenticated wrapper
post-quarantine authenticated session count is zero
```

