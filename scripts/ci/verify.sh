#!/usr/bin/env bash
# verify.sh — run HCS quality gates in independent parallel groups.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-verify.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

names=()
logs=()
pids=()

run_group() {
  local name="$1"
  shift

  local log="$tmp_dir/$name.log"
  names+=("$name")
  logs+=("$log")

  (
    set -euo pipefail
    for recipe in "$@"; do
      just "$recipe"
    done
  ) >"$log" 2>&1 &

  pids+=("$!")
}

echo "→ verify (parallel groups)"

run_group node-tools format-check lint typecheck test
run_group static-gates \
  generate-schemas-check \
  boundary-check \
  policy-lint \
  forbidden-string-scan \
  no-live-secrets \
  no-runtime-state-in-repo \
  shellcheck-scan
run_group fixtures \
  redundancy-fixture \
  trap-fixture \
  shell-logger-fixture \
  env-inspect-fixture \
  provenance-snapshot-fixture \
  direnv-mise-fixture

fail=0
failed_indexes=()

for i in "${!pids[@]}"; do
  if wait "${pids[$i]}"; then
    echo "  ✓ ${names[$i]}"
  else
    fail=1
    failed_indexes+=("$i")
    echo "  ✗ ${names[$i]}" >&2
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "✓ all quality gates passed"
  exit 0
fi

echo "✗ quality gates failed" >&2
for i in "${failed_indexes[@]}"; do
  echo "--- ${names[$i]} log ---" >&2
  cat "${logs[$i]}" >&2
done
exit 1
