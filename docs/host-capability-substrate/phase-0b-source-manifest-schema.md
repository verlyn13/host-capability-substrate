---
title: HCS Phase 0b — source-manifest.jsonl schema
category: schema
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-23
tags: [phase-0b, raw-staging, manifest, cross-agent]
priority: medium
---

# Phase 0b `source-manifest.jsonl` schema

Per-partition manifest at `.logs/phase-0/<YYYY-MM-DD>/raw/source-manifest.jsonl`. One JSONL record per ingested artifact. Staging scripts and all post-hoc analysis scripts read this file as authoritative for what was captured on that day.

The manifest is the input contract for `measure-extended-rubric.sh`, `measure-guidance-load.sh`, and (in future waves) any automated transcript consumer. If the shape changes, those consumers change with it.

## Common fields

Every record carries:

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `ingested_on` | string (`YYYY-MM-DD`) | yes | UTC partition date this manifest row belongs to |
| `kind` | string (enum below) | yes | Role of this artifact within the partition |
| `format` | string (MIME) | yes | `application/jsonl`, `text/plain`, `text/markdown` |
| `original_path` | absolute path | yes | Where the artifact was when it was ingested (pre-copy) |
| `canonical_path` | absolute path | yes | Where the ingest placed it under `.logs/phase-0/<date>/raw/` |
| `bytes` | integer | yes | Size of the canonical copy |
| `sha256` | 64-hex string | yes | Content hash of the canonical copy |
| `source_variant` | string (enum below) | yes | Which variant this is when multiple copies exist for the same session |

## Enumerations

### `kind`

| Value | Used for |
|-------|----------|
| `daily-telemetry` | Per-day measurement output (e.g., `activity-claude-code.jsonl`). Already in `.logs/phase-0/<date>/`; the manifest row records its presence and hash. |
| `prompt-session-rollout` | The primary rollout/transcript for a cross-agent prompt session (Codex `~/.codex/sessions/.../rollout-*.jsonl`, Claude Code repo-root export). |
| `prompt-session-export` | Secondary export of the same session (Codex `$HOME` pretty-print, `/tmp` fallback, `.debug.log` file, etc.). |
| `external-findings-document` | Upstream evidence document copied from another repo (e.g., system-config incident reports). Carries `upstream_commit` and `topic`. |

`prompt-session-rollout` and `prompt-session-export` are consumed by the cross-agent analysis scripts. Every other `kind` is ignored by those consumers.

### `source_variant`

In preference order (used by the cross-agent analysis scripts' `VARIANT_PREFERENCE` tuple):

| Rank | Value | Typical source |
|------|-------|----------------|
| 1 | `rollout-copy` | Codex `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` — primary, complete event stream |
| 2 | `repo-root-copy` | Claude Code export placed at repo root before staging (`YYYY-MM-DD-HHMMSS-slug.txt`) |
| 3 | `export-home` | Codex `$HOME/codex-<uuid>.*` fallback export (same session, different encoding) |
| 4 | `export-tmp` | Codex `/tmp/codex-<uuid>.*` fallback export |
| — | `already-in-place` | Reserved for `daily-telemetry` — the file was already under `.logs/phase-0/<date>/` |
| — | `system-config-copy` | Reserved for `external-findings-document` from `~/Organizations/jefahnierocks/system-config/` |

Analysis scripts deduplicate by `(agent, prompt_id, session-uuid)` and pick the first match in the preference order above. Rows with `source_variant` not in the cross-agent preference list are skipped by those consumers (they remain in the manifest for audit).

## Prompt-session fields

`prompt-session-rollout` and `prompt-session-export` records additionally carry:

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `agent` | string | yes | `claude-code`, `codex`, `cursor`, `windsurf`, `warp`, `copilot-cli` |
| `prompt_id` | integer (1..8) | yes | Which of the 8 cross-agent simulation prompts this session covers |
| `prompt_slug` | string | no | Short human-readable slug (e.g., `bounded-cleanup`) |

## External-findings fields

`external-findings-document` records additionally carry:

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `upstream_commit` | string | no | Short SHA of the upstream commit that staged the document |
| `topic` | string | no | Short tag (e.g., `op-ipc-queue-deadlock`) used by the brief for grouping |

## Example records

```jsonl
{"ingested_on":"2026-04-23","kind":"prompt-session-rollout","agent":"codex","prompt_id":5,"prompt_slug":"bounded-cleanup","format":"application/jsonl","original_path":"/Users/.../codex/sessions/2026/04/23/rollout-2026-04-23T15-04-47-019dbc96-b720-70f3-b532-1f6e9bc9eb10.jsonl","canonical_path":".logs/phase-0/2026-04-23/raw/cross-agent/day1/codex/prompt-05/rollout-2026-04-23T15-04-47-019dbc96-b720-70f3-b532-1f6e9bc9eb10.jsonl","bytes":159686,"sha256":"9539...","source_variant":"rollout-copy"}
{"ingested_on":"2026-04-23","kind":"prompt-session-export","agent":"codex","prompt_id":4,"prompt_slug":"python-version-divergence","format":"application/jsonl","original_path":"/Users/verlyn13/codex-019dbc96-a884-73e3-af96-5e90b6bf7380.jsonl","canonical_path":".logs/phase-0/2026-04-23/raw/cross-agent/day1/codex/prompt-04/export-home/codex-019dbc96-a884-73e3-af96-5e90b6bf7380.jsonl","bytes":317034,"sha256":"c694...","source_variant":"export-home"}
{"ingested_on":"2026-04-23","kind":"external-findings-document","format":"text/markdown","original_path":"/Users/.../system-config/docs/host-capability-substrate/2026-04-23-op-ipc-queue-deadlock.md","canonical_path":".logs/phase-0/2026-04-23/raw/external/system-config/2026-04-23-op-ipc-queue-deadlock.md","bytes":29005,"sha256":"e37e...","source_variant":"system-config-copy","upstream_commit":"394d8a0","topic":"op-ipc-queue-deadlock"}
```

## Consumer contract (as of 2026-04-23)

- `scripts/dev/measure-extended-rubric.sh` reads prompt-session records, groups by `(agent, prompt_id)`, picks one canonical path per group via `VARIANT_PREFERENCE`.
- `scripts/dev/measure-guidance-load.sh` reads the same records with the same selection, then cross-joins with `cross-agent-runs.jsonl`.
- `scripts/dev/measure-brief.sh` does not read the manifest directly — it consumes the outputs of the above two scripts.

Both analysis scripts fall back to a filesystem walk (`walk_sessions`) when the manifest is absent, applying the same `VARIANT_PREFERENCE` by inferring `source_variant` from path shape (`/export-tmp/`, `/export-home/`, `rollout-` prefix, else `repo-root-copy`). The fallback is defensive for partitions where staging did not land a manifest row; the primary path is manifest-driven.

## Extending the schema

When a new `source_variant` becomes needed:

1. Add the variant string to this doc's `source_variant` enum with its preference rank.
2. Add it to `VARIANT_PREFERENCE` in `measure-extended-rubric.sh` and `measure-guidance-load.sh` (same tuple, order matters).
3. Update `_walk_variant_of()` in both scripts if the new variant is detectable from path shape.
4. Note the change in the measurement-plan change log.

Do not add a new `kind` without also deciding which consumer reads it. Unused `kind` values accumulate without observable effect, which is drift.

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-04-23 | Initial schema documentation. Extracted from observed day-1 manifest shape plus the VARIANT_PREFERENCE consumer contract baked into the v1.2.0 analysis scripts. |
