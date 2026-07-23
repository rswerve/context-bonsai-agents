#!/usr/bin/env bash
# Stage-C transaction wrapper: advance the certified immutable runtime, then
# enable the proxy. Any cutover failure restores the prior runtime selector.
set -uo pipefail

[ "${CB_FINAL_GO:-0}" = "1" ] || {
  echo "Staged only. Maz's final cutover requires CB_FINAL_GO=1." >&2
  exit 2
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
source "$DIR/../auto-maintenance/lib.sh"
INSTALL_ROOT="${CB_INSTALL_ROOT:-$HOME/.local/share/context-bonsai}"
RUNTIME_ROOT="${CB_RUNTIME_ROOT:-$INSTALL_ROOT/runtime}"
CURRENT="${CB_RUNTIME_CURRENT:-$RUNTIME_ROOT/current}"
INSTALLER="${CB_RUNTIME_INSTALLER:-$ROOT/adoption/runtime/install.sh}"
LIVE_VERIFY="${CB_STAGE_C_VERIFY:-}"

[ -n "$LIVE_VERIFY" ] && [ -x "$LIVE_VERIFY" ] || {
  echo "Refusing migration: CB_STAGE_C_VERIFY must name the approved live model+AgentBridge verifier." >&2
  exit 2
}

[ -L "$CURRENT" ] || {
  echo "Refusing migration: $CURRENT is not a managed symlink." >&2
  exit 10
}
cb_acquire_lock || {
  echo "Migration skipped: Context Bonsai maintenance is already running." >&2
  exit 20
}
trap 'cb_release_lock' EXIT
previous="$(readlink "$CURRENT")"
[ -n "$previous" ] && [ -d "$previous" ] || {
  echo "Refusing migration: prior runtime target cannot be verified." >&2
  exit 10
}

parent_commit="$(git -C "$ROOT" rev-parse HEAD)" || exit 10
tweak_commit="$(git -C "$ROOT/tweakcc_context_bonsai" rev-parse HEAD)" || exit 10
target="$RUNTIME_ROOT/$parent_commit"
if [ -d "$target" ]; then
  [ "$(jq -r '.parentCommit // empty' "$target/runtime-manifest.json" 2>/dev/null)" = "$parent_commit" ] \
    && [ "$(jq -r '.tweakccCommit // empty' "$target/runtime-manifest.json" 2>/dev/null)" = "$tweak_commit" ] \
    && CB_INSTALL_ROOT="$INSTALL_ROOT" CB_RUNTIME_PATH="$target" "$target/adoption/runtime/verify.sh" >/dev/null \
    || { echo "Retained runtime candidate failed re-verification; selector unchanged." >&2; exit 10; }
  retry_stamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  selector="$RUNTIME_ROOT/.proxy-migration-current-$retry_stamp"
  retry_rollback="$RUNTIME_ROOT/.proxy-migration-prior-$retry_stamp"
  ln -s "$previous" "$retry_rollback" && ln -s "$target" "$selector" \
    || { echo "Could not pre-stage runtime selector/rollback; prior selector retained." >&2; exit 10; }
  if ! mv -fh "$selector" "$CURRENT" || [ "$(readlink "$CURRENT")" != "$target" ]; then
    mv -fh "$retry_rollback" "$CURRENT" 2>/dev/null || true
    echo "Verified runtime candidate could not be selected; prior selector restored." >&2
    exit 10
  fi
else
  CB_INSTALL_ROOT="$INSTALL_ROOT" "$INSTALLER" || exit $?
fi
CONTROL="$CURRENT/adoption/claude-proxy/control.sh"
cutover_committed=0
if [ -x "$CONTROL" ] && CB_LOCK_HELD=1 CB_RUNTIME_CURRENT="$CURRENT" "$CONTROL" enable; then
  cutover_committed=1
  if "$LIVE_VERIFY" "$CURRENT" "http://127.0.0.1:${CB_PROXY_PORT:-18399}"; then
    echo "Claude zero-patch proxy migration committed and live-verified; prior runtime retained at $previous."
    exit 0
  fi
  echo "Live model/AgentBridge verification failed; auto-rollback starting." >&2
  if ! CB_LOCK_HELD=1 CB_RUNTIME_CURRENT="$CURRENT" "$CONTROL" rollback; then
    echo "URGENT: live verification failed and the Claude off-ramp did not verify. New runtime retained to avoid stale-MCP proxy state." >&2
    exit 10
  fi
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"
rollback_link="$RUNTIME_ROOT/.proxy-migration-rollback-$stamp"
if ln -s "$previous" "$rollback_link" && mv -fh "$rollback_link" "$CURRENT" \
  && [ "$(readlink "$CURRENT")" = "$previous" ]; then
  if [ "$cutover_committed" = "1" ]; then
    echo "Live verification failed; prior Claude patch state and prior runtime selector were restored." >&2
  else
    echo "Proxy cutover failed; prior Claude state and prior runtime selector were restored." >&2
  fi
else
  echo "URGENT: proxy cutover failed and runtime selector rollback needs review. Prior target: $previous" >&2
fi
exit 10
