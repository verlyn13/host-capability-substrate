#!/usr/bin/env bash
# install-launchd.sh — render and install the HCS LaunchAgent.
#
# NOT YET FUNCTIONAL — installs nothing in Phase 0a since the kernel binary
# does not yet exist. Preserved as scaffold so the plist template path and
# install procedure are visible from commit 1.
#
# Phase 3+ when kernel is buildable: this script renders
# scripts/launchd/com.jefahnierocks.host-capability-substrate.plist.tmpl,
# installs it to ~/Library/LaunchAgents/, and bootstraps it.

set -euo pipefail

LABEL="${HCS_LAUNCH_LABEL:-com.jefahnierocks.host-capability-substrate}"
TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../launchd" && pwd)/${LABEL}.plist.tmpl"
TARGET="$HOME/Library/LaunchAgents/${LABEL}.plist"

echo "HCS launchd installer"
echo "---------------------"
echo "label:    $LABEL"
echo "template: $TEMPLATE"
echo "target:   $TARGET"
echo ""

if [ ! -f "$TEMPLATE" ]; then
  echo "✗ template not found: $TEMPLATE" >&2
  exit 1
fi

if [ ! -x "$HCS_ROOT/packages/adapters/mcp-stdio/dist/server.js" ] 2>/dev/null; then
  echo "⏸  kernel not yet built — Phase 3+ prerequisite not met"
  echo "    See PLAN.md Milestone 5 before running this installer."
  echo "    Exiting without installing."
  exit 0
fi

# Future: render template -> $TARGET, then:
#   launchctl bootstrap "gui/$(id -u)" "$TARGET"
#   (bootstrap / bootout only — deprecated load/unload is forbidden per charter invariant 11)
echo "(installer body pending Phase 3; see comments)"
