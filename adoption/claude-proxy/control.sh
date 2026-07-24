#!/usr/bin/env bash
# Reversible Claude wire-proxy cutover. Nothing happens unless explicitly run.
# enable: patched bundle -> verified stock + proxy route
# rollback: proxy route -> certified bundle patch (proxy kept alive for old sessions)
# guard: launchd health/build check; prolonged failure disables Bonsai for new sessions
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Decided BEFORE sourcing lib.sh, which creates its state directory on load. verify and
# a dry-run adopt must be provably read-only, and a created directory is still a write.
case "${1:-}" in
  verify)        CB_LIB_NO_INIT=1 ;;
  adopt|release) [ "${CB_ADOPT_DRY_RUN:-0}" = "1" ] && CB_LIB_NO_INIT=1 ;;
esac
export CB_LIB_NO_INIT="${CB_LIB_NO_INIT:-0}"
source "$DIR/../auto-maintenance/lib.sh"

ACTION="${1:-}"
case "$ACTION" in adopt|release|enable|rollback|verify|guard|retire) ;; *)
  echo "usage: $0 adopt|release|verify|guard|retire   (enable/rollback are retired)" >&2
  exit 2
esac
if [ "$ACTION" = "enable" ]; then
  echo "Claude proxy activation is retired; the live-model harness was removed." >&2
  exit 2
fi
# Retired 2026-07-24 alongside `enable`. Claude now runs stock-binary + proxy-only
# (claude-mode=proxy, WatchPaths unloaded, zero patch markers). This path would set
# mode=enabled, re-patch the live bundle, strip proxy routing and reload WatchPaths —
# silently undoing that. Off-ramp is now: remove ANTHROPIC_BASE_URL from
# ~/.claude/settings.json + the context-bonsai MCP env, and bootout the proxy agent.
if [ "$ACTION" = "rollback" ]; then
  echo "Claude proxy rollback is retired; it would re-patch the live bundle and undo proxy-only mode." >&2
  echo "To disable Bonsai: drop ANTHROPIC_BASE_URL from ~/.claude/settings.json and bootout com.atighi.context-bonsai-proxy." >&2
  exit 2
fi

RUNTIME_CURRENT="${CB_RUNTIME_CURRENT:-$HOME/.local/share/context-bonsai/runtime/current}"
PROXY_SCRIPT="${CB_PROXY_SCRIPT:-$RUNTIME_CURRENT/tweakcc_context_bonsai/proxy-prototype/proxy.mjs}"
CORRELATE_SCRIPT="${CB_CORRELATE_SCRIPT:-$(dirname "$PROXY_SCRIPT")/correlate.mjs}"
HOOK_SCRIPT="${CB_GAUGE_HOOK:-$RUNTIME_CURRENT/tweakcc_context_bonsai/hooks/context-bonsai-gauge.ts}"
HOOK_REGISTER="${CB_GAUGE_REGISTER:-$(dirname "$HOOK_SCRIPT")/register-gauge-hooks.sh}"
CLAUDE_SETTINGS="${CB_CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
PROXY_STATE="${CB_PROXY_STATE:-$HOME/.local/state/context-bonsai/claude-proxy}"
LAUNCH_AGENT_DIR="${CB_LAUNCH_AGENT_DIR:-$HOME/Library/LaunchAgents}"
LAUNCH_DOMAIN="${CB_LAUNCH_DOMAIN:-gui/$(id -u)}"
LAUNCHCTL_BIN="${CB_LAUNCHCTL:-/bin/launchctl}"
CURL_BIN="${CB_CURL:-/usr/bin/curl}"
# 8399 is the port the live route actually uses (com.atighi.context-bonsai-proxy
# plist, ~/.claude/settings.json, and the context-bonsai MCP env all agree on it).
# The former 18399 default predated that activation and made `verify` report a
# false failure against a healthy install.
PROXY_PORT="${CB_PROXY_PORT:-8399}"
PROXY_URL="http://127.0.0.1:$PROXY_PORT"
PROXY_LABEL="com.atighi.context-bonsai-proxy"
GUARD_LABEL="com.atighi.context-bonsai-proxy-guard"
WATCH_LABEL="com.atighi.context-bonsai-maintenance-claudewatch"
DAILY_LABEL="com.atighi.context-bonsai-maintenance"
PROXY_PLIST="$LAUNCH_AGENT_DIR/$PROXY_LABEL.plist"
GUARD_PLIST="$LAUNCH_AGENT_DIR/$GUARD_LABEL.plist"
WATCH_PLIST="$LAUNCH_AGENT_DIR/$WATCH_LABEL.plist"
HOOK_COMMAND="bun run $HOOK_SCRIPT"
PATH_VALUE="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

