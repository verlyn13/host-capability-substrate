---
title: P06 Provenance Experiment Plan
category: research
component: host_capability_substrate
status: proposed
version: 1.0.0
last_updated: 2026-04-27
tags: [phase-1, p06, execution-context, provenance, shell, telemetry, redaction]
priority: high
---

# P06 Provenance Experiment Plan

This plan ingests the staged external brief
`docs/host-capability-substrate/research/external/2026-04-27-p06-probe-shape.md`
as the next P06 execution plan. It is not a test result. It defines how to
close the remaining P06 gap without relying on PATH-prefix shell wrappers or
in-shell self-introspection alone.

Target ring: Ring 3 measurement/research docs. No schema, policy, or
system-config change is implied by this plan.

## Goal

Run P06 as a provenance experiment. Produce one reconciled
`ExecutionContext` record per surface, backed by three independent evidence
lanes:

| Lane | Question answered | Source of truth |
|---|---|---|
| Tool-native trace | What did the tool/controller believe it was doing? | Codex JSON events, Claude telemetry/events |
| Startup-file sentinels | What shell startup files actually affected the process? | Marker-only temporary zsh startup files |
| Host-level telemetry | What did the OS actually execute, with what parent chain? | Endpoint Security/EDR/eslogger, with DTrace-style tracing as lab fallback |

Rule: host telemetry wins for `execve` truth, sentinels win for startup-file
effects, and tool telemetry wins for tool intent. Do not collapse these into a
single "the shell did X" statement until the lanes agree.

## Run Envelope

Create a unique run id and a protected local evidence directory before
touching Claude or Codex. Raw artifacts belong under the ignored `.logs/` tree,
not in committed docs:

```sh
P06_RUN_ID="p06-$(date -u +%Y%m%dT%H%M%SZ)-$(hostname -s | shasum -a 256 | cut -c1-8)"
P06_ROOT=".logs/phase-1/shell-env/2026-04-26/p06-runs/$P06_RUN_ID"
mkdir -p "$P06_ROOT"/{tool,host,sentinel,parsed,report}
chmod 700 "$P06_ROOT"
```

Every parsed artifact should carry at least:

```json
{
  "run_id": "p06-<timestamp>-<host_hash>",
  "surface": "codex-cli-exec | claude-code-bash",
  "host": "<redacted-or-hashed>",
  "controller_version": "<captured>",
  "os_version": "<captured>",
  "evidence_lane": "tool-native | sentinel | host-telemetry",
  "redaction_policy": "no env values; command payload redacted; argv flags preserved"
}
```

Use one synthetic probe payload across all lanes. Store the raw payload only in
the protected local run directory and publish only a hash:

```sh
printf '%s' "$P06_PROBE_PAYLOAD" | shasum -a 256 > "$P06_ROOT/payload.sha256"
```

Do not collect environment values. Do not execute real user dotfiles as
evidence. Do not rely on PATH wrappers; existing P06 evidence shows absolute
`/bin/zsh` for both Codex CLI and Claude Code Bash on this host.

## Startup-File Sentinels

This lane answers only which zsh user startup files ran, in what order, and
under what shell mode. Use a temporary `ZDOTDIR`, not the user's real home
configuration:

```sh
P06_ZDOTDIR="$P06_ROOT/sentinel/zdotdir"
P06_MARKER_LOG="$P06_ROOT/sentinel/markers.ndjson"
mkdir -p "$P06_ZDOTDIR" "$P06_ROOT/sentinel/home"
chmod 700 "$P06_ZDOTDIR" "$P06_ROOT/sentinel/home"
```

Each marker file should append one marker record and nothing else. The marker
must avoid environment dumps and startup-file contents:

```zsh
{
  emulate -L zsh
  [[ -n "$P06_MARKER_LOG" ]] || return 0
  print -r -- "{\"run_id\":\"${P06_RUN_ID}\",\"file\":\"${0:t}\",\"pid\":\"$$\",\"ppid\":\"$PPID\",\"zero\":\"$0\",\"login\":\"${options[login]}\",\"interactive\":\"${options[interactive]}\",\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$P06_MARKER_LOG"
} 2>/dev/null
```

