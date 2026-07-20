#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly STATE_DIR="$HOME/.local/state/context-bonsai/codex-switch"
readonly ACTIVE_STATE="$STATE_DIR/active.env"

[[ -f "$ACTIVE_STATE" ]] || {
  print "Codex Context Bonsai is not recorded as active; nothing changed."
  exit 0
}

source "$ACTIVE_STATE"
readonly EXPECTED_TARGET="$(readlink "$LINK_PATH" 2>/dev/null || true)"
if [[ "$EXPECTED_TARGET" != "$STAGED_BINARY" ]]; then
  print -u2 "refusing rollback: $LINK_PATH no longer points to the staged binary"
  exit 1
fi
if [[ -n "$PREVIOUS" ]] && [[ ! -e "$PREVIOUS" && ! -L "$PREVIOUS" ]]; then
  print -u2 "recorded prior Codex entry is missing: $PREVIOUS"
  exit 1
fi

readonly STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mv "$LINK_PATH" "$STATE_DIR/history/codex.bonsai-disabled.$STAMP"
if [[ -n "$PREVIOUS" ]]; then
  mv "$PREVIOUS" "$LINK_PATH"
fi
mv "$ACTIVE_STATE" "$STATE_DIR/history/active.$STAMP.env"

print "Codex Context Bonsai disabled for new sessions."
print "No files were deleted; switch history remains under $STATE_DIR/history."
