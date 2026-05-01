# Host Capability Substrate — task runner.
# See docs/host-capability-substrate/implementation-charter.md §Package boundary enforcement
# and docs/host-capability-substrate/adr/0001-repo-boundary.md §10 Quality gates.

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set dotenv-load := false

# Default: show available recipes
default:
	@just --list

# Run ALL quality gates. CI runs this. Required before merge.
verify:
	@bash scripts/ci/verify.sh

# Shellcheck — covers all .sh scripts + shebang-detected files
shellcheck-scan:
	@bash scripts/ci/shellcheck-scan.sh

# Semantic redundancy mapping regression fixture
redundancy-fixture:
	@bash scripts/dev/run-redundancy-fixture.sh

# Measurement-side trap heuristic regression fixture
trap-fixture:
	@bash scripts/dev/run-trap-fixtures.sh

# P06 shell wrapper redaction regression fixture
shell-logger-fixture:
	@bash scripts/dev/run-shell-logger-fixture.sh

# P12 secret-safe env inspection regression fixture
env-inspect-fixture:
	@bash scripts/dev/run-env-inspect-fixture.sh

# P08 provenance snapshot regression fixture
provenance-snapshot-fixture:
	@bash scripts/dev/run-provenance-snapshot-fixture.sh

# P09 non-mutating direnv/mise marker baseline fixture
direnv-mise-fixture:
	@bash scripts/dev/run-direnv-mise-fixture.sh

# P09 isolated direnv allow / mise trust terminal fixture
direnv-mise-terminal-fixture:
	@bash scripts/dev/run-direnv-mise-terminal-fixture.sh

# P09 GUI/IDE probe packet redaction-contract fixture
direnv-mise-gui-probe-fixture:
	@bash scripts/dev/prepare-direnv-mise-gui-matrix.sh --fixture

# P04 Codex env-policy probe packet redaction-contract fixture
codex-env-policy-probe-fixture:
	@bash scripts/dev/prepare-codex-env-policy-matrix.sh --fixture

# P03 Codex MCP startup-order probe packet redaction-contract fixture
codex-mcp-startup-probe-fixture:
	@bash scripts/dev/prepare-codex-mcp-startup-order.sh --fixture

# Format check (no writes)
format-check:
	@echo "→ format check"
	@if [ -x node_modules/.bin/biome ]; then node_modules/.bin/biome format .; else echo "  (biome not installed yet — run 'npm install')"; fi

# Lint check
lint:
	@echo "→ lint check"
	@if [ -x node_modules/.bin/biome ]; then node_modules/.bin/biome check .; else echo "  (biome not installed yet — run 'npm install')"; fi

# Typecheck
typecheck:
	@echo "→ typecheck"
	@if [ -x node_modules/.bin/tsc ]; then node_modules/.bin/tsc --noEmit; else echo "  (tsc not installed yet — run 'npm install')"; fi

# Unit tests. `just test schemas` limits Vitest to the schema package.
test target="":
	@echo "→ unit tests"
	@if [ -x node_modules/.bin/vitest ]; then \
		if [ "{{target}}" = "schemas" ]; then \
			node_modules/.bin/vitest run packages/schemas/tests; \
		else \
			node_modules/.bin/vitest run --passWithNoTests; \
		fi; \
	else echo "  (vitest not installed yet — run 'npm install')"; fi

# Schema drift check
generate-schemas-check:
	@bash scripts/ci/schema-drift.sh

# Generate JSON Schema from Zod sources. `just generate-schemas --check` checks drift.
generate-schemas mode="":
	@if [ "{{mode}}" = "--check" ]; then npm run generate-schemas:check; else npm run generate-schemas; fi

# Ring boundary enforcement
boundary-check:
	@bash scripts/ci/boundary-check.sh

# Policy YAML schema validation
policy-lint:
	@bash scripts/ci/policy-lint.sh

# Forbidden-string scan (universal shell names, op:// resolved values, etc.)
forbidden-string-scan:
	@bash scripts/ci/forbidden-string-scan.sh

# Secret scan
no-live-secrets:
	@bash scripts/ci/no-live-secrets.sh

# Ensure runtime state never enters the repo
no-runtime-state-in-repo:
	@bash scripts/ci/no-runtime-state-in-repo.sh

# Format-and-write (dev only)
format-fix:
	npx biome format --write .

# Lint-and-fix (dev only)
lint-fix:
	npx biome check --write .

# Install mise-managed tools + Node deps
bootstrap:
	mise install
	npm install

# Open this project's dashboard (later phases)
dashboard:
	@echo "dashboard not yet live — see PLAN.md Milestone 5"

# Print HCS environment
env:
	@echo "HCS_ROOT=$HCS_ROOT"
	@echo "HCS_POLICY_DIR=$HCS_POLICY_DIR"
	@echo "HCS_STATE_DIR=$HCS_STATE_DIR"
	@echo "HCS_LOG_DIR=$HCS_LOG_DIR"
	@echo "HCS_LAUNCH_LABEL=$HCS_LAUNCH_LABEL"

# === Phase 0b measurement ===