[ "$CB_LIB_NO_INIT" = "1" ] || mkdir -p "$PROXY_STATE" "$LAUNCH_AGENT_DIR" 2>/dev/null || true

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
preserve_mode() { chmod "$(stat -f '%Lp' "$1")" "$2"; }
expected_build_id() {
  { cat "$PROXY_SCRIPT"; printf '\0'; cat "$CORRELATE_SCRIPT"; } | shasum -a 256 | awk '{print $1}'
}
loaded() { "$LAUNCHCTL_BIN" print "$LAUNCH_DOMAIN/$1" >/dev/null 2>&1; }
bootout() { "$LAUNCHCTL_BIN" bootout "$LAUNCH_DOMAIN/$1" >/dev/null 2>&1 || true; }
bootstrap() {
  "$LAUNCHCTL_BIN" bootstrap "$LAUNCH_DOMAIN" "$2" \
    && "$LAUNCHCTL_BIN" enable "$LAUNCH_DOMAIN/$1" >/dev/null 2>&1
}
mode_value() {
  if [ -f "$CB_CLAUDE_MODE_FILE" ]; then sed -n '1p' "$CB_CLAUDE_MODE_FILE"; else echo enabled; fi
}
bundle_version_matches() {
  local path="$1" version="$2" got
  got="$("$path" --version 2>/dev/null | grep -oE '2\.1\.[0-9]+' | head -1)"
  [ "$got" = "$version" ]
}
mcp_present() {
  jq -e '.mcpServers["context-bonsai"]' "$CB_CLAUDE_JSON" >/dev/null 2>&1
}
mcp_proxy_active() {
  jq -e --arg url "$PROXY_URL" \
    '.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL==$url' \
    "$CB_CLAUDE_JSON" >/dev/null 2>&1
}
mcp_proxy_absent() {
  jq -e '.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL == null' \
    "$CB_CLAUDE_JSON" >/dev/null 2>&1
}
proxy_health() {
  local body expected
  expected="$(expected_build_id)" || return 1
  body="$("$CURL_BIN" -fsS --max-time 2 "$PROXY_URL/healthz" 2>/dev/null)" || return 1
  printf '%s' "$body" | jq -e --arg build "$expected" \
    '.status=="ok" and .enforcement==true and .build_id==$build and (.pid|type=="number")' \
    >/dev/null 2>&1
}
proxy_restart_must_wait() {
  local body now
  body="$("$CURL_BIN" -fsS --max-time 2 "$PROXY_URL/healthz" 2>/dev/null)" || return 1
  now="$(($(date +%s) * 1000))"
  printf '%s' "$body" | jq -e --argjson now "$now" \
    '.status=="ok" and .enforcement==true
     and ((.active_requests // 1)>0
          or (.last_request_at_ms!=null and ($now-.last_request_at_ms)<5000))' \
    >/dev/null 2>&1
}
port_responds() {
  "$CURL_BIN" -sS --max-time 1 "$PROXY_URL/healthz" >/dev/null 2>&1
}
settings_proxy_active() {
  jq -e --arg url "$PROXY_URL" --arg cmd "$HOOK_COMMAND" \
    '.env.ANTHROPIC_BASE_URL==$url
     and ([.hooks.UserPromptSubmit[]?.hooks[]? | select(.command==$cmd)] | length)==1
     and ([.hooks.PostToolUse[]?.hooks[]? | select(.command==$cmd)] | length)==1' \
    "$CLAUDE_SETTINGS" >/dev/null 2>&1
}
settings_proxy_absent() {
  jq -e --arg cmd "$HOOK_COMMAND" \
    '(.env.ANTHROPIC_BASE_URL == null)
     and ([.hooks.UserPromptSubmit[]?.hooks[]? | select(.command==$cmd)] | length)==0
     and ([.hooks.PostToolUse[]?.hooks[]? | select(.command==$cmd)] | length)==0' \
    "$CLAUDE_SETTINGS" >/dev/null 2>&1
}
write_proxy_settings() {
  local source="$1" target="$2"
  jq --arg url "$PROXY_URL" '.env=(.env // {}) | .env.ANTHROPIC_BASE_URL=$url' \
    "$source" > "$target" \
    && preserve_mode "$source" "$target" \
    && "$HOOK_REGISTER" add "$target" >/dev/null \
    && preserve_mode "$source" "$target"
}
write_direct_settings() {
  local source="$1" target="$2"
  jq --arg url "$PROXY_URL" '
    if .env.ANTHROPIC_BASE_URL==$url then del(.env.ANTHROPIC_BASE_URL) else . end |
    if .env=={} then del(.env) else . end
  ' "$source" > "$target" \
    && preserve_mode "$source" "$target" \
    && "$HOOK_REGISTER" remove "$target" >/dev/null \
    && preserve_mode "$source" "$target"
}
write_proxy_mcp() {
  local source="$1" target="$2"
  jq --arg url "$PROXY_URL" '
    .mcpServers["context-bonsai"].env=(.mcpServers["context-bonsai"].env // {}) |
    .mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL=$url
  ' "$source" > "$target" \
    && preserve_mode "$source" "$target"
}
write_direct_mcp() {
  local source="$1" target="$2" prior="${3:-}" active_hash=""
  if [ -f "$prior" ] && jq -e '.mcpServers["context-bonsai"]' "$prior" >/dev/null 2>&1; then
    active_hash="$(jq -r '.activeMcpHash // empty' "$PROXY_STATE/active.json" 2>/dev/null)"
    if [ -n "$active_hash" ] && [ "$(sha256 "$source")" = "$active_hash" ]; then
      cp "$prior" "$target" && preserve_mode "$source" "$target"
      return $?
    fi
    jq --slurpfile prior "$prior" \
      '.mcpServers["context-bonsai"]=$prior[0].mcpServers["context-bonsai"]' \
      "$source" > "$target" \
      && preserve_mode "$source" "$target"
    return $?
  fi
  jq --arg url "$PROXY_URL" '
    if .mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL==$url
    then del(.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL)
    else . end |
    if .mcpServers["context-bonsai"].env=={}
    then del(.mcpServers["context-bonsai"].env)
    else . end
  ' "$source" > "$target" \
    && preserve_mode "$source" "$target"
}
render_plists() {
  local stamp="$1" proxy_cand="$PROXY_PLIST.cb-candidate.$stamp" guard_cand="$GUARD_PLIST.cb-candidate.$stamp"
  cat > "$proxy_cand" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$PROXY_LABEL</string>
  <key>ProgramArguments</key><array><string>/usr/bin/env</string><string>node</string><string>$PROXY_SCRIPT</string></array>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>$PATH_VALUE</string><key>HOME</key><string>$HOME</string>
    <key>CB_PROXY_PORT</key><string>$PROXY_PORT</string><key>CB_ENFORCE</key><string>1</string>
  </dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>2</integer>
  <key>StandardOutPath</key><string>$PROXY_STATE/proxy.out.log</string>
  <key>StandardErrorPath</key><string>$PROXY_STATE/proxy.err.log</string>
  <key>ProcessType</key><string>Background</string>
</dict></plist>
EOF
  cat > "$guard_cand" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$GUARD_LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$DIR/control.sh</string><string>guard</string></array>
  <key>StartInterval</key><integer>60</integer><key>RunAtLoad</key><true/>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>$PATH_VALUE</string><key>HOME</key><string>$HOME</string>
    <key>CB_PROXY_PORT</key><string>$PROXY_PORT</string>
  </dict>
  <key>StandardOutPath</key><string>$PROXY_STATE/guard.out.log</string>
  <key>StandardErrorPath</key><string>$PROXY_STATE/guard.err.log</string>
  <key>ProcessType</key><string>Background</string>
</dict></plist>
EOF
  plutil -lint "$proxy_cand" "$guard_cand" >/dev/null || return 1
  [ -f "$PROXY_PLIST" ] && cp "$PROXY_PLIST" "$PROXY_STATE/$PROXY_LABEL.$stamp.plist"
  [ -f "$GUARD_PLIST" ] && cp "$GUARD_PLIST" "$PROXY_STATE/$GUARD_LABEL.$stamp.plist"
  mv "$proxy_cand" "$PROXY_PLIST" && mv "$guard_cand" "$GUARD_PLIST"
}
verify_proxy_state() {
  local version bundle
  version="$(cb_claude_version)"; bundle="$(cb_claude_live_bundle)"
  [ -n "$version" ] && [ -n "$bundle" ] && [ -f "$bundle" ] \
    && cb_bundle_clean "$bundle" && bundle_version_matches "$bundle" "$version" \
    && cb_claude_proxy && settings_proxy_active && mcp_proxy_active \
    && proxy_health && loaded "$PROXY_LABEL" \
    && ! loaded "$WATCH_LABEL"
    # GUARD_LABEL intentionally not required: the proxy plist carries KeepAlive=true,
    # which covers process death. The residual is availability-only (an unhealthy-but-
    # running proxy), never context loss or bundle corruption — so a separate guard
    # agent would be machinery without a job.
}

guard_disable_route() {
  local stamp settings_cand settings_prior mcp_cand mcp_prior
  stamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  settings_cand="$(dirname "$CLAUDE_SETTINGS")/.cb-proxy-guard-settings.$stamp"
  settings_prior="$(dirname "$CLAUDE_SETTINGS")/.cb-proxy-guard-settings-prior.$stamp"
  mcp_cand="$(dirname "$CB_CLAUDE_JSON")/.cb-proxy-guard-mcp.$stamp"
  mcp_prior="$(dirname "$CB_CLAUDE_JSON")/.cb-proxy-guard-mcp-prior.$stamp"

  cp "$CLAUDE_SETTINGS" "$settings_prior" && cp "$CB_CLAUDE_JSON" "$mcp_prior" \
    && write_direct_settings "$CLAUDE_SETTINGS" "$settings_cand" \
    && jq 'if .mcpServers then .mcpServers |= del(.["context-bonsai"]) else . end' \
      "$CB_CLAUDE_JSON" > "$mcp_cand" \
    && preserve_mode "$CB_CLAUDE_JSON" "$mcp_cand" \
    && jq -e . "$settings_cand" >/dev/null && jq -e . "$mcp_cand" >/dev/null \
    || return 1

  cb_set_claude_mode disabled || return 1
  if mv "$settings_cand" "$CLAUDE_SETTINGS" && mv "$mcp_cand" "$CB_CLAUDE_JSON"; then
    if settings_proxy_absent && ! mcp_present && cb_claude_disabled; then
      cat > "$PROXY_STATE/last-failure.md" <<EOF
# Context Bonsai Claude proxy disabled — $(cb_ts)

The local Claude→Anthropic proxy did not recover after launchd restart attempts.
New Claude sessions now start on verified stock without Bonsai: the proxy route,
gauge hooks, and MCP registration were removed atomically. Running sessions that
already inherited the proxy URL may need a retry or restart.
EOF
      cb_notify "Context Bonsai — Claude proxy disabled safely" \
        "The Claude proxy did not recover. New sessions now use clean stock with Bonsai OFF; running sessions may need a retry or restart." \
        "Basso" "$PROXY_STATE/last-failure.md"
      return 0
    fi
  fi

  mv "$settings_prior" "$CLAUDE_SETTINGS" 2>/dev/null || true
  mv "$mcp_prior" "$CB_CLAUDE_JSON" 2>/dev/null || true
  cb_set_claude_mode proxy || true
  cb_notify "Context Bonsai — proxy rollback needs attention" \
    "The proxy failed and the clean-stock route rollback could not be verified. Existing files were restored where possible." \
    "Basso" "$PROXY_STATE"
  return 10
}

if [ "$ACTION" = "guard" ]; then
  cb_claude_proxy || exit 0
  proxy_health && exit 0
  # A healthy old build is not an outage. Wait for a quiet five-second seam
  # before launchd replaces it so an in-flight provider request is never cut.
  proxy_restart_must_wait && exit 0
  "$LAUNCHCTL_BIN" kickstart -k "$LAUNCH_DOMAIN/$PROXY_LABEL" >/dev/null 2>&1 || true
  for delay in ${CB_PROXY_RETRY_DELAYS:-1 1 2}; do
    sleep "$delay"
    proxy_health && exit 0
  done
  cb_acquire_lock || exit 0
  trap 'cb_release_lock' EXIT
  guard_disable_route
  exit $?
fi

if [ "$ACTION" = "verify" ]; then
  if verify_proxy_state; then
    echo "Claude proxy mode is healthy: stock bundle, MCP+hooks, matching supervised proxy, WatchPaths suppressed."
    exit 0
  fi
  echo "Claude proxy mode verification failed." >&2
  exit 10
fi

# ---- adopt ---------------------------------------------------------------
# Puts a machine into proxy mode, or repairs one that is partly there. This is the
# non-patch-coupled replacement for the retired `enable`: it asserts the desired
# state rather than performing a patched->stock transaction, so it is safe to
# re-run and safe on a machine that is already correct.
#
# One planner, two consumers: adopt_plan names the facts that DIFFER, dry-run
# prints that plan, and apply executes that same plan. Neither path re-derives
# what needs doing, so they cannot drift.
adopt_backup_path() {  # $1 = live bundle path
  printf '%s/%s.backup' "$CB_BACKUP_DIR" "$(printf '%s' "$1" | sed 's/[^a-zA-Z0-9._-]/_/g')"
}

adopt_plan() {  # emits one token per fact that differs from the desired state
  local bundle; bundle="$(cb_claude_live_bundle)"
  [ "$(mode_value)" = "proxy" ]              || echo mode
  loaded "$WATCH_LABEL"                      && echo watch
  loaded "$PROXY_LABEL"                      || echo proxy_agent
  settings_proxy_active                      || echo settings
  mcp_proxy_active                           || echo mcp
  [ -n "$bundle" ] && cb_bundle_any_patched "$bundle" && echo bundle
  return 0
}

# Validates prerequisites for the PLANNED facts only, before anything is written.
# A machine that already satisfies a fact is never blocked by that fact's inputs.
adopt_preflight() {  # $1 = plan
  local plan="$1" rc=0 version bundle backup url
  version="$(cb_claude_version)"; bundle="$(cb_claude_live_bundle)"
  command -v jq >/dev/null 2>&1 || { echo "adopt: jq is required." >&2; return 1; }

  case "$plan" in *settings*)
    jq -e . "$CLAUDE_SETTINGS" >/dev/null 2>&1 \
      || { echo "adopt: $CLAUDE_SETTINGS is not valid JSON." >&2; rc=1; }
    url="$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$CLAUDE_SETTINGS" 2>/dev/null)"
    [ -z "$url" ] || [ "$url" = "$PROXY_URL" ] \
      || { echo "adopt: ANTHROPIC_BASE_URL is owned by another route ($url); refusing." >&2; rc=1; }
    [ -x "$HOOK_REGISTER" ] || { echo "adopt: hook registrar missing: $HOOK_REGISTER" >&2; rc=1; }
    [ -f "$HOOK_SCRIPT" ]   || { echo "adopt: gauge hook missing: $HOOK_SCRIPT" >&2; rc=1; }
  ;; esac

  case "$plan" in *mcp*)
    jq -e . "$CB_CLAUDE_JSON" >/dev/null 2>&1 \
      || { echo "adopt: $CB_CLAUDE_JSON is not valid JSON." >&2; rc=1; }
    mcp_present || { echo "adopt: the context-bonsai MCP server is not registered; run maintenance first." >&2; rc=1; }
    url="$(jq -r '.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL // empty' "$CB_CLAUDE_JSON" 2>/dev/null)"
    [ -z "$url" ] || [ "$url" = "$PROXY_URL" ] \
      || { echo "adopt: the MCP base URL is owned by another route ($url); refusing." >&2; rc=1; }
  ;; esac

  case "$plan" in *proxy_agent*)
    [ -f "$PROXY_PLIST" ] || { echo "adopt: proxy LaunchAgent is not installed: $PROXY_PLIST" >&2; rc=1; }
  ;; esac

  # Routing Claude at a dead proxy breaks every request, so never write the base URL
  # without proof the proxy is serving. If we are ALSO starting it, that proof comes
  # after bootstrap during apply; if it is supposed to be up already, demand it now.
  case "$plan" in *settings*)
    case "$plan" in
      *proxy_agent*) ;;
      *) proxy_health \
           || { echo "adopt: the proxy is not serving a matching build; refusing to route Claude at it." >&2; rc=1; };;
    esac
  ;; esac

  # The bundle swap is the one step that can break his Claude install, so the
  # backup must be present, genuinely clean, and the SAME version as what is live.
  case "$plan" in *bundle*)
    backup="$(adopt_backup_path "$bundle")"
    if [ ! -f "$backup" ]; then
      echo "adopt: no stock backup for the live bundle: $backup" >&2; rc=1
    else
      cb_bundle_clean "$backup" \
        || { echo "adopt: the stock backup is itself patched; refusing to swap it in." >&2; rc=1; }
      [ -n "$version" ] && bundle_version_matches "$backup" "$version" \
        || { echo "adopt: the stock backup is not version $version; refusing to swap it in." >&2; rc=1; }
    fi
  ;; esac
  return $rc
}

