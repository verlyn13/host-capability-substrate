#!/usr/bin/env bash
# schema-drift.sh — verify generated JSON Schema matches Zod source.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "→ schema-drift"

if [ ! -d packages/schemas/src ] || [ -z "$(ls -A packages/schemas/src 2>/dev/null || true)" ]; then
  echo "  (packages/schemas/src empty — Phase 0a noop)"
  exit 0
fi

if [ ! -d node_modules/zod ]; then
  echo "  ✗ node_modules/zod missing; run npm install before schema drift checks" >&2
  exit 1
fi

npm run generate-schemas:check
