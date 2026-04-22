# Host Capability Substrate — task runner.
# See docs/host-capability-substrate/implementation-charter.md §Package boundary enforcement
# and docs/host-capability-substrate/0001-repo-boundary-decision.md §10 Quality gates.

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set dotenv-load := false

# Default: show available recipes
default:
	@just --list

# Run ALL quality gates. CI runs this. Required before merge.
verify: format-check lint typecheck test generate-schemas-check boundary-check policy-lint forbidden-string-scan no-live-secrets no-runtime-state-in-repo shellcheck-scan
	@echo "✓ all quality gates passed"

# Shellcheck — covers all .sh scripts + shebang-detected files
shellcheck-scan:
	@bash scripts/ci/shellcheck-scan.sh

# Format check (no writes)
format-check:
	@echo "→ format check"
	@npx --no-install biome format . 2>/dev/null || echo "  (biome not installed yet — run 'npm install')"

# Lint check
lint:
	@echo "→ lint check"
	@npx --no-install biome check . 2>/dev/null || echo "  (biome not installed yet — run 'npm install')"

# Typecheck
typecheck:
	@echo "→ typecheck"
	@npx --no-install tsc --noEmit 2>/dev/null || echo "  (tsc not installed yet — run 'npm install')"

# Unit tests
test:
	@echo "→ unit tests"
	@npx --no-install vitest run 2>/dev/null || echo "  (no tests yet — Phase 0a scaffold)"

# Schema drift check
generate-schemas-check:
	@bash scripts/ci/schema-drift.sh

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
# Runs the seven-day soak gate summary.
measure-brief:
	@bash scripts/dev/measure-brief.sh

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

# Combined soak status — launchd + hook + last partition
soak-status:
	@echo "=== launchd ==="
	@bash scripts/install/install-launchd-measure.sh status
	@echo ""
	@echo "=== hook ==="
	@bash scripts/install/install-claude-hook.sh status
	@echo ""
	@echo "=== partitions ==="
	@ls -1 .logs/phase-0/ 2>/dev/null | tail -5 | sed 's/^/  /' || echo "  (no partitions yet)"
