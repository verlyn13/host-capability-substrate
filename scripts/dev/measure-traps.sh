#!/usr/bin/env bash
# measure-traps.sh — Phase 0b: per-hit trap detection with provenance.
#
# REVISED after P2 critique: per-hit records now carry `source`, `file`, `line`,
# `evidence_redacted`, `severity`. Aggregate __summary__ record retained.
#
# Snapshot semantics: overwrites traps.jsonl fresh each run.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-traps"

OUT="traps.jsonl"
snapshot_begin "$OUT"

# Sources to scan (read-only grep). Scoped to last 7 days to keep the scan
# tractable — the full `~/.claude/projects/` tree has ~5k transcripts accreted
# over many months, and scanning all of them × 12 patterns takes >5 min.
#
# For file-level sources: listed directly.
# For directory sources: we'll resolve to a file list via `find -mtime -7` below.
file_sources=(
  "$HOME/.claude/history.jsonl"
  "$HOME/.codex/history.jsonl"
)
# Directory sources with mtime bound
dir_source_specs=(
  "$HOME/.claude/projects|-mtime -7"
  "$HOME/.codex/sessions|-mtime -7"
)

# Resolve file_list from file_sources + dir_source_specs.
file_list_tmp="$(mktemp)"
for fs in "${file_sources[@]}"; do
  [ -f "$fs" ] && printf '%s\n' "$fs"
done > "$file_list_tmp"
for spec in "${dir_source_specs[@]}"; do
  dir="${spec%|*}"
  mtime_expr="${spec#*|}"
  [ -d "$dir" ] || continue
  # shellcheck disable=SC2086
  find "$dir" -type f \( -name '*.jsonl' -o -name '*.json' \) $mtime_expr 2>/dev/null >> "$file_list_tmp"
done
file_count=$(wc -l < "$file_list_tmp" | tr -d ' ')
echo "  scoping: $file_count file(s) within 7d window"

# Trap patterns (Phase 0a seed + 4 new from self-review C-6).
# key => pattern
declare -A trap_patterns=(
  [launchctl-deprecated-verbs]='launchctl[[:space:]]+(load|unload)[[:space:]]'
  [brew-vs-mise-node-resolution]='brew[[:space:]]+(install|reinstall)[[:space:]]+(--[A-Za-z-]+[[:space:]]+)*node(@[0-9]+)?([^a-zA-Z0-9_-]|$)'
  [docker-missing-orbstack-present]='(docker-machine|docker[[:space:]]+desktop)'
  [gnu-bsd-sed-flag-divergence]='sed[[:space:]]+-i[[:space:]]+'
  [rm-rf-no-escalation]='rm[[:space:]]+-rf[[:space:]]+[^/~$][^[:space:]]'
  [xcode-select-wrong-path]='/Library/Developer/CommandLineTools'
  [spctl-csrutil-mention]='(spctl[[:space:]]+--master-disable|csrutil[[:space:]]+(disable|enable))'
  [defaults-write-general]='defaults[[:space:]]+write[[:space:]]+'
  [launchctl-load-unload-policy]='launchctl[[:space:]]+(load|unload)[[:space:]]'
  [brew-cask-escalation-missed]='brew[[:space:]]+install[[:space:]]+--cask[[:space:]]'
  [shell-mode-confusion-login]='bash[[:space:]]+-lc[[:space:]]'
  [venv-vs-system-python]='/usr/bin/python3?[[:space:]]+(-m[[:space:]]+pip|pip|install)'
)

total_hits=0

# Per-hit emitter
# Usage: emit_hit trap_name file line evidence
emit_hit() {
  local trap="$1" file="$2" line="$3" evidence="$4"
  local file_safe evidence_red evidence_esc
  file_safe="$(redact "$file" | sed 's/"/\\"/g')"
  # Truncate + redact evidence; fingerprint suffix for dedup.
  evidence_red="$(redact "$(truncate_with_fingerprint "$evidence" 160)")"
  # Escape quotes + backslashes for JSON-safe embedding
  evidence_esc="$(printf '%s' "$evidence_red" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r')"
  jsonl_append "$OUT" \
    "{\"ts\":\"$(iso_now)\",\"trap_name\":\"$trap\",\"source\":\"$(dirname "$file" | sed 's|.*/||')\",\"file\":\"$file_safe\",\"line\":$line,\"evidence_redacted\":\"$evidence_esc\",\"severity\":\"advisory\"}"
}

# For each trap, grep the file list in one pass (xargs), cap per-trap output.
CAP_PER_TRAP=50

for trap_name in "${!trap_patterns[@]}"; do
  pattern="${trap_patterns[$trap_name]}"
  trap_hits=0

  if [ "$file_count" -eq 0 ]; then
    continue
  fi

  # grep across all files in file_list in one pass; cap total output lines.
  # `-n` line numbers, `-H` always print filename.
  matches=$(xargs -0 grep -nHE "$pattern" 2>/dev/null < <(tr '\n' '\0' < "$file_list_tmp") | head -n "$CAP_PER_TRAP" || true)
  if [ -z "$matches" ]; then
    continue
  fi

  while IFS= read -r match; do
    [ "$trap_hits" -ge "$CAP_PER_TRAP" ] && break
    file_path="${match%%:*}"
    rest="${match#*:}"
    line_num="${rest%%:*}"
    content="${rest#*:}"
    if [[ "$line_num" =~ ^[0-9]+$ ]]; then
      emit_hit "$trap_name" "$file_path" "$line_num" "$content"
      trap_hits=$((trap_hits + 1))
      total_hits=$((total_hits + 1))
    fi
  done <<< "$matches"

  if [ "$trap_hits" -gt 0 ]; then
    echo "  ⚠️  $trap_name: $trap_hits hit(s)"
  fi
done

rm -f "$file_list_tmp"

# Aggregate summary record.
jsonl_append "$OUT" \
  "{\"ts\":\"$(iso_now)\",\"trap_name\":\"__summary__\",\"total_hits\":$total_hits,\"traps_scanned\":${#trap_patterns[@]},\"per_trap_cap\":$CAP_PER_TRAP}"

if [ "$total_hits" -eq 0 ]; then
  echo "  ✓ no trap matches in scanned sources"
fi
echo "  → $(log_dir)/$OUT"
