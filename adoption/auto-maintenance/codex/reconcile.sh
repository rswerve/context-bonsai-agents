#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
set +e
summary="$(bun "$SCRIPT_DIR/reconcile-codex.ts" reconcile)"
rc=$?
set -e
print -r -- "$summary"

if (( rc == 0 )) && [[ "$summary" == *'forward-ported + verified' ]]; then
  # Shared helper logs to stderr, preserving the orchestrator's exactly-one-line
  # stdout contract. Notification failure is deliberately non-fatal.
  CB_AM_SOURCE="${SCRIPT_DIR:h}"
  source "$SCRIPT_DIR/../lib.sh"
  cb_notify "Context Bonsai" "$summary — spot-check when convenient." || \
    cb_log "successful forward-port notification could not be delivered"
fi
exit "$rc"
