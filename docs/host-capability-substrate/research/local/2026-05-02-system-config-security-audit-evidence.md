---
title: System-config security audit — evidence for HCS design
category: research
component: host_capability_substrate
status: active
version: 0.1.1
last_updated: 2026-05-02
tags:
  - boundary-observation
  - execution-context
  - credential-source
  - launch-context
  - egress-policy
  - egress-observed
  - tcc
  - mcp-authorization
  - charter-v1-3
  - phase-1
  - phase-3
  - audit
priority: high
---

# System-config security audit — evidence for HCS design

Evidence piece. The 2026-05-02 wired-network security audit on this workstation
produced ground-truth findings that map directly onto HCS's ontology, charter
invariants, and `BoundaryObservation` envelope. This document compiles those
findings as design input for HCS Phase 1 ontology, Phase 3 capability
selection, and Phase 4 policy authoring. It does not propose policy and does
not propose capabilities; it identifies the boundary-discipline failures the
audit surfaced and shows where each one fits in the substrate the charter
already describes.

The substantive remediation work for the workstation is owned by `system-config`
(see "Source artifacts" below). HCS's interest in this audit is structural:
the audit is an external proof that the boundary categories the charter
already names — `ExecutionContext`, `CredentialSource`, `EnvProvenance`,
`BoundaryObservation`, `egress_policy`, `egress_observed`, `launch_context`,
`tcc`, `mcp_authorization`, `credential_routing` — are the right categories,
and that several are still incomplete in coverage.

## Source artifacts

These artifacts live outside this repo. They are referenced by absolute path
to keep this report grounded in an existing record rather than a paraphrase.

- Audit evidence directory:
  `~/Library/Logs/security-audit/2026-05-02-ua-wired/`
  (artifact index: `evidence-manifest.tsv`; 41 artifacts; `drwx------`).
- Revised hardening plan v0.2.0:
  `~/Organizations/jefahnierocks/system-config/docs/security-hardening-implementation-plan.md`
- Live secret policy:
  `~/Organizations/jefahnierocks/system-config/docs/secrets.md` v2.2.1.
- Live SSH policy:
  `~/Organizations/jefahnierocks/system-config/docs/ssh.md` v1.1.1.
- Live MCP framework:
  `~/Organizations/jefahnierocks/system-config/docs/mcp-config.md`.

The artifact directory is the authoritative record of observed state at
2026-05-02. Numbers cited below are reproducible from those files; this
document does not republish raw secret material, key fingerprints, or
sensitive history matches.

## Why this is HCS evidence

HCS exists because host boundaries on this workstation are loose,
version-sensitive, and frequently invisible to any single agent session
(charter §1, ADR 0022 §Context). The audit produced a one-time human-driven
snapshot that exposed:

- live state that no agent in any current session would have surfaced
  unprompted (15 ports answering on the public IP, 6 broken LaunchAgents,
  632 sensitive-pattern matches in shell history),
- boundary blurring exactly of the kind charter invariants 14, 15, 16, and
  17 forbid (config-spec from model memory rather than installed-runtime
  observation; GUI/IDE surfaces assumed to inherit terminal env;
  external-control-plane state asserted without typed evidence; operations
  emitted without resolved `ExecutionContext`),
- and at least one self-referential failure: HCS's own measurement
  LaunchAgent (`com.jefahnierocks.host-capability-substrate.measure`) was
  exiting `127` because the install-time substitution into the
  `{{JUST_BIN}}` token resolved to a versioned mise install path
  (`mise which just`), which became invalid on the next mise upgrade —
  itself an invariant-14 violation by HCS scaffolding against HCS rules.
  The plist template at
  `scripts/launchd/com.jefahnierocks.host-capability-substrate.measure.plist.tmpl`
  uses a token; the install script
  `scripts/install/install-launchd-measure.sh` chose the versioned path.

The structural shape of the audit is exactly what HCS's `Evidence` /
`BoundaryObservation` model is for. The audit is a pile of dated,
authority-tagged observations bound to surfaces, with a clear discriminator
per observation (network listener, credential file, plist, TCC row, WARP
trace, etc.). Translating the audit into the substrate's language is a
useful Phase 1 sanity check on the ontology.

## Findings, by boundary dimension

Each subsection below names: the audit finding (briefly), which charter
invariant the finding pressures, which `boundary_dimension` from the
registry it maps to, the candidate `BoundaryObservation` target reference,
and notes on what HCS still needs to model the finding cleanly.

Dimension names are drawn from
`docs/host-capability-substrate/ontology-registry.md` v0.2.1. All listed
dimensions there are currently `proposed`; none have been promoted to
`accepted`. This document does not propose promotion; it records candidate
fit.

### F1 — Container ports answering on a public interface

**What the audit found.** 13 container-published TCP ports answer on the
campus public IP `137.229.236.154` — `flux-*`, `authentik-server-1`, an
ad-hoc `budget-triage-db-local`. Bindings appear as both `0.0.0.0:port` and
`[::]:port` in `docker ps`. macOS Application Firewall does not stop these
because OrbStack's port forwarder runs through a privileged helper outside
`socketfilterfw` scope. Source: `tcp-listeners.txt`,
`docker-portbindings.txt`, `self-public-ip-portcheck.txt`.

**Charter invariants pressured.** Invariant 16 (external-control-plane
operations are evidence-first) — host network exposure is a remote-side
fact about the local machine that an agent cannot prove from inside the
process; it requires either a cooperating peer or a `lsof`/`docker ps`
observation tied to a probe context. Invariant 17 (`ExecutionContext`
declared, not inferred) — the OrbStack daemon, the Compose project, and
the individual container are all distinct execution contexts whose
egress posture is not derivable from one another.

**Closest existing `boundary_dimension`.** Two related dimensions exist
in the registry:

- `egress_policy` — declared/configured network egress for a surface.
- `egress_observed` — observed network egress for a surface (DNS lookups,
  established connections, denial events).

Neither covers **inbound** exposure. The audit's findings are the inverse
of egress: which host listeners are reachable from outside. The closest
candidate framing is "ingress observation," which the registry does not
yet name. Two reasonable shapes:

1. Treat the `0.0.0.0` binding itself as `egress_policy` declared on the
   container's `ExecutionContext` (the publish rule is technically a
   forwarding rule), with reachability from a non-loopback peer as
   `egress_observed` produced by an external-vantage prober.
2. Add a new dimension (e.g., `service_exposure` or `host_listener`) for
   "this surface accepts inbound connections from this address class" so
   the discriminator is unambiguous.

