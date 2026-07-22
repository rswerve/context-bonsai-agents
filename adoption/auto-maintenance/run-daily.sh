#!/usr/bin/env bash
# Daily Context Bonsai auto-maintenance orchestrator. Fail-safe: never breaks the install.
# Runs both reconcilers (each self-detects + acts safely), aggregates, writes a status file, notifies.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"

# Mode: both (default), source-only, claude-only (WatchPaths), or codex-only.
MODE="both"
for a in "$@"; do case "$a" in
  --source-only) MODE="source";;
  --claude-only) MODE="claude";;
  --codex-only) MODE="codex";;
esac; done

cb_log "===== auto-maintenance run start (mode=$MODE) ====="
trap 'cb_release_lock' EXIT
cb_acquire_lock || { cb_log "another run active — exiting"; exit 0; }

if ! cb_preflight; then
  cb_log "preflight failed — doing nothing (install untouched)"
  cb_status <<EOF
**SKIPPED** — environment preflight failed (missing bun/jq/git or the port). Nothing was changed.
Log: \`$CB_LOG\`
EOF
  cb_notify "Context Bonsai — maintenance skipped" \
    "Preflight failed: bun, jq, git, or the Bonsai port could not be resolved. No install changes were attempted."
  exit 0
fi

# --- Source lane: merge/certify both Bonsai upstreams before harness upkeep. ---
if [ "$MODE" = "both" ] || [ "$MODE" = "source" ]; then
  SOURCE_REC="${CB_SOURCE_RECONCILER:-$DIR/source/reconcile.sh}"
  if [ -x "$SOURCE_REC" ]; then
    SOURCE_OUT="$("$SOURCE_REC")"; SOURCE_RC=$?
  else
    SOURCE_OUT="source: reconciler not installed yet (skipped)"; SOURCE_RC=0
  fi
else
  SOURCE_OUT="source: skipped ($MODE-only run)"; SOURCE_RC=0
fi

# A successful source transaction may have atomically advanced runtime/current.
# Resolve the remaining lanes from that new runtime so shared-core changes can
# rebuild Codex during this same daily run.
if [ "$MODE" = "both" ]; then
  NEXT_RUNTIME="${CB_RUNTIME_CURRENT:-$HOME/.local/share/context-bonsai/runtime/current}"
  NEXT_DIR="$NEXT_RUNTIME/adoption/auto-maintenance"
  [ -x "$NEXT_DIR/run-daily.sh" ] && DIR="$NEXT_DIR"
fi

# --- Claude side ---
if [ "$MODE" = "both" ] || [ "$MODE" = "claude" ]; then
  CLAUDE_REC="${CB_CLAUDE_RECONCILER:-$DIR/reconcile-claude.sh}"
  CLAUDE_OUT="$("$CLAUDE_REC")"; CLAUDE_RC=$?
else
  CLAUDE_OUT="claude: skipped ($MODE-only run)"; CLAUDE_RC=0
fi
# --- Codex side (Codex's reconciler; discover its entry point; skip gracefully if absent) ---
if [ "$MODE" = "both" ] || [ "$MODE" = "codex" ]; then
  CODEX_REC="${CB_CODEX_RECONCILER:-}"
  if [ -z "$CODEX_REC" ]; then
    for cand in "$DIR/codex/reconcile.sh" "$DIR/codex/reconcile-codex.sh" "$DIR/reconcile-codex.sh"; do
      [ -x "$cand" ] && CODEX_REC="$cand" && break
    done
  fi
  if [ -n "$CODEX_REC" ]; then
    CODEX_OUT="$("$CODEX_REC")"; CODEX_RC=$?
  else
    CODEX_OUT="codex: reconciler not installed yet (skipped)"; CODEX_RC=0
  fi
else
  CODEX_OUT="codex: skipped ($MODE-only run)"; CODEX_RC=0
fi

cb_log "source rc=$SOURCE_RC: $SOURCE_OUT"
cb_log "claude rc=$CLAUDE_RC: $CLAUDE_OUT"
cb_log "codex  rc=$CODEX_RC: $CODEX_OUT"

NEEDS_ATTENTION=0
ATTENTION_NAMES=""
ATTENTION_DETAIL=""
EVIDENCE_LINES=""
add_attention() {
  local lane="$1" output="$2" evidence="$3" concise
  concise="$output"
  case "$concise" in
    source:*) concise="${concise#source: }";;
    claude:*) concise="${concise#claude: }";;
    codex\ *) concise="${concise#codex }";;
  esac
  [ -n "$ATTENTION_NAMES" ] && ATTENTION_NAMES="$ATTENTION_NAMES + "
  ATTENTION_NAMES="$ATTENTION_NAMES$lane"
  [ -n "$ATTENTION_DETAIL" ] && ATTENTION_DETAIL="$ATTENTION_DETAIL; "
  ATTENTION_DETAIL="$ATTENTION_DETAIL$lane: $concise"
  [ -n "$evidence" ] && EVIDENCE_LINES="$EVIDENCE_LINES
- **$lane retained evidence:** \`$evidence\`"
  NEEDS_ATTENTION=1
}

attention_safe_state() {
  local lane="$1" output="$2"
  case "$output" in
    *"ROLLBACK FAILED"*|*"rollback needs attention"*)
      printf 'URGENT: rollback could not be verified; inspect the retained evidence before launching or changing %s.' "$lane"
      ;;
    *"stock unrunnable"*)
      printf 'URGENT: stock was restored but did not pass its run check; do not assume Claude is healthy.'
      ;;
    *"previous target auto-restored"*)
      printf 'The previous certified Codex target was atomically restored.'
      ;;
    *"ROLLED BACK + verified"*|*"rolled back to stock"*)
      printf 'Claude was atomically restored to verified stock; Bonsai is safely off for that version.'
      ;;
    *"previous runtime restored"*)
      printf 'The previous certified Bonsai runtime was restored.'
      ;;
    *"previous runtime retained"*|*"runtime unchanged"*)
      printf 'The last certified Bonsai runtime remains selected; no runtime change was made.'
      ;;
    *"install untouched"*)
      printf 'The %s install is untouched; its prior working state remains selected.' "$lane"
      ;;
    *)
      printf 'The lane stopped at its transaction boundary. Treat its state as unverified until the retained evidence is reviewed.'
      ;;
  esac
}

if [ "$SOURCE_RC" = "10" ]; then
  SOURCE_EVIDENCE="$(cb_latest_evidence "${CB_SOURCE_SCRATCH_ROOT:-$HOME/.local/state/context-bonsai/source-maintenance/runs}")"
  add_attention "Source" "$SOURCE_OUT" "$SOURCE_EVIDENCE"
fi
if [ "$CLAUDE_RC" = "10" ]; then
  add_attention "Claude" "$CLAUDE_OUT" "$CB_STATE"
fi
if [ "$CODEX_RC" = "10" ]; then
  CODEX_EVIDENCE="$(cb_latest_evidence "${CB_CODEX_SCRATCH_ROOT:-$HOME/.local/state/context-bonsai/codex-maintenance/runs}")"
  add_attention "Codex" "$CODEX_OUT" "$CODEX_EVIDENCE"
fi

if [ "$NEEDS_ATTENTION" = "1" ]; then SUMMARY="⚠️ **Unresolved: $ATTENTION_NAMES.** Each failed lane stopped at its transaction boundary; its line above states whether the runtime/install was unchanged or rolled back."
else SUMMARY="✅ All good — nothing needed, or an update was applied cleanly."; fi

cb_status <<EOF
- **Source:** $SOURCE_OUT
- **Claude:** $CLAUDE_OUT
- **Codex:**  $CODEX_OUT

$SUMMARY
$EVIDENCE_LINES

Log: \`$CB_LOG\` · Disable anytime: \`$CB_AM/uninstall-schedule.sh\`
EOF

INCIDENT_HELPER="${CB_INCIDENT_REMINDER:-$DIR/incident-reminder.sh}"
INCIDENT_STATE_FAILED=0
incident_observe() {
  local lane="$1" display="$2" output="$3" evidence="$4" safe_state
  safe_state="$(attention_safe_state "$display" "$output")"
  if [ -x "$INCIDENT_HELPER" ]; then
    "$INCIDENT_HELPER" observe "$lane" "$output" "$safe_state" "$evidence" >/dev/null || INCIDENT_STATE_FAILED=1
  else
    INCIDENT_STATE_FAILED=1
  fi
}
incident_resolve() {
  local lane="$1"
  if [ -x "$INCIDENT_HELPER" ]; then
    "$INCIDENT_HELPER" resolve "$lane" >/dev/null || INCIDENT_STATE_FAILED=1
  fi
}

if [ "$SOURCE_RC" = "10" ]; then
  incident_observe "source" "Source" "$SOURCE_OUT" "${SOURCE_EVIDENCE:-$CB_STATUS}"
elif { [ "$MODE" = "both" ] || [ "$MODE" = "source" ]; } && [ "$SOURCE_RC" = "0" ]; then
  incident_resolve "source"
fi
if [ "$CLAUDE_RC" = "10" ]; then
  incident_observe "claude" "Claude" "$CLAUDE_OUT" "$CB_STATUS"
elif { [ "$MODE" = "both" ] || [ "$MODE" = "claude" ]; } && [ "$CLAUDE_RC" = "0" ]; then
  incident_resolve "claude"
fi
if [ "$CODEX_RC" = "10" ]; then
  incident_observe "codex" "Codex" "$CODEX_OUT" "${CODEX_EVIDENCE:-$CB_STATUS}"
elif { [ "$MODE" = "both" ] || [ "$MODE" = "codex" ]; } && [ "$CODEX_RC" = "0" ]; then
  incident_resolve "codex"
fi

if [ "$NEEDS_ATTENTION" = "1" ] && [ "$INCIDENT_STATE_FAILED" = "1" ]; then
  cb_notify "Context Bonsai — $ATTENTION_NAMES failed" \
    "$ATTENTION_DETAIL. The incident recorder failed, but each lane stopped at its transaction boundary." \
    "Basso" "$CB_STATUS"
elif [ "$INCIDENT_STATE_FAILED" = "1" ]; then
  cb_notify "Context Bonsai — reminder state needs attention" \
    "A maintenance lane is clean, but its prior incident could not be marked resolved. Claude and Codex were not changed. Evidence: $CB_STATUS" \
    "Basso" "$CB_STATUS"
fi
cb_log "===== auto-maintenance run end (attention=$NEEDS_ATTENTION) ====="
exit 0
