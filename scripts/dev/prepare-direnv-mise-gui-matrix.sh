#!/usr/bin/env bash
# prepare-direnv-mise-gui-matrix.sh - create a secret-safe P09 GUI/IDE probe packet.

set -euo pipefail

usage() {
  cat <<'EOF'
usage: prepare-direnv-mise-gui-matrix.sh [--fixture] [--out DIR]

Creates a P09 direnv/mise GUI/IDE probe packet. Default output is under
.logs/phase-1/shell-env/<date>/ and is gitignored. --fixture uses a temporary
directory and validates that the probe reports marker presence without printing
marker values.
EOF
}

mode="prepare"
out_dir=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --fixture)
      mode="fixture"
      shift
      ;;
    --out)
      if [ "$#" -lt 2 ]; then
        echo "--out requires a directory" >&2
        exit 2
      fi
      out_dir="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python_bin="$(command -v python3)"

if [ -z "$out_dir" ]; then
  if [ "$mode" = "fixture" ]; then
    out_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-p09-gui-matrix.XXXXXX")"
  else
    date_stamp="$(date -u +%Y-%m-%d)"
    run_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out_dir="$repo_root/.logs/phase-1/shell-env/$date_stamp/p09-gui-ide-matrix-$run_stamp"
  fi
fi

mkdir -p "$out_dir"
project_dir="$out_dir/project"
mkdir -p "$project_dir"

direnv_marker_value="p09_direnv_gui_probe_marker"
mise_marker_value="p09_mise_gui_probe_marker"
probe_path="$project_dir/probe-p09-env.py"

cat > "$project_dir/.envrc" <<EOF
export HCS_DIRENV_MARKER=$direnv_marker_value
EOF

cat > "$project_dir/.mise.toml" <<EOF
[env]
HCS_MISE_MARKER = "$mise_marker_value"
EOF

cat > "$probe_path" <<'PYEOF'
#!/usr/bin/env python3
"""Presence-only P09 direnv/mise GUI/IDE probe."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os


MARKERS = ("HCS_DIRENV_MARKER", "HCS_MISE_MARKER")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--surface", required=True)
    parser.add_argument("--launch-origin", required=True)
    parser.add_argument("--activation-mode", required=True)
    args = parser.parse_args()

    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    payload = {
        "schema_version": "p09-gui-ide-probe.v1",
        "prompt_id": "P09",
        "observed_at_utc": now,
        "surface": args.surface,
        "launch_origin": args.launch_origin,
        "activation_mode": args.activation_mode,
        "evidence_kind": "existence_only",
        "redaction": "marker_presence_only_no_values",
        "raw_values_collected": False,
        "markers": [{"name": name, "present": name in os.environ} for name in MARKERS],
    }
    print(json.dumps(payload, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PYEOF
chmod +x "$probe_path"

cat > "$project_dir/README.md" <<'EOF'
# P09 GUI/IDE Probe Packet

This packet is for a human-approved GUI or IDE execution-context probe. It
contains synthetic direnv/mise marker declarations and a probe that reports
presence only.

Do not run broad env or printenv commands. Do not echo marker values. Do not run
direnv allow or mise trust against the real user stores without a separate
operation proof and approval.

Suggested probe shape from the selected agent shell:

```bash
python3 probe-p09-env.py \
  --surface <codex_app|codex_ide_ext|claude_code_ide_ext|zed_external_agent> \
  --launch-origin <finder|dock|ide_ui|terminal_proxy|unknown> \
  --activation-mode <plain_subprocess|direnv_exec|mise_exec|agent_default>
```

Persist only the JSON line emitted by the probe. It intentionally does not
include marker values.
EOF

if [ "$mode" = "fixture" ]; then
  fixture_out="$out_dir/fixture-observed.json"
  HCS_DIRENV_MARKER="$direnv_marker_value" \
    HCS_MISE_MARKER="$mise_marker_value" \
    "$python_bin" "$probe_path" \
      --surface fixture \
      --launch-origin fixture \
      --activation-mode direct_env \
      > "$fixture_out"

  "$python_bin" - "$fixture_out" "$direnv_marker_value" "$mise_marker_value" <<'PYEOF'
from __future__ import annotations

import json
import sys
from pathlib import Path

path, direnv_marker, mise_marker = sys.argv[1:]
text = Path(path).read_text()
payload = json.loads(text)

if payload.get("schema_version") != "p09-gui-ide-probe.v1":
    raise SystemExit("unexpected probe schema version")
if payload.get("raw_values_collected") is not False:
    raise SystemExit("probe must declare that raw values were not collected")

markers = {item["name"]: item["present"] for item in payload.get("markers", [])}
for name in ("HCS_DIRENV_MARKER", "HCS_MISE_MARKER"):
    if markers.get(name) is not True:
        raise SystemExit(f"{name} was not reported present in fixture mode")

for marker in (direnv_marker, mise_marker):
    if marker in text:
        raise SystemExit("probe output leaked a synthetic marker value")

print("  ✓ p09 gui/ide probe packet fixture passed")
PYEOF
else
  printf "Created P09 GUI/IDE probe packet:\n"
  printf "  path: %s\n" "$project_dir"
  printf "  probe: %s\n" "$probe_path"
  printf "  note: no GUI launch, direnv allow, or mise trust was performed\n"
fi
