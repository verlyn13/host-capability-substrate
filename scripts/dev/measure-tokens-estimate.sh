#!/usr/bin/env bash
# measure-tokens-estimate.sh — Phase 0b: back-of-envelope tokens/day estimate.
#
# Uses:
#   - character counts from activity-*.jsonl (prompt-volume, rollout-volume, etc.)
#   - rough char/4 heuristic (no live tokenizer dependency)
#
# Output: $OUT_DIR/tokens-estimate.json
#
# Snapshot semantics: overwrites tokens-estimate.json fresh each run.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-tokens-estimate"

out_path="$OUT_DIR/tokens-estimate.json"

python3 - "$OUT_DIR" "$out_path" <<'PYEOF'
import json, os, sys
from datetime import datetime, timezone

out_dir = sys.argv[1]
out_path = sys.argv[2]
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Char-based token estimate heuristic: 1 token ≈ 4 chars English (OpenAI/Anthropic)
CHARS_PER_TOKEN = 4.0

per_source = {}
totals = {"chars": 0, "estimated_tokens": 0}
top_patterns = []

activity_files = []
for fn in sorted(os.listdir(out_dir)):
    if fn.startswith("activity-") and fn.endswith(".jsonl"):
        activity_files.append(os.path.join(out_dir, fn))

for path in activity_files:
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                src = d.get('source', '?')
                cat = d.get('category', '')
                chars = 0
                if cat == 'prompt-volume':
                    chars = int(d.get('total_chars', 0))
                elif cat == 'transcript-volume':
                    chars = int(d.get('total_tool_uses', 0)) * 2048
                elif cat == 'rollout-volume':
                    chars = int(d.get('total_function_calls', 0)) * 2048
                elif cat == 'log-volume-shape':
                    chars = int(d.get('total_bytes', 0))
                elif cat == 'history-size':
                    chars = int(d.get('bytes', 0))
                else:
                    continue
                per_source.setdefault(src, {"chars": 0, "estimated_tokens": 0, "category": cat})
                per_source[src]["chars"] += chars
                totals["chars"] += chars
    except (OSError, PermissionError):
        continue

for src, info in per_source.items():
    info["estimated_tokens"] = int(info["chars"] / CHARS_PER_TOKEN)
    top_patterns.append({"source": src, "chars": info["chars"], "tokens_approx": info["estimated_tokens"]})
top_patterns.sort(key=lambda x: -x["chars"])

totals["estimated_tokens"] = int(totals["chars"] / CHARS_PER_TOKEN)

result = {
    "ts": ts,
    "method": "character-count / 4 (back-of-envelope; not live tokenizer)",
    "chars_per_token_heuristic": CHARS_PER_TOKEN,
    "partition": os.path.basename(out_dir),
    "top_sources": top_patterns,
    "per_source": per_source,
    "totals": totals,
    "notes": "Figures include historical session content visible in partition inputs, not only newly-produced content today. For true daily delta, diff against previous-day partition totals.",
}

with open(out_path, 'w') as f:
    json.dump(result, f, indent=2)

print(f"  ✓ tokens-estimate: total_chars={totals['chars']:,} estimated_tokens≈{totals['estimated_tokens']:,}")
PYEOF

echo "  → $out_path"
