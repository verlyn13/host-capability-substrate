#!/usr/bin/env python3
"""Capture a P08 provenance snapshot for selected non-secret environment facts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Literal, TypedDict


SCHEMA_VERSION = "0.1.0"
TARGET_VARS = ("PATH", "SHELL", "HOME", "PWD", "TMPDIR", "CODEX_HOME")
SECRET_VALUE_RE = re.compile(
    r"(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)",
)
SECRET_NAME_RE = re.compile(
    r"(^|_)(TOKEN|SECRET|API_KEY|PASSWORD|PASSWD|PAT|PRIVATE_KEY|ACCESS_KEY)($|_)",
    re.IGNORECASE,
)

ValueKind = Literal["path_list", "directory_path", "path", "absent"]


class EnvRecord(TypedDict, total=False):
    name: str
    present: bool
    value_kind: ValueKind
    value: str
    value_sha256: str
    path_entries: list[str]
    provenance_tags: list[str]
    authority: str
    confidence: str
    redaction: str


def iso_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def safe_to_emit(name: str, value: str) -> bool:
    if SECRET_NAME_RE.search(name):
        return False
    return SECRET_VALUE_RE.search(value) is None


def value_kind(name: str, value: str | None) -> ValueKind:
    if value is None:
        return "absent"
    if name == "PATH":
        return "path_list"
    if name in {"HOME", "PWD", "TMPDIR", "CODEX_HOME"}:
        return "directory_path"
    return "path"


def provenance_tags(name: str, present: bool) -> list[str]:
    tags = ["surface:codex_cli_tool_call_subprocess", "authority:sandbox_observation"]
    if present:
        tags.append("source:process_environment")
    else:
        tags.append("source:process_environment_absent")
    if name == "PWD":
        tags.append("source:getcwd")
    if name == "PATH":
        tags.append("composition:unknown_runtime_path")
    if name == "CODEX_HOME":
        tags.append("codex_home:explicit_env" if present else "codex_home:not_set")
    return tags


def record_env(name: str) -> EnvRecord:
    value = os.environ.get(name)
    present = value is not None
    record: EnvRecord = {
        "name": name,
        "present": present,
        "value_kind": value_kind(name, value),
        "provenance_tags": provenance_tags(name, present),
        "authority": "sandbox-observation",
        "confidence": "best-effort",
    }
    if value is None:
        record["redaction"] = "not_present"
        return record

    record["value_sha256"] = sha256(value)
    if safe_to_emit(name, value):
        record["value"] = value
        record["redaction"] = "value_allowed_for_p08_target"
        if name == "PATH":
            record["path_entries"] = value.split(":") if value else []
    else:
        record["redaction"] = "value_redacted_secret_shape"
    return record


def build_snapshot() -> dict[str, object]:
    cwd = os.getcwd()
    env_pwd = os.environ.get("PWD")
    return {
        "schema_version": SCHEMA_VERSION,
        "fixture": "provenance-snapshot",
        "prompt_id": "P08",
        "observed_at": iso_now(),
        "surface": "codex_cli_tool_call_subprocess",
        "authority": "sandbox-observation",
        "confidence": "best-effort",
        "cwd": cwd,
        "env_pwd_matches_getcwd": env_pwd == cwd if env_pwd is not None else None,
        "target_variables": list(TARGET_VARS),
        "records": [record_env(name) for name in TARGET_VARS],
        "safety": "only_p08_allowed_non_secret_targets_emit_values",
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Capture the Phase 1 P08 provenance snapshot.")
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional output path. Writes JSON with stable key ordering and trailing newline.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    serialized = json.dumps(build_snapshot(), indent=2, sort_keys=True) + "\n"
    if args.output is None:
        sys.stdout.write(serialized)
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(serialized)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
