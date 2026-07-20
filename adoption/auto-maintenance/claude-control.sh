#!/usr/bin/env bash
# Durable manual control for Claude Context Bonsai.
#   enable  — persist operator intent, then use the fail-safe reconciler
#   disable — atomically restore verified stock + remove MCP, then stay off
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"

ACTION="${1:-}"
case "$ACTION" in
  enable|disable) ;;
  *) echo "usage: $0 enable|disable" >&2; exit 2 ;;
esac

trap 'cb_release_lock' EXIT
cb_acquire_lock || { echo "Claude Bonsai control skipped: maintenance is already running." >&2; exit 20; }

if [ "$ACTION" = "enable" ]; then
  cb_set_claude_mode enabled || { echo "Could not persist Claude Bonsai enabled state." >&2; exit 1; }
  echo "Claude Bonsai mode: enabled. Certifying the installed Claude Code bundle..."
  "$DIR/reconcile-claude.sh"
  exit $?
fi

ver="$(cb_claude_version)"; bundle="$(cb_claude_live_bundle)"
if [ -z "$ver" ] || [ -z "$bundle" ] || [ ! -f "$bundle" ]; then
  echo "Could not resolve the installed Claude Code bundle; nothing was changed." >&2
  exit 20
fi

bundle_dir="$(dirname "$bundle")"
stock_cand="$bundle_dir/.cb-disable-stock.$$"
previous_cand="$bundle_dir/.cb-disable-previous.$$"
config_cand=""; config_previous=""; config_changed=0; bundle_changed=0

cleanup() {
  for f in "${stock_cand:-}" "${previous_cand:-}" "${config_cand:-}" "${config_previous:-}"; do
    [ -n "$f" ] && [ -f "$f" ] && rm -f "$f"
  done
}
trap 'cleanup; cb_release_lock' EXIT

bundle_is_clean() {
  ! grep -qa 'cb:archived-filter\|cb:message-content-ids\|cb:context-bonsai-gauge' "$1" 2>/dev/null
}
binary_matches_version() {
  local got
  got="$("$1" --version 2>/dev/null | grep -oE '2\.1\.[0-9]+' | head -1)"
  [ "$got" = "$ver" ]
}
mcp_absent() {
  [ ! -f "$CB_CLAUDE_JSON" ] || ! jq -e '.mcpServers["context-bonsai"]' "$CB_CLAUDE_JSON" >/dev/null 2>&1
}

# Prepare and verify every replacement before recording disabled intent or
# touching either live file.
if ! bundle_is_clean "$bundle"; then
  backup="$CB_BACKUP_DIR/$(printf '%s' "$bundle" | sed 's/[^a-zA-Z0-9._-]/_/g').backup"
  if [ ! -f "$backup" ]; then
    echo "No stock backup exists for Claude Code $ver; Bonsai remains enabled and working." >&2
    exit 10
  fi
  cp "$backup" "$stock_cand" && chmod +x "$stock_cand" \
    && bundle_is_clean "$stock_cand" && binary_matches_version "$stock_cand" \
    || { echo "The stock backup for Claude Code $ver failed verification; Bonsai remains enabled." >&2; exit 10; }
  cp "$bundle" "$previous_cand" && chmod +x "$previous_cand" \
    && cb_bundle_fully_patched "$previous_cand" && binary_matches_version "$previous_cand" \
    || { echo "Could not stage the current working Claude bundle; nothing was changed." >&2; exit 10; }
fi

if [ -f "$CB_CLAUDE_JSON" ] && ! mcp_absent; then
  config_dir="$(dirname "$CB_CLAUDE_JSON")"
  config_cand="$config_dir/.cb-disable-config.$$"
  config_previous="$config_dir/.cb-disable-config-previous.$$"
  cp "$CB_CLAUDE_JSON" "$config_previous" \
    && jq 'if .mcpServers then .mcpServers |= del(.["context-bonsai"]) else . end' \
      "$CB_CLAUDE_JSON" > "$config_cand" \
    && jq -e . "$config_cand" >/dev/null 2>&1 \
    || { echo "Could not stage the Claude MCP configuration change; nothing was changed." >&2; exit 10; }
fi

# Commit: durable intent first prevents a WatchPaths/daily run from racing a
# successful rollback. All file replacements below are same-directory moves.
cb_set_claude_mode disabled \
  || { echo "Could not persist disabled state; nothing was changed." >&2; exit 10; }
if [ -f "$stock_cand" ]; then
  mv "$stock_cand" "$bundle" || { cb_set_claude_mode enabled; echo "Stock activation failed; Bonsai remains enabled." >&2; exit 10; }
  stock_cand=""; bundle_changed=1
fi
if [ -n "$config_cand" ]; then
  if mv "$config_cand" "$CB_CLAUDE_JSON"; then
    config_cand=""; config_changed=1
  else
    [ "$bundle_changed" = "1" ] && mv "$previous_cand" "$bundle" && previous_cand=""
    cb_set_claude_mode enabled
    echo "MCP configuration activation failed; the previous working state was restored." >&2
    exit 10
  fi
fi

if bundle_is_clean "$bundle" && binary_matches_version "$bundle" && mcp_absent && cb_claude_disabled; then
  cb_log "claude $ver: manually disabled — verified stock bundle + MCP absent; automatic reapply suppressed"
  echo "Claude Bonsai is disabled persistently. Stock Claude Code $ver is verified; restart sessions to take effect."
  exit 0
fi

# A post-commit invariant failed. Restore the exact prior working files and
# enabled intent from their already-staged same-volume candidates.
restore_ok=1
if [ "$bundle_changed" = "1" ]; then
  if mv "$previous_cand" "$bundle"; then previous_cand=""; else restore_ok=0; fi
fi
if [ "$config_changed" = "1" ]; then
  if mv "$config_previous" "$CB_CLAUDE_JSON"; then config_previous=""; else restore_ok=0; fi
fi
cb_set_claude_mode enabled || restore_ok=0
if [ "$restore_ok" = "1" ] && "$CB_CLAUDE_LAUNCHER" --version >/dev/null 2>&1; then
  cb_log "claude $ver: manual disable post-check failed — previous Bonsai state restored"
  echo "Disable verification failed; the previous working Bonsai state was restored." >&2
else
  cb_log "claude $ver: URGENT manual disable rollback failed; backup remains at $CB_BACKUP_DIR"
  echo "URGENT: disable verification and restoration failed; inspect $CB_BACKUP_DIR." >&2
fi
exit 10