if [ "$ACTION" = "adopt" ]; then
  DRY="${CB_ADOPT_DRY_RUN:-0}"; STAGED=""
  adopt_cleanup() { [ -z "$STAGED" ] || rm -f $STAGED 2>/dev/null; }
  # Lock BEFORE planning, not after preflight. Preflight validates the very bundle and
  # settings that apply then mutates, so a maintenance run landing in between would leave
  # adopt executing a stale plan — swapping in a backup that was version-matched when
  # checked and is not any more. Holding it across plan+preflight+apply is the only way
  # the validation still describes what gets written. A dry run takes no lock: it mutates
  # nothing, and cb_acquire_lock itself writes.
  if [ "$DRY" != "1" ]; then
    cb_acquire_lock || { echo "adopt: could not acquire the maintenance lock (another run may be active, or the lock path is unwritable — see the log); retry shortly." >&2; exit 20; }
    trap 'adopt_cleanup; cb_release_lock' EXIT
  fi
  PLAN="$(adopt_plan)"
  if [ -z "$PLAN" ]; then
    echo "Claude proxy mode already fully adopted; nothing to change."
    verify_proxy_state || { echo "…but verify still fails; run '$0 verify' for detail." >&2; exit 10; }
    exit 0
  fi
  adopt_preflight "$PLAN" || { echo "adopt: preflight failed; nothing was changed." >&2; exit 10; }

  if [ "$DRY" = "1" ]; then
    echo "DRY RUN — no changes made. Would change:"
    for fact in $PLAN; do case "$fact" in
      mode)        echo "  - claude-mode: $(mode_value) -> proxy (stops the patcher re-patching)";;
      watch)       echo "  - unload $WATCH_LABEL (the re-patch watcher)";;
      proxy_agent) echo "  - load $PROXY_LABEL";;
      settings)    echo "  - $CLAUDE_SETTINGS: route ANTHROPIC_BASE_URL to $PROXY_URL + register gauge hooks";;
      mcp)         echo "  - $CB_CLAUDE_JSON: route the context-bonsai MCP to $PROXY_URL";;
      bundle)      echo "  - restore stock $(cb_claude_version) from $(adopt_backup_path "$(cb_claude_live_bundle)")";;
    esac; done
    exit 0
  fi

  # ponytail: apply CONVERGES, it does not transact. Preflight is all-or-nothing, but if
  # a later fact fails mid-apply the earlier ones stay applied and the run exits non-zero.
  # That is deliberate for an asserter: re-running repairs the remainder, and every fact
  # is independently checked, so a partial run is a machine closer to correct rather than
  # a corrupt one. It is safe here only because preflight already validated every planned
  # fact, so a mid-apply failure means I/O trouble, not a bad plan — and because the one
  # hard-to-reverse fact (bundle) runs last, after everything else has succeeded. If a
  # future fact is added that is BOTH irreversible and not last, this needs real rollback.
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  for fact in $PLAN; do
    case "$fact" in
      # Mode first: it stops the reconciler re-patching while the rest is applied.
      mode) cb_set_claude_mode proxy || { echo "adopt: could not persist proxy mode." >&2; exit 10; }
            echo "  set claude-mode=proxy";;
      # bootout() swallows failure by design, so confirm rather than assume. Reporting
      # a watcher as unloaded while it is still live is the one lie that would let the
      # re-patch treadmill keep running under a "successfully adopted" message.
      watch) bootout "$WATCH_LABEL"
            loaded "$WATCH_LABEL" && { echo "adopt: could not unload $WATCH_LABEL." >&2; exit 10; }
            echo "  unloaded $WATCH_LABEL";;
      # Bootstrapping only proves launchd accepted the job. Settings comes next and points
      # Claude at this URL, so prove it is actually SERVING a matching build first —
      # otherwise adopt is the thing that breaks every Claude request.
      proxy_agent) bootstrap "$PROXY_LABEL" "$PROXY_PLIST" \
            || { echo "adopt: proxy LaunchAgent failed to start." >&2; exit 10; }
            for delay in ${CB_PROXY_START_DELAYS:-0.2 0.5 1 2}; do
              proxy_health && break
              sleep "$delay"
            done
            proxy_health || { echo "adopt: proxy started but is not serving a matching build." >&2; exit 10; }
            echo "  loaded $PROXY_LABEL";;
      settings) cand="$CLAUDE_SETTINGS.cb-adopt.$STAMP"; STAGED="$STAGED $cand"
            write_proxy_settings "$CLAUDE_SETTINGS" "$cand" && jq -e . "$cand" >/dev/null 2>&1 \
              && mv "$cand" "$CLAUDE_SETTINGS" \
              || { echo "adopt: could not write proxy settings." >&2; exit 10; }
            echo "  routed $CLAUDE_SETTINGS + registered gauge hooks";;
      mcp) cand="$CB_CLAUDE_JSON.cb-adopt.$STAMP"; STAGED="$STAGED $cand"
            write_proxy_mcp "$CB_CLAUDE_JSON" "$cand" && jq -e . "$cand" >/dev/null 2>&1 \
              && mv "$cand" "$CB_CLAUDE_JSON" \
              || { echo "adopt: could not write the MCP proxy env." >&2; exit 10; }
            echo "  routed the context-bonsai MCP";;
      # Bundle LAST: the only hard-to-reverse step, committed once everything else holds.
      bundle) live="$(cb_claude_live_bundle)"; cand="$(dirname "$live")/.cb-adopt-stock.$STAMP"
            STAGED="$STAGED $cand"
            cp "$(adopt_backup_path "$live")" "$cand" && preserve_mode "$live" "$cand" \
              && mv "$cand" "$live" \
              || { echo "adopt: could not restore the stock bundle; the live bundle is untouched." >&2; exit 10; }
            echo "  restored stock $(cb_claude_version)";;
    esac
  done

  if verify_proxy_state; then
    echo "Claude proxy mode adopted: stock bundle, MCP+hooks, matching supervised proxy, WatchPaths suppressed."
    exit 0
  fi
  echo "adopt: changes applied but verification still fails; run '$0 verify' for detail." >&2
  exit 10
