#!/usr/bin/env bash
# Context Bonsai — persistent Claude enable switch.
# Uses the same isolate/certify/atomic-swap reconciler as auto-maintenance.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CONTROL="$SCRIPT_DIR/../auto-maintenance/claude-control.sh"
RUNTIME_CONTROL="${CB_RUNTIME_CURRENT:-$HOME/.local/share/context-bonsai/runtime/current}/adoption/auto-maintenance/claude-control.sh"
CONTROL="${CB_CLAUDE_CONTROL:-$RUNTIME_CONTROL}"
[ -x "$CONTROL" ] || CONTROL="$LOCAL_CONTROL"
exec "$CONTROL" enable
