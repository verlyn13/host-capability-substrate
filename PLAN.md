# PLAN.md — Host Capability Substrate


Milestone-by-milestone implementation plan. Follow in order. Each milestone has acceptance criteria and validation commands. Do not skip validation.

Upstream research plan (canonical): `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md`.

## Current Focus — Phase 0b closeout / Phase 1 prep

As of 2026-04-26, this repo has completed the compressed **3-day Phase 0b soak** on top of the Milestone 0 scaffold. The same-day post-closeout follow-up landed measurement-only semantic redundancy mapping, and the refreshed brief is now green on the Phase 0b acceptance gate. Phase 1 still owns the larger formal capability ontology/policy work.

- Soak window: 2026-04-23 through 2026-04-25
- Closeout: 2026-04-26 with `just measure-brief`, charter v1.2.0, ADR 0012-0015, D-029-D-032, and scanner/hook parity for traps #16-#18
- Post-closeout measurement follow-up: `semantic-tool-map-v1` in `measure-redundancy.sh`, latest-partition redundancy selection in `measure-brief.sh`, advisory scanner catch-up for traps #37/#38, and `redundancy-fixture` / `trap-fixture` wired into `just verify`
- Kickoff battery: `just day1`
- Daily cadence during the soak: `just measure` and `just soak-status`
- Extension rule: if a future soak window does not produce a clean go/no-go, extend the soak rather than weakening the gate

### Closeout-week sequence (2026-04-24 → post-closeout)

Three-wave plan approved 2026-04-23 after synthesis of two external substrate-config research reports (see memory `project_substrate_config_research_report1.md`).

**W2 — days 2 + 3 (2026-04-24, 2026-04-25). Held-back drafts + outside-HCS work.**