Option 1 understates the asymmetry — egress and ingress are different
kinds of facts, with different discrepancy classes (an unused inbound
allowance is "exposed but unused"; an unused outbound rule is harmless).
Option 2 is the cleaner ontology fit but requires registry promotion.

**Candidate `BoundaryObservation`.**

```text
boundary_dimension      = service_exposure   # candidate; not in registry
primary target           = tool_or_provider_ref(orbstack-daemon) or
                           execution_context_id(container surface)
observation_state        = proven
discrepancy_class        = exposed-on-public-interface
observed_payload         = { port, address_family, listener_pid, container_id, source_compose_file }
expected_payload         = { bind_address: "127.0.0.1" }   # if we model intent
authority                = host-observation
parser_version           = "lsof:..."
```

Multi-dimensional facts (publishing rule + observed reachability) should be
linked observations per ADR 0022's linked-observations pattern (Decision and
Future amendments sections), not collapsed into one envelope.

**Tooling-surface-matrix gap.** The matrix at v1.4.0 covers agent surfaces
(Claude Code, Codex, Cursor, etc.) but does not include OrbStack, Docker
daemon, or individual containers as `Surface` rows. They are
`ExecutionContext`-eligible (each container is a distinct surface; the
OrbStack daemon is a privileged helper). They should be added before any
`service_exposure` capability would have a target to bind to.

### F2 — Non-container listeners (rapportd, DaVinci Resolve)

**What the audit found.** `rapportd` on `*:60979` (Continuity / Handoff /
Universal Clipboard / watch unlock / iPhone camera) and `Resolve` on
`*:49152` answer on the public IP. Source: `tcp-listeners.txt`,
`self-public-ip-portcheck.txt`.

**Charter invariants pressured.** Same as F1 (16, 17). Additionally
invariant 14 (config-spec claims require authority provenance) — whether
these listeners "should" be there at all is an app-bundled choice that an
agent can only observe via `lsof`/`launchctl`, not by reading docs.

**Closest existing `boundary_dimension`.** None directly. `launch_context`
captures *how* the process started (Finder, `open -n`, launchd) but not
what network surface it offers. `bundle_identity` captures the bundle but
not its listener footprint. The same `service_exposure` candidate from F1
fits here as well.

**Notes for HCS.** rapportd is a launchd-managed Apple system process;
Resolve is a Finder-launched user app. Distinguishing the two requires the
`launch_context` dimension to be linked alongside `service_exposure`. The
two dimensions together would let policy/gateway answer "is this process a
system service we have to live with, or an app we can relaunch with
different settings?"

### F3 — SSH key inventory and durability

**What the audit found.** 23 private SSH keys in `~/.ssh`; 20 open with
empty passphrase; 5 already have host_migrations entries in
`home/.chezmoidata.yaml`; 12 are in the existing static manifest; 11+ are
absent from the manifest entirely. One key (`opnsense_usermgmt.from-1password`)
suggests an aborted prior 1Password import. Source: `ssh-key-inventory.tsv`.

**Charter invariants pressured.** Invariant 5 (secrets never live in Ring
0/1 at rest; `op://` references only) — the keys themselves are on disk,
not in the substrate, but the *credential authority shape* is exactly what
`CredentialSource` exists to model. Invariant 14 (config-spec authority)
— deciding which key serves which host requires observed runtime
(`ssh -G`) plus the chezmoi `host_migrations` table, not model memory.

**Closest existing `boundary_dimension`.** `credential_routing` —
"which credential source a surface picks for a given audience." The
registry currently lists `apiKeyHelper`, OS Keychain, env-var
compatibility, brokered `SecretReference`, and chained helpers. SSH-agent
authority on macOS is a chained-helper case: `IdentityAgent` socket →
1Password agent → vault entry → key material; or local `IdentityFile` →
private key file → in-memory unlocked key.

**Closest existing `CredentialSource.source_type`.** `macos_keychain`,
`onepassword`, `oauth_device_flow`, `subscription_oauth`, `api_key_env`,
`api_key_helper`, `vault`, `brokered_secret_reference`. The 1Password SSH
agent specifically is not enumerated. The desktop-app constraint that
`op` cannot import existing private keys (researched 2026-05-02) means
the credential-rotation pattern HCS will need is generate-fresh-in-vault →
update remote authorized_keys → switch chezmoi `host_migrations` → archive
old item. That sequence is multi-surface and multi-context.

**Candidate `BoundaryObservation`.**

```text
boundary_dimension      = credential_routing
primary target           = credential_source_id(<per-key item or per-host alias>)
observation_state        = proven
discrepancy_class        = local-only-not-routed-via-agent
observed_payload         = {
  resolved_source_type: "disk_file_pem",
  audience: "ssh:hetzner-hq",
  helper_chain: ["~/.ssh/config", "Host hetzner-hq", "IdentityFile <local>"],
  observed_via: "ssh -G hetzner-hq | rg identityfile",
  passphrase_protected: false
}
authority               = host-observation
```

Linked observations would express "the same audience could be served by
the 1Password SSH agent if the migration completed" as a separate
`credential_routing` record bound to a different `credential_source_id`,
with `observation_state = pending` and an `expected_payload` that names
the target.

**Notes for HCS.** Three additions help here:

1. Add `onepassword_ssh_agent` (or split `onepassword` into
   `onepassword_item_value` and `onepassword_ssh_agent`) as a
   `CredentialSource.source_type`. The agent socket and the item-value-read
   are different durability surfaces with different per-app approval
   semantics (the agent prompts; `op read` does not for an authenticated
   session).
2. Treat the chezmoi `ssh.host_migrations` map as policy authoring
   (`expected_payload`) and `ssh -G` resolution as `observed_payload`.
   Discrepancies are exactly the migration backlog.
3. The `allowed_signers` lifecycle (Git SSH commit signing) is its own
   credential-routing observation — it's user-maintained, append-only on
   rotation, and tied to a different audience class (commit verification,
   not transport).

### F4 — Shell history sensitive-pattern matches

**What the audit found.** 632 sensitive-pattern matches across three
files: `~/.zsh_history` 187, `~/.local/state/zsh/history` 306,
`~/.local/share/fish/fish_history` 139. zsh recurrence prevention is
correctly configured (`HIST_IGNORE_SPACE` and friends). Source:
`history-sensitive-counts-v2.txt`, `shell-history-settings.txt`.

**Charter invariants pressured.** Invariant 5 (secrets references only at
rest) — history files are not Ring 0/1 state, but they are durable
artifacts derived from the substrate's shell `ExecutionContext` and
should not contain secret material. Forbidden-pattern entry from charter
v1.2.0: "Echoing or enumerating secret-shaped environment values with
`printenv | grep`, `env | grep`, `echo "$API_KEY"`, or argv-equivalent
diagnostics" — this rule exists precisely so future history accumulation
stops carrying secret values.