Create marker files for:

- `.zshenv`
- `.zprofile`
- `.zshrc`
- `.zlogin`
- `.zlogout`

Run local controls before involving agent tools:

| Control | Expected user startup markers |
|---|---|
| `/bin/zsh -c 'true'` | `.zshenv` |
| `/bin/zsh -lc 'true'` | `.zshenv`, `.zprofile`, `.zlogin` |
| `/bin/zsh -ic 'true'` | `.zshenv`, `.zshrc` |
| `/bin/zsh -lic 'true'` | `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` |

For actual Claude/Codex tests, `ZDOTDIR`, `P06_RUN_ID`, and
`P06_MARKER_LOG` must exist before the tool-spawned shell starts. Setting them
inside the command passed to `zsh -c` is too late for startup-file observation.

Keep user startup-file evidence separate from global startup files such as
`/etc/zshenv` and `/etc/zprofile`. The temporary `ZDOTDIR` proves user-file
behavior only.

## Tool-Native Trace

### Codex

Use `codex exec` as a scripted surface and capture the JSON event stream.
Prefer explicit settings over convenience presets:

```sh
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
```

Vary one knob at a time:

```sh
codex exec \
  --ephemeral \
  --json \
  --skip-git-repo-check \
  --sandbox workspace-write \
  -c allow_login_shell=false \
  "$P06_PROBE_PROMPT"
```

Parse Codex events into a redacted shape:

```json
{
  "surface": "codex-cli-exec",
  "tool_event_command": "/bin/zsh -lc <command_string_redacted>",
  "tool_event_source": "codex --json",
  "sandbox_mode": "workspace-write",
  "allow_login_shell": true,
  "shell_environment_policy": {
    "inherit": "captured-or-configured"
  }
}
```

Preserve executable path and flags. Redact the command payload after `-c` or
`-lc`.

### Claude

Use Claude telemetry/events for tool intent where available, not only Bash
self-introspection. Keep structural telemetry separate from content-bearing
telemetry:

```sh
CLAUDE_CODE_ENABLE_TELEMETRY=1
OTEL_METRICS_EXPORTER=none
OTEL_LOGS_EXPORTER=console
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
```

Default to structural telemetry. Only enable `OTEL_LOG_TOOL_DETAILS=1` for a
sterile synthetic run whose command payload is approved for local storage. Do
not enable content-bearing raw body logging for this investigation.

Parse Claude evidence into:

```json
{
  "surface": "claude-code-bash",
  "tool_event": "claude tool event or tool result",
  "tool_name": "Bash",
  "tool_parameters_redacted": true,
  "command_shape_if_available": "/bin/zsh -c <command_string_redacted>",
  "telemetry_detail_level": "structural | tool_details"
}
```

Permissions and sandboxing are separate concepts. Permission prompts may
explain why Bash was allowed; they do not prove the shell invocation vector.

## Host-Level Telemetry

Use host telemetry for `execve` truth. Preferred production-grade evidence is
Endpoint Security or an Endpoint Security-backed EDR that captures at least:

```json
{
  "event": "exec",
  "timestamp": "<utc>",
  "pid": 12345,
  "ppid": 12344,
  "executable_path": "/bin/zsh",
  "argv_redacted": ["/bin/zsh", "-lc", "<command_string_redacted>"],
  "cwd": "<path-or-redacted>",
  "signing_id": "<captured-if-present>",
  "team_id": "<captured-if-present>",
  "code_hash": "<captured-if-present>"
}
```

Subscribe minimally to process events:

- `exec`
- `fork`
- `exit`

`eslogger` can be used for lab reproduction if available and approved. It must
run separately from the tested controller so its own process group does not
suppress the events of interest:

```sh
sudo /usr/bin/eslogger --format json exec fork exit > "$P06_ROOT/host/eslogger.ndjson"
```

DTrace/`execsnoop`-style tracing is a tactical lab fallback, not the closure
standard. Use it only on a controlled research host or disposable VM.

