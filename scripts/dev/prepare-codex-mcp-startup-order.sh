#!/usr/bin/env bash
# prepare-codex-mcp-startup-order.sh - create a secret-safe P03 probe packet.

set -euo pipefail

usage() {
  cat <<'EOF'
usage: prepare-codex-mcp-startup-order.sh [--fixture] [--out DIR]

Creates a P03 Codex MCP startup vs setup-script ordering probe packet. Default
output is under .logs/phase-1/shell-env/<date>/ and is gitignored. --fixture
uses a temporary directory and validates that setup/MCP logger records contain
presence booleans without printing marker values.
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
    out_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-p03-mcp-startup.XXXXXX")"
  else
    date_stamp="$(date -u +%Y-%m-%d)"
    run_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out_dir="$repo_root/.logs/phase-1/shell-env/$date_stamp/p03-mcp-startup-order-$run_stamp"
  fi
fi

mkdir -p "$out_dir"
packet_dir="$out_dir/p03-mcp-startup-order"
project_dir="$packet_dir/project"
mkdir -p "$project_dir/.codex"

bearer_value="p03_synthetic_bearer_marker"
setup_marker_value="p03_setup_marker"
setup_script="$project_dir/.codex/p03-setup.macos.sh"
logger_script="$project_dir/mcp-startup-logger.py"
sequence_log="$packet_dir/sequence.jsonl"

cat > "$setup_script" <<'SHEOF'
#!/usr/bin/env bash
# Candidate Codex app local-environment setup script for P03.

set -euo pipefail

log_path="${HCS_P03_LOG_PATH:?HCS_P03_LOG_PATH is required}"
export HCS_BEARER_FAKE="${HCS_BEARER_FAKE:-p03_synthetic_bearer_marker}"
export HCS_P03_SETUP_MARKER="${HCS_P03_SETUP_MARKER:-p03_setup_marker}"

python3 - "$log_path" <<'PYEOF'
from __future__ import annotations

import datetime as dt
import json
import os
import sys

log_path = sys.argv[1]
now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
record = {
    "schema_version": "p03-startup-order-event.v1",
    "prompt_id": "P03",
    "event": "setup_script",
    "observed_at_utc": now,
    "evidence_kind": "existence_only",
    "raw_values_collected": False,
    "markers": [
        {"name": "HCS_BEARER_FAKE", "present": "HCS_BEARER_FAKE" in os.environ},
        {"name": "HCS_P03_SETUP_MARKER", "present": "HCS_P03_SETUP_MARKER" in os.environ},
    ],
}
with open(log_path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(record, sort_keys=True) + "\n")
PYEOF
SHEOF
chmod +x "$setup_script"

cat > "$logger_script" <<'PYEOF'
#!/usr/bin/env python3
"""Presence-only MCP startup logger for P03."""

from __future__ import annotations

import datetime as dt
import json
import os
import sys


def main() -> int:
    log_path = os.environ.get("HCS_P03_LOG_PATH")
    if not log_path:
        print("HCS_P03_LOG_PATH is required", file=sys.stderr)
        return 2

    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    record = {
        "schema_version": "p03-startup-order-event.v1",
        "prompt_id": "P03",
        "event": "mcp_startup_logger",
        "observed_at_utc": now,
        "evidence_kind": "existence_only",
        "raw_values_collected": False,
        "cwd": os.getcwd(),
        "markers": [
            {"name": "HCS_BEARER_FAKE", "present": "HCS_BEARER_FAKE" in os.environ},
            {"name": "HCS_P03_SETUP_MARKER", "present": "HCS_P03_SETUP_MARKER" in os.environ},
        ],
    }
    with open(log_path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PYEOF
chmod +x "$logger_script"

cat > "$project_dir/.codex/config.toml" <<'EOF'
# Candidate P03 config. Runtime behavior must be measured per surface.
# The stdio logger records process startup and env presence. A separate HTTP
# bearer-token row is still required to test bearer_token_env_var timing.

[mcp_servers.hcs_p03_stdio_logger]
command = "python3"
args = ["mcp-startup-logger.py"]
enabled = true
required = true
env_vars = ["HCS_P03_LOG_PATH", "HCS_BEARER_FAKE", "HCS_P03_SETUP_MARKER"]

[mcp_servers.hcs_p03_http_bearer_placeholder]
url = "http://127.0.0.1:9/hcs-p03-mcp-placeholder"
enabled = false
required = true
bearer_token_env_var = "HCS_BEARER_FAKE"
EOF

cat > "$packet_dir/README.md" <<'EOF'
# P03 Codex MCP Startup Order Probe Packet

This packet is for a human-approved Codex app or CLI startup-order probe. It
contains a candidate app local-environment setup script and an MCP startup
logger that writes existence-only JSONL records.

Do not put real credentials in `HCS_BEARER_FAKE`. Do not print environment
values. Do not enable the HTTP bearer placeholder without a separate approved
localhost capture plan.

Candidate files:

- `project/.codex/p03-setup.macos.sh`
- `project/.codex/config.toml`
- `project/mcp-startup-logger.py`

Observation target:

- `sequence.jsonl` under the packet directory

The current packet proves only the logging/redaction contract. Runtime ordering
between setup script execution and MCP startup remains unmeasured until Codex is
launched through an approved observation path.
EOF

if [ "$mode" = "fixture" ]; then
  HCS_P03_LOG_PATH="$sequence_log" \
    HCS_BEARER_FAKE="$bearer_value" \
    HCS_P03_SETUP_MARKER="$setup_marker_value" \
    "$setup_script"

  (
    cd "$project_dir"
    HCS_P03_LOG_PATH="$sequence_log" \
      HCS_BEARER_FAKE="$bearer_value" \
      HCS_P03_SETUP_MARKER="$setup_marker_value" \
      "$python_bin" "$logger_script"
  )

  "$python_bin" - "$sequence_log" "$bearer_value" "$setup_marker_value" <<'PYEOF'
from __future__ import annotations

import json
import sys
from pathlib import Path

path, bearer_value, setup_marker_value = sys.argv[1:]
text = Path(path).read_text()
records = [json.loads(line) for line in text.splitlines() if line.strip()]

if [record.get("event") for record in records] != ["setup_script", "mcp_startup_logger"]:
    raise SystemExit("unexpected P03 fixture event order")

for record in records:
    if record.get("schema_version") != "p03-startup-order-event.v1":
        raise SystemExit("unexpected P03 event schema version")
    if record.get("raw_values_collected") is not False:
        raise SystemExit("P03 event must declare that raw values were not collected")
    markers = {item["name"]: item["present"] for item in record.get("markers", [])}
    for name in ("HCS_BEARER_FAKE", "HCS_P03_SETUP_MARKER"):
        if markers.get(name) is not True:
            raise SystemExit(f"{name} was not reported present in fixture mode")

for marker_value in (bearer_value, setup_marker_value):
    if marker_value in text:
        raise SystemExit("P03 fixture output leaked a synthetic marker value")

print("  OK p03 mcp startup-order probe packet fixture passed")
PYEOF
else
  printf "Created P03 MCP startup-order probe packet:\n"
  printf "  path: %s\n" "$packet_dir"
  printf "  project: %s\n" "$project_dir"
  printf "  log: %s\n" "$sequence_log"
  printf "  note: no Codex surface was launched and no launchd env was changed\n"
fi
