#!/usr/bin/env bash
# measure-commands.sh — Phase 0b: per-command extraction from Claude Code and
# Codex corpora, bounded by the same 7-day window as the aggregate scripts.
#
# Emits `commands.jsonl` — one record per shell command, with fields:
#   ts, source (claude-code|codex), transcript (last 2 path components),
#   line, tool_name, command, description, cwd
#
# Feeds `measure-classify.sh` which runs each record through `classify.py`.
#
# Snapshot semantics (see measure-common.sh §IDEMPOTENCY CONTRACT):
# truncates commands.jsonl at start of run.
#
# Read-only. Source files opened once per pass.

set -euo pipefail
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/measure-common.sh"
script_banner "measure-commands"

OUT="commands.jsonl"
snapshot_begin "$OUT"

CC_HOME="$HOME/.claude"
CX_HOME="$HOME/.codex"

tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT

claude_files=0
codex_files=0

if [ -d "$CC_HOME/projects" ]; then
  find "$CC_HOME/projects" -type f -name '*.jsonl' -mtime -7 -print > "$tmp_list" 2>/dev/null || true
  claude_files=$(wc -l < "$tmp_list" | tr -d ' ')
fi

codex_tmp="$(mktemp)"
if [ -d "$CX_HOME/sessions" ]; then
  find "$CX_HOME/sessions" -type f -name 'rollout-*.jsonl' -mtime -7 -print > "$codex_tmp" 2>/dev/null || true
  codex_files=$(wc -l < "$codex_tmp" | tr -d ' ')
fi

python3 - "$tmp_list" "$codex_tmp" "$OUT_DIR/$OUT" "$HOME" <<'PYEOF'
import json
import os
import sys
from datetime import datetime, timezone

claude_list_path = sys.argv[1]
codex_list_path = sys.argv[2]
out_path = sys.argv[3]
home = sys.argv[4]

ts_now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def path_tail(p: str) -> str:
    parts = p.rsplit('/', 2)
    return '/'.join(parts[-2:]) if len(parts) >= 2 else p


def emit(out, record):
    out.write(json.dumps(record) + '\n')


written = 0
with open(out_path, 'a') as out:
    # Claude Code: tool_use records with name==Bash inside assistant messages.
    with open(claude_list_path) as lf:
        for p in (line.strip() for line in lf):
            if not p:
                continue
            try:
                with open(p, 'r', errors='replace') as fh:
                    for lineno, line in enumerate(fh, 1):
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            d = json.loads(line)
                        except Exception:
                            continue
                        if d.get('type') != 'assistant':
                            continue
                        msg = d.get('message') or {}
                        content = msg.get('content') if isinstance(msg, dict) else None
                        if not isinstance(content, list):
                            continue
                        for item in content:
                            if not isinstance(item, dict):
                                continue
                            if item.get('type') != 'tool_use':
                                continue
                            name = item.get('name') or ''
                            if name != 'Bash':
                                continue
                            tinput = item.get('input') or {}
                            cmd = tinput.get('command') if isinstance(tinput, dict) else None
                            if not cmd:
                                continue
                            desc = tinput.get('description') if isinstance(tinput, dict) else None
                            emit(out, {
                                'ts': ts_now,
                                'source': 'claude-code',
                                'transcript': path_tail(p),
                                'line': lineno,
                                'tool_name': 'Bash',
                                'command': cmd,
                                'description': desc,
                                'cwd': d.get('cwd') or None,
                            })
                            written += 1
            except (OSError, PermissionError):
                continue

    # Codex: response_item records with payload.type==function_call; we pull
    # exec_command primarily (shell invocations). Other function_call names are
    # structured tools and not classifiable as shell commands.
    with open(codex_list_path) as lf:
        for p in (line.strip() for line in lf):
            if not p:
                continue
            try:
                with open(p, 'r', errors='replace') as fh:
                    for lineno, line in enumerate(fh, 1):
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            d = json.loads(line)
                        except Exception:
                            continue
                        if d.get('type') != 'response_item':
                            continue
                        payload = d.get('payload') or {}
                        if payload.get('type') != 'function_call':
                            continue
                        name = payload.get('name') or ''
                        if name != 'exec_command':
                            continue
                        args_raw = payload.get('arguments')
                        if not args_raw:
                            continue
                        try:
                            args = json.loads(args_raw) if isinstance(args_raw, str) else args_raw
                        except Exception:
                            continue
                        # Codex exec_command arguments use key `cmd` (string) + `workdir`.
                        # Older rollouts may use `command` (list) — accept both.
                        cmd = None
                        if isinstance(args, dict):
                            if isinstance(args.get('cmd'), str):
                                cmd = args['cmd']
                            elif isinstance(args.get('command'), list):
                                cmd = ' '.join(args['command'])
                            elif isinstance(args.get('command'), str):
                                cmd = args['command']
                        if not cmd:
                            continue
                        emit(out, {
                            'ts': ts_now,
                            'source': 'codex',
                            'rollout': path_tail(p),
                            'line': lineno,
                            'tool_name': 'exec_command',
                            'command': cmd,
                            'cwd': (args.get('workdir') or args.get('cwd')) if isinstance(args, dict) else None,
                        })
                        written += 1
            except (OSError, PermissionError):
                continue

print(f"  ✓ claude-code transcripts scanned: (see file list)", flush=True)
print(f"  ✓ codex rollouts scanned: (see file list)", flush=True)
print(f"  ✓ total command records emitted: {written}", flush=True)
PYEOF

rm -f "$codex_tmp"
echo "  → $(log_dir)/$OUT ($claude_files claude / $codex_files codex source files, 7d window)"
