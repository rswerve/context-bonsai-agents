#!/usr/bin/env bash
# Context Bonsai — persistent Claude off-ramp.
# Restores verified stock, removes the MCP entry, and suppresses auto-reapply.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CONTROL="$SCRIPT_DIR/../auto-maintenance/claude-control.sh"
RUNTIME_CONTROL="${CB_RUNTIME_CURRENT:-$HOME/.local/share/context-bonsai/runtime/current}/adoption/auto-maintenance/claude-control.sh"
CONTROL="${CB_CLAUDE_CONTROL:-$RUNTIME_CONTROL}"
[ -x "$CONTROL" ] || CONTROL="$LOCAL_CONTROL"
exec "$CONTROL" disable
