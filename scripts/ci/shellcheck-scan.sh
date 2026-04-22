#!/usr/bin/env bash
# scripts/ci/shellcheck-scan.sh
# Runs shellcheck on every shell script in the repo.
# Wired into `just verify` so warnings surface in CI from commit 1.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "→ shellcheck-scan"
  echo "  ⏸  shellcheck not installed — run: mise install"
  exit 0
fi

echo "→ shellcheck-scan"

# Find all shell scripts by extension AND shebang
targets=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  targets+=("$f")
done < <(
  {
    find scripts -type f \( -name '*.sh' -o -name '*.bash' \) 2>/dev/null
    # Also shebang-detected
    find .claude/hooks scripts -type f 2>/dev/null | while read -r g; do
      [ -f "$g" ] || continue
      case "$g" in
        *.sh|*.bash) continue ;;
      esac
      first=$(head -1 "$g" 2>/dev/null || true)
      if [[ "$first" == '#!'*bash* || "$first" == '#!'*sh* ]]; then
        echo "$g"
      fi
    done
  } | sort -u
)

if [ ${#targets[@]} -eq 0 ]; then
  echo "  (no shell scripts found)"
  exit 0
fi

fail=0
for t in "${targets[@]}"; do
  # -e SC2155 informational; focus on warning+
  if ! shellcheck -x -S warning "$t"; then
    fail=1
  fi
done

if [ $fail -eq 0 ]; then
  echo "  ✓ shellcheck clean on ${#targets[@]} scripts"
  exit 0
else
  echo "✗ shellcheck FAILED" >&2
  exit 1
fi
