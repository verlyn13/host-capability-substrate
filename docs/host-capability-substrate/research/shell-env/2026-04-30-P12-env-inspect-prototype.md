---
title: P12 Env Inspect Prototype
category: research
component: host_capability_substrate
status: prototype
version: 1.0.0
last_updated: 2026-04-30
tags: [phase-1, p12, env, secrets, regression-trap]
priority: high
---

# P12 Env Inspect Prototype

Prototype evidence for shell/environment research prompt P12: secret-safe
runtime environment inspection.

## Host Context

| Field | Value |
|---|---|
| Observed at | 2026-04-30T22:16:26Z |
| Repo cwd | `/Users/verlyn13/Organizations/jefahnierocks/host-capability-substrate` |
| Helper | `scripts/dev/hcs-env-inspect.py` |
| Fixture | `scripts/dev/run-env-inspect-fixture.sh` |
| Verification recipe | `just env-inspect-fixture` |

## Implementation Summary

`scripts/dev/hcs-env-inspect.py` inspects only explicitly selected environment
variables. Selection is by repeated `--name` and `--prefix`; there is no default
full-environment dump.

Supported modes:

- `names_only`: emits selected names and presence only.
- `existence_check`: emits selected names and presence only.
- `classified`: emits selected names, presence, name shape, and value-shape
  classification.
- `hashed`: emits selected names, presence, SHA-256 hash, byte length, and
  whether an optional salt was used.

The helper never emits raw environment values. Hash salt is read from a selected
environment variable name through `--hash-salt-env`; the salt itself is not
emitted.

## Fixture Result

`scripts/dev/run-env-inspect-fixture.sh` sets synthetic values for three
variables: a JWT-shaped value, an AWS-access-key-id-shaped value, and a
non-secret-shaped value. The fixture asserts:

- classified mode reports `looks_like_jwt`,
  `looks_like_aws_access_key_id`, and `non_secret_shape`
- missing variables are represented as `present=false`
- hashed mode emits the expected salted digest without emitting the salt
- names-only mode emits no value shape, hash, or byte length
- no raw synthetic value appears in any helper output
- running without selectors exits nonzero instead of dumping the environment

## Trap Coverage

This prototype is a positive operational path for trap #18,
`agent-echoes-secret-in-env-inspection`. It does not replace hook or policy
coverage; it gives agents and future adapters a safe inspection surface to use
instead of `printenv | grep`, `env | grep`, or direct secret-variable echoes.

## Validation

`just env-inspect-fixture` passed on 2026-04-30.
