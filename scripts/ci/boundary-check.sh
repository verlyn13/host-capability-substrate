#!/usr/bin/env bash
# boundary-check.sh — enforce the four-ring import discipline.
#
# Rings (see docs/host-capability-substrate/implementation-charter.md):
#   Ring 0 — packages/schemas
#   Ring 1 — packages/kernel
#   Ring 2 — packages/adapters/**, packages/dashboard
#   Ring 3 — .agents/skills, docs, AGENTS.md, CLAUDE.md, PLAN.md, etc.
#
# At Phase 0a most packages are empty (.gitkeep only). This script confirms the
# layout is correct and will catch ring violations once code lands.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail=0
note() { printf "  %s\n" "$*"; }
err() { printf "  ✗ %s\n" "$*" >&2; fail=1; }

echo "→ boundary-check"

# 1. Ring directories exist
for dir in \
  packages/schemas \
  packages/kernel \
  packages/adapters/mcp-stdio \
  packages/adapters/mcp-http \
  packages/adapters/dashboard-http \
  packages/adapters/cli \
  packages/adapters/claude-hooks \
  packages/adapters/codex-hooks \
  packages/dashboard \
  packages/evals \
  packages/fixtures; do
  if [ ! -d "$dir" ]; then
    err "missing ring directory: $dir"
  fi
done

# 2. Ring 2 (adapters) must not import Ring 1 (kernel) private internals
#    except through packages/kernel/src/api/ (public API).
#    Scan any TS/JS files for 'from "@hcs/kernel/' patterns.
if [ -d packages/adapters ]; then
  if grep -rE "from ['\"]@hcs/kernel(/src)?/(?!api/)" packages/adapters 2>/dev/null; then
    err "adapters importing kernel private internals (use @hcs/kernel/api instead)"
  fi
fi

# 3. Ring 1 (kernel) must not import Ring 2 (adapters) at all
if [ -d packages/kernel ]; then
  if grep -rE "from ['\"]@hcs/adapters" packages/kernel 2>/dev/null; then
    err "kernel importing adapters — Ring 1 cannot depend on Ring 2"
  fi
  if grep -rE "from ['\"]@hcs/dashboard" packages/kernel 2>/dev/null; then
    err "kernel importing dashboard — Ring 1 cannot depend on Ring 2"
  fi
fi

# 4. Ring 0 (schemas) must not import anywhere above Ring 0
if [ -d packages/schemas ]; then
  if grep -rE "from ['\"]@hcs/(kernel|adapters|dashboard)" packages/schemas 2>/dev/null; then
    err "schemas importing kernel/adapters/dashboard — Ring 0 must be leaf"
  fi
fi

# 5. No universal-shell tool names registered anywhere
if grep -rE "\"(bash\.run|shell\.exec|exec\.unsafe_shell)\"" packages/ docs/ 2>/dev/null \
   | grep -v "unsafe_shell_proposal"; then
  err "universal shell execution tool name detected outside of stigmatized proposal"
fi

if [ $fail -eq 0 ]; then
  note "✓ ring boundaries intact"
  exit 0
else
  echo "✗ boundary-check FAILED" >&2
  exit 1
fi
