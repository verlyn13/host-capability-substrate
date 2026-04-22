#!/usr/bin/env bash
# install-launchd-measure.sh — render and install the Phase 0b measurement
# LaunchAgent. Runs daily via StartCalendarInterval, driving `just measure`
# + `just classify` + `just confusion`.
#
# Install:   scripts/install/install-launchd-measure.sh install
# Uninstall: scripts/install/install-launchd-measure.sh uninstall
# Status:    scripts/install/install-launchd-measure.sh status
#
# NEVER uses launchctl load/unload — deprecated, charter invariant 11 forbids.
# Uses only bootstrap/bootout/print (domain: gui/<uid>).

set -euo pipefail

LABEL="${HCS_MEASURE_LABEL:-com.jefahnierocks.host-capability-substrate.measure}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HCS_ROOT="$(cd "$HERE/../.." && pwd)"
TEMPLATE="$HERE/../launchd/${LABEL}.plist.tmpl"
LAUNCHAGENTS="$HOME/Library/LaunchAgents"
TARGET="$LAUNCHAGENTS/${LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/host-capability-substrate"

# Resolve just binary (prefer mise if available).
resolve_just() {
  if command -v mise >/dev/null 2>&1; then
    if mise which just >/dev/null 2>&1; then
      mise which just
      return 0
    fi
  fi
  if command -v just >/dev/null 2>&1; then
    command -v just
    return 0
  fi
  echo "error: just binary not found in PATH or via mise" >&2
  return 1
}

render() {
  local just_bin
  just_bin="$(resolve_just)"
  mkdir -p "$LAUNCHAGENTS" "$LOG_DIR"
  if [ ! -f "$TEMPLATE" ]; then
    echo "✗ template missing: $TEMPLATE" >&2
    exit 1
  fi
  # Substitute tokens.
  sed \
    -e "s#{{LABEL}}#${LABEL}#g" \
    -e "s#{{HCS_ROOT}}#${HCS_ROOT}#g" \
    -e "s#{{LOG_DIR}}#${LOG_DIR}#g" \
    -e "s#{{JUST_BIN}}#${just_bin}#g" \
    "$TEMPLATE" > "$TARGET"
  # Validate plist.
  if ! plutil -lint "$TARGET" >/dev/null; then
    echo "✗ plist invalid after render: $TARGET" >&2
    exit 1
  fi
  echo "  ✓ rendered $TARGET"
  echo "  ✓ just: $just_bin"
  echo "  ✓ log dir: $LOG_DIR"
}

do_install() {
  render
  local uid domain_target
  uid="$(id -u)"
  domain_target="gui/${uid}/${LABEL}"
  # bootout first in case an older copy is present.
  launchctl bootout "gui/${uid}" "$TARGET" 2>/dev/null || true
  launchctl bootstrap "gui/${uid}" "$TARGET"
  echo "  ✓ bootstrapped $domain_target"
  launchctl print "$domain_target" >/dev/null 2>&1 && echo "  ✓ verified $domain_target" || true
  echo ""
  echo "Daily measurement will now run at 09:15 local time."
  echo "Logs: $LOG_DIR/measure.stdout.log, measure.stderr.log"
  echo "To trigger manually: launchctl kickstart -k $domain_target"
}

do_uninstall() {
  local uid domain_target
  uid="$(id -u)"
  domain_target="gui/${uid}/${LABEL}"
  if launchctl print "$domain_target" >/dev/null 2>&1; then
    launchctl bootout "gui/${uid}" "$TARGET" 2>/dev/null || true
    echo "  ✓ bootout $domain_target"
  else
    echo "  ⏸  $domain_target not loaded"
  fi
  if [ -f "$TARGET" ]; then
    rm -f "$TARGET"
    echo "  ✓ removed $TARGET"
  fi
}

do_status() {
  local uid domain_target
  uid="$(id -u)"
  domain_target="gui/${uid}/${LABEL}"
  if [ -f "$TARGET" ]; then
    echo "plist: $TARGET (present)"
  else
    echo "plist: not installed"
  fi
  if launchctl print "$domain_target" >/dev/null 2>&1; then
    echo "launchd: loaded"
    launchctl print "$domain_target" | grep -E '^\s+(state|last exit code|program arguments)' || true
  else
    echo "launchd: not loaded"
  fi
  echo "last measure partition:"
  ls -1 "$HCS_ROOT/.logs/phase-0/" 2>/dev/null | tail -3 | sed 's/^/  /' || true
}

cmd="${1:-status}"
case "$cmd" in
  install) do_install ;;
  uninstall) do_uninstall ;;
  status) do_status ;;
  render) render ;;
  *)
    echo "usage: $0 {install|uninstall|status|render}"
    exit 2
    ;;
esac
