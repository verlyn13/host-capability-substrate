#!/usr/bin/env bash
# measure-guidance-load.sh — Phase 0b: textual-reference extractor over raw
# cross-agent transcripts. Cross-joins with cross-agent-runs.jsonl to
# classify each run as loaded / loaded_behavior_divergent / unread.
#
# Reads:
#   .logs/phase-0/<partition>/raw/cross-agent/**/*.jsonl
#   .logs/phase-0/<partition>/cross-agent-runs.jsonl
# Writes:
#   .logs/phase-0/<partition>/cross-agent-guidance-load.jsonl (per partition)
#
# Purpose: resolves the acceptance-criterion ambiguity "Claude Code + Codex
# both load expected guidance → mixed" by splitting *didn't read* from
# *read and ignored*. The classification is heuristic — it checks whether
# the transcript textually references repo instruction files, invariant
# numbers, or doc paths under docs/host-capability-substrate/, then pairs
# that with whether the recorded run required feedback.
#
# Snapshot semantics: overwrites cross-agent-guidance-load.jsonl per partition.
# Safe to re-run any number of times.
#
# Charter alignment: analysis-only. Does not touch classifier, hook, recorder,
# or any existing collector used by `just measure`.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-guidance-load"

python3 - "$HCS_ROOT/.logs/phase-0" <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

base = sys.argv[1]
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Reference patterns — each captures a distinct repo-instruction surface.
REFERENCES = [
    ("agents_md",             r"\bAGENTS\.md\b"),
    ("claude_md",             r"\bCLAUDE\.md\b"),
    ("plan_md",               r"\bPLAN\.md\b"),
    ("implement_md",          r"\bIMPLEMENT\.md\b"),
    ("decisions_md",          r"\bDECISIONS\.md\b"),
    ("charter",               r"\bimplementation[- ]charter\b|\bcharter v[0-9]|\bcharter invariant\b"),
    ("soak_runbook",          r"\bphase-0b-soak-runbook\b|\bsoak[- ]runbook\b|\bsoak-runbook\.md\b"),
    ("cross_agent_prompts",   r"\bphase-0b-cross-agent-prompts\b|\bcross-agent-prompts\.md\b"),
    ("measurement_plan",      r"\bphase-0b-measurement-plan\b|\bmeasurement[- ]plan\.md\b"),
    ("adr_ref",               r"\badr/\d{4}-|\bADR \d{4}\b"),
    ("invariant_n",           r"\binvariant \d+\b|\b§\s?\d+\b"),
    ("docs_hcs_path",         r"\bdocs/host-capability-substrate/"),
    ("memory_channel",        r"\bper memory\b|\bfrom memory\b"),
]

AGENT_DIR_MAP = {
    "claude": "claude-code", "claude-code": "claude-code",
    "codex": "codex", "cursor": "cursor", "windsurf": "windsurf",
    "warp": "warp", "copilot": "copilot-cli",
}

VARIANT_PREFERENCE = ("rollout-copy", "repo-root-copy", "export-home", "export-tmp")
ACCEPTED_KINDS = {"prompt-session-rollout", "prompt-session-export"}
ACCEPTED_FORMATS = {"application/jsonl", "text/plain"}

