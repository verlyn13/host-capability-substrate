---
title: HCS field addendum - Cloudflare tunnel audience validation
category: research
component: host_capability_substrate
status: active
version: 1.0.0
last_updated: 2026-04-24
tags: [research, external-control-plane, cloudflare, cloudflared, access, audience, tunnel]
priority: medium
---

# Cloudflare Tunnel Audience Validation Addendum

This field addendum records the later 2026-04-24 root-cause correction that followed the broader Cloudflare Access Stage 3a lessons brief. Source evidence is the local Codex/Hetzner coordination session from 2026-04-24 AKDT, especially session `019dc1ac-02f1-78f1-a1b6-338bffaa1002`.

## Root cause

The late 403 was tunnel-side JWT audience validation, not Cloudflare Access policy evaluation.

Observed state:

```text
Cloudflare Access authentication: service-token path accepted for the child app
cloudflared originRequest.access.required: true
cloudflared audTag list: parent app AUD only
failing JWT aud: child app AUD
cloudflared log: AccessJWTValidator rejected the child AUD
origin logs: no /api/internal/run-published request reached FastAPI
```

The important correction is that a Cloudflare Access success does not prove the request reached the origin. A protected tunnel can run its own Access JWT audience allowlist, and that allowlist can reject a valid child-app JWT before the application sees the request.

In this incident, the correct fix was host configuration: append the child app AUD to the `audTag` list for the protected hostname, validate the tunnel config, reload `cloudflared`, and run one bounded curl. A Cloudflare Access policy mutation was no longer justified once host logs showed the post-Access audience rejection.

## Substrate implications

- HCS must model remote-control-plane operations as layered authority checks, not a single "Cloudflare allowed/denied" fact.
- `PathCoverage` is necessary but not sufficient; the origin-side validator must also have an explicit audience binding for every Access application AUD that can legitimately mint a JWT for the protected path.
- Verification plans should include "did the request reach origin?" evidence before proposing another provider-side policy mutation.
- A future Cloudflare adapter should return typed evidence for Access app AUDs, tunnel `audTag` coverage, cf-ray / GraphQL Access outcome, tunnel validator logs where available, and origin reachability.
- The safe next action after "Access succeeded, origin did not receive, validator rejected AUD" is an `OriginAccessValidator` or `AudienceValidationBinding` host-config proposal, not reusable-policy isolation.

## Regression trap seed

Name:

```text
cloudflare-access-token-valid-but-tunnel-audtag-mismatch
```

Expected behavior: an agent detects that the child-app JWT audience is absent from the tunnel validator allowlist, records the Access-success/tunnel-deny split, and proposes a host config change with backup, validation, reload, bounded curl, and rollback. It must not continue mutating Access policy after the denial has been attributed to `cloudflared` audience validation.

Suggested fixture name:

```text
cloudflare-access-tunnel-audience-mismatch.fixture.md
```

Minimum fixture facts:

```text
parent Access app AUD exists
child Access app AUD exists
service-token auth succeeds for child app
tunnel originRequest.access.required is true
tunnel audTag contains parent AUD only
cloudflared AccessJWTValidator rejects child AUD
origin logs show no app request
adding child AUD to audTag clears the Cloudflare 403
```
