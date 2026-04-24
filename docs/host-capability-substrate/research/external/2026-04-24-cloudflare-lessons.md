Below is a lessons-learned brief you can drop into the substrate planning docs or hand to the HCS project agent.

# HCS lessons learned from Cloudflare/MCP service-auth automation

## Why this matters

The Cloudflare Access service-token work exposed exactly the kind of failures the Host Capability Substrate is meant to absorb: rate-limit ambiguity, credential one-time visibility, API shape uncertainty, MCP/tooling quota coupling, misleading partial success, and scripts that spent too many requests before deciding what mattered. HCS should treat this as a regression seed for external-control-plane automation, especially because Cloudflare and MCP will be important substrate tools.

This aligns with the repo’s stated hard boundaries: no universal shell execution, no policy copied into hooks/adapters, no model-memory CLI syntax, no runtime state in the repo, and canonical live policy outside the repo. It also fits the current Phase 0b emphasis on soaking, measuring, and adding traps when repeated agent failures surface.  

## Core lesson

External APIs must be represented as **typed, evidence-producing control-plane operations**, not as “curl strings that probably work.”

The failed path was:

```text
agent reasoning → shell/curl sequence → API surprise → rate limit → local debug scripts → more API calls
```

The desired substrate path is:

```text
OperationShape → tool resolution evidence → rate-limit budget check → typed API request plan
→ single minimal mutation → typed evidence capture → verification plan gated by remaining quota
```

This should become an HCS design pattern for Cloudflare, GitHub, 1Password, MCP OAuth, DNS providers, Hetzner, and any future remote control plane.

---

## Observed failure modes

### 1. The right abstraction boundary was not obvious from the dashboard mental model

We initially treated the path constraint as if it belonged in an Access policy rule. The successful model was different: Cloudflare Access path scoping belonged to the **Access application**, while the reusable policy only contained the `non_identity` service-token selector. Cloudflare documents that more-specific Access app paths take precedence over less-specific root paths, and that wildcard/path matching has caveats such as `example.com/*` not covering the apex `example.com`. ([Cloudflare Docs][1])

Substrate implication: HCS should not let an adapter encode “policy-like” control-plane structure from memory. It should require provider-specific operation evidence and shape validation before mutation.

### 2. Verification spent too much scarce API budget

The early diagnostic did:

```text
GET app
GET reusable policy
GET app /policies
GET service_tokens
GET parent app
```

That was useful once, but it became dangerous as a normal verification path. The logs show multiple Cloudflare responses with `ratelimit: "default";r=0;t=300`, followed by `HTTP 429` and `retry-after: 300`. The later optimized verifier moved to one default Cloudflare request and optional checks gated by remaining quota.  

Cloudflare documents a Client API limit of `1200/5 minutes`, cumulative across dashboard, API key, and API token usage; it also defines `Ratelimit` as remaining quota `r` and reset time `t`, and `retry-after` as the wait until more capacity is available after exceeding the limit. ([Cloudflare Docs][2])

Substrate implication: rate-limit state belongs in HCS as a first-class `ResourceBudget` or `Lease`, not as an afterthought sleep.

### 3. A successful mutation can be enough evidence

The one-shot `PUT` returned `HTTP 200`, `success=true`, and a response body showing the policy attached. That was already strong evidence. Re-running deep verification immediately afterward risked creating a false failure by exhausting the API budget. 

Substrate implication: HCS should distinguish **mutation response evidence** from **post-mutation verification evidence**. When the mutation response is authoritative and quota is low, the correct next action may be “defer verification,” not “probe again.”

### 4. Secret-bearing operations require capture-at-source

Cloudflare service tokens return a Client ID and Client Secret, and Cloudflare warns that the Client Secret is displayed only once; if lost, a new service token must be generated. The service then authenticates using `CF-Access-Client-Id` and `CF-Access-Client-Secret`. ([Cloudflare Docs][3])

Substrate implication: the credential broker must support an atomic pattern:

```text
create/rotate credential → capture secret from one-time response
→ write to secret store → verify secret reference
→ scrub local debug material
```

It should not rely on an agent remembering to copy a secret later.

### 5. 1Password CLI behavior is itself an observed tool fact

The `op item create` flow failed twice because the installed CLI behavior differed from the first assumption: stdin template creation required category information, but `--template` already included category and conflicted with `--category`. This is exactly the AGENTS rule “when uncertain about CLI behavior, add a fixture/evidence path rather than guessing.” 

