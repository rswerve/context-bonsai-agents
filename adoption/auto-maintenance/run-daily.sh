#!/usr/bin/env bash
# Daily Context Bonsai auto-maintenance orchestrator. Fail-safe: never breaks the install.
# Runs both reconcilers (each self-detects + acts safely), aggregates, writes a status file, notifies.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"

# Mode: both (default), claude-only (used by the WatchPaths instant-react agent), or codex-only.
MODE="both"
for a in "$@"; do case "$a" in --claude-only) MODE="claude";; --codex-only) MODE="codex";; esac; done

cb_log "===== auto-maintenance run start (mode=$MODE) ====="
trap 'cb_release_lock' EXIT
cb_acquire_lock || { cb_log "another run active — exiting"; exit 0; }

if ! cb_preflight; then
  cb_log "preflight failed — doing nothing (install untouched)"
  cb_status <<EOF
**SKIPPED** — environment preflight failed (missing bun/jq/git or the port). Nothing was changed.
Log: \`$CB_LOG\`
EOF
  cb_notify "Context Bonsai" "Auto-maintenance skipped (environment issue). Install untouched."
  exit 0
fi

# --- Claude side (this repo's lane) ---
if [ "$MODE" != "codex" ]; then
  CLAUDE_OUT="$("$DIR/reconcile-claude.sh")"; CLAUDE_RC=$?
else
  CLAUDE_OUT="claude: skipped (codex-only run)"; CLAUDE_RC=0
fi
# --- Codex side (Codex's reconciler; discover its entry point; skip gracefully if absent) ---
if [ "$MODE" != "claude" ]; then
  CODEX_REC=""
  for cand in "$DIR/codex/reconcile.sh" "$DIR/codex/reconcile-codex.sh" "$DIR/reconcile-codex.sh"; do
    [ -x "$cand" ] && CODEX_REC="$cand" && break
  done
  if [ -n "$CODEX_REC" ]; then
    CODEX_OUT="$("$CODEX_REC")"; CODEX_RC=$?
  else
    CODEX_OUT="codex: reconciler not installed yet (skipped)"; CODEX_RC=0
  fi
else
  CODEX_OUT="codex: skipped (claude-only run)"; CODEX_RC=0
fi

cb_log "claude rc=$CLAUDE_RC: $CLAUDE_OUT"
cb_log "codex  rc=$CODEX_RC: $CODEX_OUT"

NEEDS_ATTENTION=0
[ "$CLAUDE_RC" = "10" ] && NEEDS_ATTENTION=1
[ "$CODEX_RC" = "10" ] && NEEDS_ATTENTION=1

if [ "$NEEDS_ATTENTION" = "1" ]; then SUMMARY="⚠️ **Action may be needed** — see notifications + log."
else SUMMARY="✅ All good — nothing needed, or an update was applied cleanly."; fi

cb_status <<EOF
- **Claude:** $CLAUDE_OUT
- **Codex:**  $CODEX_OUT

$SUMMARY

Log: \`$CB_LOG\` · Disable anytime: \`$CB_AM/uninstall-schedule.sh\`
EOF

[ "$NEEDS_ATTENTION" = "1" ] && cb_notify "Context Bonsai" "Auto-maintenance needs your attention — see last-run status." "Basso"
cb_log "===== auto-maintenance run end (attention=$NEEDS_ATTENTION) ====="
exit 0
