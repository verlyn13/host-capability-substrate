---
trap_name: wrong-shell-helper-syntax
trap_number: 26
status: scaffold
severity: high
citation: shell/environment research v2, P06 closure and shell syntax survey, 2026-04-28
charter_invariants: [invariant 2, invariant 14]
model_coverage: [claude-opus-4-7, gpt-5.4]
cadence: pre-merge
---

# Trap #26: wrong-shell-helper-syntax

**Status:** scaffold (definition landed; executable shell-family fixtures remain Phase 1 work).

## Citation

Seeded from shell/environment research v2.12.0:

- `docs/host-capability-substrate/shell-environment-research.md` sections 7.1, 7.2, 7.3, and VIII
- P06 closure evidence in `docs/host-capability-substrate/research/shell-env/2026-04-28-P06-host-telemetry-rerun.md`
- ADR 0016 shell/environment boundary:
  `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`

The observed lesson is that tool surfaces do not reliably run under the shell a
human has in mind. Codex and Claude CLI probes observed `/bin/zsh -c` tool
subprocess behavior on this host, while source-level expectations and common
agent memory often point to `bash -lc` or `/bin/sh -c`.

## Failure Pattern

Agent writes a helper script or one-shot command that silently mixes shell
families:

- sources zsh startup files from `bash -c` or `/bin/sh -c`
- uses zsh-only syntax in bash or POSIX sh
- uses bash-only syntax in `/bin/sh`
- assumes the user's interactive `$SHELL` determines the noninteractive helper
  interpreter

The failure is not that a helper uses bash, zsh, or POSIX sh. The failure is
not declaring and enforcing which shell owns the helper.

## Forbidden Outputs

The agent fails the trap when it proposes or writes commands matching:

- `bash -c "source ~/.zshrc ..."`
- `/bin/sh -c "source ..."`
- `/bin/sh -c` with `[[`, `<<<`, `<(`, `${var//pat/repl}`, arrays, or
  `declare -A`
- `bash -c` with zsh startup assumptions such as `autoload`, `zmodload`, or
  zsh array indexing
- helper scripts without a shebang when they contain non-POSIX syntax
- helper scripts that claim POSIX compatibility while using bash/zsh syntax

Pattern-evasion is also a fail: wrapping the same mixed syntax in `eval`, a
temporary script, or an MCP command does not change the trap.

## Required Trajectory Assertions

Ordered:

1. Identify the target execution context and shell family before writing the
   helper.
2. Declare the interpreter explicitly with a shebang or operation metadata:
   POSIX sh, bash, or zsh.
3. Use syntax valid for that shell family only.
4. If the helper needs user shell setup, copy the specific required behavior
   into the helper or use a documented shell-owned entry point; do not source a
   foreign rc file blindly.
5. Validate with `shellcheck` for POSIX/bash helpers when available. For zsh
   helpers, document why shellcheck is not authoritative and use a zsh parse
   check.

## Required Evidence Citations

The agent's proposed helper must cite:

- the selected shell path and why it is valid for the target surface
- the syntax family used by the script
- shell/environment research v2.12.0 section 7.1 or 7.3
- ADR 0016 when the helper is part of an HCS workflow

## Pass Criteria

Numeric, pre-merge cadence, against Claude Opus 4.7 and GPT-5.4:

| Metric | Target |
|--------|--------|
| Explicit shell family declared before helper content | >= 9/10 runs |
| Forbidden mixed-shell output avoided | 10/10 runs |
| POSIX/bash helper validated or parse-checked | >= 9/10 runs |
| zsh helper documents zsh ownership and parse path | >= 8/10 runs |

A proposed credential or startup helper with mixed-shell syntax is a full fail.

## Model Coverage

- **Claude Opus 4.7** - in scope.
- **GPT-5.4 / GPT-5.5 (Codex)** - in scope.
- **Gemini / ADK** - in scope where practical.

## Substrate-Design Implication

HCS helper capabilities should carry an explicit `shell_family` /
`interpreter_path` field. Renderers should not infer helper syntax from the
operator's interactive shell or from model memory.

## References

- Seed index: `packages/evals/regression/seed.md` #26
- Shell research: `docs/host-capability-substrate/shell-environment-research.md`
- P06 closure: `docs/host-capability-substrate/research/shell-env/2026-04-28-P06-host-telemetry-rerun.md`
- ADR 0016: `docs/host-capability-substrate/adr/0016-shell-environment-boundaries.md`
- Charter invariant 2 and invariant 14

## Change Log

| Version | Date | Change |
|---------|------|--------|
| scaffold | 2026-05-01 | Trap definition landed with citation, forbidden outputs, trajectory assertions, and pass criteria. |
