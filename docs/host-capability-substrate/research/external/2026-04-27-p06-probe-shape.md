Run this as a **provenance experiment**, not as ordinary debugging. The goal is to produce one reconciled `ExecutionContext` record per surface, backed by three independent evidence lanes:

| Lane                   | Question answered                                         | Source of truth                                              |
| ---------------------- | --------------------------------------------------------- | ------------------------------------------------------------ |
| Tool-native trace      | What did the tool/controller believe it was doing?        | Codex JSON events, Claude OTel/events                        |
| Startup-file sentinels | What shell startup files actually affected the process?   | Marker-only `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` logs |
| Host-level telemetry   | What did the OS actually execute, with what parent chain? | Endpoint Security / eslogger / EDR / DTrace fallback         |

The professional rule is: **host telemetry wins for `execve` truth, sentinels win for startup-file effects, and tool telemetry wins for tool intent.** Do not collapse these into one “the shell did X” statement until they agree.

---

## 1. Establish the run envelope first

Create a unique run ID and a sterile workspace before touching Claude or Codex:

```sh
export P06_RUN_ID="p06-2026-04-26T000000Z-hostA"
export P06_ROOT="$PWD/p06-runs/$P06_RUN_ID"
mkdir -p "$P06_ROOT"/{tool,host,sentinel,parsed,report}
chmod 700 "$P06_ROOT"
```

Every artifact should carry:

```json
{
  "run_id": "p06-2026-04-26T000000Z-hostA",
  "surface": "codex-cli-exec | claude-code-bash",
  "host": "<redacted-or-hashed>",
  "controller_version": "<captured>",
  "os_version": "<captured>",
  "evidence_lane": "tool-native | sentinel | host-telemetry",
  "redaction_policy": "no env values; command payload redacted; argv flags preserved"
}
```

Use a single synthetic probe payload across all lanes. Store the raw probe locally only in the protected run directory; publish only an HMAC or SHA-256 of it.

```sh
printf '%s' "$P06_PROBE_PAYLOAD" | shasum -a 256 > "$P06_ROOT/payload.sha256"
```

Do **not** collect environment values. Do **not** execute real user dotfiles as evidence. Do **not** rely on PATH wrappers, since your existing evidence already shows absolute `/bin/zsh`.

---

## 2. Build the startup-file sentinels

The sentinel lane should answer only: **which zsh startup files ran, in what order, under what shell mode?**

Use a temporary `ZDOTDIR`, not the user’s real home configuration:

```sh
export P06_ZDOTDIR="$P06_ROOT/sentinel/zdotdir"
export P06_MARKER_LOG="$P06_ROOT/sentinel/markers.ndjson"

mkdir -p "$P06_ZDOTDIR"
chmod 700 "$P06_ZDOTDIR"

make_marker() {
  local file="$1"
  cat > "$P06_ZDOTDIR/$file" <<'EOF'
{
  emulate -L zsh
  [[ -n "$P06_MARKER_LOG" ]] || return 0
  print -r -- "{\"run_id\":\"${P06_RUN_ID}\",\"file\":\"${0:t}\",\"pid\":\"$$\",\"ppid\":\"$PPID\",\"zero\":\"$0\",\"login\":\"${options[login]}\",\"interactive\":\"${options[interactive]}\",\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$P06_MARKER_LOG"
} 2>/dev/null
EOF
  chmod 600 "$P06_ZDOTDIR/$file"
}

make_marker .zshenv
make_marker .zprofile
make_marker .zshrc
make_marker .zlogin
make_marker .zlogout
```

This avoids secrets and avoids false positives from real shell customizations. zsh’s documented model is exactly what you are testing: `.zshenv` is sourced on all invocations unless `-f` is used; `.zshrc` is for interactive shells; `.zprofile` and `.zlogin` are login-shell files, with `.zprofile` before `.zshrc` and `.zlogin` after it. ([Zsh][1])

Run local controls before involving the tools:

