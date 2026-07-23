#!/usr/bin/env bash
# Shared helpers for Context Bonsai auto-maintenance.
# Sourced by all reconcile/orchestrator scripts. Pure helpers — no side effects on source.

# --- Paths (single source of truth; the live-target ones are env-overridable so fixtures can exercise
#     every branch against scratch copies without ever touching the real install) ---
if [ -z "${CB_AM_SOURCE:-}" ]; then
  CB_AM_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
CB_REPO="${CB_REPO:-$(cd "$CB_AM_SOURCE/../.." && pwd)}"
CB_PORT="${CB_PORT:-$CB_REPO/tweakcc_context_bonsai}"            # tweakcc Claude port (MCP + apply/restore)
CB_ADOPT="$CB_REPO/adoption"
CB_AM="$CB_ADOPT/auto-maintenance"
CB_STATE="${CB_STATE:-$HOME/.local/state/context-bonsai/auto-maintenance}"
CB_LOG="$CB_STATE/maintenance.log"
CB_STATUS="$CB_STATE/last-run.md"                                # human-readable latest status
CB_LOCK="$CB_STATE/.lock"
CB_CLAUDE_MODE_FILE="${CB_CLAUDE_MODE_FILE:-$CB_STATE/claude-mode}"
CB_CLAUDE_LAUNCHER="${CB_CLAUDE_LAUNCHER:-$HOME/.local/bin/claude}"   # override in fixtures
CB_CODEX_SYMLINK="${CB_CODEX_SYMLINK:-$HOME/.local/bin/codex}"
CB_CLAUDE_JSON="${CB_CLAUDE_JSON:-$HOME/.claude.json}"                # override in fixtures
CB_BACKUP_DIR="${CB_BACKUP_DIR:-$HOME/.context-bonsai/tweakcc-backups}"  # stock-bundle backups; override in fixtures

mkdir -p "$CB_STATE" 2>/dev/null || true

# --- Logging ---
cb_ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
cb_log() { printf '%s  %s\n' "$(cb_ts)" "$*" | tee -a "$CB_LOG" >&2; }

# --- Notification (macOS): actionable when terminal-notifier is available,
#     self-contained even when the display-only AppleScript fallback is used. ---
# cb_notify <title> <message> [sound] [path-to-open]
cb_file_url() {
  local path="$1"
  path="${path//%/%25}"
  path="${path// /%20}"
  path="${path//#/%23}"
  path="${path//\?/%3F}"
  printf 'file://%s' "$path"
}

cb_notify() {
  local title="$1" msg="$2" sound="${3:-}" target="${4:-$CB_STATUS}"
  local display_target="$target" display_msg="$msg" notifier="${CB_TERMINAL_NOTIFIER:-}"
  local osascript_bin="${CB_OSASCRIPT:-}"

  if [ -n "$target" ]; then
    case "$target" in "$HOME"/*) display_target="~${target#$HOME}";; esac
    case "$display_msg" in
      *"$target"*|*"$display_target"*) ;;
      *) display_msg="$display_msg Details: $display_target";;
    esac
  fi
  cb_log "NOTIFY: $title — $display_msg"

  if [ -z "$notifier" ]; then notifier="$(command -v terminal-notifier 2>/dev/null || true)"; fi
  if [ -n "$notifier" ] && [ -x "$notifier" ]; then
    local -a args
    args=(-title "$title" -message "$display_msg" -group "context-bonsai-maintenance")
    [ -n "$sound" ] && args+=(-sound "$sound")
    [ -n "$target" ] && args+=(-open "$(cb_file_url "$target")")
    if "$notifier" "${args[@]}" >/dev/null 2>&1; then return 0; fi
    cb_log "notification backend failed: $notifier — trying AppleScript fallback"
  fi

  if [ -z "$osascript_bin" ]; then osascript_bin="$(command -v osascript 2>/dev/null || true)"; fi
  if [ -n "$osascript_bin" ] && [ -x "$osascript_bin" ]; then
    if "$osascript_bin" - "$title" "$display_msg" "$sound" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  set notificationTitle to item 1 of argv
  set notificationMessage to item 2 of argv
  set notificationSound to item 3 of argv
  if notificationSound is "" then
    display notification notificationMessage with title notificationTitle
  else
    display notification notificationMessage with title notificationTitle sound name notificationSound
  end if
end run
APPLESCRIPT
    then return 0
    fi
    cb_log "notification backend failed: $osascript_bin"
  fi
  return 1
}

# Return the newest retained candidate/run directory under a lane root.
cb_latest_evidence() {
  local root="$1" newest="" candidate
  for candidate in "$root"/*; do
    [ -d "$candidate" ] || continue
    if [ -z "$newest" ] || [ "$candidate" -nt "$newest" ]; then newest="$candidate"; fi
  done
  printf '%s' "$newest"
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

# --- Persistent operator intent ---
# Missing mode files mean "enabled" for compatibility with installations that
# predate this control.  Explicit disable survives daily runs, WatchPaths fires,
# runtime upgrades, and source reconciliations because CB_STATE is durable.
cb_claude_disabled() {
  [ -f "$CB_CLAUDE_MODE_FILE" ] && [ "$(sed -n '1p' "$CB_CLAUDE_MODE_FILE" 2>/dev/null)" = "disabled" ]
}
cb_set_claude_mode() { # enabled | disabled; atomic within the durable state directory
  local mode="$1" tmp
  case "$mode" in enabled|disabled) ;; *) return 2;; esac
  mkdir -p "$(dirname "$CB_CLAUDE_MODE_FILE")" || return 1
  tmp="$(dirname "$CB_CLAUDE_MODE_FILE")/.claude-mode.$$"
  printf '%s\n' "$mode" > "$tmp" && mv "$tmp" "$CB_CLAUDE_MODE_FILE"
}

# --- Version helpers ---
cb_claude_version() { "$CB_CLAUDE_LAUNCHER" --version 2>/dev/null | grep -oE '2\.1\.[0-9]+' | head -1; }
cb_claude_live_bundle() { readlink "$CB_CLAUDE_LAUNCHER" 2>/dev/null; }
cb_bundle_patched() { grep -qa 'cb:archived-filter' "$1" 2>/dev/null; }   # $1 = bundle path (quick check)
cb_bundle_any_patched() {
  grep -qa 'cb:archived-filter\|cb:message-content-ids\|cb:context-bonsai-gauge\|cb:in-memory-archive' "$1" 2>/dev/null
}
cb_bundle_clean() { ! cb_bundle_any_patched "$1"; }
cb_bundle_fully_patched() {  # $1 = bundle path; require all host patches AND the autonomous five-user-turn controller
  grep -qa 'cb:archived-filter'      "$1" 2>/dev/null \
  && grep -qa 'cb:message-content-ids'  "$1" 2>/dev/null \
  && grep -qa 'cb:context-bonsai-gauge' "$1" 2>/dev/null \
  && grep -qa 'cb:in-memory-archive' "$1" 2>/dev/null \
  && grep -qa '__cbContextBonsaiApplyInMemory' "$1" 2>/dev/null \
  && grep -qa 'excluded_messages=' "$1" 2>/dev/null \
  && grep -qa '__cbTurns%5===0' "$1" 2>/dev/null \
  && grep -qa '__cbContextBonsaiInjectGauge' "$1" 2>/dev/null \
  && grep -qa 'cache_read_input_tokens' "$1" 2>/dev/null \
  && ! grep -qa '__cbTurns>20' "$1" 2>/dev/null \
  && ! grep -qa '__cbTurns!==__cbState.lastTurn' "$1" 2>/dev/null
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
