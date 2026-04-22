#!/usr/bin/env bash
# policy-lint.sh — validate policy snapshot and structure.
#
# Canonical live policy lives in system-config; this repo's policies/generated-snapshot/
# is a test fixture only. At Phase 0a the snapshot is empty; script validates the
# directory exists and no stray live-policy files have been committed.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "→ policy-lint"

if [ ! -d policies/generated-snapshot ]; then
  echo "  ✗ missing policies/generated-snapshot/" >&2
  exit 1
fi

# 1. Policy must not live at policies/*.yaml — only in generated-snapshot/
if find policies -maxdepth 1 -type f -name "*.yaml" 2>/dev/null | grep -q .; then
  echo "  ✗ live policy YAML found at policies/ root — canonical location is system-config" >&2
  exit 1
fi

# 2. Any YAML under generated-snapshot/ must match the expected shape (has 'schema_version')
if [ -d policies/generated-snapshot ]; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if ! grep -q "schema_version" "$f"; then
      echo "  ✗ $f missing schema_version" >&2
      exit 1
    fi
  done < <(find policies/generated-snapshot -type f -name "*.yaml" 2>/dev/null)
fi

echo "  ✓ policy layout OK"
exit 0