fi

# ---- release -------------------------------------------------------------
# The off-ramp adopt owes. Reverses ONLY Bonsai-owned state and leaves everything else
# alone: the write_direct_* helpers delete ANTHROPIC_BASE_URL only when it is OUR url,
# and the hook registrar removes only its own exact command, so unrelated permissions,
# plugins, model, theme and any other route survive untouched.
#
# Deliberately NOT done: the stock bundle is left stock and the WatchPaths agent is left
# unloaded. Reloading it would re-patch the binary, which is the treadmill this whole
# migration existed to end. Mode therefore goes to `disabled`, not `enabled` — Bonsai off
# AND staying off, rather than off until the next Claude release quietly patches it back.
release_plan() {
  settings_proxy_absent          || echo settings
  mcp_proxy_absent               || echo mcp
  loaded "$PROXY_LABEL"          && echo proxy_agent
  [ "$(mode_value)" = "disabled" ] || echo mode
  return 0
}

if [ "$ACTION" = "release" ]; then
  DRY="${CB_ADOPT_DRY_RUN:-0}"; STAGED=""
  release_cleanup() { [ -z "$STAGED" ] || rm -f $STAGED 2>/dev/null; }
  # Same reasoning as adopt: the lock spans plan, checks and mutation so the checks still
  # describe what gets written. Dry run stays lock-free.
  if [ "$DRY" != "1" ]; then
    cb_acquire_lock || { echo "release: could not acquire the maintenance lock (another run may be active, or the lock path is unwritable — see the log); retry shortly." >&2; exit 20; }
    trap 'release_cleanup; cb_release_lock' EXIT
  fi
  PLAN="$(release_plan)"
  if [ -z "$PLAN" ]; then echo "Claude proxy mode already released; nothing to change."; exit 0; fi
  command -v jq >/dev/null 2>&1 || { echo "release: jq is required." >&2; exit 10; }
  case "$PLAN" in *settings*)
    jq -e . "$CLAUDE_SETTINGS" >/dev/null 2>&1 \
      || { echo "release: $CLAUDE_SETTINGS is not valid JSON; nothing was changed." >&2; exit 10; }
    [ -x "$HOOK_REGISTER" ] \
      || { echo "release: hook registrar missing: $HOOK_REGISTER" >&2; exit 10; };; esac
  case "$PLAN" in *mcp*)
    jq -e . "$CB_CLAUDE_JSON" >/dev/null 2>&1 \
      || { echo "release: $CB_CLAUDE_JSON is not valid JSON; nothing was changed." >&2; exit 10; };; esac

  if [ "$DRY" = "1" ]; then
    echo "DRY RUN — no changes made. Would change:"
    for fact in $PLAN; do case "$fact" in
      settings)    echo "  - $CLAUDE_SETTINGS: drop our ANTHROPIC_BASE_URL + unregister our gauge hooks";;
      mcp)         echo "  - $CB_CLAUDE_JSON: drop our base URL from the context-bonsai MCP env";;
      proxy_agent) echo "  - unload $PROXY_LABEL";;
      mode)        echo "  - claude-mode: $(mode_value) -> disabled (Bonsai off and staying off)";;
    esac; done
    exit 0
  fi

  STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  for fact in $PLAN; do
    case "$fact" in
      # Settings first: stop routing Claude at the proxy BEFORE stopping the proxy, so
      # there is no window where the base URL points at something no longer listening.
      settings) cand="$CLAUDE_SETTINGS.cb-release.$STAMP"; STAGED="$STAGED $cand"
            write_direct_settings "$CLAUDE_SETTINGS" "$cand" && jq -e . "$cand" >/dev/null 2>&1 \
              && mv "$cand" "$CLAUDE_SETTINGS" \
              || { echo "release: could not rewrite settings; nothing further changed." >&2; exit 10; }
            echo "  unrouted $CLAUDE_SETTINGS + unregistered gauge hooks";;
      mcp) cand="$CB_CLAUDE_JSON.cb-release.$STAMP"; STAGED="$STAGED $cand"
            write_direct_mcp "$CB_CLAUDE_JSON" "$cand" && jq -e . "$cand" >/dev/null 2>&1 \
              && mv "$cand" "$CB_CLAUDE_JSON" \
              || { echo "release: could not rewrite the MCP env." >&2; exit 10; }
            echo "  unrouted the context-bonsai MCP";;
      proxy_agent) bootout "$PROXY_LABEL"
            loaded "$PROXY_LABEL" && { echo "release: could not unload $PROXY_LABEL." >&2; exit 10; }
            echo "  unloaded $PROXY_LABEL";;
      mode) cb_set_claude_mode disabled || { echo "release: could not persist disabled mode." >&2; exit 10; }
            echo "  set claude-mode=disabled";;
    esac
  done
  echo "Claude Bonsai released: stock bundle, no proxy route, no gauge hooks, patcher suppressed."
  echo "Re-adopt with: $0 adopt"
  exit 0