**Closest existing concept.** `EnvProvenance` defines acceptable
observation modes as `name_only`, `existence_only`, `classified`,
`hash_only`, `absent`, `not_observed`. History files violate this when
they contain `export FOO=bar` style lines. There is no current
`boundary_dimension` for shell-history hygiene — it is a derived artifact
that becomes interesting when secret-shaped values appear.

**Notes for HCS.** Shell-history scrub is not a substrate operation; the
substrate's role is upstream — making sure agents never produce the
secret-revealing commands in the first place. Two concrete connections:

1. The `EnvProvenance` schema's prohibition on a raw `value` field is
   the schema-level analogue of the forbidden-pattern rule. Confirm
   that hook bodies, audit-lane payloads, and dashboard contracts
   inherit the same constraint by reference, not by re-implementation.
2. The audit's history files predate the current `HIST_IGNORE_SPACE`
   posture; the operational rule for new sensitive shell input
   (`op run --env-file`, leading-space commands) should be
   policy-published, not just documented in `docs/secrets.md`.

### F5 — macOS Sharing, Firewall, TCC, BPF

**What the audit found.**

- Application Firewall on, stealth mode on, FileVault on, SIP enabled.
- One configured share point: `/Users/verlyn13/Public` is shared via SMB
  with **guest access enabled** and **read-write**. SMB sharing service
  itself is off, so the share is dormant. Source: `sharing-sharepoints.txt`.
- TCC database (`tcc-user-grants.tsv`): broad agent grants
  (file-provider, network-volumes, folder access) across claude-code,
  claudefordesktop, codex, windsurf, vscode, iterm2, Terminal. Notable
  outlier: `kTCCServiceAppleEvents` granted to
  `/opt/homebrew/Cellar/node/25.9.0_1/bin/node` — AppleEvents allows
  scripting other apps; a node binary having this is unusual.
- ChmodBPF LaunchDaemon loaded; user `verlyn13` is in the `access_bpf`
  group; 256+ `/dev/bpfNN` devices readable by anything running as the
  user (live packet capture without root). Source: `bpf-wireshark.txt`.

**Charter invariants pressured.** Invariant 17 (`ExecutionContext`
declared, not inferred) — TCC grants apply to specific app bundles in
specific launch contexts; a TCC grant to a node binary is properly bound
to the node-binary `ExecutionContext`, not to whatever app spawned that
node process. Forbidden-pattern entry from v1.3.2: "Recording an
`ExecutionContext` whose `sandbox` profile, `env_inheritance` mode, or
`kind` is materially inconsistent with the observed runtime." This is
the inverse situation: the *grant* is what's inconsistent (a CLI binary
with AppleEvents authority).

**Closest existing `boundary_dimension`.** `tcc` exists in the registry,
sample payload `{ tcc_service, grant_state, observed_via }`. Two notes:

