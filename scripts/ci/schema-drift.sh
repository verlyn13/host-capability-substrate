#!/usr/bin/env bash
# schema-drift.sh — verify generated JSON Schema matches Zod source.
#
# At Phase 0a packages/schemas is empty (.gitkeep only). This script noops
# until Milestone 1 (Ontology schemas) ships. At that point, regenerate and diff.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "→ schema-drift"

# Phase 0a: schemas empty, noop
if [ ! -d packages/schemas/src ] || [ -z "$(ls -A packages/schemas/src 2>/dev/null || true)" ]; then
  echo "  (packages/schemas/src empty — Phase 0a noop)"
  exit 0
fi

# Future (Milestone 1+): run generate + diff
# just generate-schemas > /tmp/generated.out
# diff -r packages/schemas/generated /tmp/generated.out || { echo "SCHEMA DRIFT"; exit 1; }
echo "  (skeleton implementation; extend at Milestone 1)"
exit 0