fi

if [ "$ACTION" = "retire" ]; then
  [ "${CB_CONFIRM_DRAINED:-0}" = "1" ] || {
    echo "Refusing to stop the proxy: restart all Claude sessions, then rerun with CB_CONFIRM_DRAINED=1." >&2
    exit 2
  }
  cb_claude_proxy && { echo "Refusing to stop the active Claude proxy route." >&2; exit 10; }
  settings_proxy_absent && mcp_proxy_absent \
    || { echo "Refusing to stop: Claude settings or MCP still route to this proxy." >&2; exit 10; }
  bootout "$GUARD_LABEL"; bootout "$PROXY_LABEL"
  echo "Claude proxy supervision stopped after explicit drain confirmation; plist and evidence files were retained."
  exit 0
fi

if [ "${CB_LOCK_HELD:-0}" != "1" ]; then
  cb_acquire_lock || { echo "Claude proxy cutover skipped: maintenance is already running." >&2; exit 20; }
  trap 'cb_release_lock' EXIT
fi

for file in "$PROXY_SCRIPT" "$CORRELATE_SCRIPT" "$HOOK_SCRIPT" "$HOOK_REGISTER" "$CLAUDE_SETTINGS" "$CB_CLAUDE_JSON"; do
  [ -f "$file" ] || { echo "Required file missing: $file" >&2; exit 10; }