1. The candidate sample lists a single `tcc_service` per envelope. The
   audit data shows a many-grants-per-app pattern; the registry note
   ("singular discriminator; multi-dimensional facts are linked
   observations") implies one envelope per grant, with linked observations
   per app surface. This is the right shape but produces many envelopes
   per app — a 6-app review yields ~50 envelopes. Worth confirming during
   payload design.
2. `kTCCServiceLiverpool` (Apple's iCloud Drive subsystem) accounts for
   ~70 of the 190 TCC rows in this audit. The registry sample uses TCC
   service as a discriminator value, which suggests an enum of TCC
   services exists somewhere in the producer; the producer should consult
   `apple/tcc` documentation for the canonical list (and treat it as
   `vendor-doc` authority class).

The `Public` SMB share-point and ChmodBPF/BPF-group membership are not
covered by the existing `tcc` or `sandbox` dimensions. They are host
posture facts that fit best as a new dimension (candidate
`host_service_exposure` or `host_capability_grant`) or as evidence
subtypes outside the boundary envelope. Either way, "user is in
`access_bpf` group → can capture packets without root" is the same
authority-shape question as TCC: a coarse capability granted to a
principal/surface that may not need it.

### F6 — LaunchAgent lifecycle and config-spec authority

**What the audit found.** 6 broken or stale custom user-level agents:

- `com.mcp.docs`, `com.mcp.models`, `com.mcp.control`,
  `com.mcp.daily-refresh` — all `EX_CONFIG` (78); reference an
  `~/workspace/mcp-control-plane/` (Doppler-era) tree.
- `com.happy-devkit.mcp-server` — `EX_CONFIG` after 3,027 restart
  attempts.
- `com.jefahnierocks.host-capability-substrate.measure` — exit `127`. The
  *installed* plist contains the resolved versioned mise path
  `/Users/verlyn13/.local/share/mise/installs/just/1.46.0/just`,
  substituted into `{{JUST_BIN}}` at install time via
  `mise which just` in
  `scripts/install/install-launchd-measure.sh`'s `resolve_just()`
  function. The path becomes invalid the moment `mise` upgrades `just`.
  The plist template itself uses the `{{JUST_BIN}}` token, not a
  hard-coded path.

Plus 2 with invalid plist XML
(`com.workspace.budgeteer.{api,ingest}` — raw `&&` not entity-escaped).
4 healthy. Source: `launch-plists.tsv`,
`launchctl-custom-details.txt`, `budgeteer-launchagents-detail.txt`.

**Charter invariants pressured.** This is the densest invariant cluster
in the audit:

- Invariant 11 (operations never use deprecated syntax when a modern
  replacement exists; `launchctl load`/`unload` deprecated; use
  `bootstrap`/`bootout`) — every fix-up `launchctl unload` recommended
  by the system-config plan must use `bootout`. Note: HCS's own
  `scripts/install/install-launchd-measure.sh` already follows this
  invariant (`bootstrap`/`bootout` only).
- Invariant 14 (config-spec claims require authority provenance) — the
  installed plist's resolved `{{JUST_BIN}}` value is a static path
  produced from `mise which just` (a versioned mise install path) at
  install time, with no re-resolution on subsequent `mise upgrade just`
  events. The fix is to prefer the version-agnostic mise shim
  (`~/.local/share/mise/shims/just`) over `mise which just` in the
  install script's `resolve_just()` function, so the resolved path
  survives mise upgrades by re-resolving on every invocation. The plist
  template's `{{JUST_BIN}}` token is correct; the substitution policy
  is what produces the stale path.
- Invariant 15 (GUI shell-env inheritance must not be assumed) — the
  failing agents inherit only the launchd-default `PATH`
  (`/usr/bin:/bin:/usr/sbin:/sbin`); they do not inherit terminal
  shell exports or direnv state. The agents that depended on
  Doppler-style env injection (`DOPPLER_PROJECT=mp-dotfiles`) were
  configured for an environment the launchd execution context cannot
  produce.
- Invariant 17 (`ExecutionContext` declared, not inferred) — each
  LaunchAgent is a distinct surface with its own `ExecutionContext`
  (`kind: launchd_user_session`, `phase: launchd_user_session`,
  `env_inheritance: rejected`). The plist *is* the EnvProvenance
  declaration for that context.

**Closest existing `boundary_dimension`.** `launch_context` covers *how*
the surface started, with sample payload `{ launch_source, launcher_pid,
launch_evidence_kind }`. Service health (failure loops, missing executable,
EX_CONFIG count) is not a `launch_context` payload field; it is closer to
a `*Receipt` observation per the Q-011 grammar — a typed receipt of an
event that did or did not happen at launch time. Candidate names:
`LaunchAgentLoadReceipt`, `ServiceHealthObservation`.

The candidate `LaunchAgentLoadReceipt` here is naming-adjacent to ADR 0028
(proposed 2026-05-02; in review): the EX_CONFIG / exit-127 outcomes are
exactly `CommandCaptureReceipt.capture_status: failed` cases, and the
launchd execution context is an `ExecutionModeObservation` with
`mode: normal` and `observed_via: kernel_observation` (host-trusted
launchd telemetry). A future schema PR for `LaunchAgentLoadReceipt`
should compose ADR 0028's three execution-mode receipts as component
evidence rather than reinventing them.

**Self-referential note.** The HCS measure agent's failure mode (exit
127, install-time-substituted versioned mise path) is precisely the kind
of boundary-discipline failure HCS exists to prevent. Fixing it inside
the HCS repo is the natural Phase 1 first move that proves the
substrate's own scaffolding follows its own rules. The fix lives in the
install script's `resolve_just()` function
(`scripts/install/install-launchd-measure.sh`), not in the plist
template under `scripts/launchd/`; the template already uses a
`{{JUST_BIN}}` token correctly. The install script also already follows
invariant 11 (`bootstrap`/`bootout`, never `load`/`unload`); the
remaining gap is invariant 14.

### F7 — MCP profile sprawl and the Rule of Two

**What the audit found.** 6 AI-tool surfaces (Claude Code CLI, Claude
Desktop, Cursor, Windsurf, Copilot CLI, Codex CLI) all carry the same
9-server MCP baseline. The baseline contains servers that, per Meta's
"Agents Rule of Two" (2025-10), combine all three risk legs in a single
session: `github` (private data + untrusted issue/PR bodies + write
authority); `cloudflare` and `runpod` provide state-change/exfil channels;
`memory` is a dual-use durability surface. **Zero secret literals** in
any synced config — the wrapper-based externalization is working.
Source: `mcp-config-server-names.txt`,
`mcp-config-sensitive-token-counts.txt`,
`claude-json-secret-literal-counts.txt`.

**Charter invariants pressured.**

- Invariant 1 (no policy decision in an adapter) — choosing which
  server set applies to which surface in which session is policy. It
  belongs in Ring 1's policy/gateway, not in `sync-mcp.sh` switch
  logic, not in any one tool's config UI.
- Invariant 5 (secrets at rest only as references) — already honored
  by the existing wrapper architecture; the audit confirms.
- Invariant 16 (external-control-plane operations are evidence-first)
  — the `mcp_authorization` dimension exists for exactly this. Per-MCP
  session authorization posture (OAuth resource metadata, audience,
  rate-limit markers) is observable evidence, not implicit.
- Invariant 17 (`ExecutionContext` declared, not inferred) — Claude
  Desktop, Claude Code CLI, Codex CLI each get a distinct
  `ExecutionContext` per the v1.3.0 schema; the MCP set offered to each
  is a property of that context, not a property of the user.

**Closest existing `boundary_dimension`.** `mcp_authorization` exists,
sample payload `{ mcp_server_ref, auth_kind, principal_audience,
fan_out_state, last_429_at }`. The payload covers per-session auth
posture but does not name the *risk class* of the server (Rule-of-Two
membership). Two reasonable shapes:

1. Treat risk class as a property of the `Capability` (Ring 1 registry),
   not of the `BoundaryObservation`. The boundary observation records
   what auth surface the session had; policy decides whether that
   surface should ever be paired with another (B)-class server in one
   session.
2. Add a `risk_class` field to the `mcp_authorization` payload schema
   when it is designed. The audit suggests the field would have at
   least three values: `(A)` private-data, `(B)` untrusted-content,
   `(C)` state-change-or-exfil; multiple labels are allowed.

Per the registry's "narrowest matching dimension" rule, option 1 is
preferred — risk class is a policy property, not an observation.

**Closest existing `Capability` shape.** None yet. Phase 3 design will
need a `mcp.session.start` capability per surface that takes:

```text
operation_shape          = mcp.session.start.v1
arguments                = {
  surface_id,                     # ExecutionContext binding
  server_set: PolicySelectorValue # "engineering" | "low-risk" | ...
}
required_evidence        = [
  BoundaryObservation(boundary_dimension=mcp_authorization, ...) for each server in set,
  ExecutionContext(surface_id) of authority host-observation
]
mutation_scope           = none   # session-start does not mutate; tool calls do
```

The system-config plan's two-profile design (`engineering` vs `low-risk`)
maps onto a `PolicySelectorValue` argument. Per the v1.3.1
boundary-enforcement bullet, `PolicySelectorValue` is a typed slot
distinct from `SecretReference`, `ProviderObjectReference`, and
`PublicClientId`; the corresponding v1.3.1 forbidden pattern explicitly
prohibits conflating these slots in `OperationShape` arguments,
`CommandShape` rendered output, adapter wiring, hook bodies, or audit
payloads.

**Notes for HCS.**

- Codex CLI's per-profile MCP configuration (`.codex/config.toml`
  `[mcp_servers.*]` blocks; selectable with `--profile`) is the closest
  any current tool gets to the kernel's eventual capability model —
  worth referencing in the Phase 3 capability design as the working
  precedent.
- Claude Desktop and Windsurf currently support no per-session MCP
  selection (single global config). Until vendor support changes, those
  surfaces are file-swap-only at the policy/gateway layer; the
  boundary observation should reflect that constraint.
