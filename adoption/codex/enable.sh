#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly REPO_ROOT="${SCRIPT_DIR:h:h}"
readonly STAGED_BINARY="$REPO_ROOT/.artifacts/context-bonsai/codex/0.144.5/bin/codex"
readonly LINK_DIR="$HOME/.local/bin"
readonly LINK_PATH="$LINK_DIR/codex"
readonly STATE_DIR="$HOME/.local/state/context-bonsai/codex-switch"
readonly ACTIVE_STATE="$STATE_DIR/active.env"

"$SCRIPT_DIR/verify-staged.sh"

if [[ -f "$ACTIVE_STATE" ]]; then
  print -u2 "a Codex Context Bonsai switch is already recorded: $ACTIVE_STATE"
  exit 1
fi

mkdir -p "$LINK_DIR" "$STATE_DIR/history"
readonly STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
previous=""
activated=0

restore_on_error() {
  if (( activated )) && [[ -e "$LINK_PATH" || -L "$LINK_PATH" ]]; then
    mv "$LINK_PATH" "$STATE_DIR/history/codex.bonsai-failed.$STAMP"
  fi
  if [[ -n "$previous" ]] && [[ -e "$previous" || -L "$previous" ]]; then
    mv "$previous" "$LINK_PATH"
  fi
}
trap restore_on_error ERR

if [[ -e "$LINK_PATH" || -L "$LINK_PATH" ]]; then
  previous="$STATE_DIR/history/codex.before-bonsai.$STAMP"
  mv "$LINK_PATH" "$previous"
fi

ln -s "$STAGED_BINARY" "$LINK_PATH"
activated=1
{
  print -r -- "STAGED_BINARY=${(q)STAGED_BINARY}"
  print -r -- "LINK_PATH=${(q)LINK_PATH}"
  print -r -- "PREVIOUS=${(q)previous}"
  print -r -- "ENABLED_AT=${(q)STAMP}"
} > "$ACTIVE_STATE"
trap - ERR

print "Codex Context Bonsai enabled for new sessions: $LINK_PATH"
print "Existing Codex processes were not restarted."
print "Rollback: $SCRIPT_DIR/rollback.sh"