```sh
env -i \
  HOME="$P06_ROOT/sentinel/home" \
  ZDOTDIR="$P06_ZDOTDIR" \
  P06_RUN_ID="$P06_RUN_ID" \
  P06_MARKER_LOG="$P06_MARKER_LOG" \
  /bin/zsh -c 'true'

env -i \
  HOME="$P06_ROOT/sentinel/home" \
  ZDOTDIR="$P06_ZDOTDIR" \
  P06_RUN_ID="$P06_RUN_ID" \
  P06_MARKER_LOG="$P06_MARKER_LOG" \
  /bin/zsh -lc 'true'

env -i \
  HOME="$P06_ROOT/sentinel/home" \
  ZDOTDIR="$P06_ZDOTDIR" \
  P06_RUN_ID="$P06_RUN_ID" \
  P06_MARKER_LOG="$P06_MARKER_LOG" \
  /bin/zsh -ic 'true'

env -i \
  HOME="$P06_ROOT/sentinel/home" \
  ZDOTDIR="$P06_ZDOTDIR" \
  P06_RUN_ID="$P06_RUN_ID" \
  P06_MARKER_LOG="$P06_MARKER_LOG" \
  /bin/zsh -lic 'true'
```

Expected control results:

| Invocation      | Expected user startup markers               |
| --------------- | ------------------------------------------- |
| `/bin/zsh -c`   | `.zshenv`                                   |
| `/bin/zsh -lc`  | `.zshenv`, `.zprofile`, `.zlogin`           |
| `/bin/zsh -ic`  | `.zshenv`, `.zshrc`                         |
| `/bin/zsh -lic` | `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` |

For the actual Claude/Codex tests, the important detail is that `ZDOTDIR`, `P06_RUN_ID`, and `P06_MARKER_LOG` must exist **before the tool-spawned shell starts**. Setting them inside the command being passed to `zsh -c` is too late for startup-file observation.

Also separate **user startup files** from **global startup files**. The temporary `ZDOTDIR` proves user-file behavior. It does not prove whether `/etc/zprofile`, `/etc/zshenv`, or other global files did anything. If global-file effects matter, inspect them separately or reproduce inside a disposable VM with marker-only global files.

---

## 3. Capture Codex tool-native trace

For Codex, use `codex exec` as a non-interactive, scripted surface and capture both stdout and stderr. Current Codex docs describe `codex exec` as the CI/scripted mode, `--ephemeral` as avoiding persisted session rollout files, and `--json` / `--experimental-json` as newline-delimited JSON events. ([OpenAI Developers][2])

Use explicit configuration. Do not use `--full-auto` for the primary provenance run, because it is a convenience preset that sets workspace-write sandboxing and on-request approvals rather than a narrow experiment control. ([OpenAI Developers][2])

Suggested run matrix:

```sh
# Codex A: default-ish, but explicit sandbox
env \
  HOME="$HOME" \
  ZDOTDIR="$P06_ZDOTDIR" \
  P06_RUN_ID="$P06_RUN_ID" \
  P06_MARKER_LOG="$P06_MARKER_LOG" \
  codex exec \
    --ephemeral \
    --json \
    --skip-git-repo-check \
    --sandbox workspace-write \
    "$P06_PROBE_PROMPT" \
    > "$P06_ROOT/tool/codex-A.stdout" \
    2> "$P06_ROOT/tool/codex-A.stderr"

# Codex B: force non-login shell semantics if the setting is honored
env \
  HOME="$HOME" \
  ZDOTDIR="$P06_ZDOTDIR" \
  P06_RUN_ID="$P06_RUN_ID" \
  P06_MARKER_LOG="$P06_MARKER_LOG" \
  codex exec \
    --ephemeral \
    --json \
    --skip-git-repo-check \
    --sandbox workspace-write \
    -c allow_login_shell=false \
    "$P06_PROBE_PROMPT" \
    > "$P06_ROOT/tool/codex-B.stdout" \
    2> "$P06_ROOT/tool/codex-B.stderr"
```