- The Cloudflare MCP read-only gap (no `--read-only` flag in the
  upstream server, issue #263) is an `mcp_authorization` payload note,
  not a separate dimension.

### F8 — Agent memory durability and scope

**What the audit found.**

- `~/.codex/memories/MEMORY.md` — 64 KB; 5 IPv4, 1 MAC, 119 personal-term
  matches, 117 infra-term matches.
- `~/.codex/memories/memory_summary.md` — 18 KB; comparable density.
- `~/.claude/CLAUDE.md` — 6.9 KB; clean.
- `~/.claude/projects/-Users-verlyn13/memory/MEMORY.md` — 823 bytes; this
  is the *global-scope* Claude memory, distinct from the project-scoped
  memory at `~/.claude/projects/-Users-verlyn13-Organizations-jefahnierocks-system-config/memory/`.
  Source: `agentic-memory-pii-counts.tsv`.

**Charter invariants pressured.** Invariant 5 (secrets at rest only as
references) — agent memory should never carry secret values, but the
audit notes infra-term and personal-term density that warrants review.
Invariant 17 (`ExecutionContext` declared, not inferred) — global-scope
memory and project-scope memory are different `ExecutionContext`
surfaces with different `phase` semantics (project memory loads at
project start; global memory loads at every Claude Code session).

**Closest existing `boundary_dimension`.** None directly. Memory is a
durability surface for agent context; closest analogue is
`credential_routing` (in the sense that "what context the agent loads at
startup" is itself a kind of routing decision), but credentials are
distinct from context. Candidate dimension: `agent_memory_scope` or
`session_context_durability`. Either should be drafted before Phase 3
adds capabilities that mutate agent memory.

**Notes for HCS.**

- The codex-vs-claude memory size disparity (82 KB vs ~7 KB) is a
  surface-specific durability fact. The substrate should not flatten
  per-tool memory conventions, but it should give the dashboard a way
  to surface "this surface accumulates more durable context than that
  one" for human review.
- Memory is not a `CredentialSource` — it does not authorize anything
  by itself — but the security-relevant subset of memory (what
  surfaces, what infra IPs, what hostnames) is exactly the kind of
  thing the substrate's audit lane is designed to keep from leaking
  via secret-shaped env inspection (forbidden pattern from charter
  v1.2.0).

### F9 — Cloudflare WARP gateway off (external control plane)

**What the audit found.** `cdn-cgi/trace` shows `warp=plus` (Zero Trust
enrolled, `homezerotrust` org) and `gateway=off` (Gateway HTTP proxy not
inspecting this device's traffic). Mode is `WarpWithDnsOverHttps` (the
documented default; supports full filtering when Gateway is enabled).
WireGuard tunnel up; `Always On: true`; `Switch Locked: false`. Most
likely cause (per researched Cloudflare docs): the org-level Secure Web
Gateway proxy toggle (TCP) is not enabled in Traffic Settings. Source:
`warp-state.txt`.

**Charter invariants pressured.** Invariant 16 is the load-bearing one
— "external-control-plane operations are evidence-first." The
workstation's `cdn-cgi/trace` is observation-class evidence, not
authoritative on org state. The authoritative answer requires the
Cloudflare API or dashboard. This is exactly the precedent ADR 0015's
`OriginAccessValidator` / `AudienceValidationBinding` is for: HCS must
distinguish provider-side declared policy from workstation-side observed
behavior.

**Closest existing `boundary_dimension`s.**

- `egress_policy` — declared/configured network egress for a surface.
  Cloudflare Gateway rules are policy. Producer authority must be the
  Cloudflare API, not the workstation.
- `egress_observed` — observed egress from the workstation. Producer
  authority is the workstation's own probes.
- `path_coverage` — provider-side scope coverage gaps (currently only
  Cloudflare Access in the registry, but the same shape applies to
  Gateway TCP-toggle scope).

The audit finding is the discrepancy between `egress_policy` (declared
intent) and `egress_observed` (no Gateway-mediated traffic). Per the
"linked observations" pattern from ADR 0022, this is exactly the
shape the registry already supports — two separate `BoundaryObservation`
records sharing the workstation's `ExecutionContext` as a target,
producing a downstream `Decision` of "policy-declared but unenforced
on this device."

**Notes for HCS.**

- The Cloudflare API observation is `external-control-plane` authority;
  the workstation `cdn-cgi/trace` is `host-observation` authority. The
  authority enum on `Evidence` already supports both
  (`vendor-doc | installed-runtime | host-observation | derived` etc.);
  per ADR 0023's freshness-bound rule, neither alone is sufficient
  authority for a Decision that mutates org-side state.
- Break-glass behavior (`warp-cli disconnect` works without auth because
  `Switch Locked: false`) is a separate observation worth modeling as
  `egress_policy` payload (the policy permits user disconnect).

### F10 — ng-doctor posture as evidence-class observation

**What the audit found.** `ng-doctor` (in
`system-config/home/dot_local/bin/executable_ng-doctor.tmpl`) has 9
categories and 48 checks; 34 pass, 2 fail, 3 skip in current state. The
revised hardening plan (P10) proposes adding a 10th `posture` category
covering firewall state, sharing services, container publishes,
non-container listeners, 1Password agent presence, SSH passphrase counts,
shell-history sensitive-pattern counts, LaunchAgent health, ChmodBPF
presence, and WARP enforcement.

**Charter invariants pressured.** None directly — `ng-doctor` is a
system-config tool, not an HCS tool. But the proposed `posture`
category is exactly the same shape as Phase 3 HCS capability:
"observe a host-state fact, classify it as proven/denied/pending/etc.,
report." The duplication is intentional during the substrate's
absence; the posture category should be designed so that, once HCS
ships, each check becomes a `BoundaryObservation` producer the kernel
consumes, not a parallel system the substrate has to reconcile against.

**Notes for HCS.**

- The system-config plan's P10 explicitly recommends landing checks in
  "skip-mode" (informational) first, then promoting to fail-mode as
  each underlying surface stabilizes. That's the same gating pattern
  ADR 0022 prescribes for `BoundaryObservation` consumption: `unknown`
  is not the same as `denied`; missing or unobservable evidence is its
  own state.
- `ng-doctor` checks are good fixture sources for HCS regression
  testing. Each check has a known-passing case (in the pre-soak
  baseline) and known-failing cases (the audit findings). Treating
  them as evidence inputs to a future `boundary.observe` capability
  preserves the institutional knowledge they encode.

## Mapping to charter invariants (audit confirms necessity)

For each non-negotiable invariant in `implementation-charter.md` v1.3.2,
the audit finding(s) below confirm that the invariant exists for a
real, observed reason on this workstation. Invariants without a 2026-05-02
audit finding are listed for completeness; their motivating evidence
lives elsewhere.

| Invariant | Audit finding(s) confirming the invariant |
|---|---|
| 1 (no policy in adapter) | F7 — MCP profile sprawl is policy; centralizing in Ring 1 prevents per-tool drift |
| 2 (no shell command as ontology) | (none from this audit; charter motivation is design, not incident) |
| 3 (no cross-ring shortcut) | F6 — `com.jefahnierocks.host-capability-substrate.measure` shortcut to a hard-coded mise path is a cross-layer shortcut analogue |
| 4 (audit logging is internal) | F4 — shell history files are evidence that "logging" must not become an agent-callable surface |
| 5 (secrets as references at rest) | F3 (SSH keys), F4 (history), F8 (memory PII), F7 (verified zero secret literals in MCP configs) |
| 6 (`forbidden` tier non-escalable) | F7 — the (A)+(B)+(C) Rule-of-Two combination needs a tier shape that is non-approvable |
| 7 (execute lane gated on full stack) | F1, F2 — current state is "execute without ledger"; HCS exists so this stops being possible |
| 8 (sandbox observations not promoted) | F1 — container-internal observations are sandbox-class; reachability from external vantage is a separate authority |
| 9 (skills canonical at `.agents/skills/`) | (no audit finding; design rule) |
| 10 (public source / private deployment) | F4 (history pre-scrub backup), F8 (memory) — durable artifacts must not enter the repo |
| 11 (deprecated-syntax refusal) | F6 — `launchctl load`/`unload` is the relevant fix for plan recommendations |
| 12 (tool version baseline explicit) | F6 — HCS measure agent's mise pin is the inverse failure mode (over-pinning) |
| 13 (deletion authority is not gitignore state) | F4 — backup-then-rewrite pattern for history files is the same shape |
| 14 (config-spec requires provenance) | F6 (HCS measure agent's hard-coded mise path), F1 (compose-file authority for binding rules) |
| 15 (GUI shell-env inheritance not assumed) | F6 (DOPPLER_PROJECT inheritance assumption broke the four `com.mcp.*` agents) |
| 16 (external-control-plane evidence-first) | F1 (reachability requires external probe), F9 (Cloudflare Gateway state requires API authority, not `cdn-cgi/trace` alone) |
| 17 (`ExecutionContext` declared, not inferred) | F5 (TCC grants per surface), F6 (each LaunchAgent is its own ExecutionContext), F7 (per-tool MCP scope), F8 (memory scope per surface) |

The audit produces no novel invariants. Every finding category fits an
existing invariant. This is a useful confirmation that v1.3.2's invariant
set is at the right level of generality for this workstation's failure
modes.

## Mapping to BoundaryObservation envelope

A short table for use during Phase 1 schema implementation. Per ADR 0022,
the envelope is `Evidence`-subtype; per ontology-registry §"Singular
discriminator," each row is one `boundary_dimension`. Rows marked
"candidate" are not in the registry yet; the audit suggests they should
be drafted.

| Audit finding | `boundary_dimension` | Primary target | Producer authority |
|---|---|---|---|
| F1 container public-IF reach | `service_exposure` *(candidate)* or `egress_policy` (forwarding rule) + `egress_observed` (external probe) linked | `tool_or_provider_ref(orbstack-daemon)`, linked `execution_context_id(container)` | `host-observation` (lsof) + `host-observation` (external probe) |
| F2 non-container listeners | `launch_context` + candidate `service_exposure` linked | `execution_context_id(<app surface>)` | `host-observation` |
| F3 SSH key inventory | `credential_routing` (per audience) | `credential_source_id` | `host-observation` (`ssh -G`) |
| F4 shell history | (no `boundary_dimension`; constrained by `EnvProvenance` schema rule) | `execution_context_id(shell-session)` | `host-observation` |
| F5 macOS Sharing/TCC/BPF | `tcc` per grant; candidate `host_capability_grant` for share-points and BPF group | `execution_context_id(<app surface>)` | `host-observation` (TCC.db, sharing -l, dscl) |
| F6 LaunchAgent health | `launch_context` + candidate `LaunchAgentLoadReceipt` | `execution_context_id(<launchd-service>)` | `host-observation` (launchctl, plutil) |
| F7 MCP profile sprawl | `mcp_authorization` per server; risk-class is policy property | `tool_or_provider_ref(<mcp-server>)`, supplemental `execution_context_id` | `host-observation` (per-tool config files) + `external-control-plane` (per-server auth metadata) |
| F8 agent memory PII | candidate `agent_memory_scope` or `session_context_durability` | `execution_context_id(<agent surface>)` | `host-observation` |
| F9 Cloudflare Gateway off | `egress_policy` (Cloudflare-side, authoritative) + `egress_observed` (`cdn-cgi/trace`) linked | `execution_context_id(workstation)` | `external-control-plane` + `host-observation` |
| F10 ng-doctor posture | (multiple; per check) | per-check | `host-observation` |

## Gaps in current HCS coverage that the audit reveals

### Tooling-surface-matrix additions worth considering

The matrix at v1.4.0 covers agent surfaces well. The audit suggests four
non-agent surfaces should be added before Phase 3 capability work, because
each one is a target reference that boundary observations will need to
bind to:

- **OrbStack daemon** (`dev.orbstack.OrbStack.privhelper`) — privileged
  helper that publishes container ports outside the App Firewall scope.
  Surface category: host service. Phase posture: observe only.
- **Docker daemon (via OrbStack)** — distinct from the helper; this is
  what `docker ps` queries. Surface category: tool provider.
- **Cloudflare WARP daemon** (`com.cloudflare.1dot1dot1dot1.macos.warp.daemon`)
  — system LaunchDaemon mediating egress. Surface category: host service.
- **Wireshark ChmodBPF LaunchDaemon** (`org.wireshark.ChmodBPF`) — host
  capability grant (BPF group membership). Surface category: host service.

The matrix's existing "Runtime (not in repo)" section is the right home
for these — they are host services HCS observes but does not own.

### `boundary_dimension` candidates worth drafting

Per ADR 0027's precedent (proposed 2026-05-02; in review): the choice
between `BoundaryObservation` payload and `evidenceSchema`-direct typed
payload is "default to `evidenceSchema` direct; use `BoundaryObservation`
only when the fact is truly a contextual boundary claim." The four
candidates below are all contextual boundary claims (about the boundary
between exposed and unexposed, healthy and failed, scoped and unscoped),
so the `BoundaryObservation` payload framing fits.

In rough priority for Phase 1 ontology-registry work, with motivating
audit findings:

1. **`service_exposure`** (or `host_listener`) — covers F1 (containers)
   and F2 (non-container listeners). The egress dimensions are not
   structurally suited to inbound facts; trying to fold ingress into
   `egress_policy` collapses two ontologically distinct discrepancy
   classes.
2. **`launch_health`** (or a `*Receipt` shape per Q-011 grammar:
   `LaunchAgentLoadReceipt`) — covers F6. The current `launch_context`
   dimension covers *how* a surface started; service health is *whether*
   it succeeded and *how often* it has been retried.
3. **`agent_memory_scope`** (or `session_context_durability`) — covers
   F8. The substrate already distinguishes session-only vs disk-persisted
   credentials in `CredentialSource.durability`; agent memory is a
   different durability surface and warrants its own discriminator.
4. **`host_capability_grant`** — covers F5's BPF group membership and
   share-point definitions. Distinct from `tcc` (which is per-app) and
   `sandbox` (which is process-level). This is host-side principal-grants
   to the user account.

### `CredentialSource.source_type` additions

Currently enumerated: `macos_keychain`, `codex_home_file`,
`claude_credentials_file`, `oauth_device_flow`, `subscription_oauth`,
`api_key_env`, `api_key_helper`, `onepassword`, `infisical`, `vault`,
`devenv_secretspec`, `long_lived_setup_token`, `service_account`,
`brokered_secret_reference`.

Audit-driven additions to consider:

- **`onepassword_ssh_agent`** — distinct from `onepassword` item-value
  read. Different per-app authorization semantics; different durability;
  different audit-lane shape.
- **`disk_file_pem` / `disk_file_openssh`** — for the on-disk SSH keys
  the migration is moving away from. Has to be a typed source so
  `credential_routing` observations can name it.
- **`onepassword_op_ssh_sign`** — for `op-ssh-sign` invocations used
  for Git SSH signing; different from agent socket because it's a
  per-invocation helper, not a long-lived agent.

### `ExecutionContext.surface` additions

Currently enumerated: `codex_cli`, `codex_app_sandboxed`,
`codex_ide_ext`, `claude_code_cli`, `claude_desktop`,
`claude_code_ide_ext`, `zed_external_agent`, `warp_terminal`,
`mcp_server`, `setup_script`, `app_integrated_terminal`.

Audit-driven additions to consider for completeness:

- **`launchd_user_service`** — for plist-launched user services
  (`com.mcp.*`, `com.workspace.*`, `com.jefahnierocks.*`).
- **`launchd_system_daemon`** — for `LaunchDaemons` (WARP, OrbStack
  privhelper, ChmodBPF).
- **`docker_container`** — for individual containers as observable
  surfaces. Per the Q-010 isolation vocabulary, container/VM is a
  distinct containment mechanism; the audit's containers each warrant
  a surface ID.
- **`shell_history_artifact`** — not a runtime surface but a durable
  artifact derived from a shell session; needed if F4-style observations
  bind to a target.

The above are candidates only. Promotion follows the schema-change
workflow at `.agents/skills/hcs-schema-change/SKILL.md`.

## Recommendations for HCS phasing (audit-informed)

These are not requirements; they are sequencing notes for whoever picks
up the next ontology-registry, schema, or capability PR.

**Vocabulary note.** "Phase 1/3/4" below follows the upstream research
plan (`~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`
§6) and is also referenced in HCS PLAN.md alongside the milestone
vocabulary. Approximate mapping to HCS PLAN.md milestones:

- Phase 1 (ontology/schemas) ≈ HCS Milestone 1 (Ring 0 ontology
  schemas).
- Phase 3 (kernel capabilities + adapters) ≈ HCS Milestones 4–5 (first
  read-only MCP tools + gateway/dashboard).
- Phase 4 (policy authoring) ≈ HCS Milestone 2 (policy snapshot +
  decision package) plus the post-Milestone-6 execute lane (research
  plan §6 Phase 4).

### Phase 1 (ontology / schemas)

- Use the audit fixtures as test corpora for `BoundaryObservation`
  payload schemas as they land. Each finding category is a real
  observation with known authority class, observed_at, and target
  reference.
- Treat the four `boundary_dimension` candidates above as queue items
  for the registry, in the priority order listed.
- Treat the `CredentialSource.source_type` additions above as queue
  items.
- The `ExecutionContext.surface` additions are smaller; they can land
  with the first capability that needs them.

### Phase 3 (kernel capabilities + adapters)

- Capability candidate: `host.posture.observe.v1` — wraps the audit's
  observation set as a kernel-resolvable capability. `mutation_scope:
  none`. Replaces the `ng-doctor posture` category once HCS ships.
- Capability candidate: `mcp.session.start.v1` per surface — takes a
  `PolicySelectorValue` (server set name); evaluates per-set
  `mcp_authorization` evidence; returns a `Decision`.
- Capability candidate: `service.launchd.health.v1` — observes one
  user-level launchd service and produces a candidate
  `LaunchAgentLoadReceipt` (or `BoundaryObservation` with
  `boundary_dimension: launch_health`). `mutation_scope: none`.
- The first mutating capability the substrate ships should not be in
  any of the audit's high-blast-radius areas (SSH rotation, container
  bind changes, WARP policy enforcement). Per invariant 7, the full
  approval/audit/dashboard/lease stack must exist first; the audit
  reinforces that none of these mutations are urgent enough to short
  that ordering.

### Phase 4 (policy authoring)

- `system-config/policies/host-capability-substrate/tiers.yaml` should
  encode the Rule-of-Two policy as a `forbidden` tier for any session
  that combines (A)+(B)+(C) servers — the (A)+(B)+(C) combination is
  non-escalable per invariant 6. This is the most concrete policy
  artifact the audit motivates.
- The HCS measure agent's hard-coded mise path lesson belongs in
  policy as well: any future `service.launchd.install.v1` capability
  must produce plist content from probed installed-runtime evidence,
  not model memory or static docs.

### Self-referential first move

Fix the `{{JUST_BIN}}` resolution for
`com.jefahnierocks.host-capability-substrate.measure`. The plist
template at
`scripts/launchd/com.jefahnierocks.host-capability-substrate.measure.plist.tmpl`
correctly uses a `{{JUST_BIN}}` token, and the install script
`scripts/install/install-launchd-measure.sh` already follows
invariant 11 (`bootstrap`/`bootout` only, never `load`/`unload`). The
actual invariant-14 violation is in the install script's
`resolve_just()` function: it prefers `mise which just`, which returns
a *versioned* install path
(`~/.local/share/mise/installs/just/1.46.0/just`) that becomes invalid
the moment mise upgrades the underlying `just`.

The fix is in `resolve_just()` in
`scripts/install/install-launchd-measure.sh`: prefer the
version-agnostic shim `~/.local/share/mise/shims/just` over the
versioned install path returned by `mise which just`. The shim
re-resolves the active `just` version on every invocation, so it
survives mise upgrades. A re-render after mise upgrade would still be
needed only if the shim path itself ever changes — which is rare but
should be observed-runtime evidence per invariant 14, not assumed.

This is the smallest possible Phase 1 closeout action that demonstrates
HCS scaffolding follows its own rules.

## Risks if HCS does not ship in time

The audit was a one-time human-driven snapshot. Without HCS, there is no
in-session way for any agent to:

1. Detect that container publishes have drifted back to `0.0.0.0`
   after a project compose-file change. A fresh agent session sees
   only the local source tree and would have to be told to look.
2. Detect that the four `com.mcp.*` LaunchAgents are still failing
   after their tree was deleted. `launchctl list | grep` requires
   knowing to look.
3. Detect that an MCP profile session inadvertently combines (A)+(B)+(C)
   servers. Each surface's MCP set is local config; no kernel sees
   the combination.
4. Detect that the Cloudflare Gateway proxy toggle remains disabled
   org-side. The `cdn-cgi/trace` value is observation-class; the
   authoritative answer requires the Cloudflare API.
5. Detect that the HCS measure agent itself is still broken. The
   audit found this only because the audit happened.

Most of these are detectable by a Phase 3 `host.posture.observe`
capability that runs the audit's commands and emits typed evidence.
Until that ships, the workstation is in a "snapshot-and-hope" posture
between audits.

## Validation that the v1.3.x charter posture is correctly scoped

The 2026-05-02 charter v1.3.x cycle (waves 1–3, ADRs 0021 + 0024) added
invariants 16 and 17 plus extensive plumbing. The audit's mapping table
above shows every wave-3 forbidden-pattern entry has an audit-finding
analogue:

- "Treating a parent process's sandbox, app/TCC permission, credential
  authority, provider mutation authority, HCS `ApprovalGrant` status,
  egress policy, filesystem authority, or `BoundaryObservation` records
  as evidence for a child `ExecutionContext` without typed inheritance
  evidence" — F6 (the `com.mcp.*` agents assumed they would inherit
  Doppler env from the parent shell; they did not).
- "Treating Codex `shell_environment_policy` `inherit` / `include_only`
  — or any equivalent operator on Claude Desktop, Claude Code IDE
  extensions, JetBrains AI Assistant, GitHub Copilot CLI, Cursor,
  Windsurf, Warp, Zed external agents, MCP servers, setup scripts, or
  launchd `EnvironmentVariables` — as proof of credential authority,
  sandbox scope, app/TCC permission, provider mutation authority, or
  HCS `ApprovalGrant` status" — F6 (the `EnvironmentVariables` block in
  each broken plist was a materialization claim, not an authority
  claim).
