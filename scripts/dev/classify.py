#!/usr/bin/env python3
# classify.py — Phase 0b interim command classifier.
#
# PHASE 0b INTERIM: rules are embedded here because canonical policy
# (tiers.yaml at system-config/policies/host-capability-substrate/) does not
# yet exist. When it materializes (ADR-0006), this classifier must be replaced
# by a consumer of the generated policy snapshot. See AGENTS.md §Hard boundaries:
# "Do not copy policy into hooks. Hooks call HCS or read the generated policy
# snapshot." This file is explicitly scoped to Phase 0b measurement only.
#
# Input: one shell-command string per invocation (argv or --command).
# Output: JSON on stdout with keys: class, reason, first_token, pipeline_segments.
#
# Classes (severity order — most severe wins across pipeline segments):
#   forbidden > write-destructive > write-host > write-local > unknown > read-safe
#
# The "unknown" class ranks above read-safe so that review attention flows to
# unclassified commands; they are the ontology-expansion signal.

from __future__ import annotations
import argparse
import json
import re
import shlex
import sys

CLASSES = [
    "forbidden",
    "write-destructive",
    "write-host",
    "write-local",
    "unknown",
    "read-safe",
    "parser-error",
]

SEVERITY = {
    "forbidden": 6,
    "write-destructive": 5,
    "write-host": 4,
    "write-local": 3,
    "unknown": 2,
    "read-safe": 1,
    "parser-error": 0,
}

# Commands whose arguments are data, not executed subcommands. When one of
# these is the first token of a segment, pattern matches inside its arguments
# do NOT upgrade severity. Guards the over-fire failure class
# (`echo 'rm -rf / is dangerous'` must classify read-safe).
STRINGY_COMMANDS = {
    "echo",
    "printf",
    "cat",
    "less",
    "more",
    "head",
    "tail",
    "rg",
    "grep",
    "ag",
    "ack",
    "jq",
    "yq",
    "awk",
    "sed",
    "cut",
    "tr",
    "sort",
    "uniq",
    "wc",
    "column",
    "paste",
    "xxd",
    "hexdump",
    "base64",
    "nl",
    "fold",
    "fmt",
    "expand",
    "unexpand",
    "diff",
    "cmp",
    "comm",
}

# Shell no-op / navigation / pure-builtin commands. Always read-safe on their
# own; in a pipeline they contribute nothing dangerous.
NOOP_COMMANDS = {
    "cd",
    "pwd",
    "pushd",
    "popd",
    "sleep",
    "true",
    "false",
    "exit",
    "return",
    "read",
    "source",
    ".",
    ":",
    "wait",
    "alias",
    "unalias",
    "set",
    "unset",
    "export",
    "declare",
    "local",
    "typeset",
    "shopt",
    "bind",
    "trap",
    "eval",  # dangerous in theory, but bare `eval` is usually benign; pipeline reveals the rest
    "let",
    "test",
    "[",
    "[[",
    "(",
    "((",
    "echo",  # also stringy; here for completeness
    "if",
    "then",
    "else",
    "elif",
    "fi",
    "for",
    "while",
    "until",
    "do",
    "done",
    "case",
    "esac",
    "function",
    "in",
    "select",
    "break",
    "continue",
}

# Commands that can mutate despite being "stringy" in some invocations.
# Checked after stringy short-circuit.
STRINGY_MUTATES = {
    ("sed", "-i"),
}

# Prefix commands that delegate to the subsequent command. Strip and recurse.
TRANSPARENT_PREFIXES = {"env", "nohup", "nice", "ionice", "time", "stdbuf", "timeout"}

FORBIDDEN_RULES = [
    (r"\bspctl\s+--master-disable\b", "disables Gatekeeper"),
    (r"\bcsrutil\s+disable\b", "disables SIP"),
    (r"\bnvram\s+boot-args\b", "boot-args mutation"),
    (r"\bsudo\s+rm\s+-rf\s+/\s*$", "rm -rf of root"),
    (r"\brm\s+-rf\s+/\s*$", "rm -rf of root"),
    (r"\brm\s+-rf\s+\"?\$HOME\"?/?\s*$", "rm -rf HOME"),
    (r"\brm\s+-rf\s+~/?\s*$", "rm -rf home"),
    (r"\blaunchctl\s+(load|unload)\b", "deprecated launchctl verbs (charter invariant 11)"),
    (r"\bbrew\s+uninstall\s+--cask\b", "cask uninstall"),
    (r"\bdseditgroup\s+-o\s+edit\s+-a\s+.*-t\s+user\s+admin\b", "group membership mutation"),
]