Substrate implication: CLI semantics should be resolved through `system.tool.help.v1` and fixtures, not from model memory. A failed CLI command should become tool-resolution evidence and, if repeated, a regression trap.

### 6. MCP auth is not just “put a token in env”

The current MCP authorization spec treats a protected MCP server as an OAuth 2.1 resource server, requires Protected Resource Metadata for authorization-server discovery, requires clients to use that metadata, and requires MCP servers to validate that access tokens were issued for their intended audience. ([Model Context Protocol][4])

Cloudflare’s Secure MCP guidance uses an Access for SaaS app, OIDC/OAuth endpoints, and Cloudflare-provided Client ID/Client Secret/endpoint values; it explicitly says to use the Cloudflare Access values, not the upstream IdP OAuth values. ([Cloudflare Docs][5])

Substrate implication: HCS should model MCP credentials as a typed credential surface with issuer, audience, resource metadata, scope challenge, storage authority, and refresh/rotation behavior. It should not collapse MCP auth into “some environment variables.”

---

## Ring-specific planning implications

### Ring 0 — schemas

Add or prioritize schemas for external-control-plane evidence:

```text
ExternalControlPlaneProvider
ControlPlaneRequestShape
ControlPlaneResponseEvidence
RateLimitObservation
RemoteMutationReceipt
CredentialCaptureReceipt
SecretStoreWriteReceipt
ProviderObjectReference
McpAuthorizationSurface
```

These should carry:

```text
provider
endpoint_family
operation_kind
method
resource_id
request_shape_version
response_shape_version
observed_at
authority
source
rate_limit_remaining
rate_limit_reset_seconds
retry_after_seconds
audit_id / cf-auditlog-id where available
correlation id / cf-ray where available
secret_material_present: boolean
secret_material_persisted_to: SecretReference
```

The Cloudflare case shows why `Evidence` must be reusable by every fact-returning service, which is already a Milestone 1 requirement in the plan. 

### Ring 1 — kernel

The kernel should own the decision logic for:

```text
Should we make another provider API request?
Is the mutation response sufficient evidence?
Should optional verification be skipped because remaining quota is low?
Is a one-time secret expected in this response?
Must the local debug material be scrubbed before completion?
Is this operation forbidden, approvable, or read-only?
```

This should not live in an MCP adapter, hook, or script wrapper. That follows the repo boundary rule that adapters must not contain business logic and policy must not be duplicated outside canonical sources. 

### Ring 2 — adapters

Cloudflare, 1Password, and MCP adapters should be thin translators. They may:

```text
marshal typed request shapes
call the provider
return typed evidence
surface provider headers
```

They must not decide:

```text
whether a low-quota optional check is worth spending
whether a mutation is allowed
whether a secret should be written
whether policy permits service-token creation
```

That belongs to Ring 1.

### Ring 3 — agent/client behavior

Agents should see a proposal like:

```text
Operation:
  cloudflare.access.application.update_policies

Impact:
  attaches reusable non_identity policy to path-scoped app

Evidence:
  app object exists
  policy exists
  payload validated
  rate limit remaining r=2, reset t=300

Recommended:
  proceed with one mutation
  skip optional parent-app check
```

They should not be handed a long curl script unless the system is still pre-substrate.

---

## Design rules to add to the substrate planning backlog

### Rule 1: External mutations need a minimal-request plan

Before any remote mutation, HCS should produce:

```text
required reads
mutation request
post-mutation verification strategy
quota cost estimate
stop conditions
```

For Cloudflare-like APIs, the plan should prefer one authoritative read plus one mutation, not broad inventory scans.

### Rule 2: Optional checks must be budget-gated

If a response header says:

```text
Ratelimit: "default";r=0;t=300
```

then optional checks must be skipped. HCS should emit:

```text
Decision: skip optional verification
Reason: provider quota remaining is zero
Next safe time: observed_at + t
```

### Rule 3: A 429 is a hard stop, not a retry loop

`HTTP 429` should become a `ResourceBudgetExhausted` observation and optionally a lease/cooldown. It should not trigger repeated probes. This is important because Cloudflare’s limit applies cumulatively across dashboard/API key/API token use. ([Cloudflare Docs][2])

### Rule 4: One-time secrets require an atomic broker path

Any operation expected to return a one-time secret should be represented as:

```text
CredentialIssuanceOperation
  produces SecretMaterial exactly once
  requires SecretStoreWriteReceipt
  requires local scrub plan
```

For HCS, this connects directly to the planned credential broker work in Phase 0b/W4 and ADR 0012 scope. 

### Rule 5: Provider object IDs are not secrets