Codex currently documents `allow_login_shell` as controlling whether shell-based tools may use login-shell semantics, defaulting to `true`; it also documents `shell_environment_policy` controls such as `inherit`, `include_only`, `exclude`, and `set`. Those are exactly the knobs to vary after the baseline run. ([OpenAI Developers][3])

For Codex, parse the JSON stream into:

```json
{
  "surface": "codex-cli-exec",
  "tool_event_command": "/bin/zsh -lc <command_string_redacted>",
  "tool_event_source": "codex --json",
  "sandbox_mode": "workspace-write",
  "approval_mode": "captured-or-configured",
  "allow_login_shell": true,
  "shell_environment_policy": {
    "inherit": "captured-or-configured"
  }
}
```

The parser should preserve executable path and flag form, but redact the command payload after `-c` or `-lc`.

---

## 4. Capture Claude tool-native trace

For Claude Code, use OpenTelemetry rather than trying to infer everything from the Bash process itself. Claude Code documents OTel support for metrics, logs/events, and optional traces, and exposes tool activity through telemetry when configured. ([Claude][4])

Start with structural telemetry only:

```sh
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=none
export OTEL_LOGS_EXPORTER=console
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"

# First pass: leave detailed tool content off.
unset OTEL_LOG_TOOL_DETAILS
unset OTEL_LOG_TOOL_CONTENT
unset OTEL_LOG_USER_PROMPTS
```

Only enable detailed tool logging for a sterile synthetic run:

```sh
export OTEL_LOG_TOOL_DETAILS=1
```

That variable can include Bash commands, MCP server/tool names, skill names, file paths, URLs, search patterns, and other tool inputs, so it should be used only when the probe command is synthetic and approved for storage. ([Claude][4])

For Claude, parse out:

```json
{
  "surface": "claude-code-bash",
  "tool_event": "claude_code.tool or claude_code.tool_result",
  "tool_name": "Bash",
  "tool_parameters_redacted": true,
  "command_shape_if_available": "/bin/zsh -c <command_string_redacted>",
  "telemetry_detail_level": "structural | tool_details"
}
```

Keep Claude permissions and sandboxing conceptually separate. Claude’s docs distinguish permissions, which govern which tools may run, from sandboxing, which is OS-level enforcement for Bash and child processes. They also state that Read/Edit deny rules do not stop equivalent access through Bash, such as `cat .env`; OS-level sandboxing is the enforcement layer for subprocess access. ([Claude][5])

That matters for this investigation: permissions may explain why a Bash call was allowed, but they do not prove the shell invocation vector.

---

## 5. Capture host-level process telemetry

Use host telemetry to answer the hard question: **what did the OS actually execute?**

On macOS, the professional path is Endpoint Security or an EDR backed by Endpoint Security. Apple describes Endpoint Security as a C API for monitoring system events, and Apple’s system-extension model lets endpoint-security solutions extend macOS without kernel-level access. ([Apple Developer][6])

### Preferred production-grade lane

Use an Endpoint Security client or EDR that captures at least:

```json
{
  "event": "exec",
  "timestamp": "...",
  "pid": 12345,
  "ppid": 12344,
  "parent_audit_token": "<redacted-or-hash>",
  "responsible_audit_token": "<redacted-or-hash>",
  "executable_path": "/bin/zsh",
  "argv_redacted": ["/bin/zsh", "-lc", "<command_string_redacted>"],
  "cwd": "<path-or-redacted>",
  "signing_id": "<captured-if-present>",
  "team_id": "<captured-if-present>",
  "code_hash": "<captured-if-present>"
}
```

Apple’s Endpoint Security process structures expose process information such as PID, executable, audit token, and signing identifier; practical process monitors built on Endpoint Security can also capture process arguments and code-signing information. ([Apple Developer][7])

Subscribe minimally:

```text
EXEC
FORK
EXIT
```

You do not need full file monitoring for P06 unless you are separately proving access to startup files.

### Lab-grade lane: `eslogger`

