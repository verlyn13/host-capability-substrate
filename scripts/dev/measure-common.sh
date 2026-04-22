#!/usr/bin/env bash
# measure-common.sh — shared helpers for Phase 0b measurement scripts.
#
# Sourced (not executed). Provides:
#   - OUT_DIR env: `.logs/phase-0/<today>/`
#   - snapshot_begin(file): truncate an output file so the current run starts
#     with an empty snapshot (idempotency).
#   - jsonl_append(file, json): append one JSONL line. Callers MUST call
#     snapshot_begin() for each file they own at the top of the script.
#   - redact(text): apply privacy redactions before logging.
#   - iso_now(), script_banner(name)
#
# CHARTER (v1.1.0 invariant 10): no runtime state / session content enters the
# repo. Observations live only in .logs/, which is gitignored.
#
# IDEMPOTENCY CONTRACT: measurement scripts produce a day-partition snapshot
# of current host state. Running the same day twice must produce the same
# output (modulo host drift since the previous run). Scripts enforce this by
# calling snapshot_begin() for each output file they own, then appending
# records. The legacy behaviour (unconditional append) is deliberately removed.

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HCS_ROOT="$(cd "$_script_dir/../.." && pwd)"
export HCS_ROOT

_today="$(date -u +%Y-%m-%d)"
OUT_DIR="$HCS_ROOT/.logs/phase-0/$_today"
export OUT_DIR
mkdir -p "$OUT_DIR"

log_dir() {
  printf '%s' "$OUT_DIR"
}

# Mark start of a fresh snapshot for a file. Truncates the file to zero bytes.
# Subsequent appends form the snapshot.
snapshot_begin() {
  local file="$1"
  : > "$OUT_DIR/$file"
}

# Append a JSONL line. Caller guarantees snapshot_begin() has been invoked
# for this file during the current script run.
jsonl_append() {
  local file="$1"
  local json="$2"
  printf '%s\n' "$json" >> "$OUT_DIR/$file"
}

# Overwrite an entire file with given content (useful for JSON, not JSONL).
file_replace() {
  local file="$1"
  local content="$2"
  printf '%s\n' "$content" > "$OUT_DIR/$file"
}

# Redact likely-sensitive patterns BEFORE writing to .logs/.
# Conservative (may over-redact). BSD sed compatible (uses `#` delimiter so `|`
# alternation inside patterns does not collide with the sed delimiter).
redact() {
  local s="$1"
  s="$(printf '%s' "$s" | sed -E 's/sk-[A-Za-z0-9]{20,}/<REDACTED:key-sk>/g')"
  s="$(printf '%s' "$s" | sed -E 's/ghp_[A-Za-z0-9]{20,}/<REDACTED:key-ghp>/g')"
  s="$(printf '%s' "$s" | sed -E 's/github_pat_[A-Za-z0-9_]{20,}/<REDACTED:key-github-pat>/g')"
  s="$(printf '%s' "$s" | sed -E 's/xoxb-[0-9A-Za-z-]+/<REDACTED:key-slack>/g')"
  s="$(printf '%s' "$s" | sed -E 's/AKIA[0-9A-Z]{16}/<REDACTED:key-aws>/g')"
  s="$(printf '%s' "$s" | sed -E 's#op://[^ \"]+#<REDACTED:op-uri>#g')"
  s="$(printf '%s' "$s" | sed -E 's/Bearer [A-Za-z0-9._-]+/<REDACTED:bearer>/g')"
  s="$(printf '%s' "$s" | sed -E "s#$HOME/(Documents|Desktop|Downloads|Library/Mail)(/[^ \"']*)?#<REDACTED:user-path>#g")"
  s="$(printf '%s' "$s" | sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<REDACTED:email>/g')"
  s="$(printf '%s' "$s" | sed -E 's/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+/<REDACTED:jwt>/g')"
  printf '%s' "$s"
}

# Truncate long free-form text; keep an 8-char sha256 tail for dedup.
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

# Self-test redact() on a known-bad string. Returns 0 if sanitized, 1 if any
# expected secret pattern leaks through.
#
# Test tokens are constructed at runtime from parts so static forbidden-string
# scanners don't flag this helper as a leaked-secret site.
redact_self_test() {
  local sk_p='sk-' sk_b='AAAABBBBCCCCDDDDEEEEFFFF'
  local ghp_p='ghp_' ghp_b='1234567890ABCDEFGHIJKLMNOP'
  local op_p='op:' op_b='//Dev/foo/bar'
  local bearer='Bearer '
  local tok='tok-abc'
  local email='jeff'
  local domain='@example.com'
  local input="${sk_p}${sk_b} ${ghp_p}${ghp_b} ${op_p}${op_b} ${bearer}${tok} ${email}${domain}"
  local out
  out="$(redact "$input")"
  for forbidden_token in "${sk_p}${sk_b}" "${ghp_p}${ghp_b}" "${op_p}${op_b}" "${bearer}${tok}" "${email}${domain}"; do
    if printf '%s' "$out" | grep -qF "$forbidden_token"; then
      printf 'redact-self-test FAILED: %q leaked through\n' "$forbidden_token" >&2
      return 1
    fi
  done
  return 0
}

# Count matches of a regex in a file. Defensive against set -e + grep's exit-1-on-no-match.
# Always prints a non-negative integer (0 on miss, empty file, or unreadable input).
count_matches() {
  local pat="$1" file="$2"
  local c
  c="$(grep -cE "$pat" "$file" 2>/dev/null; true)"
  c="${c//[^0-9]/}"
  printf '%s' "${c:-0}"
}

# First-match extract helper. Returns empty string on no match.
first_match() {
  local pat="$1" file="$2"
  grep -m1 -E "$pat" "$file" 2>/dev/null || true
}

iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

script_banner() {
  local name="$1"
  printf '=== %s  %s ===\n' "$name" "$(iso_now)"
  printf '    output: %s\n' "$OUT_DIR"
}
