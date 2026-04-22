#!/usr/bin/env bash
# measure-confusion.sh — Phase 0b: aggregate classify.jsonl into confusion-
# matrix inputs. Emits:
#   confusion-matrix.json   per-source class counts + top-N unknowns + top-N
#                           forbidden + the source×class cross-tab.
#
# Current Phase 0b does not yet have ground-truth labels, so the "matrix" is
# actually a `source × classified_class` cross-tab plus unknown/forbidden
# highlights. When a labelled review set lands, this script will extend to a
# true confusion matrix (expected vs actual).
#
# Snapshot semantics: overwrites confusion-matrix.json at start of run.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-confusion"

IN="classify.jsonl"
OUT="confusion-matrix.json"

if [ ! -s "$OUT_DIR/$IN" ]; then
  echo "  ⏸  no classify.jsonl in $OUT_DIR — run measure-classify first"
  file_replace "$OUT" '{"status":"no-input"}'
  exit 0
fi

python3 - "$OUT_DIR/$IN" "$OUT_DIR/$OUT" <<'PYEOF'
import json
import sys
from collections import Counter, defaultdict

in_path, out_path = sys.argv[1], sys.argv[2]

class_counts = Counter()
source_class = defaultdict(Counter)
unknown_first_tokens = Counter()
forbidden_samples = []
unknown_samples = []
first_token_class = defaultdict(Counter)

total = 0
with open(in_path) as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            class_counts['parser-error'] += 1
            continue
        cls = d.get('classified_class', 'parser-error')
        src = d.get('source', 'unknown')
        first = d.get('classified_first_token') or ''
        total += 1
        class_counts[cls] += 1
        source_class[src][cls] += 1
        first_token_class[first][cls] += 1
        if cls == 'unknown':
            unknown_first_tokens[first] += 1
            if len(unknown_samples) < 20:
                unknown_samples.append({
                    'source': src,
                    'command': (d.get('command') or '')[:120],
                    'first_token': first,
                })
        elif cls == 'forbidden':
            if len(forbidden_samples) < 20:
                forbidden_samples.append({
                    'source': src,
                    'command': (d.get('command') or '')[:120],
                    'reason': d.get('classified_reason'),
                })

overblock_rate = 0.0
safe_count = class_counts.get('read-safe', 0)
hard_block_count = class_counts.get('forbidden', 0) + class_counts.get('write-destructive', 0)
# Overblock indicator = fraction of FIRST-TOKEN-safe commands (echo/cat/rg/etc.)
# that nonetheless got classified as hard-block. Phase 0b target: <2%.
stringy_first_tokens = {
    'echo', 'printf', 'cat', 'less', 'more', 'head', 'tail',
    'rg', 'grep', 'ag', 'jq', 'yq', 'awk',
}
stringy_total = sum(sum(v.values()) for k, v in first_token_class.items() if k in stringy_first_tokens)
stringy_blocked = sum(
    v.get('forbidden', 0) + v.get('write-destructive', 0)
    for k, v in first_token_class.items() if k in stringy_first_tokens
)
if stringy_total:
    overblock_rate = round(100 * stringy_blocked / stringy_total, 3)

classify_error_rate = 0.0
if total:
    classify_error_rate = round(100 * class_counts.get('parser-error', 0) / total, 3)

report = {
    'total': total,
    'class_counts': dict(class_counts.most_common()),
    'source_class_cross_tab': {s: dict(c.most_common()) for s, c in source_class.items()},
    'top_unknown_first_tokens': dict(unknown_first_tokens.most_common(20)),
    'forbidden_samples': forbidden_samples,
    'unknown_samples': unknown_samples,
    'gates': {
        'parse_error_rate_pct': classify_error_rate,
        'overblock_rate_pct_on_stringy_first_tokens': overblock_rate,
        'parse_error_rate_target_pct_max': 10.0,
        'overblock_rate_target_pct_max': 2.0,
        'parse_error_ok': classify_error_rate <= 10.0,
        'overblock_ok': overblock_rate <= 2.0,
    },
    'phase_0b_notes': [
        "This is NOT yet a confusion matrix — Phase 0b has no labelled ground truth.",
        "source × classified_class is the honest shape until a review set exists.",
        "top_unknown_first_tokens feeds ontology expansion + trap corpus growth.",
    ],
}

with open(out_path, 'w') as fh:
    json.dump(report, fh, indent=2)

print(f"  ✓ {total} classified records")
print(f"  ✓ classes: {dict(class_counts.most_common())}")
print(f"  ✓ overblock rate on stringy first tokens: {overblock_rate}% (target ≤2%)")
print(f"  ✓ parse-error rate: {classify_error_rate}% (target ≤10%)")
PYEOF

echo "  → $(log_dir)/$OUT"