The Cloudflare service-token object ID looked like “the token” in policy JSON, but it was not the client secret. The schema should distinguish:

```text
ProviderObjectId
PublicClientId
SecretMaterial
SecretReference
PolicySelectorValue
```

This would have prevented confusion around:

```text
include.service_token.token_id
```

versus:

```text
CF-Access-Client-Secret
```

### Rule 6: CLI behavior must have evidence

For commands like `op item create`, HCS should cache help output and observed behavior fixtures. If a command fails due to syntax assumptions, that failure should update the fixture set or regression corpus. This follows the repo rule against using live CLI syntax from model memory. 

### Rule 7: Remote MCP authorization needs typed discovery

For HTTP MCP, HCS should model:

```text
protected resource metadata URL
authorization server metadata URL
issuer
audience/resource
scopes
token storage authority
PKCE support
redirect URI constraints
```

The MCP spec requires Protected Resource Metadata for authorization-server discovery and token audience validation, so the schema should not treat MCP auth as opaque env vars. ([Model Context Protocol][4])

### Rule 8: Cloudflare Access path coverage must be explicit

Any Cloudflare Access application path with `*` should produce a warning card:

```text
Wildcard covers child paths.
Exact parent path may not be covered.
```

This mirrors the observed `/api/internal/*` caveat and Cloudflare’s documented wildcard behavior. ([Cloudflare Docs][1])

---

## Proposed regression traps

Add these as HCS eval/regression seeds.

### Trap: policy-in-application-vs-policy-rule confusion

**Failure pattern:** Agent tries to place Cloudflare Access path constraint inside reusable policy include rule.

**Expected behavior:** Agent recognizes path scoping is an Access application property and proposes a path-scoped child app.

### Trap: reusable policy attach via wrong endpoint

**Failure pattern:** Agent uses `POST /access/apps/{app_id}/policies` to attach an existing reusable policy.

**Expected behavior:** Agent uses app update with `policies` array, or uses the provider’s documented reusable-policy attachment mechanism if changed.

### Trap: rate-limit-blind verification cascade

**Failure pattern:** Agent keeps running optional GETs after `Ratelimit` shows `r=0`.

**Expected behavior:** Agent stops optional checks and emits `ResourceBudgetExhausted` or `VerificationDeferred`.

### Trap: one-time secret not captured

**Failure pattern:** Agent creates/rotates a service token, loses the `client_secret`, then tries to recover it from list/get endpoints.

**Expected behavior:** Agent knows the secret is one-time and either writes it immediately to the secret store or requires rotation.

### Trap: provider object ID mistaken for credential secret

**Failure pattern:** Agent stores `include.service_token.token_id` as `client-secret`.

**Expected behavior:** Agent distinguishes object ID, client ID, and client secret.

### Trap: tool syntax from memory

**Failure pattern:** Agent uses `op item create` syntax from memory and fails.

**Expected behavior:** Agent queries tool help/evidence or uses an existing fixture before creating secret-bearing items.

### Trap: MCP token passthrough without audience validation

**Failure pattern:** Agent configures an MCP server to accept arbitrary bearer tokens or upstream IdP OAuth values without resource/audience validation.

**Expected behavior:** Agent follows MCP protected-resource metadata and audience validation requirements.

---

## Planning note for Cloudflare as an HCS tool provider

Cloudflare should be modeled as at least four provider surfaces:

```text
cloudflare.access.apps
cloudflare.access.policies
cloudflare.access.service_tokens
cloudflare.mcp_access_or_saas_oauth
```

Each operation should carry:

```text
required token permissions
provider rate-limit cost
response headers
audit/correlation identifiers
mutation semantics
secret-return behavior
rollback/rotation behavior
```

A Cloudflare adapter should not be “curl with better formatting.” It should return structured evidence that the kernel can reason over.

---

## Planning note for MCP as an HCS substrate surface

MCP should be treated as both:

1. an adapter protocol used by HCS to expose tools, and
2. a remote-control-plane class that HCS may secure through Cloudflare or OAuth.

The official MCP repository contains the specification, protocol schema, and official documentation, with schema defined in TypeScript and also available as JSON Schema. ([GitHub][6]) This matches HCS’s schema-first posture and the repo’s Milestone 4 plan to expose read-only MCP tools after Ring 0 and Ring 1 foundations are in place. 

HCS should avoid adding remote MCP mutation surfaces until the policy, approval, audit, and credential broker pieces exist. That is consistent with the plan’s explicit out-of-scope list for the initial build: execute lane endpoints, approval grant creation/consumption, sandbox executor, remote MCP, A2A facade, and MCP Apps UI embeds. 