done
grep -qF '[[CB-PRUNE v1 archive=' "$CB_PORT/mcp-server/index.ts" \
  && grep -qF 'canonicalHash' "$CB_PORT/mcp-server/index.ts" \
  && grep -qF 'verifiedLocalProxyEnforcement' "$CB_PORT/mcp-server/index.ts" \
  || { echo "Runtime MCP lacks the wire-marker/shared-hash capability; nothing changed." >&2; exit 10; }
for command in node bun jq shasum plutil "$CURL_BIN" "$LAUNCHCTL_BIN"; do
  command -v "$command" >/dev/null 2>&1 || { echo "Required command missing: $command" >&2; exit 10; }
done
jq -e . "$CLAUDE_SETTINGS" >/dev/null && jq -e . "$CB_CLAUDE_JSON" >/dev/null \
  || { echo "Claude configuration JSON is invalid; nothing changed." >&2; exit 10; }

if [ "$ACTION" = "enable" ]; then
  if verify_proxy_state; then
    echo "Claude proxy mode is already enabled and healthy."
    exit 0
  fi
  existing_url="$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$CLAUDE_SETTINGS")"
  [ -z "$existing_url" ] || [ "$existing_url" = "$PROXY_URL" ] || {
    echo "ANTHROPIC_BASE_URL is already owned by another route ($existing_url); nothing changed." >&2
    exit 10
  }
  existing_mcp_url="$(jq -r '.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL // empty' "$CB_CLAUDE_JSON")"
  [ -z "$existing_mcp_url" ] || [ "$existing_mcp_url" = "$PROXY_URL" ] || {
    echo "The context-bonsai MCP already has a different ANTHROPIC_BASE_URL ($existing_mcp_url); nothing changed." >&2
    exit 10
  }
  if ! proxy_health && port_responds; then
    echo "$PROXY_URL is occupied by a different or stale service; nothing changed." >&2
    exit 10
  fi
  node --check "$PROXY_SCRIPT" >/dev/null \
    && node "$(dirname "$PROXY_SCRIPT")/correlate.test.mjs" >/dev/null \
    && node "$(dirname "$PROXY_SCRIPT")/proxy.test.mjs" >/dev/null \
    || { echo "Proxy certification tests failed; nothing changed." >&2; exit 10; }

  version="$(cb_claude_version)"; bundle="$(cb_claude_live_bundle)"
  [ -n "$version" ] && [ -n "$bundle" ] && [ -f "$bundle" ] \
    && cb_bundle_fully_patched "$bundle" && bundle_version_matches "$bundle" "$version" \
    && mcp_present \
    || { echo "Current Claude Bonsai patch/MCP state is not fully healthy; nothing changed." >&2; exit 10; }
  backup="$CB_BACKUP_DIR/$(printf '%s' "$bundle" | sed 's/[^a-zA-Z0-9._-]/_/g').backup"
  [ -f "$backup" ] && cb_bundle_clean "$backup" && bundle_version_matches "$backup" "$version" \
    || { echo "Verified clean Claude $version backup is unavailable; nothing changed." >&2; exit 10; }
  [ "$(mode_value)" = "enabled" ] \
    || { echo "Claude is not in host-patch mode; refusing a nonstandard cutover." >&2; exit 10; }

  stamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  prior_bundle="$(dirname "$bundle")/.cb-proxy-patched-prior.$stamp"
  stock_cand="$(dirname "$bundle")/.cb-proxy-stock.$stamp"
  prior_settings="$(dirname "$CLAUDE_SETTINGS")/.cb-proxy-settings-prior.$stamp"
  settings_cand="$(dirname "$CLAUDE_SETTINGS")/.cb-proxy-settings.$stamp"
  prior_mcp="$(dirname "$CB_CLAUDE_JSON")/.cb-proxy-mcp-prior.$stamp"
  mcp_cand="$(dirname "$CB_CLAUDE_JSON")/.cb-proxy-mcp.$stamp"
  cp "$bundle" "$prior_bundle" && chmod +x "$prior_bundle" \
    && cp "$backup" "$stock_cand" && chmod +x "$stock_cand" \
    && cp "$CLAUDE_SETTINGS" "$prior_settings" \
    && cp "$CB_CLAUDE_JSON" "$prior_mcp" \
    && write_proxy_settings "$CLAUDE_SETTINGS" "$settings_cand" \
    && write_proxy_mcp "$CB_CLAUDE_JSON" "$mcp_cand" \
    && jq -e . "$settings_cand" >/dev/null && jq -e . "$mcp_cand" >/dev/null \
    && cb_bundle_fully_patched "$prior_bundle" \
    && cb_bundle_clean "$stock_cand" && bundle_version_matches "$stock_cand" "$version" \
    || { echo "Candidate staging failed; live state untouched." >&2; exit 10; }
  prior_bundle_hash="$(sha256 "$prior_bundle")"
  prior_settings_hash="$(sha256 "$prior_settings")"
  prior_mcp_hash="$(sha256 "$prior_mcp")"
  render_plists "$stamp" || { echo "LaunchAgent staging failed; live state untouched." >&2; exit 10; }

  previous_mode="$(mode_value)"
  watch_was_loaded=0; loaded "$WATCH_LABEL" && watch_was_loaded=1
  daily_was_loaded=0; loaded "$DAILY_LABEL" && daily_was_loaded=1
  proxy_was_loaded=0; loaded "$PROXY_LABEL" && proxy_was_loaded=1
  guard_was_loaded=0; loaded "$GUARD_LABEL" && guard_was_loaded=1
  if ! loaded "$PROXY_LABEL"; then bootstrap "$PROXY_LABEL" "$PROXY_PLIST" || {
    [ "$proxy_was_loaded" = "1" ] || bootout "$PROXY_LABEL"
    echo "Proxy LaunchAgent failed to start; live Claude state untouched." >&2; exit 10;
  }; fi
  for delay in ${CB_PROXY_START_DELAYS:-0.2 0.5 1}; do
    proxy_health && break
    sleep "$delay"
  done
  proxy_health || {
    [ "$proxy_was_loaded" = "1" ] || bootout "$PROXY_LABEL"
    echo "Proxy failed its health/build gate; live Claude state untouched." >&2
    exit 10
  }

  committed_bundle=0; committed_settings=0; committed_mcp=0
  cb_set_claude_mode proxy && { bootout "$WATCH_LABEL"; true; } \
    && mv "$stock_cand" "$bundle" && committed_bundle=1 \
    && mv "$settings_cand" "$CLAUDE_SETTINGS" && committed_settings=1 \
    && mv "$mcp_cand" "$CB_CLAUDE_JSON" && committed_mcp=1 \
    && { loaded "$GUARD_LABEL" || bootstrap "$GUARD_LABEL" "$GUARD_PLIST"; } \
    && verify_proxy_state \
    && { [ "$daily_was_loaded" = "0" ] || loaded "$DAILY_LABEL"; }
  commit_rc=$?
  if [ "$commit_rc" = "0" ]; then
    jq -n --arg activatedAt "$(cb_ts)" --arg url "$PROXY_URL" --arg version "$version" \
      --arg bundle "$bundle" --arg priorBundle "$prior_bundle" \
      --arg priorSettings "$prior_settings" --arg priorMcp "$prior_mcp" \
      --arg activeMcpHash "$(sha256 "$CB_CLAUDE_JSON")" --arg build "$(expected_build_id)" \
      '{activatedAt:$activatedAt,url:$url,claudeVersion:$version,bundle:$bundle,
        priorBundle:$priorBundle,priorSettings:$priorSettings,priorMcp:$priorMcp,
        activeMcpHash:$activeMcpHash,buildId:$build}' \
      > "$PROXY_STATE/active.json"
    cb_notify "Context Bonsai — Claude proxy enabled" \
      "Claude $version now uses the supervised zero-patch Bonsai proxy for new sessions. Existing sessions were untouched." \
      "" "$PROXY_STATE/active.json"
    echo "Claude proxy enabled and verified; daily source+Codex maintenance remains loaded."
    exit 0
  fi

  rollback_ok=1
  [ "$committed_mcp" = "0" ] || mv "$prior_mcp" "$CB_CLAUDE_JSON" || rollback_ok=0
  [ "$committed_settings" = "0" ] || mv "$prior_settings" "$CLAUDE_SETTINGS" || rollback_ok=0
  [ "$committed_bundle" = "0" ] || mv "$prior_bundle" "$bundle" || rollback_ok=0
  cb_set_claude_mode "$previous_mode" || rollback_ok=0
  if [ "$watch_was_loaded" = "1" ] && ! loaded "$WATCH_LABEL"; then
    bootstrap "$WATCH_LABEL" "$WATCH_PLIST" || rollback_ok=0
  fi
  [ "$guard_was_loaded" = "1" ] || bootout "$GUARD_LABEL"
  [ "$proxy_was_loaded" = "1" ] || bootout "$PROXY_LABEL"
  if [ "$rollback_ok" = "1" ] && cb_bundle_fully_patched "$bundle" \
    && [ "$(sha256 "$bundle")" = "$prior_bundle_hash" ] \
    && [ "$(sha256 "$CLAUDE_SETTINGS")" = "$prior_settings_hash" ] \
    && [ "$(sha256 "$CB_CLAUDE_JSON")" = "$prior_mcp_hash" ]; then
    echo "Claude proxy activation failed; prior patched state was auto-restored." >&2
  else
    echo "URGENT: Claude proxy activation failed and exact restoration needs review. Evidence: $PROXY_STATE" >&2
  fi
  exit 10