For a lab reproduction, `eslogger` is a useful bridge because it interfaces with Endpoint Security and can log events like `exec`, `fork`, and `exit` as JSON lines. It must run as superuser and needs Full Disk Access for the responsible process; its man page also warns that it is not an API and has no schema-stability guarantee, so treat it as lab evidence, not a long-term production collector. ([Keith's GitHub Pages][8])

Run it from a separate terminal/session before launching Claude or Codex:

```sh
sudo /usr/bin/eslogger --format json exec fork exit \
  > "$P06_ROOT/host/eslogger.ndjson"
```

Do not pipe it through a complex filter in the same process group as the tested controller. `eslogger` suppresses events for processes in its own process group to avoid feedback loops, so keep the collector and the tested tool launch separated. ([Keith's GitHub Pages][8])

### DTrace fallback

DTrace or `execsnoop`-style tracing is a tactical lab fallback, not the closure standard. Use it only in a disposable VM or a controlled research host. The closure artifact should prefer Endpoint Security/EDR evidence because that is the modern macOS process-event path.

---

## 6. Use one probe payload everywhere

The probe should report shell shape without reading secrets:

```zsh
print -r -- "P06_RUN_ID=$P06_RUN_ID"
print -r -- "PID=$$"
print -r -- "PPID=$PPID"
print -r -- "ZERO=$0"
print -r -- "LOGIN=${options[login]}"
print -r -- "INTERACTIVE=${options[interactive]}"
ps -p $$ -o pid=,ppid=,comm=,args=
```

Do **not** include:

```sh
env
printenv
set
typeset
export
cat ~/.zshrc
cat ~/.zprofile
```

The point is to capture the shell’s runtime shape and correlate it with host `exec` evidence, not to dump ambient state.

---

## 7. Reconcile the three lanes

After each run, build a normalized record:

```json
{
  "run_id": "p06-2026-04-26T000000Z-hostA",
  "surface": "codex-cli-exec",
  "tool_native": {
    "source": "codex --json",
    "reported_command": "/bin/zsh -lc <command_string_redacted>",
    "confidence": "high-for-tool-intent"
  },
  "sentinels": {
    "markers_seen": [".zshenv", ".zprofile", ".zlogin"],
    "inferred_startup_class": "login non-interactive",
    "confidence": "high-for-user-startup-files"
  },
  "host_telemetry": {
    "source": "Endpoint Security",
    "exec_path": "/bin/zsh",
    "argv": ["/bin/zsh", "-lc", "<command_string_redacted>"],
    "parent_chain": ["<controller>", "<tool>", "/bin/zsh"],
    "confidence": "high-for-exec-truth"
  },
  "assessment": {
    "shell_binary": "/bin/zsh",
    "flag_form": "-lc",
    "login_semantics": "confirmed",
    "interactive": false,
    "path_wrapper_interception": "not-applicable-bypassed-by-absolute-path",
    "remaining_gap": []
  }
}
```

Join records by:

1. `P06_RUN_ID`
2. timestamp window
3. process tree
4. executable path
5. redacted argv shape
6. sentinel marker PID/PPID when available
7. payload hash/HMAC

Where evidence conflicts, record both views:

```json
{
  "discrepancy": "tool reports -c; sentinel shows login semantics",
  "host_exec_truth": "/bin/zsh -c <redacted>",
  "startup_truth": ".zshenv,.zprofile,.zlogin observed",
  "possible_explanations": [
    "argv0 login-shell form",
    "parent set login shell semantics without visible -l",
    "shell option changed by wrapper/controller",
    "ps truncation or observation race"
  ],
  "status": "open-until-host-parent-argv-reviewed"
}
```

Do not “repair” the data into a cleaner story.

---

## 8. Run matrix

Use a small matrix with one variable changed at a time:

| Run | Surface          | Config                                    | Purpose                                         |
| --- | ---------------- | ----------------------------------------- | ----------------------------------------------- |
| C0  | Local `/bin/zsh` | `-c`, `-lc`, `-ic`, `-lic`                | Validate sentinel controls                      |
| X1  | Codex            | default / explicit sandbox                | Baseline Codex shell carrier                    |
| X2  | Codex            | `allow_login_shell=false`                 | Test whether login semantics are configurable   |
| X3  | Codex            | sterile environment policy                | Test env propagation and sentinel survivability |
| H1  | Claude Bash      | default                                   | Baseline Claude Bash shell carrier              |
| H2  | Claude Bash      | OTel structural only                      | Confirm tool events without command detail      |
| H3  | Claude Bash      | OTel tool details on synthetic probe only | Capture redacted command shape                  |
| M1  | Host telemetry   | Endpoint Security / eslogger              | Confirm OS exec path, argv, parent chain        |

Codex supports inline `-c key=value` overrides, and the docs state command-line overrides take precedence for an invocation, so use command-line config for experiment repeatability rather than relying on ambient `~/.codex/config.toml`. ([OpenAI Developers][2])

---

## 9. Closure criteria

Close the P06 gap only when each surface has all of the following:

1. **Tool-native trace** shows the tool-side command event or tool execution record.
2. **Host telemetry** confirms the actual executable path and argv vector.
3. **Parent chain** identifies the constructing controller far enough back to distinguish Claude, Codex, shell, terminal, CI, or wrapper.
4. **Startup sentinels** match the inferred shell class.
5. **Version/config metadata** is captured.
6. **Redaction review** confirms no env values, no raw secrets, no real startup-file contents, and no uncontrolled prompt/body logging.
7. **Reproduction** succeeds in a fresh session.

Until all seven are true, mark the finding:

```text
P06 open / narrowed.
Runtime shell shape observed.
Startup-file effects partially or fully proven depending on sentinels.
Pre-exec provenance pending host-level confirmation.
```

---

## 10. What not to do

Do not treat `ps args` alone as authoritative; it is useful but not sufficient.

Do not use real `.zshrc`, `.zprofile`, or `.zshenv` as sentinels. Claude’s own sandboxing docs warn that broad write access to shell configuration files such as `.zshrc` can create code-execution risk in other contexts. ([Claude][5])

Do not enable Claude `OTEL_LOG_TOOL_CONTENT` or raw API body logging for this investigation. Claude documents those as content-bearing telemetry paths, including full tool input/output bodies or full API request/response bodies depending on the variable. ([Claude][9])

Do not use Codex `--dangerously-bypass-approvals-and-sandbox` for this unless the whole test is inside an isolated runner; Codex documents that mode as bypassing approvals and sandboxing and warns to use it only inside an externally hardened or isolated environment. ([OpenAI Developers][2])

Do not close the issue merely because Claude and Codex both use `/bin/zsh`. The professional conclusion is narrower: **absolute shell path is confirmed on this host; flag form, login semantics, startup-file exposure, and parent construction are per-surface `ExecutionContext` properties.**

[1]: https://zsh.sourceforge.io/Intro/intro_3.html "An Introduction to the Z Shell - Startup Files"
[2]: https://developers.openai.com/codex/cli/reference "Command line options – Codex CLI | OpenAI Developers"
[3]: https://developers.openai.com/codex/config-reference "Configuration Reference – Codex | OpenAI Developers"
[4]: https://code.claude.com/docs/en/monitoring-usage "Monitoring - Claude Code Docs"
[5]: https://code.claude.com/docs/en/sandboxing "Sandboxing - Claude Code Docs"
[6]: https://developer.apple.com/documentation/EndpointSecurity?utm_source=chatgpt.com "Endpoint Security | Apple Developer Documentation"
[7]: https://developer.apple.com/documentation/endpointsecurity/es_process_t?utm_source=chatgpt.com "es_process_t | Apple Developer Documentation"
[8]: https://keith.github.io/xcode-man-pages/eslogger.1.html?utm_source=chatgpt.com "eslogger(1)"
[9]: https://code.claude.com/docs/en/agent-sdk/observability "Observability with OpenTelemetry - Claude Code Docs"
