#!/usr/bin/env bash
# run-direnv-mise-fixture.sh — non-mutating P09 baseline for direnv/mise markers.

set -euo pipefail

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-direnv-mise-fixture.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

python_bin="$(command -v python3)"
direnv_bin="$(command -v direnv)"
mise_bin="$(command -v mise)"

project_dir="$tmp_dir/project"
home_dir="$tmp_dir/home"
direnv_config="$tmp_dir/direnv-config"
mise_data="$tmp_dir/mise-data"
mkdir -p "$project_dir" "$home_dir" "$direnv_config" "$mise_data"

cat > "$project_dir/.envrc" <<'EOF'
export HCS_DIRENV_MARKER=p09_direnv_marker_should_not_leak
EOF

cat > "$project_dir/.mise.toml" <<'EOF'
[env]
HCS_MISE_MARKER = "p09_mise_marker_should_not_leak"
EOF

path_min="/opt/homebrew/bin:/usr/bin:/bin"
plain_out="$tmp_dir/plain.json"
direnv_out="$tmp_dir/direnv.out"
direnv_status="$tmp_dir/direnv.status"
mise_out="$tmp_dir/mise.out"
mise_status="$tmp_dir/mise.status"

env -i \
  HOME="$home_dir" \
  PATH="$path_min" \
  SHELL="/bin/zsh" \
  PROJECT_DIR="$project_dir" \
  "$python_bin" - <<'PYEOF' > "$plain_out"
import json
import os

os.chdir(os.environ["PROJECT_DIR"])
print(json.dumps({
    "cwd": os.getcwd(),
    "HCS_DIRENV_MARKER_present": "HCS_DIRENV_MARKER" in os.environ,
    "HCS_MISE_MARKER_present": "HCS_MISE_MARKER" in os.environ,
}, sort_keys=True))
PYEOF

set +e
env -i \
  HOME="$home_dir" \
  PATH="$path_min" \
  SHELL="/bin/zsh" \
  DIRENV_CONFIG="$direnv_config" \
  XDG_CONFIG_HOME="$tmp_dir/xdg" \
  /bin/sh -c 'cd "$1" && "$2" export json' sh "$project_dir" "$direnv_bin" > "$direnv_out" 2>&1
printf '%s\n' "$?" > "$direnv_status"

env -i \
  HOME="$home_dir" \
  PATH="$path_min" \
  SHELL="/bin/zsh" \
  MISE_DATA_DIR="$mise_data" \
  MISE_CACHE_DIR="$tmp_dir/mise-cache" \
  MISE_STATE_DIR="$tmp_dir/mise-state" \
  /bin/sh -c 'cd "$1" && "$2" env --json' sh "$project_dir" "$mise_bin" > "$mise_out" 2>&1
printf '%s\n' "$?" > "$mise_status"
set -e

"$python_bin" - "$plain_out" "$direnv_out" "$direnv_status" "$mise_out" "$mise_status" "$project_dir" "$direnv_config" "$mise_data" <<'PYEOF'
import json
import sys
from pathlib import Path

plain_path, direnv_path, direnv_status_path, mise_path, mise_status_path, project_dir, direnv_config, mise_data = sys.argv[1:]

plain = json.loads(Path(plain_path).read_text())
if plain["HCS_DIRENV_MARKER_present"] is not False:
    raise SystemExit("plain noninteractive process unexpectedly saw HCS_DIRENV_MARKER")
if plain["HCS_MISE_MARKER_present"] is not False:
    raise SystemExit("plain noninteractive process unexpectedly saw HCS_MISE_MARKER")

direnv_text = Path(direnv_path).read_text()
if "HCS_DIRENV_MARKER" in direnv_text:
    raise SystemExit("direnv output exposed or applied HCS_DIRENV_MARKER before allow")
if "p09_direnv_marker_should_not_leak" in direnv_text:
    raise SystemExit("direnv output exposed marker value before allow")
if ".envrc is blocked" not in direnv_text:
    raise SystemExit("expected direnv to report blocked .envrc without allow")
if str(Path(project_dir)) not in direnv_text:
    raise SystemExit("direnv output did not reference the isolated temp project")

mise_text = Path(mise_path).read_text()
if "HCS_MISE_MARKER" in mise_text:
    raise SystemExit("mise output exposed or applied HCS_MISE_MARKER before trust")
if "p09_mise_marker_should_not_leak" in mise_text:
    raise SystemExit("mise output exposed marker value before trust")
if "not trusted" not in mise_text:
    raise SystemExit("expected mise to report untrusted .mise.toml")
if str(Path(project_dir)) not in mise_text:
    raise SystemExit("mise output did not reference the isolated temp project")

if not str(Path(direnv_config)).startswith("/"):
    raise SystemExit("direnv config path should be absolute temp state")
if not str(Path(mise_data)).startswith("/"):
    raise SystemExit("mise data path should be absolute temp state")

print("  ✓ direnv/mise fixture passed")
PYEOF
