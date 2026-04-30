#!/usr/bin/env bash
# run-provenance-snapshot-fixture.sh — regression check for P08 snapshot shape.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hcs-provenance-snapshot-fixture.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

current_snapshot="$tmp_dir/current-provenance-snapshot.json"
python3 "$repo_root/scripts/dev/capture-provenance-snapshot.py" --output "$current_snapshot"

fixture_files=("$repo_root"/packages/fixtures/provenance-snapshot-*.json)
if [ ! -e "${fixture_files[0]}" ]; then
  echo "expected at least one packages/fixtures/provenance-snapshot-*.json fixture" >&2
  exit 1
fi

python3 - "$current_snapshot" "${fixture_files[@]}" <<'PYEOF'
import hashlib
import json
import re
import sys

TARGET_VARS = ["PATH", "SHELL", "HOME", "PWD", "TMPDIR", "CODEX_HOME"]
SECRET_VALUE_RE = re.compile(
    r"(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)"
)
ISO_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


def sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def validate_snapshot(path: str) -> None:
    with open(path) as f:
        snapshot = json.load(f)

    if snapshot.get("schema_version") != "0.1.0":
        raise SystemExit(f"{path}: unexpected schema_version {snapshot.get('schema_version')!r}")
    if snapshot.get("fixture") != "provenance-snapshot":
        raise SystemExit(f"{path}: unexpected fixture {snapshot.get('fixture')!r}")
    if snapshot.get("prompt_id") != "P08":
        raise SystemExit(f"{path}: unexpected prompt_id {snapshot.get('prompt_id')!r}")
    if snapshot.get("authority") != "sandbox-observation":
        raise SystemExit(f"{path}: snapshot must remain sandbox-observation authority")
    if snapshot.get("confidence") != "best-effort":
        raise SystemExit(f"{path}: snapshot must remain best-effort confidence")
    if snapshot.get("surface") != "codex_cli_tool_call_subprocess":
        raise SystemExit(f"{path}: unexpected surface {snapshot.get('surface')!r}")
    if snapshot.get("target_variables") != TARGET_VARS:
        raise SystemExit(f"{path}: expected target_variables {TARGET_VARS!r}")
    if snapshot.get("safety") != "only_p08_allowed_non_secret_targets_emit_values":
        raise SystemExit(f"{path}: missing safety marker")
    if not ISO_RE.match(snapshot.get("observed_at", "")):
        raise SystemExit(f"{path}: observed_at is not UTC second timestamp")

    records = snapshot.get("records")
    if not isinstance(records, list):
        raise SystemExit(f"{path}: records must be a list")
    names = [record.get("name") for record in records]
    if names != TARGET_VARS:
        raise SystemExit(f"{path}: expected records in target order {TARGET_VARS!r}, got {names!r}")

    for record in records:
        name = record["name"]
        if record.get("authority") != "sandbox-observation":
            raise SystemExit(f"{path}:{name}: record authority must be sandbox-observation")
        if record.get("confidence") != "best-effort":
            raise SystemExit(f"{path}:{name}: record confidence must be best-effort")
        tags = record.get("provenance_tags")
        if not isinstance(tags, list) or "surface:codex_cli_tool_call_subprocess" not in tags:
            raise SystemExit(f"{path}:{name}: missing surface provenance tag")
        if "authority:sandbox_observation" not in tags:
            raise SystemExit(f"{path}:{name}: missing authority provenance tag")

        present = record.get("present")
        if present is True:
            if "value_sha256" not in record:
                raise SystemExit(f"{path}:{name}: present record missing value_sha256")
            if record.get("redaction") == "value_allowed_for_p08_target":
                value = record.get("value")
                if not isinstance(value, str):
                    raise SystemExit(f"{path}:{name}: allowed record missing value")
                if SECRET_VALUE_RE.search(value):
                    raise SystemExit(f"{path}:{name}: emitted value has secret-shaped content")
                if record["value_sha256"] != sha256(value):
                    raise SystemExit(f"{path}:{name}: value_sha256 does not match value")
                if name == "PATH":
                    path_entries = record.get("path_entries")
                    if path_entries != (value.split(":") if value else []):
                        raise SystemExit(f"{path}:{name}: path_entries do not match PATH value")
            elif record.get("redaction") == "value_redacted_secret_shape":
                if "value" in record:
                    raise SystemExit(f"{path}:{name}: redacted record must not emit value")
            else:
                raise SystemExit(f"{path}:{name}: unexpected redaction {record.get('redaction')!r}")
        elif present is False:
            if record.get("redaction") != "not_present":
                raise SystemExit(f"{path}:{name}: absent record must use not_present redaction")
            if "value" in record or "value_sha256" in record:
                raise SystemExit(f"{path}:{name}: absent record emitted value material")
        else:
            raise SystemExit(f"{path}:{name}: present must be boolean")


for snapshot_path in sys.argv[1:]:
    validate_snapshot(snapshot_path)

print("  ✓ provenance snapshot fixture passed")
PYEOF
