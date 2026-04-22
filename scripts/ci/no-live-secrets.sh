#!/usr/bin/env bash
# no-live-secrets.sh — secret scan using gitleaks if available; fallback to regex heuristics.
#
# Per charter invariant 5: secrets never in repo, only op:// references.
# Per charter invariant 10 and ADR 0011: no runtime tokens, audit-signing material,
# or resolved 1Password content in the public repo.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "→ no-live-secrets"

if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --no-banner --source "$repo_root" --redact --exit-code 1 2>&1 | tail -20
  gitleaks_status=$?
  if [ "$gitleaks_status" -ne 0 ]; then
    echo "✗ gitleaks detected secrets" >&2
    exit 1
  fi
  echo "  ✓ gitleaks clean"
  exit 0
fi

# Fallback regex heuristics (weaker than gitleaks)
echo "  (gitleaks not installed — running fallback regex heuristics)"

fail=0

# Private keys
if grep -rE "-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----" \
  --include='*' \
  -l 2>/dev/null | grep -v ".gitignore\|scripts/ci/no-live-secrets.sh"; then
  echo "  ✗ private key material committed" >&2
  fail=1
fi

# .env file committed
if [ -f .env ] || [ -f .env.local ]; then
  echo "  ✗ .env or .env.local committed" >&2
  fail=1
fi

# Common secret-like patterns
for pattern in \
  'AWS_SECRET_ACCESS_KEY\s*[:=]\s*[A-Za-z0-9/+=]{30,}' \
  'GITHUB_TOKEN\s*[:=]\s*[A-Za-z0-9_]{30,}' \
  'OPENAI_API_KEY\s*[:=]\s*sk-[A-Za-z0-9]{20,}' \
  'ANTHROPIC_API_KEY\s*[:=]\s*sk-ant-[A-Za-z0-9]{20,}'; do
  if grep -rE "$pattern" --include='*' 2>/dev/null | grep -v "scripts/ci/no-live-secrets.sh\|op://"; then
    echo "  ✗ potential secret literal matched: $pattern" >&2
    fail=1
  fi
done

if [ $fail -eq 0 ]; then
  echo "  ✓ no secret literals detected"
  exit 0
else
  echo "✗ no-live-secrets FAILED (install gitleaks for stronger scanning)" >&2
  exit 1
fi