- "Using a `BoundaryObservation` … whose primary target reference …
  does not match the consuming `OperationShape`'s execution context as
  evidence for that operation" — F1 (a container's internal port-bind
  observation is bound to the container's `ExecutionContext`, not to
  the daemon's nor the host's; reachability needs separate evidence).

The charter is correctly scoped. The audit reveals no needed-but-missing
invariants, only candidate registry entries and ontology surface
additions.

## References

### Source artifacts (system-config + audit)

- `~/Library/Logs/security-audit/2026-05-02-ua-wired/evidence-manifest.tsv`
- `~/Organizations/jefahnierocks/system-config/docs/security-hardening-implementation-plan.md` v0.2.0
- `~/Organizations/jefahnierocks/system-config/docs/secrets.md` v2.2.1
- `~/Organizations/jefahnierocks/system-config/docs/ssh.md` v1.1.1
- `~/Organizations/jefahnierocks/system-config/docs/mcp-config.md`

### HCS internal references

- Charter: `docs/host-capability-substrate/implementation-charter.md` v1.3.2
- Tooling matrix: `docs/host-capability-substrate/tooling-surface-matrix.md` v1.4.0
- Ontology: `docs/host-capability-substrate/ontology.md` v0.7.0
- Ontology registry: `docs/host-capability-substrate/ontology-registry.md` v0.2.1
- ADR 0015: external-control-plane automation
- ADR 0016: shell environment boundaries
- ADR 0017: Codex app execution context
- ADR 0018: durable credential preference
- ADR 0021: charter v1.3 wave 1 (invariants 16, 17)
- ADR 0022: BoundaryObservation envelope
- ADR 0023: Evidence base shape
- ADR 0024: charter v1.3 waves 2 and 3
- ADR 0025: BranchDeletionProof composite shape (accepted 2026-05-02)
- ADR 0027: Q-006 stage-1 source-control evidence subtypes
  (`GitRepositoryObservation`, `GitRemoteObservation`,
  `BranchProtectionObservation`; proposed 2026-05-02; review pending)
