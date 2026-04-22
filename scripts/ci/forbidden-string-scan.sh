#!/usr/bin/env bash
# forbidden-string-scan.sh — scan for forbidden patterns and bad values.
#
# Detects:
#   - Universal shell execution tool registrations
#   - Resolved op:// values (secrets should be references, not resolved)
#   - Deprecated macOS verbs in renderer code
#   - Resurrection of banned capability names

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "→ forbidden-string-scan"

fail=0

# Scan targets — everything committed except docs/adr (which may quote forbidden
# patterns as examples) and .logs (gitignored anyway).
scan_dirs="packages scripts .claude .agents .codex .cursor .vscode"

# 1. Universal shell names — banned capability identifiers.
# Allowed exception: "unsafe_shell_proposal" (the stigmatized ADR-recorded name).
for pattern in '"bash\.run"' '"shell\.exec"' '"exec\.unsafe_shell"\s*[,)]'; do
  if grep -rE "$pattern" $scan_dirs 2>/dev/null | grep -v "unsafe_shell_proposal"; then
    echo "  ✗ forbidden capability name: pattern $pattern" >&2
    fail=1
  fi
done

# 2. Resolved op:// values — configs should use op:// references, never resolved tokens
# Heuristic: look for patterns like "sk-...", "ghp_...", raw-looking API keys that
# aren't inside op:// URIs.
# (Phase 0a: conservative scan. Extend with gitleaks in no-live-secrets.sh.)
if grep -rE '\b(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|xoxb-[0-9]+-[A-Za-z0-9]+|AKIA[0-9A-Z]{16})\b' $scan_dirs 2>/dev/null; then
  echo "  ✗ likely resolved secret value found" >&2
  fail=1
fi

# 3. Deprecated launchctl verbs in renderer code (not docs, not eval corpus, not comments)
# Allowed in:
#   - docs/** (documentation may describe forbidden patterns)
#   - packages/evals/regression/** (eval corpus documents what agents must NOT do)
#   - install-launchd.sh and hcs-hook (explicitly block or warn against these)
#   - plist template (comment-only mentions as "NEVER" warnings)
if grep -rnE '\blaunchctl\s+(load|unload)\b' packages/ scripts/ 2>/dev/null \
    | grep -v -E '(install-launchd|hcs-hook|packages/evals/regression/|/launchd/.*\.tmpl:\s*[^<]*NEVER)'; then
  echo "  ✗ deprecated launchctl verb in renderer/script code" >&2
  fail=1
fi

# 4. Audit-write endpoint exposure as agent-callable
if grep -rE '"system\.audit\.log\.v[0-9]+"' packages/ scripts/ 2>/dev/null; then
  echo "  ✗ system.audit.log.v* exposed as agent-callable (charter invariant 4)" >&2
  fail=1
fi

if [ $fail -eq 0 ]; then
  echo "  ✓ no forbidden strings detected"
  exit 0
else
  echo "✗ forbidden-string-scan FAILED" >&2
  exit 1
fi