## Probe Payload

The probe reports shell shape only:

```zsh
print -r -- "P06_RUN_ID=$P06_RUN_ID"
print -r -- "PID=$$"
print -r -- "PPID=$PPID"
print -r -- "ZERO=$0"
print -r -- "LOGIN=${options[login]}"
print -r -- "INTERACTIVE=${options[interactive]}"
ps -p $$ -o pid=,ppid=,comm=,args=
```

Do not run:

```sh
env
printenv
set
typeset
export
cat ~/.zshrc
cat ~/.zprofile
```

## Reconciliation Record

After each run, normalize one record per surface:

```json
{
  "run_id": "p06-<timestamp>-<host_hash>",
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

Join evidence by run id, timestamp window, process tree, executable path,
redacted argv shape, sentinel PID/PPID, and payload hash.

Where evidence conflicts, preserve the discrepancy:

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

Do not repair conflicting evidence into a cleaner story.

## Minimal Run Matrix

| Run | Surface | Config | Purpose |
|---|---|---|---|
| C0 | Local `/bin/zsh` | `-c`, `-lc`, `-ic`, `-lic` | Validate sentinel controls |
| X1 | Codex | explicit sandbox baseline | Baseline Codex shell carrier |
| X2 | Codex | `allow_login_shell=false` | Test whether login semantics are configurable |
| X3 | Codex | sterile environment policy | Test env propagation and sentinel survivability |
| H1 | Claude Bash | default | Baseline Claude Bash shell carrier |
| H2 | Claude Bash | structural telemetry only | Confirm tool events without command detail |
| H3 | Claude Bash | tool details on synthetic probe only | Capture redacted command shape |
| M1 | Host telemetry | Endpoint Security/eslogger | Confirm OS exec path, argv, parent chain |

## Closure Criteria

Close P06 only when each surface has all of the following:

1. Tool-native trace shows the tool-side command event or tool execution
   record.
2. Host telemetry confirms the actual executable path and argv vector.
3. Parent chain identifies the constructing controller far enough back to
   distinguish Claude, Codex, shell, terminal, CI, or wrapper.
4. Startup sentinels match the inferred shell class.
5. Version and config metadata are captured.
6. Redaction review confirms no env values, no raw secrets, no real
   startup-file contents, and no uncontrolled prompt/body logging.
7. Reproduction succeeds in a fresh session.

Until all seven are true, the status remains:

```text
P06 open / narrowed.
Runtime shell shape observed.
Startup-file effects partially or fully proven depending on sentinels.
Pre-exec provenance pending host-level confirmation.
```

## Do Not Do

- Do not treat `ps args` alone as authoritative.
- Do not use real `.zshrc`, `.zprofile`, or `.zshenv` as sentinels.
- Do not enable Claude content-bearing telemetry or raw API body logging for
  this investigation.
- Do not use Codex dangerous bypass modes unless the whole test is inside an
  externally isolated runner.
- Do not close P06 merely because Claude and Codex both use `/bin/zsh`.

## References

The imported brief cited these references for future verification:

- Zsh startup files: `https://zsh.sourceforge.io/Intro/intro_3.html`
- Codex CLI reference: `https://developers.openai.com/codex/cli/reference`
- Codex config reference: `https://developers.openai.com/codex/config-reference`
- Claude monitoring docs: `https://code.claude.com/docs/en/monitoring-usage`
- Claude sandboxing docs: `https://code.claude.com/docs/en/sandboxing`
- Apple Endpoint Security docs: `https://developer.apple.com/documentation/EndpointSecurity`
- Apple `es_process_t` docs: `https://developer.apple.com/documentation/endpointsecurity/es_process_t`
- `eslogger(1)`: `https://keith.github.io/xcode-man-pages/eslogger.1.html`
- Claude OTel observability: `https://code.claude.com/docs/en/agent-sdk/observability`

## Change Log

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-04-27 | Initial ingestion of `research/external/2026-04-27-p06-probe-shape.md` as the P06 three-lane provenance experiment plan. |
