#!/usr/bin/env bash
# run-env-inspect-fixture.sh — regression check for the P12 env-inspect prototype.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-env-inspect-fixture.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

jwt_value='header.payload.signature'
aws_id="AKIA$(printf 'A%.0s' {1..16})"
normal_value='fixture-non-secret-value'
hash_salt='fixture-hash-salt'

classified_out="$tmp_dir/classified.json"
hashed_out="$tmp_dir/hashed.json"
names_out="$tmp_dir/names.json"
empty_err="$tmp_dir/empty.err"

HCS_ENV_FIXTURE_JWT="$jwt_value" \
HCS_ENV_FIXTURE_AWS_ID="$aws_id" \
HCS_ENV_FIXTURE_NORMAL="$normal_value" \
  python3 "$repo_root/scripts/dev/hcs-env-inspect.py" \
    --mode classified \
    --name HCS_ENV_FIXTURE_JWT \
    --name HCS_ENV_FIXTURE_AWS_ID \
    --name HCS_ENV_FIXTURE_NORMAL \
    --name HCS_ENV_FIXTURE_MISSING \
    > "$classified_out"

HCS_ENV_FIXTURE_JWT="$jwt_value" \
HCS_ENV_FIXTURE_AWS_ID="$aws_id" \
HCS_ENV_FIXTURE_NORMAL="$normal_value" \
HCS_ENV_HASH_SALT="$hash_salt" \
  python3 "$repo_root/scripts/dev/hcs-env-inspect.py" \
    --mode hashed \
    --hash-salt-env HCS_ENV_HASH_SALT \
    --name HCS_ENV_FIXTURE_JWT \
    --name HCS_ENV_FIXTURE_NORMAL \
    > "$hashed_out"

HCS_ENV_FIXTURE_JWT="$jwt_value" \
HCS_ENV_FIXTURE_AWS_ID="$aws_id" \
HCS_ENV_FIXTURE_NORMAL="$normal_value" \
  python3 "$repo_root/scripts/dev/hcs-env-inspect.py" \
    --mode names_only \
    --prefix HCS_ENV_FIXTURE_ \
    > "$names_out"

set +e
python3 "$repo_root/scripts/dev/hcs-env-inspect.py" --mode names_only > /dev/null 2> "$empty_err"
empty_status=$?
set -e

if [ "$empty_status" -ne 2 ]; then
  echo "expected no-selector invocation to exit 2, got $empty_status" >&2
  exit 1
fi

python3 - "$classified_out" "$hashed_out" "$names_out" "$jwt_value" "$aws_id" "$normal_value" "$hash_salt" <<'PYEOF'
import hashlib
import json
import sys

classified_path, hashed_path, names_path, jwt_value, aws_id, normal_value, hash_salt = sys.argv[1:]

with open(classified_path) as f:
    classified = json.load(f)
with open(hashed_path) as f:
    hashed = json.load(f)
with open(names_path) as f:
    names_only = json.load(f)

serialized = json.dumps([classified, hashed, names_only], sort_keys=True)
for raw_value in (jwt_value, aws_id, normal_value, hash_salt):
    if raw_value in serialized:
        raise SystemExit(f"env-inspect output leaked raw value: {raw_value!r}")

if classified.get("safety") != "raw_env_values_never_emitted":
    raise SystemExit("classified output missing safety marker")

records = {record["name"]: record for record in classified["records"]}
expected_shapes = {
    "HCS_ENV_FIXTURE_JWT": "looks_like_jwt",
    "HCS_ENV_FIXTURE_AWS_ID": "looks_like_aws_access_key_id",
    "HCS_ENV_FIXTURE_NORMAL": "non_secret_shape",
}
for name, expected_shape in expected_shapes.items():
    record = records.get(name)
    if record is None:
        raise SystemExit(f"missing classified record for {name}")
    if record.get("present") is not True:
        raise SystemExit(f"{name} should be present")
    if record.get("value_shape") != expected_shape:
        raise SystemExit(f"{name}: expected {expected_shape!r}, got {record.get('value_shape')!r}")
    if "hash" in record:
        raise SystemExit(f"{name}: classified mode must not emit hashes")

missing = records.get("HCS_ENV_FIXTURE_MISSING")
if missing is None or missing.get("present") is not False:
    raise SystemExit("missing variable should be represented as present=false")
if missing.get("redaction") != "not_present":
    raise SystemExit("missing variable should use not_present redaction")

hashed_records = {record["name"]: record for record in hashed["records"]}
expected_hash = hashlib.sha256((hash_salt + "\0" + jwt_value).encode()).hexdigest()
jwt_hash = hashed_records["HCS_ENV_FIXTURE_JWT"]
if jwt_hash.get("hash") != expected_hash:
    raise SystemExit("salted hash for JWT fixture did not match expected digest")
if jwt_hash.get("salted_hash") is not True:
    raise SystemExit("hashed output should mark salted_hash=true")
if "value_shape" in jwt_hash:
    raise SystemExit("hashed mode must not emit value_shape")

for record in names_only["records"]:
    if record.get("present") is not True:
        raise SystemExit(f"prefix-selected record should be present: {record!r}")
    for forbidden_key in ("value_shape", "hash", "byte_length"):
        if forbidden_key in record:
            raise SystemExit(f"names_only record emitted {forbidden_key}: {record!r}")

expected_names = [
    "HCS_ENV_FIXTURE_AWS_ID",
    "HCS_ENV_FIXTURE_JWT",
    "HCS_ENV_FIXTURE_NORMAL",
]
actual_names = [record["name"] for record in names_only["records"]]
if actual_names != expected_names:
    raise SystemExit(f"expected prefix-selected names {expected_names!r}, got {actual_names!r}")

print("  ✓ env inspect fixture passed")
PYEOF
