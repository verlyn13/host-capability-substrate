#!/usr/bin/env bash
# run-shell-logger-fixture.sh — regression check for the P06 shell wrapper.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-shell-logger-fixture.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

fake_shell="$tmp_dir/fake-bash"
log_path="$tmp_dir/wrapper.jsonl"
exec_record="$tmp_dir/exec-argv.txt"
payload='printf "SHOULD_NOT_APPEAR_IN_WRAPPER_LOG\n"'

cat >"$fake_shell" <<'SHEOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'argc=%s\n' "$#" >"$HCS_SHELL_LOGGER_EXEC_RECORD"
for arg in "$@"; do
  printf 'arg=%s\n' "$arg" >>"$HCS_SHELL_LOGGER_EXEC_RECORD"
done
exit 23
SHEOF
chmod +x "$fake_shell"

set +e
HCS_SHELL_LOGGER_LOG="$log_path" \
  HCS_SHELL_LOGGER_REAL_SHELL="$fake_shell" \
  HCS_SHELL_LOGGER_EXEC_RECORD="$exec_record" \
  "$repo_root/scripts/dev/hcs-shell-logger.sh" -lc "$payload"
status=$?
set -e

if [ "$status" -ne 23 ]; then
  echo "expected wrapper to return fake shell status 23, got $status" >&2
  exit 1
fi

python3 - "$log_path" "$exec_record" <<'PYEOF'
import json
import sys

log_path, exec_record = sys.argv[1], sys.argv[2]

with open(log_path) as f:
    records = [json.loads(line) for line in f if line.strip()]

if len(records) != 1:
    raise SystemExit(f"expected one wrapper log record, got {len(records)}")

record = records[0]
expected_shape = ["shell_flag:-lc", "command_string_redacted"]
if record.get("arg_shape") != expected_shape:
    raise SystemExit(f"arg_shape: expected {expected_shape!r}, got {record.get('arg_shape')!r}")

if record.get("shell_flags") != ["-lc"]:
    raise SystemExit(f"shell_flags: expected ['-lc'], got {record.get('shell_flags')!r}")

if record.get("arg_count") != 2:
    raise SystemExit(f"arg_count: expected 2, got {record.get('arg_count')!r}")

serialized = json.dumps(record, sort_keys=True)
if "SHOULD_NOT_APPEAR_IN_WRAPPER_LOG" in serialized:
    raise SystemExit("wrapper log leaked shell command payload")

for forbidden_key in ("env", "environment"):
    if forbidden_key in record:
        raise SystemExit(f"wrapper log must not include {forbidden_key!r}")

with open(exec_record) as f:
    exec_text = f.read()

if "SHOULD_NOT_APPEAR_IN_WRAPPER_LOG" not in exec_text:
    raise SystemExit("fake shell did not receive the original command payload")

print("  ✓ shell logger fixture passed")
PYEOF
