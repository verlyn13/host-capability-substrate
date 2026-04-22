#!/usr/bin/env bash
# measure-common.sh — shared helpers for Phase 0b measurement scripts.
#
# Sourced (not executed). Provides:
#   - OUT_DIR env: `.logs/phase-0/<today>/`
#   - log_dir(): ensures and prints today's output dir
#   - jsonl_append(file, json): append a JSONL line to a file under OUT_DIR
#   - redact(text): apply privacy redactions before logging
#   - assert_read_only_host_paths(): fail-loud safety guard — no script may mutate tool-owned paths
#
# CHARTER: invariant 10 — no runtime state / session content enters the repo.
#          The repo contains only measurement code. Observations live in .logs/
#          which is gitignored.

set -euo pipefail

# Resolve repo root (parent of scripts/dev/ — three levels up)
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HCS_ROOT="$(cd "$_script_dir/../.." && pwd)"
export HCS_ROOT

# Per-day partition; idempotent (re-runs append to the same day file)
_today="$(date -u +%Y-%m-%d)"
OUT_DIR="$HCS_ROOT/.logs/phase-0/$_today"
export OUT_DIR
mkdir -p "$OUT_DIR"

log_dir() {
  printf '%s' "$OUT_DIR"
}

# Append a JSONL line.
# Usage: jsonl_append "activity.jsonl" '{"ts":"...", ...}'
jsonl_append() {
  local file="$1"
  local json="$2"
  printf '%s\n' "$json" >> "$OUT_DIR/$file"
}

# Redact likely-sensitive patterns BEFORE writing to .logs/.
# Conservative (may over-redact).
# Usage: redacted="$(redact "$input")"
redact() {
  local s="$1"
  # API key shapes
  s="$(printf '%s' "$s" | sed -E 's/sk-[A-Za-z0-9]{20,}/<REDACTED:key-sk>/g')"
  s="$(printf '%s' "$s" | sed -E 's/ghp_[A-Za-z0-9]{20,}/<REDACTED:key-ghp>/g')"
  s="$(printf '%s' "$s" | sed -E 's/github_pat_[A-Za-z0-9_]{20,}/<REDACTED:key-github-pat>/g')"
  s="$(printf '%s' "$s" | sed -E 's/xoxb-[0-9A-Za-z-]+/<REDACTED:key-slack>/g')"
  s="$(printf '%s' "$s" | sed -E 's/AKIA[0-9A-Z]{16}/<REDACTED:key-aws>/g')"
  # op:// URIs: mask everything after the vault path segment
  s="$(printf '%s' "$s" | sed -E 's|op://[^ \"]+|<REDACTED:op-uri>|g')"
  # Bearer tokens
  s="$(printf '%s' "$s" | sed -E 's/Bearer [A-Za-z0-9._-]+/<REDACTED:bearer>/g')"
  # Home-dir file paths outside the HCS/system-config tree.
  # Use `#` as the sed delimiter so `|` can be used for alternation in the pattern.
  s="$(printf '%s' "$s" | sed -E "s#$HOME/(Documents|Desktop|Downloads|Library/Mail)(/[^ \"']*)?#<REDACTED:user-path>#g")"
  # Email addresses
  s="$(printf '%s' "$s" | sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<REDACTED:email>/g')"
  # JWT-ish patterns
  s="$(printf '%s' "$s" | sed -E 's/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+/<REDACTED:jwt>/g')"
  printf '%s' "$s"
}

# Truncate long free-form text; keep a short fingerprint at the tail for dedup.
truncate_with_fingerprint() {
  local text="$1"
  local maxlen="${2:-200}"
  if [ "${#text}" -le "$maxlen" ]; then
    printf '%s' "$text"
    return
  fi
  local prefix="${text:0:$maxlen}"
  local fp
  fp="$(printf '%s' "$text" | shasum -a 256 | awk '{print substr($1,1,8)}')"
  printf '%s…[%s]' "$prefix" "$fp"
}

# Safety guard: assert this process does not modify any tool-owned path.
# Call at the start of every script.
assert_read_only_host_paths() {
  # Currently advisory — no enforcement beyond code review.
  # Future: could inspect ktrace/dtrace under privilege, but outside Phase 0b scope.
  :
}

# ISO-8601 UTC
iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# Print a summary header for a script run
script_banner() {
  local name="$1"
  printf '=== %s  %s ===\n' "$name" "$(iso_now)"
  printf '    output: %s\n' "$OUT_DIR"
}
