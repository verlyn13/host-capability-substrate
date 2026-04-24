#!/usr/bin/env bash
# record-cross-agent-feedback.sh — append one structured feedback item for the
# current Phase 0b day partition.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"

OUT="cross-agent-feedback.jsonl"

usage() {
  cat <<'EOF'
usage:
  record-cross-agent-feedback.sh \
    --agent <name> \
    --prompt-id <1-8> \
    --severity <critical|major|minor> \
    --dimension <name> \
    --summary <text> \
    --required-change <text> \
    [--owner <name>] \
    [--status <open|rerun_requested|resolved|backlog>] \
    [--lane <rerun_today|closeout|phase_1>] \
    [--session-ref <ref>] \
    [--evidence-ref <ref>]
EOF
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required" >&2
    exit 1
  fi
}

agent=""
prompt_id=""
severity=""
dimension=""
summary=""
required_change=""
owner="human"
status="open"
lane="closeout"
session_ref=""
evidence_ref=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agent) agent="$2"; shift 2 ;;
    --prompt-id) prompt_id="$2"; shift 2 ;;
    --severity) severity="$2"; shift 2 ;;
    --dimension) dimension="$2"; shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    --required-change) required_change="$2"; shift 2 ;;
    --owner) owner="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --lane) lane="$2"; shift 2 ;;
    --session-ref) session_ref="$2"; shift 2 ;;
    --evidence-ref) evidence_ref="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "error: unknown arg '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$agent" ] || [ -z "$prompt_id" ] || [ -z "$severity" ] || [ -z "$dimension" ] || \
   [ -z "$summary" ] || [ -z "$required_change" ]; then
  usage >&2
  exit 2
fi

case "$prompt_id" in
  1|2|3|4|5|6|7|8) ;;
  *)
    echo "error: prompt id must be 1..8" >&2
    exit 2
    ;;
esac

case "$severity" in
  critical|major|minor) ;;
  *)
    echo "error: severity must be critical|major|minor" >&2
    exit 2
    ;;
esac

case "$status" in
  open|rerun_requested|resolved|backlog) ;;
  *)
    echo "error: status must be open|rerun_requested|resolved|backlog" >&2
    exit 2
    ;;
esac

case "$lane" in
  rerun_today|closeout|phase_1) ;;
  *)
    echo "error: lane must be rerun_today|closeout|phase_1" >&2
    exit 2
    ;;
esac

require_jq
mkdir -p "$OUT_DIR"
touch "$OUT_DIR/$OUT"

feedback_id="$(date -u +%Y%m%dT%H%M%SZ)-${agent}-p${prompt_id}-${severity}"

record="$(jq -cn \
  --arg ts "$(iso_now)" \
  --arg schema_version "1" \
  --arg feedback_id "$feedback_id" \
  --arg agent "$agent" \
  --argjson prompt_id "$prompt_id" \
  --arg severity "$severity" \
  --arg dimension "$dimension" \
  --arg summary "$(redact "$(truncate_with_fingerprint "$summary" 240)")" \
  --arg required_change "$(redact "$(truncate_with_fingerprint "$required_change" 240)")" \
  --arg owner "$owner" \
  --arg status "$status" \
  --arg lane "$lane" \
  --arg session_ref "$(redact "$session_ref")" \
  --arg evidence_ref "$(redact "$evidence_ref")" \
  '{
    ts: $ts,
    schema_version: $schema_version,
    feedback_id: $feedback_id,
    agent: $agent,
    prompt_id: $prompt_id,
    severity: $severity,
    dimension: $dimension,
    summary: $summary,
    required_change: $required_change,
    owner: $owner,
    status: $status,
    lane: $lane,
    session_ref: $session_ref,
    evidence_ref: $evidence_ref
  }')"

jsonl_append "$OUT" "$record"
echo "recorded cross-agent feedback: id=$feedback_id severity=$severity agent=$agent prompt=$prompt_id"
