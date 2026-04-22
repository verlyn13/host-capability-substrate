#!/usr/bin/env bash
# no-runtime-state-in-repo.sh — ensure runtime state never enters the repo.
#
# Per charter invariant 10 and ADR 0011: runtime state lives at $HCS_STATE_DIR
# (~/Library/Application Support/host-capability-substrate/) and logs at $HCS_LOG_DIR
# (~/Library/Logs/host-capability-substrate/). These layouts must never appear in the repo.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "→ no-runtime-state-in-repo"

fail=0

# Suspicious runtime-ish file extensions/names at repo root or under packages
patterns=(
  "*.sqlite"
  "*.sqlite-wal"
  "*.sqlite-shm"
  "audit_events.*"
  "facts.*"
  "cache_entries.*"
  "hcs.*.log"
  "dashboard-token*"
)

for pat in "${patterns[@]}"; do
  matches="$(find . -path ./node_modules -prune -o -path ./.git -prune -o -type f -name "$pat" -print 2>/dev/null | head -10)"
  if [ -n "$matches" ]; then
    echo "  ✗ runtime-state-like file(s) found matching '$pat':" >&2
    echo "$matches" | sed 's/^/      /' >&2
    fail=1
  fi
done

# No hard-coded absolute paths to HCS_STATE_DIR or HCS_LOG_DIR as source material
# (references in docs, ADRs, and CI scripts are fine)
if grep -rE "\"[^\"]*Library/Application Support/host-capability-substrate[^\"]*\"" packages/ scripts/ci 2>/dev/null \
   | grep -v "no-runtime-state-in-repo.sh"; then
  echo "  ✗ hard-coded $HCS_STATE_DIR path in package source" >&2
  fail=1
fi

if [ $fail -eq 0 ]; then
  echo "  ✓ no runtime state in repo"
  exit 0
else
  echo "✗ no-runtime-state-in-repo FAILED" >&2
  exit 1
fi