def load_manifest_sessions(partition_root):
    manifest_path = os.path.join(partition_root, 'raw', 'source-manifest.jsonl')
    if not os.path.exists(manifest_path):
        return []
    by_key = {}
    with open(manifest_path, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get('kind') not in ACCEPTED_KINDS:
                continue
            if rec.get('format') not in ACCEPTED_FORMATS:
                continue
            agent = rec.get('agent')
            prompt_id = rec.get('prompt_id')
            if not agent or prompt_id is None:
                continue
            path = rec.get('canonical_path')
            if not path or not os.path.exists(path):
                continue
            by_key.setdefault((agent, int(prompt_id)), []).append(rec)
    selected = []
    for key, candidates in by_key.items():
        picked = None
        for variant in VARIANT_PREFERENCE:
            for c in candidates:
                if c.get('source_variant') == variant:
                    picked = c
                    break
            if picked is not None:
                break
        if picked is None:
            picked = candidates[0]
        selected.append({
            "agent": picked['agent'],
            "prompt_id": int(picked['prompt_id']),
            "path": picked['canonical_path'],
            "session_ref": os.path.basename(picked['canonical_path']),
        })
    return selected

def parse_path(path, partition_root):
    rel = os.path.relpath(path, partition_root)
    parts = rel.split(os.sep)
    agent = None
    prompt_id = None
    for p in parts:
        if p in AGENT_DIR_MAP:
            agent = AGENT_DIR_MAP[p]
        m = re.match(r'prompt-(\d+)', p)
        if m:
            prompt_id = int(m.group(1))
    return agent, prompt_id, os.path.basename(path)

def _walk_variant_of(path):
    if '/export-tmp/' in path:
        return 'export-tmp'
    if '/export-home/' in path:
        return 'export-home'
    fname = os.path.basename(path)
    if fname.startswith('rollout-'):
        return 'rollout-copy'
    return 'repo-root-copy'

def _walk_session_key(agent, prompt_id, path):
    fname = os.path.basename(path)
    uuid_m = re.search(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', fname)
    if uuid_m:
        return (agent, prompt_id, uuid_m.group(0).lower())
    return (agent, prompt_id, path)

def walk_sessions(partition_root):
    """Filesystem fallback when raw/source-manifest.jsonl is absent.
    Groups (agent, prompt, session-uuid-or-path), selects canonical variant
    per VARIANT_PREFERENCE so Codex export duplicates collapse to one record."""
    raw_root = os.path.join(partition_root, 'raw', 'cross-agent')
    if not os.path.isdir(raw_root):
        return []
    by_key = {}
    for root, _dirs, files in os.walk(raw_root):
        for fname in files:
            if not (fname.endswith('.jsonl') or fname.endswith('.txt')):
                continue
            path = os.path.join(root, fname)
            agent, prompt_id, session_ref = parse_path(path, partition_root)
            if not agent or not prompt_id:
                continue
            key = _walk_session_key(agent, prompt_id, path)
            by_key.setdefault(key, []).append({
                "agent": agent, "prompt_id": prompt_id, "path": path,
                "session_ref": session_ref, "variant": _walk_variant_of(path),
            })
    out = []
    for key, candidates in by_key.items():
        picked = None
        for variant in VARIANT_PREFERENCE:
            for c in candidates:
                if c['variant'] == variant:
                    picked = c
                    break
            if picked is not None:
                break
        if picked is None:
            picked = candidates[0]
        out.append({
            "agent": picked['agent'], "prompt_id": picked['prompt_id'],
            "path": picked['path'], "session_ref": picked['session_ref'],
        })
    return out

def load_text(path):
    parts = []
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                    parts.append(json.dumps(obj, ensure_ascii=False))
                except Exception:
                    parts.append(line)
    except Exception:
        return ""
    return "\n".join(parts)

def load_runs(partition_root):
    """Build map (agent, prompt_id) -> list[run_records], newest ts last."""
    path = os.path.join(partition_root, 'cross-agent-runs.jsonl')
    runs_by_key = {}
    if not os.path.exists(path):
        return runs_by_key
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            agent = rec.get('agent')
            prompt_id = rec.get('prompt_id')
            if not agent or not prompt_id:
                continue
            key = (agent, int(prompt_id))
            runs_by_key.setdefault(key, []).append(rec)
    # Sort each list by ts ascending
    for key in runs_by_key:
        runs_by_key[key].sort(key=lambda r: r.get('ts', ''))
    return runs_by_key

def pick_matching_run(runs_by_key, agent, prompt_id, session_ref):
    """Pick the run record matching agent+prompt+session_ref most closely.
    Strategy: exact session_ref substring match wins; else latest run by ts."""
    key = (agent, int(prompt_id))
    runs = runs_by_key.get(key, [])
    if not runs:
        return None
    # Prefer runs whose session_ref string shares a substring with the
    # transcript filename (operator often writes the rollout id).
    if session_ref:
        s_base = os.path.splitext(session_ref)[0]
        for r in runs:
            rsr = r.get('session_ref') or ''
            if rsr and (rsr in s_base or s_base in rsr):
                return r
        # Try UUID-ish token match
        tokens = re.findall(r'[0-9a-f-]{12,}', s_base, re.IGNORECASE)
        for tok in tokens:
            for r in runs:
                if tok in (r.get('session_ref') or ''):
                    return r
    return runs[-1]  # newest

def classify(refs_count, paired_run):
    if refs_count == 0:
        return "unread"
    # References present; check whether paired run required feedback
    if paired_run is None:
        return "loaded_no_paired_run"
    if paired_run.get('feedback_required') is True:
        return "loaded_behavior_divergent"
    return "loaded"

def score_transcript(agent, prompt_id, session_ref, text, paired_run):
    refs = []
    counts = {}
    for name, pat in REFERENCES:
        hits = re.findall(pat, text, re.IGNORECASE)
        if hits:
            counts[name] = len(hits)
            # record up to 2 excerpts per reference type
            for m in re.finditer(pat, text, re.IGNORECASE):
                refs.append({
                    "type": name,
                    "match_redacted": m.group(0)[:80],
                })
                if sum(1 for r in refs if r["type"] == name) >= 2:
                    break
    reference_count = sum(counts.values())
    classification = classify(reference_count, paired_run)
    out = {
        "ts": ts,
        "schema_version": "1",
        "agent": agent,
        "prompt_id": prompt_id,
        "session_ref": session_ref,
        "references": refs[:24],
        "references_by_type": counts,
        "reference_count": reference_count,
        "classification": classification,
    }
    if paired_run is not None:
        out["paired_run"] = {
            "score": paired_run.get('score'),
            "feedback_required": paired_run.get('feedback_required'),
            "ts": paired_run.get('ts'),
            "session_ref": paired_run.get('session_ref'),
        }
    return out

partitions = sorted([d for d in os.listdir(base)
                     if re.match(r'^\d{4}-\d{2}-\d{2}$', d)
                     and os.path.isdir(os.path.join(base, d))])

total_written = 0
for p in partitions:
    partition_root = os.path.join(base, p)
    out_path = os.path.join(partition_root, 'cross-agent-guidance-load.jsonl')

    open(out_path, 'w').close()  # snapshot_begin

    sessions = load_manifest_sessions(partition_root)
    if not sessions:
        sessions = walk_sessions(partition_root)

    if not sessions:
        print(f"  {p}: no cross-agent sessions — empty snapshot")
        continue

    runs_by_key = load_runs(partition_root)

    records = []
    for s in sessions:
        text = load_text(s['path'])
        if not text:
            continue
        paired = pick_matching_run(runs_by_key, s['agent'], s['prompt_id'], s['session_ref'])
        records.append(score_transcript(s['agent'], s['prompt_id'], s['session_ref'], text, paired))

    records.sort(key=lambda r: (r["agent"], r["prompt_id"], r["session_ref"]))
    with open(out_path, 'w') as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    total_written += len(records)

    breakdown = {"loaded": 0, "loaded_behavior_divergent": 0, "loaded_no_paired_run": 0, "unread": 0}
    for r in records:
        breakdown[r["classification"]] = breakdown.get(r["classification"], 0) + 1
    print(f"  {p}: {len(records)} records — loaded={breakdown['loaded']} "
          f"divergent={breakdown['loaded_behavior_divergent']} "
          f"unread={breakdown['unread']} "
          f"no_paired_run={breakdown['loaded_no_paired_run']}")

print(f"  total records written: {total_written}")
PYEOF

echo "  ✓ measure-guidance-load complete"