fi

# rollback/off-ramp: reapply the certified host patch before removing the route.
version="$(cb_claude_version)"; bundle="$(cb_claude_live_bundle)"
[ -n "$version" ] && [ -n "$bundle" ] && [ -f "$bundle" ] \
  || { echo "Could not resolve the installed Claude bundle; proxy state unchanged." >&2; exit 20; }
if cb_bundle_fully_patched "$bundle" && bundle_version_matches "$bundle" "$version" \
  && settings_proxy_absent && mcp_proxy_absent \
  && [ "$(mode_value)" = "enabled" ] && mcp_present; then
  echo "Claude host-patch mode is already enabled; proxy route is absent."
  exit 0
fi
existing_url="$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$CLAUDE_SETTINGS")"
[ -z "$existing_url" ] || [ "$existing_url" = "$PROXY_URL" ] || {
  echo "ANTHROPIC_BASE_URL is owned by another route ($existing_url); nothing changed." >&2
  exit 10
}
existing_mcp_url="$(jq -r '.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL // empty' "$CB_CLAUDE_JSON")"
[ -z "$existing_mcp_url" ] || [ "$existing_mcp_url" = "$PROXY_URL" ] || {
  echo "The context-bonsai MCP ANTHROPIC_BASE_URL is owned by another route ($existing_mcp_url); nothing changed." >&2
  exit 10
}
offstamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"
settings_cand="$(dirname "$CLAUDE_SETTINGS")/.cb-proxy-offramp-settings.$offstamp"
prior_settings="$(dirname "$CLAUDE_SETTINGS")/.cb-proxy-offramp-prior.$offstamp"
mcp_cand="$(dirname "$CB_CLAUDE_JSON")/.cb-proxy-offramp-mcp.$offstamp"
prior_mcp="$(dirname "$CB_CLAUDE_JSON")/.cb-proxy-offramp-mcp-prior.$offstamp"
saved_mcp="$(jq -r '.priorMcp // empty' "$PROXY_STATE/active.json" 2>/dev/null)"
cp "$CLAUDE_SETTINGS" "$prior_settings" \
  && cp "$CB_CLAUDE_JSON" "$prior_mcp" \
  && write_direct_settings "$CLAUDE_SETTINGS" "$settings_cand" \
  && write_direct_mcp "$CB_CLAUDE_JSON" "$mcp_cand" "$saved_mcp" \
  && jq -e . "$settings_cand" >/dev/null && jq -e . "$mcp_cand" >/dev/null \
  || { echo "Could not stage direct-route settings; proxy remains active." >&2; exit 10; }