- ADR 0028: Q-008(a) execution-mode receipts (`ToolInvocationReceipt`,
  `CommandCaptureReceipt`, `ExecutionModeObservation`; proposed
  2026-05-02; review pending)

### External references (used by the system-config audit and plan)

- "Lethal trifecta" (Willison, 2025-06):
  https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/
- "Agents Rule of Two" (Meta, 2025-10):
  https://ai.meta.com/blog/practical-ai-agent-security/
- 1Password SSH developer docs:
  https://developer.1password.com/docs/ssh/
- Cloudflare Zero Trust Gateway proxy toggle:
  https://developers.cloudflare.com/cloudflare-one/traffic-policies/proxy/

## Change log

| Version | Date | Change |
|---|---|---|
| 0.1.1 | 2026-05-02 | Corrected after cross-check against repo state. Self-referential first move reframed: the plist template uses a `{{JUST_BIN}}` token (correct), and `scripts/install/install-launchd-measure.sh` already follows invariant 11; the actual invariant-14 violation is in the install script's `resolve_just()` function preferring `mise which just` (versioned path) over the version-agnostic shim. Charter v1.3.1 attribution split into boundary-enforcement bullet vs forbidden pattern. ADR 0022 section reference replaced with accurate "linked-observations pattern" phrasing. Phase 1/3/4 vocabulary explicitly mapped to HCS PLAN.md milestones at the top of §Recommendations. ADR 0025 (accepted), ADR 0027 (proposed, review pending), and ADR 0028 (proposed, review pending) cross-references added in F6 and References. No content removed. |
| 0.1.0 | 2026-05-02 | Initial. Translates the 2026-05-02 system-config security audit and revised hardening plan v0.2.0 into HCS evidence terms: per-finding mapping to charter invariants, `BoundaryObservation` envelope rows, gaps in current registry/matrix coverage, and Phase 1/3/4 sequencing notes including a self-referential first move (fix the HCS measure agent's mise pin and `launchctl` syntax). No schema, registry, or policy changes proposed; this document is evidence input. |