# Run one measurement pass across all sources. Read-only. Snapshot semantics:
# each script overwrites its per-day partition outputs, so re-runs are idempotent.
# See docs/host-capability-substrate/phase-0b-measurement-plan.md.
measure:
	@bash scripts/dev/measure-claude-code.sh
	@bash scripts/dev/measure-codex.sh
	@bash scripts/dev/measure-ide-hosts.sh
	@bash scripts/dev/measure-traps.sh
	@bash scripts/dev/measure-governance-inventory.sh
	@bash scripts/dev/measure-protocol-features.sh
	@bash scripts/dev/measure-redundancy.sh
	@bash scripts/dev/measure-tokens-estimate.sh
	@bash scripts/dev/measure-commands.sh
	@bash scripts/dev/measure-classify.sh
	@bash scripts/dev/measure-confusion.sh
	@bash scripts/dev/measure-partition-summary.sh

# Summarize the current partition (read-only)
measure-summary:
	@bash scripts/dev/measure-partition-summary.sh --detail

# Consolidate all partitions into brief.md + brief.json under .logs/phase-0/.
# Runs the current soak gate summary. Invokes measure-extended-rubric and
# measure-guidance-load as pre-aggregation steps; see phase-0b-measurement-plan v1.2.0.
measure-brief:
	@bash scripts/dev/measure-brief.sh

# Supplementary-rubric scoring over raw cross-agent transcripts (v1.2.0+).
# Reads raw/source-manifest.jsonl to pick canonical sessions; writes
# cross-agent-runs-extended.jsonl per partition. Safe during soak.
measure-extended-rubric:
	@bash scripts/dev/measure-extended-rubric.sh

# Guidance-load classification over raw cross-agent transcripts (v1.2.0+).
# Cross-joins with cross-agent-runs.jsonl; writes cross-agent-guidance-load.jsonl
# per partition. Safe during soak.
measure-guidance-load:
	@bash scripts/dev/measure-guidance-load.sh

# === Phase 0b classification pipeline (post-hoc) ===

# Extract per-command records from Claude Code + Codex corpora (7d window)
extract-commands:
	@bash scripts/dev/measure-commands.sh

# Classify commands (depends on extract-commands having run)
classify:
	@bash scripts/dev/measure-classify.sh

# Generate confusion-matrix-shaped aggregate (depends on classify)
confusion:
	@bash scripts/dev/measure-confusion.sh

# === Phase 0b Day-1 evidence battery ===

# Run the hook against 10 golden fixtures and check each verdict
fixtures:
	@bash scripts/dev/run-hook-fixtures.sh

# Verify safe-but-suspicious commands are NOT hard-blocked (target 0)
over-fire:
	@bash scripts/dev/run-overfire.sh

# Verify forbidden/destructive commands are NOT under-classified (target 0)
under-fire:
	@bash scripts/dev/run-underfire.sh

# Fault injection — 10 scenarios against the log-only hook
faults:
	@bash scripts/dev/run-fault-injection.sh

# Dashboard contract rehearsal — fake rows from current logs
dashboard-rehearse:
	@bash scripts/dev/render-dashboard.sh

# Run the full Day-1 battery end to end (synthetic layer)
day1: measure fixtures over-fire under-fire faults dashboard-rehearse
	@echo "✓ Day-1 battery complete — review .logs/phase-0/$(date -u +%Y-%m-%d)/"

# === Phase 0b soak installation ===

# Install daily measurement LaunchAgent (bootstrap, not load)
soak-install-launchd:
	@bash scripts/install/install-launchd-measure.sh install

# Remove daily measurement LaunchAgent (bootout)
soak-uninstall-launchd:
	@bash scripts/install/install-launchd-measure.sh uninstall

# Status of daily measurement LaunchAgent
soak-status-launchd:
	@bash scripts/install/install-launchd-measure.sh status

# Install opt-in global Claude Code hook (log-only)
soak-install-hook:
	@bash scripts/install/install-claude-hook.sh install

# Remove global Claude Code hook
soak-uninstall-hook:
	@bash scripts/install/install-claude-hook.sh uninstall

# Status of Claude Code hook installation + today's decision count
soak-status-hook:
	@bash scripts/install/install-claude-hook.sh status

# Combined soak status — launchd + hook + last partition + v1.2.0 supplementary outputs
soak-status:
	@echo "=== launchd ==="
	@bash scripts/install/install-launchd-measure.sh status
	@echo ""
	@echo "=== hook ==="
	@bash scripts/install/install-claude-hook.sh status
	@echo ""
	@echo "=== partitions ==="
	@ls -1 .logs/phase-0/ 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | tail -5 | sed 's/^/  /' || echo "  (no partitions yet)"
	@echo ""
	@echo "=== supplementary outputs (v1.2.0) ==="
	@for d in $(ls -1 .logs/phase-0/ 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | tail -3); do \
		if [ -f .logs/phase-0/$d/cross-agent-runs-extended.jsonl ]; then ext=$(wc -l < .logs/phase-0/$d/cross-agent-runs-extended.jsonl); else ext=0; fi; \
		if [ -f .logs/phase-0/$d/cross-agent-guidance-load.jsonl ]; then gl=$(wc -l < .logs/phase-0/$d/cross-agent-guidance-load.jsonl); else gl=0; fi; \
		printf "  %s  extended=%s  guidance-load=%s\n" "$d" "$(echo $ext | tr -d ' ')" "$(echo $gl | tr -d ' ')"; \
	done
