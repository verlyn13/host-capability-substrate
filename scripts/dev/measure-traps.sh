#!/usr/bin/env bash
# measure-traps.sh — Phase 0b: scan session artifacts for known trap patterns.
#
# Each hit counts as an instance of a regression trap that the substrate should
# prevent in Phase 3+. Patterns are defined from the 15 seed traps at
# packages/evals/regression/seed.md.
#
# Redaction is strict — we log trap_name + a short hash of the matched line,
# not the line content itself.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
assert_read_only_host_paths
script_banner "measure-traps"

# Sources to scan (read-only grep).
sources=(
  "$HOME/.claude/history.jsonl"
  "$HOME/.claude/sessions"
  "$HOME/.codex/history.jsonl"
)

# Trap regex patterns — each name should match a seed trap.
declare -A trap_patterns=(
  [launchctl-deprecated-verbs]='launchctl[[:space:]]+(load|unload)[[:space:]]'
  [brew-vs-mise-node-resolution]='brew[[:space:]]+install[[:space:]]+node(@[0-9]+)?[^a-zA-Z0-9-]'
  [docker-missing-orbstack-present]='(docker-machine|docker[[:space:]]+desktop)'
  [gnu-bsd-sed-flag-divergence]='sed[[:space:]]+-i[[:space:]]+'
  [rm-rf-no-escalation]='rm[[:space:]]+-rf[[:space:]]+[^/~$][^[:space:]]'
  [xcode-select-wrong-path]='/Library/Developer/CommandLineTools'
  [spctl-csrutil-mention]='(spctl[[:space:]]+--master-disable|csrutil[[:space:]]+(disable|enable))'
  [defaults-write-general]='defaults[[:space:]]+write[[:space:]]+'
)

# Safe counter helper — grep exit 1 on no match must not trip pipefail/errexit.
_count_in_file() {
  local pat="$1" file="$2"
  grep -cE "$pat" "$file" 2>/dev/null || printf '0'
}
_count_in_dir() {
  local pat="$1" dir="$2"
  # Disable pipefail locally so grep's exit-1-on-no-match doesn't kill the pipe.
  set +o pipefail
  local c
  c=$(grep -rE "$pat" "$dir" 2>/dev/null | wc -l | tr -d ' ')
  set -o pipefail
  printf '%s' "${c:-0}"
}

total_hits=0
for trap_name in "${!trap_patterns[@]}"; do
  pattern="${trap_patterns[$trap_name]}"
  hits=0
  for src in "${sources[@]}"; do
    if [ -f "$src" ]; then
      count=$(_count_in_file "$pattern" "$src")
    elif [ -d "$src" ]; then
      count=$(_count_in_dir "$pattern" "$src")
    else
      count=0
    fi
    # Defensive: strip anything non-digit
    count="${count//[^0-9]/}"
    : "${count:=0}"
    hits=$((hits + count))
  done
  if [ "$hits" -gt 0 ]; then
    jsonl_append "traps.jsonl" \
      "{\"ts\":\"$(iso_now)\",\"trap_name\":\"$trap_name\",\"hits_week\":$hits,\"severity\":\"advisory\"}"
    echo "  ⚠️  $trap_name: $hits hits"
    total_hits=$((total_hits + hits))
  fi
done

jsonl_append "traps.jsonl" \
  "{\"ts\":\"$(iso_now)\",\"trap_name\":\"__summary__\",\"total_hits\":$total_hits,\"traps_scanned\":${#trap_patterns[@]}}"

if [ "$total_hits" -eq 0 ]; then
  echo "  ✓ no trap matches in scanned sources"
fi
echo "  → $(log_dir)/traps.jsonl"
