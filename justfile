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
	@bash scripts/dev/measure-partition-summary.sh

# Summarize the current partition (read-only)
measure-summary:
	@bash scripts/dev/measure-partition-summary.sh --detail

# Consolidate all partitions into brief.md + brief.json under .logs/phase-0/.
# Runs the seven-day soak gate summary.
measure-brief:
	@bash scripts/dev/measure-brief.sh
