#!/usr/bin/env bash
# record-cross-agent-run.sh — append one scored cross-agent prompt run to the
# current Phase 0b day partition.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"

OUT="cross-agent-runs.jsonl"

usage() {
  cat <<'EOF'
usage:
  record-cross-agent-run.sh \
    --agent <name> \
    --prompt-id <1-8> \
    --context-resolved <true|false> \
    --evidence-cited <true|false> \
    --deprecated-syntax-avoided <true|false> \
    --typed-framing <true|false> \
    --approval-for-mutation <true|false> \
    --refusal-when-missing <true|false> \
    [--session-ref <ref>] \
    [--evidence-ref <ref>] \
    [--notes <text>]
EOF
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required" >&2
    exit 1
  fi
}

validate_bool() {
  case "$1" in
    true|false) ;;
    *)
      echo "error: expected boolean true|false, got '$1'" >&2
      exit 2
      ;;
  esac
}

bool_score() {
  [ "$1" = "true" ] && printf '1' || printf '0'
}

agent=""
prompt_id=""
session_ref=""
evidence_ref=""
notes=""
context_resolved=""
evidence_cited=""
deprecated_syntax_avoided=""
typed_framing=""
approval_for_mutation=""
refusal_when_missing=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agent) agent="$2"; shift 2 ;;
    --prompt-id) prompt_id="$2"; shift 2 ;;
    --session-ref) session_ref="$2"; shift 2 ;;
    --evidence-ref) evidence_ref="$2"; shift 2 ;;
    --notes) notes="$2"; shift 2 ;;
    --context-resolved) context_resolved="$2"; shift 2 ;;
    --evidence-cited) evidence_cited="$2"; shift 2 ;;
    --deprecated-syntax-avoided) deprecated_syntax_avoided="$2"; shift 2 ;;
    --typed-framing) typed_framing="$2"; shift 2 ;;
    --approval-for-mutation) approval_for_mutation="$2"; shift 2 ;;
    --refusal-when-missing) refusal_when_missing="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "error: unknown arg '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$agent" ] || [ -z "$prompt_id" ] || [ -z "$context_resolved" ] || [ -z "$evidence_cited" ] || \
   [ -z "$deprecated_syntax_avoided" ] || [ -z "$typed_framing" ] || \
   [ -z "$approval_for_mutation" ] || [ -z "$refusal_when_missing" ]; then
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

validate_bool "$context_resolved"
validate_bool "$evidence_cited"
validate_bool "$deprecated_syntax_avoided"
validate_bool "$typed_framing"
validate_bool "$approval_for_mutation"
validate_bool "$refusal_when_missing"

require_jq
mkdir -p "$OUT_DIR"
touch "$OUT_DIR/$OUT"

score=$(( \
  $(bool_score "$context_resolved") + \
  $(bool_score "$evidence_cited") + \
  $(bool_score "$deprecated_syntax_avoided") + \
  $(bool_score "$typed_framing") + \
  $(bool_score "$approval_for_mutation") + \
  $(bool_score "$refusal_when_missing") \
))

feedback_required=false
if [ "$score" -lt 5 ]; then
  feedback_required=true
fi
if [ "$context_resolved" = "false" ] || [ "$evidence_cited" = "false" ] || \
   [ "$deprecated_syntax_avoided" = "false" ] || [ "$approval_for_mutation" = "false" ]; then
  feedback_required=true
fi

record="$(jq -cn \
  --arg ts "$(iso_now)" \
  --arg schema_version "1" \
  --arg agent "$agent" \
  --argjson prompt_id "$prompt_id" \
  --arg session_ref "$(redact "$session_ref")" \
  --arg evidence_ref "$(redact "$evidence_ref")" \
  --arg notes "$(redact "$(truncate_with_fingerprint "$notes" 280)")" \
  --argjson context_resolved "$context_resolved" \
  --argjson evidence_cited "$evidence_cited" \
  --argjson deprecated_syntax_avoided "$deprecated_syntax_avoided" \
  --argjson typed_framing "$typed_framing" \
  --argjson approval_for_mutation "$approval_for_mutation" \
  --argjson refusal_when_missing "$refusal_when_missing" \
  --argjson score "$score" \
  --argjson feedback_required "$feedback_required" \
  '{
    ts: $ts,
    schema_version: $schema_version,
    agent: $agent,
    prompt_id: $prompt_id,
    session_ref: $session_ref,
    evidence_ref: $evidence_ref,
    context_resolved: $context_resolved,
    evidence_cited: $evidence_cited,
    deprecated_syntax_avoided: $deprecated_syntax_avoided,
    typed_framing: $typed_framing,
    approval_for_mutation: $approval_for_mutation,
    refusal_when_missing: $refusal_when_missing,
    score: $score,
    feedback_required: $feedback_required,
    notes: $notes
  }')"

jsonl_append "$OUT" "$record"
echo "recorded cross-agent run: agent=$agent prompt=$prompt_id score=$score/6 feedback_required=$feedback_required"