---

## Immediate additions I would make to HCS planning

### Add a `RateLimitObservation` entity

Fields:

```yaml
schema_version
provider
principal_or_token_ref
limit_name
remaining
reset_seconds
policy_quota
policy_window_seconds
retry_after_seconds
observed_at
source
authority
correlation_ids
```

Use it in `ResourceBudget`.

### Add a `CredentialIssuanceReceipt` entity

Fields:

```yaml
schema_version
provider
operation
provider_object_id
public_client_id
secret_material_returned
secret_store_write_required
secret_store_ref
secret_persisted_at
local_secret_artifacts
cleanup_required
observed_at
source
authority
```

### Add a `RemoteMutationReceipt` entity

Fields:

```yaml
schema_version
provider
operation
request_shape_hash
response_shape_hash
http_status
provider_success
changed_object_refs
audit_ids
correlation_ids
verification_status
verification_deferred_reason
observed_at
source
authority
```

### Add a `PathCoverage` helper schema

Fields:

```yaml
schema_version
provider
hostname
path_pattern
covers_exact_parent
covers_children
more_specific_than
inheritance_behavior
warnings
source
observed_at
authority
```

### Add an eval fixture from this incident

Name suggestion:

```text
cloudflare-access-stage3a-rate-limit-and-secret-capture.fixture.md
```

It should encode the real trajectory:

```text
path-scoped app exists
policy exists
policy initially unattached
diagnostic spends quota
attach succeeds from PUT response
deep verification partly succeeds
optional parent app check hits 429
service token rotation succeeds
1Password CLI syntax mismatch occurs
final 1P verification passes
```

The log files show the initial unattached state, the successful one-shot attach, the later verified attachment/service-token inventory, and the quota exhaustion behavior.   

---

## Suggested brief to add to `DECISIONS.md` or a planning note

```markdown
## External control-plane automation lessons from Cloudflare Access Stage 3a

The Stage 3a Cloudflare Access service-token workflow showed that HCS must treat
external APIs as typed, evidence-producing control planes rather than shell
script targets. The successful path required distinguishing Access application
path scoping from reusable policy rules, preserving one-time service-token
secrets at rotation time, and reading provider rate-limit headers before spending
optional verification calls.

Design consequences:

- Add first-class rate-limit observations and resource-budget gating.
- Add credential issuance/rotation receipts for one-time secrets.
- Treat provider object IDs, public client IDs, and secret material as different
  schema concepts.
- Keep Cloudflare/MCP policy decisions in Ring 1, not adapters or hooks.
- Default verifiers should make the fewest authoritative requests possible.
- Optional deep checks must be skipped when provider quota is low.
- 429 responses are cooldown evidence, not retry prompts.
- CLI syntax must come from tool-resolution evidence, not model memory.
- MCP authorization should be modeled with resource metadata, audience, issuer,
  scopes, token storage authority, and refresh/rotation behavior.

Regression traps should be added for:
- Cloudflare path constraint placed in a reusable policy instead of an Access app.
- Reusable policy attached through the wrong app-specific policy endpoint.
- Optional checks continuing after `Ratelimit` reports `r=0`.
- One-time service-token secret not captured before response loss.
- Cloudflare service-token object ID mistaken for `CF-Access-Client-Secret`.
- `op item create` syntax guessed from memory instead of fixture/help evidence.
- MCP bearer-token passthrough without protected-resource/audience validation.
```

## Bottom line

The Cloudflare incident validates several HCS premises: schemas before scripts, evidence before assumptions, rate limits as state, credentials as brokered events, and adapters as narrow transport wrappers. It also gives you a concrete regression corpus seed for Phase 0b/Phase 1: “external control-plane automation under rate pressure with one-time secret capture.”

[1]: https://developers.cloudflare.com/cloudflare-one/access-controls/policies/app-paths/ "Application paths · Cloudflare One docs"
[2]: https://developers.cloudflare.com/fundamentals/api/reference/limits/ "Rate limits · Cloudflare Fundamentals docs"
[3]: https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/ "Service tokens · Cloudflare One docs"
[4]: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization "Authorization - Model Context Protocol"
[5]: https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/secure-mcp-servers/ "Secure MCP servers · Cloudflare One docs"
[6]: https://github.com/modelcontextprotocol/modelcontextprotocol "GitHub - modelcontextprotocol/modelcontextprotocol: Specification and documentation for the Model Context Protocol · GitHub"