DESTRUCTIVE_RULES = [
    (r"\brm\s+-rf\b", "recursive delete"),
    (r"\brm\s+-[rR][fF]?\b", "recursive delete"),
    (r"\bgit\s+reset\s+--hard\b", "git hard reset"),
    (r"\bgit\s+clean\s+-[fxd]+\b", "git clean force"),
    (r"\bgit\s+push\s+(?:[^|;]*\s+)?--force\b", "force push"),
    (r"\bgit\s+push\s+(?:[^|;]*\s+)?-f\b", "force push"),
    (r"\bgit\s+branch\s+-D\b", "git branch -D"),
    (r"\bdd\s+.*\bof=/", "dd to absolute path"),
    (r">\s*/dev/sd[a-z]", "write to block device"),
    (r"\btrash\s+-rf?\b", "trash recursive"),
    (r"\bshred\b", "shred"),
]

HOST_RULES = [
    (r"\bsudo\b", "sudo prefix"),
    (r"\bbrew\s+(install|uninstall|upgrade|reinstall|tap|untap|link|unlink)\b", "brew write"),
    (r"\bmise\s+(install|use\s+-g|uninstall|plugin)\b", "mise write"),
    (r"\bnpm\s+install\s+-g\b", "global npm install"),
    (r"\bnpm\s+(uninstall|remove|rm)\s+-g\b", "global npm remove"),
    (r"\bpip\s+(install|uninstall)\s+(?!--user\b)", "system pip"),
    (r"\bpipx\s+(install|uninstall|upgrade)\b", "pipx write"),
    (r"\bcargo\s+install\b", "cargo install"),
    (r"\bgo\s+install\b", "go install"),
    (r"\bdefaults\s+write\b", "macOS defaults write"),
    (r"\bdefaults\s+delete\b", "macOS defaults delete"),
    (r"\blaunchctl\s+(bootstrap|bootout|enable|disable|kickstart|blame|remove)\b", "launchctl write (approved verbs)"),
    (r"\bsoftwareupdate\s+(-i|--install)\b", "system update"),
    (r"\bsystemextensionsctl\b", "system extension"),
    (r"\bdscl\b", "directory services"),
    (r"\bkextload\b|\bkextunload\b", "kernel extension"),
    (r"\bpfctl\s+-f\b", "packet filter reload"),
    (r"\bscutil\s+--set\b", "scutil set"),
    (r"\bpmset\b", "power management"),
    (r"\bsharing\b", "sharing service"),
    (r"\bnetworksetup\b", "network setup"),
]

LOCAL_RULES = [
    (r"\bgit\s+(add|commit|push|pull|rebase|merge|checkout|reset(?!\s+--hard)|restore|stash(?!\s+list)|tag|cherry-pick|revert|am|apply)\b", "git write-local"),
    (r"\bnpm\s+(install|i|ci|update|upgrade)\b", "local npm install"),
    (r"\bpnpm\s+(install|i|add|update)\b", "local pnpm install"),
    (r"\byarn\s+(install|add|upgrade)\b", "local yarn install"),
    (r"\bbun\s+(install|add)\b", "local bun install"),
    (r"\bpip\s+install\s+--user\b", "user pip"),
    (r"\bmv\b", "move"),
    (r"\bcp\s+-[rR]\b", "recursive copy"),
    (r"\bln\s+-s\b", "symlink"),
    (r"\btouch\b", "touch"),
    (r"\bmkdir\b", "mkdir"),
    (r"\bchmod\b", "chmod"),
    (r"\bchown\b", "chown"),
    (r"\btee\b", "tee"),
    (r"\bsed\s+-i\b", "sed in-place"),
    (r"\bawk\s+-i\s+inplace\b", "awk in-place"),
    (r"\bpython\s+-c\s+['\"].*\bopen\(.*['\"]w['\"]\)", "python write"),
    (r"(?<![<>|])>(?!>|\s*&\s*[0-9])", "redirect"),
    (r">>", "append redirect"),
]

