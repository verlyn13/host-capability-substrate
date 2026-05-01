#!/usr/bin/env bash
# prepare-codex-env-policy-matrix.sh - create a secret-safe P04 probe packet.

set -euo pipefail

usage() {
  cat <<'EOF'
usage: prepare-codex-env-policy-matrix.sh [--fixture] [--out DIR]

Creates a P04 Codex shell_environment_policy probe packet. Default output is
under .logs/phase-1/shell-env/<date>/ and is gitignored. --fixture uses a
temporary directory and validates that the probe reports marker presence without
printing marker values.
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
    out_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-p04-env-policy.XXXXXX")"
  else
    date_stamp="$(date -u +%Y-%m-%d)"
    run_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out_dir="$repo_root/.logs/phase-1/shell-env/$date_stamp/p04-codex-env-policy-$run_stamp"
  fi
fi

mkdir -p "$out_dir"
packet_dir="$out_dir/p04-codex-env-policy"
mkdir -p "$packet_dir"

plain_value="p04_plain_marker"
secret_token_value="p04_fake_token_marker"
secret_key_value="p04_fake_key_marker"
include_value="p04_include_marker"
set_value="p04_config_set_marker"
probe_path="$packet_dir/probe-p04-env-policy.py"

write_config() {
  local variant_dir="$1"
  local ignore_default_excludes="$2"
  local inherit_mode="$3"

  mkdir -p "$variant_dir/.codex"
  {
    printf '# Candidate P04 config. Runtime behavior must be measured per surface.\n'
    printf '[shell_environment_policy]\n'
    printf 'inherit = "%s"\n' "$inherit_mode"
    if [ "$ignore_default_excludes" = "true" ]; then
      printf 'ignore_default_excludes = true\n'
    fi
    printf 'include_only = [\n'
    printf '  "HCS_P04_PLAIN",\n'
    printf '  "HCS_P04_FAKE_TOKEN",\n'
    printf '  "HCS_P04_FAKE_KEY",\n'
    printf '  "HCS_P04_INCLUDE_ONLY",\n'
    printf '  "HCS_P04_CONFIG_SET",\n'
    printf ']\n'
    printf 'set = { HCS_P04_CONFIG_SET = "%s" }\n' "$set_value"
  } > "$variant_dir/.codex/config.toml"
}

write_config "$packet_dir/variants/inherit-all-default-filter" "false" "all"
write_config "$packet_dir/variants/inherit-all-ignore-default-excludes" "true" "all"
write_config "$packet_dir/variants/inherit-none-set-only" "true" "none"

cat > "$probe_path" <<'PYEOF'
#!/usr/bin/env python3
"""Presence-only P04 Codex env-policy probe."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os


MARKERS = (
    "HCS_P04_PLAIN",
    "HCS_P04_FAKE_TOKEN",
    "HCS_P04_FAKE_KEY",
    "HCS_P04_INCLUDE_ONLY",
    "HCS_P04_CONFIG_SET",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--surface", required=True)
    parser.add_argument("--launch-origin", required=True)
    parser.add_argument("--config-variant", required=True)
    args = parser.parse_args()

    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    payload = {
        "schema_version": "p04-codex-env-policy-probe.v1",
        "prompt_id": "P04",
        "observed_at_utc": now,
        "surface": args.surface,
        "launch_origin": args.launch_origin,
        "config_variant": args.config_variant,
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

cat > "$packet_dir/README.md" <<'EOF'
# P04 Codex Env Policy Probe Packet

This packet is for a human-approved Codex CLI/app/IDE execution-context probe.
It contains candidate `.codex/config.toml` variants and a probe that reports
marker presence only.

Do not run broad `env` or `printenv` commands. Do not echo marker values. Do
not treat these candidate configs as evidence; runtime truth comes only from a
probe row produced by the selected Codex surface.

Candidate variants:

- `variants/inherit-all-default-filter`
- `variants/inherit-all-ignore-default-excludes`
- `variants/inherit-none-set-only`

Suggested probe shape from the selected Codex shell/tool subprocess:

```bash
python3 probe-p04-env-policy.py \
  --surface <codex_cli|codex_app|codex_ide_ext> \
  --launch-origin <terminal|finder|dock|ide_ui|terminal_proxy|unknown> \
  --config-variant <variant-name>
```

Persist only the JSON line emitted by the probe. It intentionally does not
include marker values.
EOF

cat > "$packet_dir/env-vector.json" <<EOF
{
  "schema_version": "p04-env-vector.v1",
  "markers": [
    {"name": "HCS_P04_PLAIN", "class": "plain_parent_env"},
    {"name": "HCS_P04_FAKE_TOKEN", "class": "secret_shaped_parent_env_synthetic"},
    {"name": "HCS_P04_FAKE_KEY", "class": "secret_shaped_parent_env_synthetic"},
    {"name": "HCS_P04_INCLUDE_ONLY", "class": "include_only_parent_env"},
    {"name": "HCS_P04_CONFIG_SET", "class": "config_set_value"}
  ],
  "redaction": "names_only_no_values"
}
EOF

if [ "$mode" = "fixture" ]; then
  fixture_out="$out_dir/fixture-observed.json"
  HCS_P04_PLAIN="$plain_value" \
    HCS_P04_FAKE_TOKEN="$secret_token_value" \
    HCS_P04_FAKE_KEY="$secret_key_value" \
    HCS_P04_INCLUDE_ONLY="$include_value" \
    HCS_P04_CONFIG_SET="$set_value" \
    "$python_bin" "$probe_path" \
      --surface fixture \
      --launch-origin fixture \
      --config-variant direct_env \
      > "$fixture_out"

  "$python_bin" - "$fixture_out" "$plain_value" "$secret_token_value" "$secret_key_value" "$include_value" "$set_value" <<'PYEOF'
from __future__ import annotations

import json
import sys
from pathlib import Path

path = sys.argv[1]
marker_values = sys.argv[2:]
text = Path(path).read_text()
payload = json.loads(text)

if payload.get("schema_version") != "p04-codex-env-policy-probe.v1":
    raise SystemExit("unexpected probe schema version")
if payload.get("raw_values_collected") is not False:
    raise SystemExit("probe must declare that raw values were not collected")

markers = {item["name"]: item["present"] for item in payload.get("markers", [])}
expected_names = {
    "HCS_P04_PLAIN",
    "HCS_P04_FAKE_TOKEN",
    "HCS_P04_FAKE_KEY",
    "HCS_P04_INCLUDE_ONLY",
    "HCS_P04_CONFIG_SET",
}
if set(markers) != expected_names:
    raise SystemExit("probe marker name set drifted")
for name in expected_names:
    if markers.get(name) is not True:
        raise SystemExit(f"{name} was not reported present in fixture mode")

for marker_value in marker_values:
    if marker_value in text:
        raise SystemExit("probe output leaked a synthetic marker value")

print("  OK p04 codex env-policy probe packet fixture passed")
PYEOF
else
  printf "Created P04 Codex env-policy probe packet:\n"
  printf "  path: %s\n" "$packet_dir"
  printf "  probe: %s\n" "$probe_path"
  printf "  note: no Codex surface was launched and no profile was changed\n"
fi