- `system-config/scripts/lint-claude-settings.py` (new): validates `~/.claude/settings.json` and `~/.claude.json` against both (a) published JSON Schema and (b) installed-CLI runtime parse; flags divergence. Integrates into `system-update` hygiene flow. Outside this repo.
- Charter v1.2.0 amendment **draft branch** (not merged during soak). Includes invariants 13 (cleanup derivability-authority), 14 (config-spec authority + provenance), and 15 (GUI shell-env non-inheritance; Apple-doc + Anthropic-VS-Code-doc backed). Subagent objections from `hcs-architect`, `hcs-policy-reviewer`, `hcs-security-reviewer`, `hcs-ontology-reviewer` during days 2–3.
- ADR 0012 credential broker **draft branch** — scope revised 2026-04-24 after D-028 landed (system-config shipped the `host_secret_*` caller-facing contract + HCS_SECRET_* env namespace), the IPC deadlock recurred within 24 hours, AND the Cloudflare Stage 3a lessons brief (`docs/.../research/external/2026-04-24-cloudflare-lessons.md`) added one-time-secret capture-at-source as broker scope. Scope changes from "conditional, measurement-gated" to **"committed, phased; caller-facing phase already shipped as D-028; HCS work is the broker daemon at `$HCS_BROKER_SOCKET` speaking the existing contract, plus an atomic `create → capture → store → verify → scrub` pattern for provider-issued one-time secrets."** Broker serves CLI via `apiKeyHelper`/`awsCredentialExport` AND GUI via OAuth + Keychain separately (apiKeyHelper is CLI-only per metal-verified Anthropic docs); the broker does NOT unify the two surfaces.
- ADR 0013 forbidden-tier split **draft branch**.
- ADR 0014 InterventionRecord entity **draft branch**.
- ADR 0015 external-control-plane automation **draft branch** — NEW 2026-04-24. Scope: Cloudflare, GitHub, 1Password-CLI, MCP-OAuth, DNS providers, Hetzner as one provider class treated with typed evidence discipline (typed `OperationShape`, not shell strings). Absorbs the 8 design rules from the Cloudflare Stage 3a brief: minimal-request plan, budget-gated optional checks, 429-as-cooldown-not-retry, one-time-secret atomic broker path, ProviderObjectId / PublicClientId / SecretMaterial / SecretReference / PolicySelectorValue schema distinction, CLI-syntax-from-evidence-not-memory, typed MCP OAuth discovery (protected resource metadata + audience), explicit Cloudflare Access wildcard-path coverage warnings. Also absorbs the later `cloudflared` root-cause lesson: Access policy success and tunnel/origin audience validation are separate authority layers, so tunnel `audTag` coverage must be typed evidence before another Access mutation is proposed. Also absorbs the MCP diagnostics lesson: authenticated Cloudflare MCP fan-out is principal-scoped shared-token pressure, so local session fan-out, quarantine state, and `last_cf_mcp_429` are pre-mutation evidence. Drafted in W2, merged in W3 sequence after ADR 0014. Drafting distributed across W2 + early W4; scaffold files for the 7 associated regression traps (#19–#25) plus the tunnel-audience trap (#36) are Phase 1 work, not W3.
- Daily `just measure` + `just soak-status`; re-run `measure-extended-rubric` + `measure-guidance-load` over new partitions; any field incidents captured under `.logs/phase-0/interventions/`.
- Soak-safe improvement lane: Ring 3 docs, decision-ledger entries, ADR drafts, runbook structure, and non-semantic status/reporting fixes may land during the soak when they improve closeout decision quality. Do **not** change `classify.py`, hook enforcement behavior, metric-producing collectors, Codex profiles, live policy, or charter-on-main during the soak window; if a script change can alter day-over-day metrics, hold it for W3 closeout.

**W3 — closeout 2026-04-26. Ordered merge sequence. Completed in the closeout flow.**

1. `just measure-brief` — final narrative over the three partitions with v1.2.0 supplementary surfaces.
2. Charter v1.2.0 landed with invariants 13-15 and the D-029 public-semver baseline split.
3. ADR 0012, 0013, 0014, and 0015 landed in sequence (broker → forbidden-tier split → InterventionRecord → external-control-plane automation). ADR 0015 lands last because it depends on 0012's broker surface for the one-time-secret capture-at-source pattern.
4. Scanner parity landed for traps #16 (`ignored-but-load-bearing-deletion`), #17 (`harness-config-boolean-type`), and #18 (`agent-echoes-secret-in-env-inspection`) in `measure-traps.sh`; same-day post-closeout follow-up added advisory scanner heuristics for #37 (`process-argv-secret-exposure`) and #38 (`cloudflare-mcp-mutation-without-fanout-check`). Seed is at 38 (18 prior + 7 Cloudflare Stage 3a + 5 shell/environment research v2 + 5 coordination-lessons brief + 1 Cloudflare tunnel-audience lesson + 1 process-argv secret-exposure lesson + 1 Cloudflare MCP fan-out diagnostics lesson). Traps #19–#36 were seed-only at closeout; Phase 1 later landed scaffold files for #19–#30 and #36, while #31–#35 remain gated by Q-003. Hook literal-forbidden-list extension for trap #18's secret-echo regexes landed with this flow.
5. **DECISIONS.md batch commit (renumbered)** landed: D-029 (public-semver strings and separate app-build identifiers; Claude Code CLI `2.1.120`, Claude app `1.4758.0 (fb266c)` dated `2026-04-24T20:22:30.000Z`, Codex CLI `0.125.0`, Codex macOS app `26.422.30944 (2080)`, GPT-5.5/GPT-5.4-compatible HCS profiles + Opus 4.7 model posture), D-030 (OAuth-preferred HTTP MCP baseline; `enabled=false` + explicit opt-in, not profile-gating), D-031 (Codex profiles are CLI-only opt-ins), and D-032 (external control-plane automation; ADR 0015 is the master decision). Runtime-governs conflict rule is absorbed into D-026 + charter inv. 14. (D-028 already landed 2026-04-24 as the `host_secret_*` credential plane; see user commit `d59a35c`.)
6. Closeout narrative `docs/host-capability-substrate/phase-0b-closeout.md` answers the 5 runbook questions.
7. `phase-0b-self-review.md` v1.2.0 records closeout outcomes and Phase 1 carry-forward.

**W4 — post-closeout Phase 1 prep.**

The shell-environment research v2.12.0 (`docs/host-capability-substrate/shell-environment-research.md`) lays out a formal 10-working-day research program (2026-04-27 -> 2026-05-08, ~55-60 hours) using prompt IDs P01-P13. The existing direct-test queue items below cross-reference those prompt IDs; several are resolved at the documentation level and reduce to confirmatory smoke tests. P03 now has an operation-proofed MCP startup-order probe packet, P04 has an operation-proofed Codex env-policy probe packet, P08 has an initial Codex CLI tool-call snapshot fixture, P09 has terminal blocked/untrusted and isolated allowed/trusted fixtures plus an operation-proofed GUI/IDE probe packet, P11 has a LaunchAgent env policy design memo, and P12 has a repo-local secret-safe env-inspection prototype. 2026-05-01 source ingests update Codex config/app settings and Claude Desktop / Claude Code Desktop settings, including app-managed workspace dependencies, Git/worktree settings, permissions, local environments, Claude filesystem tool permissions, Preview state, and web PR automation. These remain future Ring 0/Ring 1 design inputs rather than accepted kernel operation surfaces.

Execution runbook: `docs/host-capability-substrate/phase-1-shell-env-direct-test-runbook.md`. It records local preflight evidence as of 2026-04-26, the Wave 1 order, secret-safe artifact contract, and operation-proof stubs. Current Claude context: local Claude Code is 2.1.123; sandboxed `claude auth status` can still report `loggedIn=false`, but host-context auth was available for the 2026-04-28/29 P06 closure run.

Next-agent handoff: `docs/host-capability-substrate/phase-1-shell-env-handoff-2026-04-30.md` captures the committed P08/P09/P11/P12 status, host-local wrapper install state, expected validation output, and open approvals.

P13 partial evidence: `docs/host-capability-substrate/research/shell-env/2026-04-26-P13-codex-app-bundle-signing.md` captures read-only Codex app bundle/signing metadata plus live process sandbox flags. That memo's last P13-specific refresh observed Codex app `26.422.71525` build `2210`; the 2026-05-01 Codex settings ingest separately observed the current local app bundle as `26.429.20946` build `2312`. Helpers show Electron/Chromium sandbox markers (`--seatbelt-client`, `--enable-sandbox`, `--service-sandbox-type=network`), while entitlement extraction remains unusable and app-internal Keychain/filesystem/network probes remain open. Generated app-server protocol schemas identify typed filesystem/network/account/MCP surfaces; the approved stdio app-server probe initialized successfully and returned `exitCode: 0` for a `/usr/bin/true` `command/exec` status probe, but that temporary server is not GUI app-internal evidence. A 2026-04-28/29 status probe correlated to the active Codex CLI session, not the GUI app. The current blocker is a reachable GUI app-server control path or a human-run sterile Codex app UI probe.

P01 partial evidence: `docs/host-capability-substrate/research/shell-env/2026-04-26-P01-codex-auth-metadata.md` captures metadata-only Codex auth state plus the approved migration attempt. Current host did not show a `Codex Auth` Keychain item with the safe lookup, while `${CODEX_HOME}/auth.json` exists. `codex login status` reports ChatGPT login, but the GitHub MCP entry still uses `bearer_token_env_var = "GITHUB_PAT"`; `codex mcp login github` failed because dynamic client registration is unsupported. Do not migrate MCP auth off env/PAT patterns until a static-client/manual OAuth strategy or broker decision is accepted and a restart check passes.

P02 validated evidence: `docs/host-capability-substrate/research/shell-env/2026-04-26-P02-codex-app-gui-launch-env.md` records that terminal `open -n` forwarded a synthetic marker into a new Codex app process, so terminal `open` is not a valid GUI proxy. A true Finder-origin cold start did not inherit the synthetic terminal-only marker (`p02_gui_marker_present=false`), supporting the rule that Codex app GUI sessions must not be modeled as inheriting shell-exported credentials.

P05 partial evidence: `docs/host-capability-substrate/research/shell-env/2026-04-26-P05-claude-desktop-auth-boundary.md` captures read-only Claude Desktop app/config metadata plus the approved synthetic runtime smoke. It found Claude.app 1.4758.0, no top-level `env` or `apiKeyHelper` in `claude_desktop_config.json`, and only the `MEMORY_FILE_PATH` env key name in Desktop MCP config. Terminal `open -b` propagated a synthetic marker, so it is not a valid GUI-origin proxy; Finder-origin launch did not inherit the marker and the Finder-launched process lacked common Claude credential env names by existence-only check.

P06 CLI closure evidence: `docs/host-capability-substrate/research/shell-env/2026-04-26-P06-shell-wrapper-logger-prep.md` captures the in-repo redaction-safe wrapper `scripts/dev/hcs-shell-logger.sh`, fixture `scripts/dev/run-shell-logger-fixture.sh`, approved host install to `/usr/local/bin/hcs-shell-logger`, shebang/atomic-append fixes required by the live run, and clean PATH-routed shell records. The fixture proves the wrapper preserves argv for the real shell while redacting `-c` command payloads from the wrapper log. The approved 2026-04-26/27 Codex probes displayed `/bin/zsh -lc` and bypassed PATH routing, but the 2026-04-28/29 host-telemetry rerun in `docs/host-capability-substrate/research/shell-env/2026-04-28-P06-host-telemetry-rerun.md` split that into separate phases: Codex internal startup shells used `/bin/zsh -lc`, while the actual Codex CLI tool-call subprocess execed through `sandbox-exec -- /bin/zsh -c <redacted>`. The focused closure run resolved the Codex `allow_login_shell=false` marker question for Codex CLI 0.125.0: the same host argv is preserved, but the synthetic marker env does not reach the actual tool shell in the no-login-shell config. Claude Code CLI 2.1.122 now has host telemetry for the Bash-tool subprocess: `/bin/zsh -c <redacted>`, marker visible, `.zshenv` only for the actual tool shell. PATH-prefix interception is closed as unsuitable except for negative controls; future re-baselining should use all-process host telemetry with live redaction.

Direct-test queue (combined from report 1 §14 + report 2 verification + shell research v2.12.0 P01-P13; blocks work that depends on each outcome):

1. `codex mcp login github` → Keychain entry → restart Codex → MCP starts clean without `GITHUB_PAT`. The approved attempt failed because dynamic client registration is unsupported, so this is blocked on a static-client/manual auth strategy or deliberate PAT/broker decision. If a future OAuth path succeeds, remove `bearer_token_env_var = "GITHUB_PAT"` from the system-config managed Codex block only after restart verification. *(Related: shell research v2 **P01**.)*
2. Codex app + CLI + IDE reuse the same MCP OAuth token (same `CODEX_HOME` → same Keychain key). *(Shell research v2 **P01**: resolved at doc level — Keychain service `"Codex Auth"`, account `cli|<sha256(CODEX_HOME)[:16]>`. Smoke test only, 1h.)*
3. Codex app honors project-scoped `.codex/config.toml` MCP definitions in trusted projects.
4. Codex app GUI cold start does NOT inherit terminal-only markers. *(Shell research v2 **P02**: validated locally for Finder-origin cold start on 2026-04-26; terminal `open -n` is explicitly not a GUI proxy. Retest on Codex app upgrades.)*
5. Claude Desktop uses OAuth-only; does NOT read `apiKeyHelper` or `ANTHROPIC_API_KEY`. *(Shell research v2 **P05**: docs-level claim plus local Finder-origin smoke now support this; terminal `open -b` is not a GUI proxy.)*
6. Claude Code #18692 (resolved-secrets-into-`.mcp.json`) does NOT repro on 2.1.120+. Local CLI is 2.1.123; host-context Claude auth was available for the 2026-04-28/29 P06 closure even though sandboxed `claude auth status` can report `loggedIn=false`, so run this from host context if selected.
7. `shell_environment_policy.include_only` reliably exposes named var on Codex CLI 0.125.0+ and current Codex macOS app `26.429.20946` build `2312`. *(Shell research v2 **P04**: schema documented but cross-surface behavior undocumented; issue #3064 suggests divergence. `scripts/dev/prepare-codex-env-policy-matrix.sh` and `just codex-env-policy-probe-fixture` now provide the probe packet and redaction-contract check. Runtime CLI/app/IDE rows remain open and require an approved observation path.)*
8. Verify `apiKeyHelper` CLI-only scope statement against live Anthropic docs. *(Shell research v2 §2.3 confirms at doc level.)*
9. Confirm D-031 surface coverage: `[profiles.hcs-*]` are CLI-only opt-ins unless a future Codex app/IDE probe proves otherwise.
10. Codex app MCP startup happens before worktree setup scripts. *(Shell research v2 **P03**: genuinely undocumented; marker-based timing test with synthetic repo, 8h. `scripts/dev/prepare-codex-mcp-startup-order.sh` and `just codex-mcp-startup-probe-fixture` now provide the setup/MCP startup-order packet and redaction-contract check. Runtime rows remain open and require an approved Codex app/control path.)*
11. **NEW — P06**: Shell wrapper-log validation and provenance closure. P06 is closed for Codex CLI and Claude Code CLI as of the 2026-04-28/29 host-telemetry closure run. In-repo wrapper, redaction fixture, and `/usr/local/bin/hcs-shell-logger` host install exist; approved PATH-routed probes confirmed the wrapper can capture `bash -lc`, `sh -c`, and `zsh -lc` safely after the shebang/atomic-append fixes. Cross-surface runtime evidence now has a sharper Codex split: internal Codex startup shells can use `/bin/zsh -lc`, but the actual Codex CLI tool-call subprocess is `sandbox-exec -- /bin/zsh -c <redacted>`. The focused matrix resolved the Codex `allow_login_shell=false` question for this version/config: no-login-shell preserves the same tool subprocess argv while preventing the synthetic marker env from reaching the actual tool shell. Claude Code CLI Bash-tool subprocess is now host-observed as `/bin/zsh -c <redacted>` with marker propagation and `.zshenv` only. App/IDE surfaces remain separate P02/P03/P04/P13 work, not P06 blockers.
12. **NEW — P13**: Codex app sandbox boundary characterization (new `ExecutionContext` class). Static bundle/signing plus live helper process flags are captured; generated schema and stdio app-server status probe are complete; app-internal Keychain/filesystem/network status-code probes remain open. Current state is open/narrowed because the GUI app-server control socket is unavailable from this session and Computer Use cannot operate `com.openai.codex`; next proof requires a reachable GUI app-server control path or a human-run sterile Codex app UI turn.
13. **NEW — P08**: Provenance snapshot — initial Codex CLI tool-call subprocess fixture landed as `packages/fixtures/provenance-snapshot-2026-04-30.json`, generated by `scripts/dev/capture-provenance-snapshot.py` and validated by `just provenance-snapshot-fixture`. The fixture captures PATH/SHELL/HOME/PWD/TMPDIR/CODEX_HOME value/provenance tags for this surface only with `authority: sandbox-observation`; additional surfaces still require their own snapshots. Original scope: commit `packages/fixtures/provenance-snapshot-YYYY-MM-DD.json` golden data. 6h.
14. **NEW — P09**: direnv + mise cross-surface visibility. Terminal fixtures landed for both blocked/untrusted and isolated allowed/trusted paths. `scripts/dev/run-direnv-mise-fixture.sh` validates no marker visibility before allow/trust; `scripts/dev/run-direnv-mise-terminal-fixture.sh` validates marker visibility after temp-scoped `direnv allow` and `mise trust`. Both use synthetic repos plus sanitized temp `HOME`/`DIRENV_CONFIG`/`MISE_*` state. `scripts/dev/prepare-direnv-mise-gui-matrix.sh` and `just direnv-mise-gui-probe-fixture` now provide the GUI/IDE probe packet and redaction-contract check. GUI/IDE runtime rows remain open and require explicit approval for launch/app state and any real trust-store writes.

Phase 1 work items (queued, unordered here — sequenced in ADR 0012, ADR 0015, ADR 0016/0017/0018, and the Phase 1 research plan):

- If W4-1 succeeds: migrate all HTTP MCP servers with OAuth support off `bearer_token_env_var` patterns (per D-028).
- Sparkle intervention F-08 (kernel RPC for typed per-section diagnostics) — permanent fix for `pipefail+head` class.
- Sparkle intervention F-09 (hook-decision schema v2 with version field + rotation).
- Extended-rubric formalization into primary scoring schema (Phase 1 cross-agent layer).
- `just verify-baseline` recipe — operationalizes charter inv. 14's "retest on upgrade" cadence.
- Formal semantic capability identity — extend beyond the measurement-only `semantic-tool-map-v1` into Ring 0 ontology/policy schema so equivalent operation surfaces are first-class substrate facts.
- Remaining Sparkle follow-ups F-01/F-02/F-03/F-07/F-11/F-13.
- **Ring-0 entity additions from ADR 0015 scope** (Milestone 1 20-entity list expands; design choice of new entity vs. Evidence subtype remains a Phase 1 schema decision): `RateLimitObservation`, `RemoteMutationReceipt`, `CredentialIssuanceReceipt`, `ProviderObjectReference`, `PathCoverage`, `McpAuthorizationSurface`, `OriginAccessValidator` with nested/linked `AudienceValidationBinding` semantics (resolved by ADR 0015; motivated by `cloudflared` `audTag` mismatch), and `McpSessionObservation` / `ControlPlaneBackoffMarker` candidates (or Evidence subtypes) for authenticated MCP fan-out and `last_cf_mcp_429` diagnostics.
- **Ring-0 entity additions from shell research v2 (ADRs 0016/0017/0018)**: initial Zod schemas, generated JSON Schema, ontology docs, and tests landed for `ExecutionContext`, `EnvProvenance`, `CredentialSource`, and `StartupPhase`. The slice preserves per-surface execution-context evidence, devcontainer-style env timing, Codex env-policy vocabulary, durable credential-source preference, and the 14-phase startup timeline. Remaining Ring 0 work: reconcile these shell/env entities with the 20 core Milestone 1 entities, add `ToolResolution`, and fold ADR 0015 external-control-plane evidence entities into the same schema package without moving policy into adapters.
- **Trap scaffold expansion for #19–#30 and #36** — Cloudflare/external-control-plane traps #19–#25, shell research traps #26–#30, and tunnel-audience trap #36 now have scaffold files under `packages/evals/regression/`, matching the #16/#18/#37 scaffold format. Executable fixtures remain future work: #19–#25 need provider-shape/rate-limit/credential/MCP auth fixtures, #36 needs live-provider/tunnel fixture design, and #31–#35 remain gated by Q-003.
- **Cloudflare Stage 3a eval fixture** — `cloudflare-access-stage3a-rate-limit-and-secret-capture.fixture.md` encoding the real trajectory. Seed trajectory in the Cloudflare lessons brief.
- **Cloudflare tunnel-audience eval fixture** — `cloudflare-access-tunnel-audience-mismatch.fixture.md` encoding the child Access app AUD accepted by Access but rejected by `cloudflared` because `audTag` listed only the parent app AUD. Seed trajectory in the Cloudflare lessons addendum.
- **Cloudflare MCP fan-out eval fixture** — `cloudflare-mcp-fanout-and-quarantine.fixture.md` encoding multiple authenticated `mcp-remote` sessions against one account-scoped token, recent `last_cf_mcp_429`, authenticated-wrapper quarantine, and docs-MCP degraded mode. Seed trajectory in the Cloudflare MCP diagnostics addendum.
- **Codex/ScopeCam eval fixture candidates #39–#44** — seed-only until a redacted primary transcript or human-approved fixture exists. Trap families: `tool-symptom-as-environment-diagnosis`, `execution-mode-conflation`, `remote-gone-branch-deletion-without-proof`, `worktree-ownership-ignored`, `branch-flow-ancestry-ignored`, and `inline-pr-body-shell-expansion`. Q-008 owns whether these become full scaffolds and which typed evidence receipts they require.
- **`hcs env-inspect` prototype** (shell research v2 §V.P12, 10h). Initial repo-local prototype landed as `scripts/dev/hcs-env-inspect.py` with fixture recipe `just env-inspect-fixture`; modes are `names_only | existence_check | classified | hashed`. Classifiers report "present + looks like JWT" / "present + looks like AWS key" / "present + non-secret shape" without echoing values. Includes regression coverage for the `printenv | grep` anti-pattern. First-class operational surface for trap #18 defense-in-depth remains future Ring 1 work (text rule + hook + operation-shape).
- **Typed process-inspection operation** — close trap #37 by separating host process reads from generic shell. Default to pid/name-only fields (`comm`), require redaction before transcript persistence for argv, and treat termination as a separate mutating operation requiring approval.
- **Semantic ontology + resource-pressure research intake** — use `docs/host-capability-substrate/semantic-ontology-resource-research-plan.md` to collect official-source findings before Phase 1 Ring-0 schema work and ResourceBudget enforcement. Scope includes W3C-style semantic practices, Covenant/Citadel governance materials as citation inputs, and test-runner/memory-pressure limits for Vitest, pytest/xdist, Node, Python, Playwright, Jest, Go, Cargo, Gradle, and macOS host signals.
- **2026-04-26 research execution intake** — run the semantic/resource program as source-bound discovery before synthesis. Use the source-class taxonomy, worker result template, output registry, and verification gates added in `semantic-ontology-resource-research-plan.md` v1.1.0. If capacity is limited, start with Wave 1C/1D: Vitest, Jest, pytest/xdist, Node, Playwright, Go, Cargo, Gradle, package managers, containers, macOS memory pressure, and macOS process limits.
- **Runner architecture compatibility intake** — preserve HCS/Citadel boundaries from `docs/host-capability-substrate/local-first-ci-opentofu-runner-design.md` and `docs/host-capability-substrate/research/external/2026-04-26-proposed-runner-architecture.md`: GitHub schedules and gates, Citadel/OpenTofu/PaC owns desired runner/workflow state, Proxmox/Linux x64 is the trusted self-hosted appliance class, hosted smoke remains the clean-room sentinel, MacBook runner use stays manual-only, and HCS consumes runner/check/resource/credential evidence rather than becoming a CI control plane. Q-005 gates any CI-specific entity or policy work.
- **GitHub/version-control authority intake** — preserve the 2026-04-29 local report at `docs/host-capability-substrate/research/local/2026-04-29-github-version-control-agentic-surface.md`. Q-006 gates schema/policy work that would model GitHub as an authority surface. Core lesson: GitHub on this host spans SSH transport aliases, Git signing/authorship config, `gh` keyring sessions, GitHub MCP PAT/OAuth/Copilot auth, per-workspace env overrides, repo settings/rulesets/Actions, check status sources, and local worktree/remote state. Do not collapse these into a single "GitHub auth" fact.
- **Version-control authority consult intake** — preserve the 2026-05-01 inline consult source note at `docs/host-capability-substrate/research/external/2026-05-01-version-control-authority-consult.md` and synthesis at `docs/host-capability-substrate/research/local/2026-05-01-version-control-authority-consult-synthesis.md`. Q-006 now explicitly includes source-control continuity, expected check source identity, Actions posture, `BranchDeletionProof`, split GitHub credential surfaces, and read-only dashboard posture before any GitHub mutation lane. Core lesson: green check names, `gh` login state, MCP tool availability, branch UI state, and local Git observations are all partial evidence, not authority by themselves.
- **ADR 0020 accepted posture** — `docs/host-capability-substrate/adr/0020-version-control-authority.md` records the accepted limited Q-006 direction: version control is a typed authority surface, Git/GitHub facts start as evidence subtypes/receipts, check consumption requires expected-source identity, branch cleanup requires `BranchDeletionProof`, Actions posture is separate evidence, and source-control continuity is freshness-bound. Its receipt list is split into five load-bearing Q-006 review names (`GitConfigResolution`, `GitIdentityBinding`, `BranchDeletionProof`, `StatusCheckSourceObservation`, `SourceControlContinuityReceipt`) plus a broader deferred inventory. ADR 0020 accepts no GitHub mutation and does not displace Q-005/Q-008/Q-009.
- **Ontology promotion and receipt dedupe planning** — `docs/host-capability-substrate/research/local/2026-05-01-ontology-promotion-receipt-dedupe-plan.md` records the cross-Q review rule before additional Ring 0 schema work: observed facts start as evidence subtypes, durable lifecycle objects become standalone entities, and proof composites / authored coordination facts need their own sub-rules. Q-011 is human-approved for the promotion buckets, naming convention, duplicate dispositions, dependency order, full `Evidence` base-shape prerequisite, `boundary_dimension` registry location, and `ExecutionContext.sandbox` coexistence/migration. No schema or policy changes are accepted from this planning doc.
- **Version-control posture dashboard planning** — `docs/host-capability-substrate/dashboard-contracts.md` v0.2.3 adds a candidate read-only `VersionControlPosture` view model, `/source-control` route sketch, and canonical per-surface capability state vocabulary (`proven`, `denied`, `pending`, `stale`, `contradictory`, `inapplicable`, `unknown`). It is planning only: no dashboard route, schema, API endpoint, policy tier, GitHub setting, or mutation lane exists yet. The view exists to keep Q-006 evidence dashboard-renderable before any source-control mutation operation is designed.
- **Quality-management boundary intake** — preserve the 2026-04-29 synthesis at `docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md` and source reports at `docs/host-capability-substrate/research/external/2026-04-29-github-boundaries-research.md` / `docs/host-capability-substrate/research/external/2026-04-29-hcp-quality-management.md`. Q-007 gates schema/policy/dashboard work for `QualityGate`, `BoundaryObservation`, macOS app/TCC/filesystem evidence, package-manager/shim provenance, and boundary uncertainty. Core lesson: boundaries are loose by nature on macOS/GitHub/package-manager surfaces, so HCS should model stale, missing, contradictory, and context-bound evidence explicitly rather than pretending the boundary is stable.
- **ADR 0022 accepted (2026-05-02)** — `docs/host-capability-substrate/adr/0022-boundary-observation-envelope.md` accepts the Q-007a direction: model `BoundaryObservation` as a freshness-bound `Evidence` subtype envelope first, keep `QualityGate` deferred, and use the envelope to reconcile macOS/TCC/app-bundle, package-manager, runner, source-control, execution-mode, and remote-agent boundary claims without making adapters or dashboards own policy. The accepted field block makes version composition, target references, singular `boundary_dimension` taxonomy discipline, primary-target binding, `observed_payload` / `expected_payload` domain-payload ownership, and linked-observation semantics explicit. Version/build/dependency changes are freshness invalidation signals for specific dimensions, not a generic `version_drift` dimension. ADR 0022 acceptance commits envelope shape only; the `boundary_dimension` registry at `docs/host-capability-substrate/ontology-registry.md`, `BoundaryObservation` Zod source and generated JSON Schema, policy tier, dashboard route, regression-trap, and runtime probe remain follow-up work.
- **BoundaryObservation regression candidates** — the hcs-architect review recommends traps for "anything uncertain" boundary envelopes, multi-dimension envelopes, authority promotion, and version drift as dimension. Do not scaffold these as regression files until ADR 0022 is accepted and each trap satisfies `.agents/skills/hcs-regression-trap/SKILL.md`'s no-synthetic-trap rule. The observed `version_drift` candidate-dimension misstep is eligible for future trap review with commits `c6d3183` / `c9661b6` as citation; the other three need an observed incident or human-approved fixture source before entering `packages/evals/regression/seed.md`.
- **Charter v1.3.1 wave-2 landed (2026-05-02)** — charter v1.3.1 added 3 boundary-enforcement bullets and 6 forbidden-pattern entries operationalizing invariants 16 and 17, closing the enforcement-plumbing gap that the post-merge `hcs-architect` review flagged on wave-1 (v1.3.0). Invariant text unchanged. CI implementation of the new bullets is queued separately: the policy-lint check that "every `OperationShape` carries a resolved `ExecutionContext` reference" requires a kernel `OperationShape` schema first (Milestone 1 expansion); the `provider_kind != "local"` evidence-shape declaration check requires capability-manifest schema work (Milestone 2 / 4); the typed-slot distinction check (`ProviderObjectReference` vs `PublicClientId` vs `PolicySelectorValue` vs `SecretReference`) requires the schema slice that introduces those types. Charter prose is binding; CI plumbing follows the supporting schemas.
- **`BoundaryObservation.evidence_refs` migration** — the BoundaryObservation Zod schema currently uses the lightweight `evidenceRefSchema` for `evidence_refs`. ADR 0022's stated precondition that the full `Evidence` base entity must land before envelope acceptance has been met (commit `760a5b6`); migration to typed pointers or full `evidenceSchema` references should be tracked. Hold for ontology review on whether `evidenceRefSchema` remains the canonical inter-entity reference for all evidence subtypes or whether a typed pointer-by-id pattern is preferred. Coordinated with `EnvProvenance`, `CredentialSource`, `ExecutionContext`, and `StartupPhase` which use the same lightweight reference today.
- **`evidence_schema_version` typing follow-up** — the BoundaryObservation envelope's `evidence_schema_version` field is currently typed as `schemaVersionSchema` (literal `'0.1.0'`). Per ADR 0022, envelope and base-Evidence schema versions are independent; once `Evidence` bumps past `0.1.0`, this typing will block envelope acceptance. Replace with a dedicated `evidenceSchemaVersionSchema` literal that tracks the Evidence schema's current version, or with `z.string().min(1)` mirroring the `payload_schema_version` treatment. Coordinate with any future Evidence schema version bump.
- **BoundaryObservation envelope-level freshness/redaction posture** — ADR 0022's candidate field block does not include `valid_until`, `observed_at`, `authority`, or `redaction_mode` at the envelope level; freshness and redaction currently compose from the embedded `evidence_refs`. The `hcs-architect` post-merge review flagged this as a six-question surface-boundary discipline gap (questions e and f). Decide whether the envelope itself carries Evidence-base provenance fields (envelope is itself an `Evidence` record) or remains a pure aggregator (freshness/redaction sourced from underlying evidence refs). Resolution affects Q-007 sub-decision (d) gate behavior and any domain-payload schema work.
- **Codex/ScopeCam execution-reality intake** — preserve the 2026-04-30 report at `docs/host-capability-substrate/research/external/2026-04-30-codex-scopecam-exchange-lessons.md` and synthesis at `docs/host-capability-substrate/research/local/2026-04-30-codex-scopecam-exchange-synthesis.md`. Q-008 gates schema/policy/eval work for `ToolInvocationReceipt`, `CommandCaptureReceipt`, `ExecutionModeObservation`, `BranchDeletionProof`, branch-flow invariants, worktree ownership, and `gh --body-file` renderer discipline. Core lesson: a command symptom is not a diagnosis; no-output/tool failures must stop destructive Git cleanup and implementation until execution mode is classified.
- **HCS diagnostic surface and workspace manifest intake** — preserve the normalized 2026-04-30 report at `docs/host-capability-substrate/research/external/2026-04-30-hcs-evidence-planning-report-1.md` and synthesis at `docs/host-capability-substrate/research/local/2026-04-30-hcs-evidence-planning-synthesis.md`. Q-009 gates schema/policy/adapter work for candidate surfaces `system.runtime.diagnose.v1`, `system.git.diagnose.v1`, `system.workspace.diagnose.v1`, `system.process.inspect_safe.v1`, `system.docs.diagnose.v1`, `system.cleanup.plan.v1`, and `system.claims.reconcile.v1`; only D-028's `host_secret_*` compatibility contract is accepted today. Core lesson: HCS should expose typed, redacted, provenance-carrying diagnostics and workspace-profile inputs rather than letting target repos reinvent host reality checks.
- **Agentic tool isolation compatibility intake** — preserve the 2026-05-01 report at `docs/host-capability-substrate/research/external/2026-05-01-agentic-coding-tool-isolation-report.md` and synthesis at `docs/host-capability-substrate/research/local/2026-05-01-agentic-tool-isolation-synthesis.md`. Q-010 gates schema/policy/tooling-matrix work for cross-agent containment vocabulary. Core lesson: permission gating, worktree/file isolation, local kernel sandboxing, container/VM isolation, and remote cloud execution are separate evidence dimensions. Do not import the report's `SharedAgentPolicySchema` as canonical HCS shape; reconcile the useful vocabulary through `ExecutionContext`, `AgentClient`, `ToolInstallation`, `ResolvedTool`, `CredentialSource`, `WorkspaceContext`, `ResourceBudget`, and future `BoundaryObservation` candidates.
- **Provenance snapshot data** (shell research v2 §V.P08, 6h) — initial Codex CLI tool-call fixture committed as `packages/fixtures/provenance-snapshot-2026-04-30.json`; re-snapshot on tool version changes per charter inv. 14 and add separate fixtures for app/IDE surfaces after their execution context probes exist.
- **Codex official config/app-settings ingest** — `docs/host-capability-substrate/research/shell-env/2026-05-01-codex-official-config-app-settings-ingest.md` preserves the 2026-05-01 official config basics and macOS app settings intake. Key implications: CLI flags/profiles/project/user/system/default config precedence; untrusted projects skip `.codex/` project layers; managed `requirements.toml` is an admin constraint source, not HCS live policy; Workspace Dependencies are app-managed toolchain evidence; app Git/worktree settings can prune worktrees but do not prove branch deletion safety; local environments are worktree/bootstrap scope, not startup-auth authority.
- **Claude Desktop / Claude Code Desktop settings ingest** — `docs/host-capability-substrate/research/shell-env/2026-05-01-claude-desktop-code-settings-ingest.md` preserves the 2026-05-01 app settings intake. Key implications: Claude Desktop MCP config lives at `~/Library/Application Support/Claude/claude_desktop_config.json`; filesystem tool `ask` prompts are app-mediated permissions, not HCS `ApprovalGrant` records; bypass mode and auto permissions mode are app postures, not kernel policy; persisted Preview sessions may contain cookies/local storage/login state; `.claude/worktrees` is generated but potentially load-bearing state; web PR/autofix automation belongs to the GitHub/external-control-plane authority workstream.
- **LaunchAgent env policy table** (shell research v2 §V.P11, 6h) — design-only memo landed at `docs/host-capability-substrate/research/shell-env/2026-04-30-P11-launchagent-env-policy-table.md`; ADR acceptance remains future synthesis work.
- **Charter v1.3.0 invariant 16 (active 2026-05-02)** — Charter v1.3.0 landed with "external-control-plane evidence-first": operations against remote control planes must produce typed evidence before provider-side mutations, distinguish provider object references / public client IDs / policy selector values / secret references / secret material, model separable provider validator surfaces before mutations that depend on them, and treat rate-limit/backoff state as evidence rather than retry pressure. Typed evidence is necessary, not sufficient, and does not bypass policy/gateway, approvals, broker FSM, audit, dashboard review, or leases.
- **Charter v1.3.0 invariant 17 (active 2026-05-02)** — Charter v1.3.0 landed with "execution-context is declared, not inferred": every operation carries a resolved `ExecutionContext.surface` reference; agents must not assume a subprocess inherits any sandbox, capability, environment, or credential scope from the parent context unless intentional inheritance is represented by typed evidence bound to the target context and the exact dimension asserted. Codex `inherit` / `include_only` is environment-materialization evidence only; it does not prove credential authority, sandbox scope, app/TCC permission, provider mutation authority, or HCS `ApprovalGrant` status.
- **ADR 0021 accepted** — `docs/host-capability-substrate/adr/0021-charter-v1-3-wave-1.md` packages charter v1.3.0 wave 1: invariant 16 and invariant 17 only, with invariants 18-20 deferred to Q-003/Q-007/Q-008. The charter-edit PR landed 2026-05-02; invariants 16 and 17 are now active in `implementation-charter.md` v1.3.0.
- **Principal-level `ResourceBudget` rollup** — the Cloudflare 5-minute/1200-request limit is a user-level budget cumulative across dashboard/API-key/API-token/MCP surfaces. Principal-scoped `ResourceBudget` abstraction queued in ADR 0015, with broker enforcement consuming MCP fan-out diagnostics and `last_cf_mcp_429` markers before mutations.
- **Charter v1.3.0 candidate invariant 19** — "boundary claims are freshness-bound and execution-context-bound": HCS must model contradictory or missing boundary evidence explicitly and must not promote a boundary inference across macOS app, shell, package-manager, Git/GitHub, or MCP surfaces without a matching observed context. Queue-only; Q-007 decides whether this becomes a charter invariant or remains a Phase 1 design principle.
- **Charter v1.3.0 candidate invariant 20** — "command symptoms are not diagnoses": HCS-mediated agents must distinguish tool/runtime failure from command failure, must not promote command evidence across unmatched execution modes, and must block destructive Git cleanup unless branch/worktree safety is proven by typed evidence. Queue-only; Q-008 decides whether this becomes a charter invariant or remains an agent operating-contract rule.

### CI runner compatibility items (gated by Q-005)

The 2026-04-26 runner architecture brief is for a separate CI/runner project,
but HCS must stay compatible with it. Treat the report as Ring 3 planning and
do not implement runner infrastructure from this repo.

- **Boundary rule:** HCS observes and gates HCS-mediated local host operations; GitHub/Citadel own CI scheduling, branch/ruleset gates, runner group desired state, workflow policy, and Proxmox runner definitions.
- **Evidence candidates:** `RunnerHostObservation`, `RunnerIsolationObservation`, `WorkflowRunReceipt`, `CleanRoomSmokeReceipt`, `ResourceBudgetObservation`, and `PolicyPlanReceipt` should be considered as `Evidence` subtypes before adding standalone Ring-0 entities.
- **Policy candidates:** public fork code on self-hosted runners, generic `runs-on: self-hosted`, MacBook always-on CI, runner tokens in OpenTofu state, personal credentials on CI hosts, and Docker socket exposure to untrusted jobs are forbidden/non-escalable candidates, but tier entries belong in canonical system-config policy after review.
- **Regression-trap candidates:** `public-fork-self-hosted-runner`, `macbook-ambient-credential-runner`, `persistent-runner-workspace-authority`, `ci-cache-promoted-to-evidence`, `runner-token-in-opentofu-state`, `status-check-from-wrong-source`, `docker-socket-on-untrusted-runner`, and `workflow-yaml-as-build-system`. Do not add them to the committed corpus until a concrete observed failure or human-approved trap expansion exists.
- **Phase 1 synthesis dependency:** fold runner observations into ResourceBudget/external-control-plane synthesis after Wave 1C/1D verification, not before.

### Coordination / shared-state items (gated by Q-003)

The 2026-04-24 coordination-lessons brief (`docs/host-capability-substrate/research/external/2026-04-24-coordination-lessons.md`) proposes a three-layer shared-state architecture. The brief is highly aligned with existing HCS posture (charter inv. 1/2/5/7/8/10, D-025/D-026, ADR 0004/0010/0011), but committing to the architecture is a whole-system design commitment. **Five sub-decisions are bundled as Q-003 in DECISIONS.md pending** and must be resolved before any of the items below land on main:

- **ADR 0019 — HCS Knowledge and Coordination Store (candidate).** Three-layer taxonomy: (1) authoritative operational store (existing SQLite WAL, M3); (2) coordination state layer (NEW — typed gateable coordination facts); (3) retrieval/RAG index (NEW — derived, never authoritative). Plus the promotion workflow (agent proposes → verifier promotes). Drafting window: **post-Phase-1 synthesis (2026-05-08) or later** — not Week 1 of Phase 1, because ADR 0019 is a larger commitment than 0016/0017/0018.
- **Four Ring-0 entity candidates (Q-003 sub-decision b reconciles vs existing `Evidence`):** `KnowledgeSource` (indexable canonical source: charter / ADR / decision-ledger / runbook / vendor-doc / receipt / code / schema / audit-summary), `KnowledgeChunk` (derived chunk with stable content hash), `CoordinationFact` (subject/predicate/object gateable state with `evidence_ids`, `authority`, `confidence`, `valid_until`), `DerivedSummary` (agent-authored summary with `allowed_for_gate: false` until promoted).
- **Charter v1.3.0 invariant 18 candidate** — "Derived retrieval results are never decision authority. A retrieved chunk may guide the agent to a source, probe, receipt, or schema, but policy/gateway decisions and release gates consume only typed evidence, approved decisions, receipts, leases, and live observations." Extends charter inv. 8 (sandbox observations cannot be promoted) to the retrieval/RAG surface. Q-003 sub-decision (e) is whether this warrants a new invariant or remains a strong guideline under inv. 8.
- **Five regression trap seeds #31–#35** (stale-rag-release-gate, detached-worktree-false-regression, agent-summary-overclaim, stale-ssh-alias, auth-surface-conflation) — seeded in `packages/evals/regression/seed.md`. Scaffolds require the coordination/knowledge substrate which is gated by Q-003 resolution.
- **D-033 candidate** — "HCS shared memory is typed evidence + coordination state + derived retrieval index, not agent memory." **NOT in the W3 closeout batch** (D-029/D-030/D-031/D-032 only); D-033 lands on a post-Phase-1 decisions sweep once Q-003 is resolved.
- **Promotion workflow formalization** (Q-003 sub-decision d): agent writes `candidate_memory` with `requires_verification`; verifier promotes to `coordination_fact` with `evidence_ids` and `allowed_for_gate: true`. Open question: is this a parallel track to the approval-grant pattern (M2) or reuse with a different target entity?
- **Dashboard views** (Milestone 5+ additions, gated by Q-003): `/evidence`, `/coordination`, `/knowledge`, `/interventions`, `/reconciliation`. Should show when a model used a retrieved chunk vs. when a gate used typed evidence — the distinction visible to the human reviewer.
- **Storage posture** (aligns with existing D-003/ADR 0004 — no divergence): SQLite WAL remains the authority store; SQLite FTS is sufficient for the first retrieval layer; embeddings are a derived index rebuildable from `KnowledgeSource` + `KnowledgeChunk`; hosted vector stores are NOT acceptable for private runtime state (aligns with charter inv. 10 + D-018); Postgres/pgvector only becomes worth it when HCS goes multi-host or multi-writer.

### Phase 1 shell/environment research program (shell research v2.12.0, 2026-04-27 -> 2026-05-08)

Formal 10-working-day research program from `docs/host-capability-substrate/shell-environment-research.md` §IV. Secret-safe testing constraint throughout: existence-only checks, name-only capture, hashes, or classified/redacted — no raw secret values in transcripts. Grounded in trap #18 + NIST SP 800-92 + CWE-532/200 + OWASP logging guidance.

| Wave | Days | Prompts | Hours | Deliverable |
|------|------|---------|-------|-------------|
| Foundation | Mon 04-27 | — | 4 | Redaction-safe harness, synthetic repo, evidence template, redaction rules |
| Wave 1 — resolved/near-resolved | 04-27 → 04-29 | P01, P05, P02, P13, P06 | 12 | Five memos + wrapper logs + sandbox characterization |
| Wave 2 - genuinely open | 04-30 -> 05-06 | P04, P03, P09 GUI/IDE; P08 surface expansion as available | 30 | Cross-surface matrix + MCP/setup-script trace + direnv/mise matrix; initial Codex CLI provenance snapshot, P03/P04/P09 probe packets, and P09 terminal fixtures landed |
| Wave 3 - design + prototype (parallel with Wave 2) | 04-29 -> 05-06 | P12 Ring 1 design later | 16-20 | LaunchAgent-env policy table and repo-local `hcs env-inspect` prototype landed |
| Synthesis | 05-07 -> 05-08 | - | 6 | ADR 0016 + 0017 + 0018 accepted, regression trap scaffolds #26-#30 landed, initial shell/env Ring-0 schemas landed; core reconciliation remains next |

**ADR candidates from synthesis (scoped by shell research v2 §VIII):**

- **ADR 0016 — Shell/environment ownership boundaries.** Accepted at `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`. It records policy conclusions 1–11 from shell research v2 §VI: shell-exported secrets are CLI convenience only, project config and shell/bootstrap config are separate planes, agent command shell persistence cannot be assumed, helper scripts declare shell ownership, HCS adopts Codex `shell_environment_policy` vocabulary and devcontainer env typing, `CLAUDE_ENV_FILE` is best-effort, and subagent isolation is preserved. Trap #29 (`packages/evals/regression/claude-env-file-durability.md`) is the existing canonical trap for `CLAUDE_ENV_FILE` durability; do not add a duplicate.
- **ADR 0017 — Codex app as distinct ExecutionContext.** Accepted at `docs/host-capability-substrate/adr/0017-codex-app-execution-context.md`. It models Codex app as `codex_app_sandboxed` with identity, launch, app-setting, and host-visible process evidence separated from pending app-internal Keychain/filesystem/network capability rows. It blocks the "Codex is Codex" mental model while keeping P13 runtime rows open. Dashboard-facing capability rows should use the shared seven-state capability vocabulary from `dashboard-contracts.md` / ADR 0022.
- **ADR 0018 — Durable credential source preference.** Accepted at `docs/host-capability-substrate/adr/0018-durable-credential-preference.md` with schema-field-only posture. It preserves tool-native OAuth + OS storage where first-party and verified, but prefers brokered `SecretReference` values, long-lived setup-token-style credentials, API keys, or service accounts for HCS-integrated/headless/non-OAuth/one-time-secret flows. Shell env remains a compatibility rendering, not the durable credential source. Future credential-source schema review should preserve audience and mutation-scope posture without pre-accepting the Q-006 GitHub MCP read/mutation split.

**Remaining unknowns** (shell research v2 §VII — upstream questions, not blocking Phase 1):

- `apiKeyHelper` Windows behavior (PowerShell vs cmd inconsistency).
- `CLAUDE_ENV_FILE` path uniqueness across parallel Claude Code sessions.
- Whether Codex `shell_snapshot` captures credential-shaped env vars under the default exclude filter.
- Whether `mise activate` runs in a non-TTY ACP session (Zed → Claude Agent).
- Whether Codex app Seatbelt profile is strictly tighter than CLI's.
- Claude Desktop Keychain service name vs CLI's `"Claude Code-credentials"`.

Discipline for W2–W3: no changes to `classify.py`, `.claude/hooks/`, `just measure` collectors, Codex profiles, `tiers.yaml`, or charter-on-main during the soak window (2026-04-24 and 2026-04-25). Draft-in-branch is permitted; merges land on 2026-04-26 in the ordered sequence above.

---

## Milestone 0 — Repository scaffold

**Goal:** The repo enforces its own discipline from commit 1.

**Acceptance:**

- Package layout exists (`packages/schemas`, `packages/kernel`, `packages/adapters`, `packages/dashboard`, `packages/evals`, `packages/fixtures`)
- `just verify` runs (even if it only runs lint + boundary-check + forbidden-string-scan + no-runtime-state-in-repo)
- Schema package compiles (empty but typed)
- `docs/host-capability-substrate/` exists with charter (v1.3.0+), tooling-surface-matrix, ADR template, and accepted ADRs 0001-0015 through closeout
- `AGENTS.md`, `CLAUDE.md`, `PLAN.md`, `IMPLEMENT.md`, `DECISIONS.md` in place
- `.agents/skills/` has the six canonical workflow skills (hcs-adr-review, hcs-draft-adr, hcs-regression-trap, hcs-operation-proof, hcs-policy-tier-entry, hcs-schema-change)
- `.claude/agents/` has six subagents (architect, ontology-reviewer, policy-reviewer, security-reviewer, hook-integrator, eval-reviewer)
- `.claude/skills/` empty at Phase 0a
- `.claude/settings.json` present with model=opus, deny-list for forbidden literals, hook wiring
- `.claude/hooks/hcs-hook` present in log-only mode
- No `WARP.md`, no `.windsurf/`, no `.copilot/`
- CI boundary checks wired (strict from M0): boundary-check, policy-lint, schema-drift, forbidden-string-scan, no-live-secrets, no-runtime-state-in-repo

**Validation:**

```bash
just verify
```

---

## Milestone 1 — Ontology schemas (Ring 0)

**Goal:** 22 canonical entities are real and versioned.

**Acceptance:**

- 22 canonical entities (HostProfile, WorkspaceContext, Principal, AgentClient, Session, ToolProvider, ToolInstallation, ResolvedTool, Capability, OperationShape, CommandShape, Evidence, ExecutionContext, PolicyRule, Decision, ApprovalGrant, Run, Artifact, Lease, Lock, SecretReference, ResourceBudget) as Zod schemas. `ExecutionContext` is on the canonical list per ADR 0021 invariant 17 forward binding (charter v1.3.0); `EnvProvenance`, `CredentialSource`, and `StartupPhase` remain Phase 1 supplemental entities until Q-011-guided ontology review promotes them.
- JSON Schema generated from Zod
- Every entity has `schema_version`
- Provenance schema (`Evidence`) is reusable by every fact-returning service
- Docs autogenerated or hand-written and verified against schemas

**Validation:**

```bash
just test schemas
just generate-schemas --check
```

---

## Milestone 2 — Policy snapshot + decision package

**Goal:** Policy can be evaluated against structured inputs without a running kernel.

**Acceptance:**

- `tiers.yaml` schema validates against Zod entity schemas
- `Decision` and `ApprovalRequest` schemas exist
- `Decision` and `ApprovalRequest` consume `BoundaryObservation` evidence refs; gate-behavior is defined for `observation_state` ∈ {`stale`, `contradictory`, `unknown`, `inapplicable`} per Q-007 sub-decision (d). Resolution of Q-007(d) is the natural Milestone 2 entry point per ADR 0022 Consequences.
- YAML policy loader exists and rejects malformed or stale-schema-version files
- Policy input shape (principal + session + host + workspace + operation + resolved_tools + evidence + requested_capability + time) is defined
- **No execution path exists yet.** No `system.exec.*`, no approval endpoints.

**Validation:**

```bash
just test policy
just policy-lint
```

---

## Milestone 3 — SQLite audit/facts bootstrap

**Goal:** Visible state and audit state are both persisted and queryable, independently.

**Acceptance:**

- `storage.sql` applied to a temp SQLite DB with WAL mode
- `audit_events` append implemented with hash chain (row_hash = sha256(prev_hash || canonical(row)))
- Checkpoint table exists (checkpoints not yet written to `op://`)
- `facts` + `fact_observations` split implemented
- Read-only `recent_events(limit, filter)` query exists
- Power-cut mid-write test passes (WAL integrity)

**Validation:**

```bash
just test storage
just test audit-chain
```

---

## Milestone 4 — First MCP read tools

**Goal:** First adapter surface live. Five read-only capabilities callable from Claude Code, Codex, etc.

**Acceptance:**

- `system.host.profile.v1` exposes structured output matching `HostProfile` schema
- `system.session.current.v1` returns live `Session` + `SessionContext`
- `system.tool.resolve.v1` walks mise → project-local → brew → system and returns `ResolvedTool` with provenance
- `system.tool.help.v1` caches `--help` with provenance + parser version
- `system.policy.classify_operation.v1` accepts `OperationShape`, returns `Decision`
- **No mutating endpoints.** Charter invariant 7 enforced by absence.
- MCP stdio adapter wires these 5 tools with strict tool schemas
- Audit log records every call

**Validation:**

```bash
just test mcp
just test integration:claude-code
```

---

## Milestone 5 — Gateway propose + dashboard summary

**Goal:** Full slice-1 surface live; dashboard shows live state.

**Acceptance:**

- `system.gateway.propose.v1` creates a proposal, returns decision package, does not execute
- `system.audit.recent.v1` queries visible state
- `system.dashboard.summary.v1` returns summary payload + local dashboard URL
- Dashboard has read-only views: `/health`, `/sessions`, `/tools`, `/policy`, `/audit`, `/dashboard-summary.json`
- View-model contracts match `DashboardSummary`, `LiveSessionRow`, `HostFactCard`, `ToolResolutionTrace`, `PolicyDecisionCard`, `OperationProposalCard`, `AuditTimelineEvent`, `CacheEntryCard`, `HealthStatus`
- Dashboard never bypasses policy — calls through the same gateway

**Validation:**

```bash
just test dashboard
just test integration:end-to-end-readonly
```

---

## Milestone 6 — Hooks wired + regression corpus runner

**Goal:** Agent behavior is shaped by substrate from session 1.

**Acceptance:**

- Claude Code PreToolUse hook calls `resolve` + `classify_operation` with 50ms timeout and cache fallback
- Codex hook (where supported) logs advisory signals and blocks forbidden Bash patterns
- Regression corpus runner executes the seed 15 traps against at least Claude Opus
- Acceptance criteria from research plan §6 Phase 3 measurable:
  - ≥50% reduction in redundant `--help` probes across agents vs baseline (top 10)
  - cache-hit p50 < 20ms, p99 < 80ms
  - cache-miss overhead < 50ms above underlying CLI
  - graceful degradation when kernel down
  - ≥1 documented substrate-beats-raw-shell case

**Validation:**

```bash
just test evals
just measure       # run daily during the active soak window
just measure-brief # consolidate partitions into the metrics diff
```

---

## Stop-and-fix rules

- If `just verify` fails, fix before proceeding to the next milestone.
- If a boundary-check rule is violated, the PR does not merge — even if tests pass.
- If a regression trap is triggered by substrate changes, add the trap to the corpus and fix in the same PR.
- If a schema changes, regenerate JSON Schema in the same commit.

## Architecture notes

- Ring 0 (schemas) ships first. Every other ring builds on it.
- Ring 1 (kernel) ships before any adapter. Never the reverse.
- Dashboard view contracts land with Ring 1 services — kernel output must be dashboard-renderable from day 1.
- Execute lane (mutations) is blocked at CI until Milestone M4-Month-4 of the full roadmap in research plan §6 Phase 4.

## Out of scope for initial build (explicit)

- Execute lane endpoints
- Approval grant creation/consumption
- Sandbox executor
- Remote (non-localhost) MCP
- A2A facade
- MCP Apps UI embeds

These belong in later milestones after the read-only substrate has demonstrated value under soak.