SAFE_RULES = [
    (r"(?:^|[\s|&;])(ls|stat|file|wc|md5|md5sum|sha1|sha256|shasum|du|df|readlink|basename|dirname|realpath)\b", "read-only fs info"),
    (r"(?:^|[\s|&;])(ps|top|htop|who|whoami|uname|uptime|hostname|date|id|groups|tty)\b", "system info"),
    (r"(?:^|[\s|&;])(which|command\s+-v|type|env|printenv|locale)\b", "environment inspect"),
    (r"(?:^|[\s|&;])git\s+(status|log|diff|blame|show|branch(?!\s+-D)|remote(?:\s+-v)?|stash\s+list|config\s+--get|describe|rev-parse|rev-list|reflog|ls-files|ls-tree|cat-file)\b", "git read-only"),
    (r"(?:^|[\s|&;])curl\s+-[IsSL-]+(?!.*-[oO]\b)", "curl read"),
    (r"(?:^|[\s|&;])wget\s+--spider\b", "wget check"),
    (r"(?:^|[\s|&;])brew\s+(list|info|outdated|search|doctor|leaves|deps|uses|--prefix|--repository|shellenv|bundle\s+(check|dump|list))\b", "brew read"),
    (r"(?:^|[\s|&;])mise\s+(ls|list|current|which|settings(?!\s+set)|doctor|tasks|version|--version|env|exec)\b", "mise read"),
    (r"(?:^|[\s|&;])launchctl\s+(list|print(?:-disabled|-cache)?|dumpstate|dumpjpcategory|procinfo|getenv|hostinfo|examine|error)\b", "launchctl read"),
    (r"(?:^|[\s|&;])just\s+(--list|--list-tasks|--summary|--dry-run|-n|--show|--evaluate|--fmt\s+--check)\b", "just read"),
    (r"(?:^|[\s|&;])(docker|orb)\s+(ps|images|inspect|logs(?!\s+-f)|version|info|stats|events|history)\b", "docker read"),
    (r"(?:^|[\s|&;])kubectl\s+(get|describe|logs(?!\s+-f)|explain|version|cluster-info|config\s+view)\b", "kubectl read"),
    (r"(?:^|[\s|&;])ssh\s+-[CGT]\b", "ssh query"),
    (r"(?:^|[\s|&;])dig\b|(?:^|[\s|&;])nslookup\b|(?:^|[\s|&;])host\b", "dns query"),
    (r"(?:^|[\s|&;])ping\s+-c\s+\d", "ping bounded"),
    (r"(?:^|[\s|&;])(true|false|:)\s*$", "shell noop"),
]


def _tokenize(segment: str) -> list[str]:
    try:
        return shlex.split(segment, posix=True)
    except ValueError:
        return segment.split()


def _first_command(tokens: list[str]) -> str:
    if not tokens:
        return ""
    first = tokens[0]
    # Strip VAR=value prefixes (e.g., DEBUG=1 python foo.py).
    idx = 0
    while idx < len(tokens) and re.match(r"^[A-Z_][A-Z0-9_]*=", tokens[idx]):
        idx += 1
    if idx < len(tokens):
        return tokens[idx]
    return first


def _match_first(rules, text: str):
    for pat, reason in rules:
        if re.search(pat, text):
            return reason
    return None


