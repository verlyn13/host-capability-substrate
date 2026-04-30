#!/usr/bin/env python3
"""Secret-safe environment inspection prototype for Phase 1 P12.

The helper intentionally inspects only explicit variable names and prefixes.
It never emits raw values; modes expose names, presence, classified value shape,
or hashes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import UTC, datetime
from typing import Iterable, Literal, TypedDict


SCHEMA_VERSION = "0.1.0"
VALID_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
VALID_PREFIX_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SECRET_NAME_RE = re.compile(
    r"(^|_)(TOKEN|SECRET|API_KEY|PASSWORD|PASSWD|PAT|PRIVATE_KEY|ACCESS_KEY)($|_)",
    re.IGNORECASE,
)
AWS_ACCESS_KEY_ID_RE = re.compile(r"^(A3T[A-Z0-9]|AKIA|ASIA)[A-Z0-9]{16}$")
JWT_RE = re.compile(r"^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$")
GITHUB_PAT_RE = re.compile(r"^(gh[pousr]_|github_pat_)[A-Za-z0-9_]{20,}$")
OPENAI_KEY_RE = re.compile(r"^sk-[A-Za-z0-9_-]{20,}$")
BASE64ISH_RE = re.compile(r"^[A-Za-z0-9_+/=-]{32,}$")
PATH_RE = re.compile(r"^(/[^:\0]+)(:/[^:\0]+)*$")
URL_RE = re.compile(r"^[a-z][a-z0-9+.-]*://", re.IGNORECASE)

Mode = Literal["names_only", "existence_check", "classified", "hashed"]


class Record(TypedDict, total=False):
    name: str
    present: bool
    name_shape: str
    redaction: str
    value_shape: str
    hash: str
    hash_algorithm: str
    byte_length: int
    salted_hash: bool


def iso_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def validate_name(value: str) -> str:
    if not VALID_NAME_RE.match(value):
        raise argparse.ArgumentTypeError(f"invalid env var name: {value!r}")
    return value


def validate_prefix(value: str) -> str:
    if not VALID_PREFIX_RE.match(value):
        raise argparse.ArgumentTypeError(f"invalid env var prefix: {value!r}")
    return value


def unique_ordered(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            result.append(value)
    return result


def selected_names(explicit_names: list[str], prefixes: list[str]) -> list[str]:
    prefixed = sorted(
        name for name in os.environ if any(name.startswith(prefix) for prefix in prefixes)
    )
    return unique_ordered([*explicit_names, *prefixed])


def name_shape(name: str) -> str:
    return "secret_shaped" if SECRET_NAME_RE.search(name) else "ordinary"


def value_shape(value: str) -> str:
    if value == "":
        return "empty"
    if JWT_RE.match(value):
        return "looks_like_jwt"
    if AWS_ACCESS_KEY_ID_RE.match(value):
        return "looks_like_aws_access_key_id"
    if GITHUB_PAT_RE.match(value):
        return "looks_like_github_pat"
    if OPENAI_KEY_RE.match(value):
        return "looks_like_openai_api_key"
    if "BEGIN " in value and "PRIVATE KEY" in value:
        return "looks_like_private_key"
    if BASE64ISH_RE.match(value):
        return "looks_like_high_entropy_token"
    if PATH_RE.match(value):
        return "looks_like_path"
    if URL_RE.match(value):
        return "looks_like_url"
    return "non_secret_shape"


def hash_value(value: str, salt: str | None) -> str:
    material = value.encode("utf-8")
    if salt is not None:
        material = salt.encode("utf-8") + b"\0" + material
    return hashlib.sha256(material).hexdigest()


def record_for(name: str, mode: Mode, salt: str | None) -> Record:
    present = name in os.environ
    record: Record = {
        "name": name,
        "present": present,
        "name_shape": name_shape(name),
    }
    if not present:
        record["redaction"] = "not_present"
        return record

    if mode in {"names_only", "existence_check"}:
        record["redaction"] = "value_not_collected"
        return record

    value = os.environ[name]
    if mode == "classified":
        record["value_shape"] = value_shape(value)
        record["redaction"] = "value_classified_not_emitted"
        return record

    if mode == "hashed":
        record["hash"] = hash_value(value, salt)
        record["hash_algorithm"] = "sha256"
        record["byte_length"] = len(value.encode("utf-8"))
        record["salted_hash"] = salt is not None
        record["redaction"] = "value_hashed_not_emitted"
        return record

    raise AssertionError(f"unhandled mode: {mode}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inspect selected environment variables without emitting raw values.",
    )
    parser.add_argument(
        "--mode",
        choices=("names_only", "existence_check", "classified", "hashed"),
        required=True,
    )
    parser.add_argument(
        "--name",
        action="append",
        default=[],
        type=validate_name,
        help="Environment variable name to inspect. May be repeated.",
    )
    parser.add_argument(
        "--prefix",
        action="append",
        default=[],
        type=validate_prefix,
        help="Environment variable prefix to inspect. May be repeated.",
    )
    parser.add_argument(
        "--hash-salt-env",
        type=validate_name,
        help="Optional env var name containing a hash salt. The salt is never emitted.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    names = selected_names(args.name, args.prefix)
    if not names:
        print(
            "hcs-env-inspect requires at least one --name or a --prefix with matches",
            file=sys.stderr,
        )
        return 2

    salt = os.environ.get(args.hash_salt_env) if args.hash_salt_env else None
    records = [record_for(name, args.mode, salt) for name in names]
    output = {
        "schema_version": SCHEMA_VERSION,
        "tool": "hcs-env-inspect",
        "mode": args.mode,
        "observed_at": iso_now(),
        "selectors": {
            "names": args.name,
            "prefixes": args.prefix,
        },
        "record_count": len(records),
        "records": records,
        "safety": "raw_env_values_never_emitted",
    }
    print(json.dumps(output, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