previous_mode="$(mode_value)"
cb_set_claude_mode enabled || { echo "Could not stage enabled mode; proxy remains active." >&2; exit 10; }
CLAUDE_REC="${CB_CLAUDE_RECONCILER:-$DIR/../auto-maintenance/reconcile-claude.sh}"
"$CLAUDE_REC" >/dev/null
reconcile_rc=$?
if [ "$reconcile_rc" != "0" ] || ! cb_bundle_fully_patched "$bundle" \
  || ! bundle_version_matches "$bundle" "$version" || ! mcp_present; then
  cb_set_claude_mode "$previous_mode" || true
  echo "Claude patch certification failed; proxy route and settings remain active." >&2
  exit 10
fi

committed_settings=0; committed_mcp=0
if mv "$settings_cand" "$CLAUDE_SETTINGS" && committed_settings=1 \
  && mv "$mcp_cand" "$CB_CLAUDE_JSON" && committed_mcp=1 \
  && settings_proxy_absent && mcp_proxy_absent; then
  if [ -f "$WATCH_PLIST" ] && ! loaded "$WATCH_LABEL"; then
    bootstrap "$WATCH_LABEL" "$WATCH_PLIST" || {
      [ "$committed_mcp" = "0" ] || mv "$prior_mcp" "$CB_CLAUDE_JSON" 2>/dev/null || true
      mv "$prior_settings" "$CLAUDE_SETTINGS" 2>/dev/null || true
      cb_set_claude_mode proxy || true
      echo "WatchPaths restart failed; proxy route was restored and the patched bundle remains safe." >&2
      exit 10
    }
  fi
  cb_notify "Context Bonsai — Claude patch off-ramp complete" \
    "New Claude sessions use the certified host patch again. The proxy remains supervised only for already-running sessions that inherited its URL." \
    "" "$PROXY_STATE"
  echo "Claude patch mode restored; proxy kept alive for already-running routed sessions."
  echo "After restarting all Claude sessions: CB_CONFIRM_DRAINED=1 $DIR/control.sh retire"
  exit 0
fi

[ "$committed_mcp" = "0" ] || mv "$prior_mcp" "$CB_CLAUDE_JSON" 2>/dev/null || true
mv "$prior_settings" "$CLAUDE_SETTINGS" 2>/dev/null || true
cb_set_claude_mode proxy || true
echo "Direct-route settings swap failed; proxy route was restored and the patched bundle remains safe." >&2
exit 10