def _classify_segment(segment: str) -> tuple[str, str] | None:
    segment = segment.strip()
    if not segment:
        return None

    tokens = _tokenize(segment)
    if not tokens:
        return None

    first = _first_command(tokens)

    # Recurse through transparent prefixes.
    if first in TRANSPARENT_PREFIXES and len(tokens) > 1:
        idx = 1
        while idx < len(tokens) and tokens[idx].startswith("-"):
            idx += 1
        if idx < len(tokens):
            remainder = " ".join(shlex.quote(t) for t in tokens[idx:])
            sub = _classify_segment(remainder)
            if sub:
                return sub

    # Shell builtins / navigation / no-ops: read-safe.
    if first in NOOP_COMMANDS:
        return ("read-safe", f"{first} is builtin/noop")

    # Stringy short-circuit: arguments are data, not commands — EXCEPT for
    # known mutating flag combos (sed -i, awk -i inplace).
    if first in STRINGY_COMMANDS:
        if first == "sed" and "-i" in tokens:
            return ("write-local", "sed in-place")
        if first == "awk" and "-i" in tokens and "inplace" in tokens:
            return ("write-local", "awk in-place")
        if first == "jq" and "-i" in tokens:
            return ("write-local", "jq in-place")
        return ("read-safe", f"{first} consumes args as data")

    # Forbidden rules checked BEFORE sudo short-circuit: `sudo spctl --master-disable`
    # must classify forbidden, not write-host.
    r = _match_first(FORBIDDEN_RULES, segment)
    if r:
        return ("forbidden", r)

    # sudo short-circuit: privileged regardless of what follows (unless forbidden
    # already matched above).
    if first == "sudo":
        return ("write-host", "sudo prefix")

    # Check remaining rule bands in severity order.
    r = _match_first(DESTRUCTIVE_RULES, segment)
    if r:
        return ("write-destructive", r)
    r = _match_first(HOST_RULES, segment)
    if r:
        return ("write-host", r)
    r = _match_first(LOCAL_RULES, segment)
    if r:
        return ("write-local", r)
    r = _match_first(SAFE_RULES, segment)
    if r:
        return ("read-safe", r)
    return ("unknown", "no rule match")


def classify(command: str) -> dict:
    if command is None or not command.strip():
        return {"class": "parser-error", "reason": "empty", "first_token": "", "segments": []}

    s = command.strip()

    # Split on pipeline operators AND command-substitution boundaries.
    # Extract $(...) and `...` subshells and classify them separately.
    subshells: list[str] = []
    # $(...) — handle one level of nesting.
    def _collect(pattern, text):
        out = []
        i = 0
        while True:
            m = re.search(pattern, text[i:])
            if not m:
                break
            out.append(m.group(1))
            i += m.end()
        return out

    subshells.extend(_collect(r"\$\(([^$()]*)\)", s))
    subshells.extend(_collect(r"`([^`]*)`", s))

    segments = re.split(r"\s*(?:\|\||&&|[|;&\n])\s*", s)

    results: list[tuple[str, str]] = []
    for seg in segments + subshells:
        v = _classify_segment(seg)
        if v is not None:
            results.append(v)

    if not results:
        return {
            "class": "unknown",
            "reason": "no classifiable segment",
            "first_token": _first_command(_tokenize(s)),
            "segments": segments,
        }

    results.sort(key=lambda r: SEVERITY.get(r[0], 0), reverse=True)
    winner_cls, winner_reason = results[0]

    return {
        "class": winner_cls,
        "reason": winner_reason,
        "first_token": _first_command(_tokenize(s)),
        "segments": segments,
        "subshells": subshells,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Classify a shell command (Phase 0b interim).")
    parser.add_argument("--command", help="The command string to classify.")
    parser.add_argument(
        "--batch",
        action="store_true",
        help="Read JSONL from stdin; each line has key 'command'. Emit JSONL on stdout.",
    )
    parser.add_argument(
        "--classes",
        action="store_true",
        help="Print known classes in severity order and exit.",
    )
    args, extra = parser.parse_known_args()

    if args.classes:
        for c in CLASSES:
            print(c)
        return 0

    if args.batch:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                sys.stdout.write(json.dumps({"class": "parser-error", "reason": "bad-json-input", "input": line[:120]}) + "\n")
                continue
            cmd = record.get("command", "")
            verdict = classify(cmd)
            out = {**record, **{f"classified_{k}": v for k, v in verdict.items()}}
            sys.stdout.write(json.dumps(out) + "\n")
        return 0

    cmd = args.command
    if cmd is None and extra:
        cmd = " ".join(extra)
    if cmd is None:
        print("error: --command is required (or --batch for JSONL input)", file=sys.stderr)
        return 2

    verdict = classify(cmd)
    print(json.dumps(verdict, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
