#!/bin/zsh
# Off-ramp for Codex Context Bonsai. adoption/auto-maintenance/uninstall-schedule.sh points
# users here as THE way to remove Bonsai from Codex, so it has to work against whatever is
# actually installed — not against what a bootstrap script recorded once.
#
# It used to trust $ACTIVE_STATE and refuse when the symlink disagreed. That record is
# written only by the legacy 0.144.5 enable.sh, while the daily reconciler forward-ports
# Codex by re-pointing the symlink at a new content-addressed artifact and never updates
# it. So after the first forward-port the recorded target is permanently wrong and the
# documented off-ramp dead-ends on "refusing rollback" with no way to disable Bonsai.
#
# The live symlink is the authority. The recorded state is consulted only for PREVIOUS,
# the pre-Bonsai entry to restore.
set -euo pipefail

readonly STATE_DIR="$HOME/.local/state/context-bonsai/codex-switch"
readonly ACTIVE_STATE="$STATE_DIR/active.env"
readonly ARTIFACT_ROOT="$HOME/.local/share/context-bonsai/artifacts/codex"
readonly DRY_RUN="${CB_ROLLBACK_DRY_RUN:-0}"

LINK_PATH="$HOME/.local/bin/codex"
PREVIOUS=''
if [[ -f "$ACTIVE_STATE" ]]; then
  source "$ACTIVE_STATE"   # may set LINK_PATH and PREVIOUS; STAGED_BINARY is deliberately ignored
fi

readonly TARGET="$(readlink "$LINK_PATH" 2>/dev/null || true)"
if [[ -z "$TARGET" ]]; then
  print "Codex Context Bonsai is not active ($LINK_PATH is not a symlink); nothing changed."
  exit 0
fi
# Only ever unlink a Bonsai artifact; anything else on this path belongs to someone else.
if [[ "$TARGET" != "$ARTIFACT_ROOT"/* ]]; then
  print -u2 "refusing rollback: $LINK_PATH points outside the Bonsai artifact root."
  print -u2 "  points to: $TARGET"
  exit 1
fi
if [[ -n "$PREVIOUS" ]] && [[ ! -e "$PREVIOUS" && ! -L "$PREVIOUS" ]]; then
  print -u2 "recorded prior Codex entry is missing: $PREVIOUS"
  exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  print "DRY RUN — no changes made."
  print "  would disable: $LINK_PATH -> $TARGET"
  if [[ -n "$PREVIOUS" ]]; then
    print "  would restore prior entry: $PREVIOUS"
  else
    print "  no prior entry recorded; new launches resolve to stock Codex on PATH"
  fi
  exit 0
fi

readonly STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$STATE_DIR/history"
mv "$LINK_PATH" "$STATE_DIR/history/codex.bonsai-disabled.$STAMP"
if [[ -n "$PREVIOUS" ]]; then
  mv "$PREVIOUS" "$LINK_PATH"
fi
if [[ -f "$ACTIVE_STATE" ]]; then
  mv "$ACTIVE_STATE" "$STATE_DIR/history/active.$STAMP.env"
fi

print "Codex Context Bonsai disabled for new sessions."
print "The compiled artifact is untouched; switch history remains under $STATE_DIR/history."
print "Re-enable by restoring the symlink: ln -s $TARGET $LINK_PATH"
