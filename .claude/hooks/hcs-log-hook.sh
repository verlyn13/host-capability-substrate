#!/usr/bin/env bash
# hcs-log-hook.sh — project-scoped Claude Code hook wrapper.
#
# Configured in .claude/settings.json under hooks.PreToolUse. Delegates to the
# CLI hook script in scripts/dev/. Log-only in Phase 0b.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HCS_ROOT="$(cd "$HERE/../.." && pwd)"
export HCS_ROOT
exec "$HCS_ROOT/scripts/dev/hcs-hook-cli.sh"
