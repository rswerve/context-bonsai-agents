#!/usr/bin/env bash
# Shared helpers for Context Bonsai auto-maintenance.
# Sourced by all reconcile/orchestrator scripts. Pure helpers — no side effects on source.

# --- Paths (single source of truth; the live-target ones are env-overridable so fixtures can exercise
#     every branch against scratch copies without ever touching the real install) ---
CB_REPO="${CB_REPO:-/Users/atighi/dev/context-bonsai-agents}"
CB_PORT="${CB_PORT:-$CB_REPO/tweakcc_context_bonsai}"            # tweakcc Claude port (MCP + apply/restore)
CB_ADOPT="$CB_REPO/adoption"
CB_AM="$CB_ADOPT/auto-maintenance"
CB_STATE="${CB_STATE:-$CB_AM/state}"                            # logs + last-run status (git-ignored)
CB_LOG="$CB_STATE/maintenance.log"
CB_STATUS="$CB_STATE/last-run.md"                                # human-readable latest status
CB_LOCK="$CB_STATE/.lock"
CB_CLAUDE_LAUNCHER="${CB_CLAUDE_LAUNCHER:-$HOME/.local/bin/claude}"   # override in fixtures
CB_CODEX_SYMLINK="${CB_CODEX_SYMLINK:-$HOME/.local/bin/codex}"
CB_CLAUDE_JSON="${CB_CLAUDE_JSON:-$HOME/.claude.json}"                # override in fixtures
CB_BACKUP_DIR="${CB_BACKUP_DIR:-$HOME/.context-bonsai/tweakcc-backups}"  # stock-bundle backups; override in fixtures

mkdir -p "$CB_STATE" 2>/dev/null || true

# --- Logging ---
cb_ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
cb_log() { printf '%s  %s\n' "$(cb_ts)" "$*" | tee -a "$CB_LOG" >&2; }

# --- Notification (macOS): non-fatal if osascript unavailable ---
# cb_notify <title> <message> [sound]
cb_notify() {
  local title="$1" msg="$2" sound="${3:-}"
  cb_log "NOTIFY: $title — $msg"
  if command -v osascript >/dev/null 2>&1; then
    local s=""; [ -n "$sound" ] && s=" sound name \"$sound\""
    osascript -e "display notification \"${msg//\"/\\\"}\" with title \"${title//\"/\\\"}\"$s" >/dev/null 2>&1 || true
  fi
}

# --- Status file: overwrite with the latest run summary the user can read anytime ---
# cb_status <<'EOF' ... EOF   (reads body from stdin)
cb_status() { { echo "# Context Bonsai auto-maintenance — last run $(cb_ts)"; echo; cat; } > "$CB_STATUS"; }

# --- Single-instance lock (prevents overlapping daily runs) ---
cb_acquire_lock() {
  if [ -e "$CB_LOCK" ]; then
    local pid; pid="$(cat "$CB_LOCK" 2>/dev/null || echo)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      cb_log "another maintenance run (pid $pid) is active — exiting"; return 1
    fi
    cb_log "stale lock (pid ${pid:-none}) — reclaiming"
  fi
  echo "$$" > "$CB_LOCK"; return 0
}
cb_release_lock() { rm -f "$CB_LOCK" 2>/dev/null || true; }

# --- Version helpers ---
cb_claude_version() { "$CB_CLAUDE_LAUNCHER" --version 2>/dev/null | grep -oE '2\.1\.[0-9]+' | head -1; }
cb_claude_live_bundle() { readlink "$CB_CLAUDE_LAUNCHER" 2>/dev/null; }
cb_bundle_patched() { grep -qa 'cb:archived-filter' "$1" 2>/dev/null; }   # $1 = bundle path (quick check)
cb_bundle_fully_patched() {  # $1 = bundle path; true ONLY if ALL THREE patch sentinels are present
  grep -qa 'cb:archived-filter'      "$1" 2>/dev/null \
  && grep -qa 'cb:message-content-ids'  "$1" 2>/dev/null \
  && grep -qa 'cb:context-bonsai-gauge' "$1" 2>/dev/null
}
cb_codex_symlink_target() { readlink "$CB_CODEX_SYMLINK" 2>/dev/null; }
cb_codex_fork_version() { "$CB_CODEX_SYMLINK" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }

# --- Safety guard: refuse to run if the repo/port/tools are missing (fail closed, do nothing) ---
cb_preflight() {
  local ok=0
  command -v bun >/dev/null 2>&1 || { cb_log "PREFLIGHT FAIL: bun not on PATH"; ok=1; }
  command -v jq  >/dev/null 2>&1 || { cb_log "PREFLIGHT FAIL: jq not on PATH"; ok=1; }
  command -v git >/dev/null 2>&1 || { cb_log "PREFLIGHT FAIL: git not on PATH"; ok=1; }
  [ -d "$CB_PORT" ] || { cb_log "PREFLIGHT FAIL: port missing at $CB_PORT"; ok=1; }
  return $ok
}
