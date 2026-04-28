#!/bin/bash
# hcs-shell-logger.sh — redaction-safe shell invocation logger for P06.
#
# This script is intended to be symlinked or copied to a controlled wrapper path
# during an approved P06 run. It logs invocation shape, then execs the real
# shell with the original argv. It must not log environment values or command
# strings passed to shell -c forms.

set -euo pipefail

real_shell="${HCS_SHELL_LOGGER_REAL_SHELL:-/bin/bash}"
log_path="${HCS_SHELL_LOGGER_LOG:-${HOME:-/tmp}/Library/Logs/host-capability-substrate/shell-wrapper.jsonl}"

if [ "$real_shell" = "$0" ]; then
  echo "hcs-shell-logger: refusing to exec itself as the real shell" >&2
  exit 126
fi

json_escape() {
  local s=${1-}
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

append_json_string() {
  printf '"%s"' "$(json_escape "$1")"
}

is_shell_flag() {
  case "$1" in
    -c | -l | -i | -s | -lc | -cl | -lic | -ilc | -lci | -cli | -cil | -icl)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

flag_contains_command() {
  case "$1" in
    -*c*) return 0 ;;
    *) return 1 ;;
  esac
}

arg_shape_json() {
  local expect_command=0
  local first=1
  local arg kind

  printf '['
  for arg in "$@"; do
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0

    if [ "$expect_command" -eq 1 ]; then
      kind="command_string_redacted"
      expect_command=0
    elif is_shell_flag "$arg"; then
      kind="shell_flag:${arg}"
      if flag_contains_command "$arg"; then
        expect_command=1
      fi
    elif [[ "$arg" == -* ]]; then
      kind="flag_redacted"
    elif [[ "$arg" == */* ]]; then
      kind="path_like_redacted"
    elif [ -z "$arg" ]; then
      kind="empty"
    else
      kind="word_redacted"
    fi

    append_json_string "$kind"
  done
  printf ']'
}

shell_flags_json() {
  local first=1
  local arg

  printf '['
  for arg in "$@"; do
    if is_shell_flag "$arg"; then
      if [ "$first" -eq 0 ]; then
        printf ','
      fi
      first=0
      append_json_string "$arg"
    fi
  done
  printf ']'
}

write_log() {
  local cwd line log_dir ts
  cwd="$(pwd -P)"
  log_dir="$(dirname "$log_path")"
  mkdir -p "$log_dir"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  line="$(
    printf '{"schema_version":"1.0.0"'
    printf ',"tool":"hcs-shell-logger"'
    printf ',"ts":'
    append_json_string "$ts"
    printf ',"pid":%s' "$$"
    printf ',"ppid":%s' "$PPID"
    printf ',"cwd":'
    append_json_string "$cwd"
    printf ',"argv0":'
    append_json_string "$0"
    printf ',"real_shell":'
    append_json_string "$real_shell"
    printf ',"arg_count":%s' "$#"
    printf ',"shell_flags":'
    shell_flags_json "$@"
    printf ',"arg_shape":'
    arg_shape_json "$@"
    printf '}'
  )"
  printf '%s\n' "$line" >>"$log_path"
}

if [ "${HCS_SHELL_LOGGER_DISABLE:-0}" != "1" ]; then
  write_log "$@"
fi

exec "$real_shell" "$@"
