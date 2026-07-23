#!/usr/bin/env bash
# Isolated transaction fixtures. Creates a retained .staging sandbox; never
# touches the real Claude bundle, settings, MCP config, or LaunchAgents.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTROL="$ROOT/adoption/claude-proxy/control.sh"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
SB="$ROOT/.staging/claude-proxy-fixtures-$STAMP"
mkdir -p "$SB/bin" "$SB/launch-agents" "$SB/state" "$SB/backups" "$SB/proxy-state"

pass=0; fail=0
check() {
  if [ "$2" = "$3" ]; then
    echo "  PASS: $1"; pass=$((pass+1))
  else
    echo "  FAIL: $1 (got '$2', want '$3')"; fail=$((fail+1))
  fi
}
sha() { shasum -a 256 "$1" | awk '{print $1}'; }

real_bundle="$(readlink "$HOME/.local/bin/claude")"
real_bundle_before="$(sha "$real_bundle")"
real_settings_before="$(sha "$HOME/.claude/settings.json")"
real_mcp_before="$(sha "$HOME/.claude.json")"
real_agents_before="$(find "$HOME/Library/LaunchAgents" -maxdepth 1 -name 'com.atighi.context-bonsai*' -type f -exec shasum -a 256 {} \; | sort | shasum -a 256 | awk '{print $1}')"

cat > "$SB/patched-claude" <<'EOF'
#!/bin/sh
# cb:archived-filter
# cb:message-content-ids
# cb:context-bonsai-gauge
# cb:in-memory-archive
# __cbContextBonsaiApplyInMemory
# excluded_messages=
# __cbTurns%5===0
# __cbContextBonsaiInjectGauge
# cache_read_input_tokens
echo "Claude Code 2.1.218"
EOF
chmod +x "$SB/patched-claude"
cp "$SB/patched-claude" "$SB/live-claude"
cat > "$SB/stock-claude" <<'EOF'
#!/bin/sh
echo "Claude Code 2.1.218"
EOF
chmod +x "$SB/stock-claude"
ln -s "$SB/live-claude" "$SB/claude"
backup="$SB/backups/$(printf '%s' "$SB/live-claude" | sed 's/[^a-zA-Z0-9._-]/_/g').backup"
cp "$SB/stock-claude" "$backup"
chmod +x "$backup"

cat > "$SB/settings.json" <<'EOF'
{"theme":"dark","hooks":{"SessionStart":[{"matcher":"*","hooks":[{"type":"command","command":"echo existing"}]}]}}
EOF
chmod 600 "$SB/settings.json"
cat > "$SB/claude.json" <<EOF
{"mcpServers":{"context-bonsai":{"command":"bun","args":["run","$ROOT/tweakcc_context_bonsai/mcp-server/index.ts"]}}}
EOF
printf 'enabled\n' > "$SB/state/claude-mode"
printf '%s\n' \
  com.atighi.context-bonsai-maintenance \
  com.atighi.context-bonsai-maintenance-claudewatch \
  com.atighi.context-bonsai-maintenance-reminder > "$SB/launch-state"

cat > "$SB/launch-agents/com.atighi.context-bonsai-maintenance-claudewatch.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>Label</key><string>com.atighi.context-bonsai-maintenance-claudewatch</string>
</dict></plist>
EOF

cat > "$SB/bin/launchctl" <<'EOF'
#!/bin/bash
set -u
state="$CB_FAKE_LAUNCH_STATE"
case "$1" in
  print)
    label="${2##*/}"
    grep -Fx "$label" "$state" >/dev/null 2>&1
    ;;
  bootout)
    label="${2##*/}"
    awk -v label="$label" '$0 != label' "$state" > "$state.next"
    mv "$state.next" "$state"
    ;;
  bootstrap)
    label="$(plutil -extract Label raw -o - "$3")" || exit 1
    [ "${CB_FAKE_FAIL_LABEL:-}" != "$label" ] || exit 1
    grep -Fx "$label" "$state" >/dev/null 2>&1 || printf '%s\n' "$label" >> "$state"
    ;;
  enable|kickstart) exit 0 ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$SB/bin/launchctl"

cat > "$SB/bin/curl" <<'EOF'
#!/bin/bash
[ "${CB_FAKE_HEALTH:-ok}" = "ok" ] || exit 7
cat "$CB_FAKE_HEALTH_FILE"
EOF
chmod +x "$SB/bin/curl"

cat > "$SB/bin/reconcile-claude" <<'EOF'
#!/bin/bash
target="$(readlink "$CB_CLAUDE_LAUNCHER")"
cp "$CB_FIXTURE_PATCHED_SOURCE" "$target"
chmod +x "$target"
printf 'claude 2.1.218: fixture patch applied\n'
EOF
chmod +x "$SB/bin/reconcile-claude"

proxy="$ROOT/tweakcc_context_bonsai/proxy-prototype/proxy.mjs"
correlate="$ROOT/tweakcc_context_bonsai/proxy-prototype/correlate.mjs"
build="$({ cat "$proxy"; printf '\0'; cat "$correlate"; } | shasum -a 256 | awk '{print $1}')"
printf '{"status":"ok","pid":12345,"enforcement":true,"build_id":"%s","active_requests":0,"last_request_at_ms":null}\n' "$build" > "$SB/health.json"

export CB_CLAUDE_LAUNCHER="$SB/claude"
export CB_CLAUDE_SETTINGS="$SB/settings.json"
export CB_CLAUDE_JSON="$SB/claude.json"
export CB_BACKUP_DIR="$SB/backups"
export CB_STATE="$SB/state"
export CB_PROXY_STATE="$SB/proxy-state"
export CB_LAUNCH_AGENT_DIR="$SB/launch-agents"
export CB_LAUNCH_DOMAIN="gui/fixture"
export CB_LAUNCHCTL="$SB/bin/launchctl"
export CB_CURL="$SB/bin/curl"
export CB_FAKE_LAUNCH_STATE="$SB/launch-state"
export CB_FAKE_HEALTH_FILE="$SB/health.json"
export CB_PROXY_SCRIPT="$proxy"
export CB_CORRELATE_SCRIPT="$correlate"
export CB_GAUGE_HOOK="$ROOT/tweakcc_context_bonsai/hooks/context-bonsai-gauge.ts"
export CB_PROXY_PORT=38439
export CB_PROXY_START_DELAYS="0"
export CB_PROXY_RETRY_DELAYS="0 0"
export CB_CLAUDE_RECONCILER="$SB/bin/reconcile-claude"
export CB_FIXTURE_PATCHED_SOURCE="$SB/patched-claude"
export CB_TERMINAL_NOTIFIER=/bin/true
export CB_OSASCRIPT=/bin/false

echo "=== final-go gate ==="
patched_hash="$(sha "$SB/live-claude")"
settings_hash="$(sha "$SB/settings.json")"
bash "$CONTROL" enable >/dev/null 2>&1; rc=$?
check "direct activation without final go is refused" "$rc" "2"
check "refused activation leaves the bundle byte-identical" "$(sha "$SB/live-claude")" "$patched_hash"
check "refused activation leaves settings byte-identical" "$(sha "$SB/settings.json")" "$settings_hash"
export CB_FINAL_GO=1

echo "=== post-commit failure auto-rollback ==="
patched_hash="$(sha "$SB/live-claude")"
settings_hash="$(sha "$SB/settings.json")"
CB_FAKE_FAIL_LABEL=com.atighi.context-bonsai-proxy-guard \
  bash "$CONTROL" enable >/dev/null 2>&1; rc=$?
check "injected post-commit failure exits attention" "$rc" "10"
check "failed cutover restores patched bundle exactly" "$(sha "$SB/live-claude")" "$patched_hash"
check "failed cutover restores settings exactly" "$(sha "$SB/settings.json")" "$settings_hash"
check "failed cutover restores enabled mode" "$(cat "$SB/state/claude-mode")" "enabled"
check "failed cutover reloads WatchPaths" "$(grep -Fxc 'com.atighi.context-bonsai-maintenance-claudewatch' "$SB/launch-state")" "1"
check "failed cutover unloads newly-started proxy" "$(grep -Fxc 'com.atighi.context-bonsai-proxy' "$SB/launch-state")" "0"

echo "=== proxy enable transaction ==="
out="$(bash "$CONTROL" enable 2>&1)"; rc=$?
echo "  -> $out (rc=$rc)"
check "enable exits cleanly" "$rc" "0"
check "bundle atomically becomes stock" "$(grep -ca 'cb:archived-filter' "$SB/live-claude")" "0"
check "mode becomes proxy" "$(cat "$SB/state/claude-mode")" "proxy"
check "base URL is installed" "$(jq -r '.env.ANTHROPIC_BASE_URL' "$SB/settings.json")" "http://127.0.0.1:38439"
check "private settings mode is preserved" "$(stat -f '%Lp' "$SB/settings.json")" "600"
check "existing hook survives" "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$SB/settings.json")" "echo existing"
check "gauge hook registered twice" "$(jq '[.hooks.UserPromptSubmit[]?.hooks[]?,.hooks.PostToolUse[]?.hooks[]?] | map(select(.command|contains("context-bonsai-gauge.ts"))) | length' "$SB/settings.json")" "2"
check "MCP remains registered" "$(jq -r '.mcpServers["context-bonsai"].command' "$SB/claude.json")" "bun"
check "WatchPaths is unloaded" "$(grep -Fxc 'com.atighi.context-bonsai-maintenance-claudewatch' "$SB/launch-state")" "0"
check "daily maintenance remains loaded" "$(grep -Fxc 'com.atighi.context-bonsai-maintenance' "$SB/launch-state")" "1"
check "proxy supervisor is loaded" "$(grep -Fxc 'com.atighi.context-bonsai-proxy' "$SB/launch-state")" "1"
check "guard is loaded" "$(grep -Fxc 'com.atighi.context-bonsai-proxy-guard' "$SB/launch-state")" "1"
bash "$CONTROL" verify >/dev/null 2>&1; check "post-enable verifier passes" "$?" "0"

echo "=== build refresh waits for an idle request seam ==="
now_ms="$(($(date +%s) * 1000))"
printf '{"status":"ok","pid":12345,"enforcement":true,"build_id":"%064d","active_requests":1,"last_request_at_ms":%s}\n' 0 "$now_ms" > "$SB/health.json"
bash "$CONTROL" guard >/dev/null 2>&1; rc=$?
check "busy old build defers restart cleanly" "$rc" "0"
check "busy old build leaves proxy mode selected" "$(cat "$SB/state/claude-mode")" "proxy"
check "busy old build leaves route installed" "$(jq -r '.env.ANTHROPIC_BASE_URL' "$SB/settings.json")" "http://127.0.0.1:38439"
printf '{"status":"ok","pid":12345,"enforcement":true,"build_id":"%s","active_requests":0,"last_request_at_ms":null}\n' "$build" > "$SB/health.json"

echo "=== patch off-ramp transaction ==="
out="$(bash "$CONTROL" rollback 2>&1)"; rc=$?
echo "  -> $out (rc=$rc)"
check "off-ramp exits cleanly" "$rc" "0"
check "bundle is patched before route removal" "$(grep -ca 'cb:archived-filter' "$SB/live-claude")" "1"
check "mode returns to enabled" "$(cat "$SB/state/claude-mode")" "enabled"
check "base URL is absent" "$(jq -r '.env.ANTHROPIC_BASE_URL // "absent"' "$SB/settings.json")" "absent"
check "off-ramp preserves private settings mode" "$(stat -f '%Lp' "$SB/settings.json")" "600"
check "owned gauge hooks are absent" "$(jq '[.hooks.UserPromptSubmit[]?.hooks[]?,.hooks.PostToolUse[]?.hooks[]?] | map(select(.command|contains("context-bonsai-gauge.ts"))) | length' "$SB/settings.json")" "0"
check "WatchPaths is reloaded" "$(grep -Fxc 'com.atighi.context-bonsai-maintenance-claudewatch' "$SB/launch-state")" "1"
check "proxy remains for routed old sessions" "$(grep -Fxc 'com.atighi.context-bonsai-proxy' "$SB/launch-state")" "1"

echo "=== prolonged proxy failure transaction ==="
bash "$CONTROL" enable >/dev/null 2>&1
CB_FAKE_HEALTH=down bash "$CONTROL" guard >/dev/null 2>&1; rc=$?
check "guard handles unrecovered failure" "$rc" "0"
check "guard records disabled intent" "$(cat "$SB/state/claude-mode")" "disabled"
check "guard removes the route" "$(jq -r '.env.ANTHROPIC_BASE_URL // "absent"' "$SB/settings.json")" "absent"
check "guard preserves private settings mode" "$(stat -f '%Lp' "$SB/settings.json")" "600"
check "guard removes gauge hooks" "$(jq '[.hooks.UserPromptSubmit[]?.hooks[]?,.hooks.PostToolUse[]?.hooks[]?] | map(select(.command|contains("context-bonsai-gauge.ts"))) | length' "$SB/settings.json")" "0"
check "guard removes MCP for new sessions" "$(jq -r '.mcpServers["context-bonsai"] // "absent"' "$SB/claude.json")" "absent"
check "guard leaves stock bundle untouched" "$(grep -ca 'cb:archived-filter' "$SB/live-claude")" "0"
check "guard writes actionable evidence" "$(test -f "$SB/proxy-state/last-failure.md"; echo $?)" "0"

echo "=== outer runtime-selector transaction ==="
runtime_root="$SB/runtime"
old_runtime="$runtime_root/old"
parent_commit="$(git -C "$ROOT" rev-parse HEAD)"
new_runtime="$runtime_root/$parent_commit"
mkdir -p "$old_runtime" "$SB/runtime-control-template"
ln -s "$old_runtime" "$runtime_root/current"
cat > "$SB/runtime-control-template/control.sh" <<'EOF'
#!/bin/bash
exit 10
EOF
chmod +x "$SB/runtime-control-template/control.sh"
cat > "$SB/bin/runtime-installer" <<'EOF'
#!/bin/bash
mkdir -p "$CB_FAKE_RUNTIME_TARGET/adoption/claude-proxy"
cp "$CB_FAKE_RUNTIME_CONTROL" "$CB_FAKE_RUNTIME_TARGET/adoption/claude-proxy/control.sh"
chmod +x "$CB_FAKE_RUNTIME_TARGET/adoption/claude-proxy/control.sh"
ln -s "$CB_FAKE_RUNTIME_TARGET" "$CB_FAKE_RUNTIME_ROOT/.installer-current"
mv -fh "$CB_FAKE_RUNTIME_ROOT/.installer-current" "$CB_FAKE_RUNTIME_ROOT/current"
EOF
chmod +x "$SB/bin/runtime-installer"
cat > "$SB/bin/live-verify" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$SB/bin/live-verify"
CB_FINAL_GO=1 \
CB_STAGE_C_VERIFY="$SB/bin/live-verify" \
CB_RUNTIME_ROOT="$runtime_root" \
CB_RUNTIME_CURRENT="$runtime_root/current" \
CB_RUNTIME_INSTALLER="$SB/bin/runtime-installer" \
CB_FAKE_RUNTIME_TARGET="$new_runtime" \
CB_FAKE_RUNTIME_ROOT="$runtime_root" \
CB_FAKE_RUNTIME_CONTROL="$SB/runtime-control-template/control.sh" \
  bash "$ROOT/adoption/claude-proxy/migrate.sh" >/dev/null 2>&1
rc=$?
check "failed inner cutover returns attention" "$rc" "10"
check "outer transaction restores prior runtime selector" "$(readlink "$runtime_root/current")" "$old_runtime"
check "failed candidate runtime is retained as evidence" "$(test -d "$new_runtime"; echo $?)" "0"

mkdir -p "$new_runtime/adoption/runtime"
cat > "$new_runtime/adoption/runtime/verify.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$new_runtime/adoption/runtime/verify.sh"
cat > "$new_runtime/adoption/claude-proxy/control.sh" <<'EOF'
#!/bin/bash
printf '%s\n' "$1" >> "$CB_FAKE_CONTROL_LOG"
exit 0
EOF
chmod +x "$new_runtime/adoption/claude-proxy/control.sh"
tweak_commit="$(git -C "$ROOT/tweakcc_context_bonsai" rev-parse HEAD)"
jq -n --arg parent "$parent_commit" --arg tweak "$tweak_commit" \
  '{parentCommit:$parent,tweakccCommit:$tweak}' > "$new_runtime/runtime-manifest.json"
cat > "$SB/bin/live-verify-fail" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$SB/bin/live-verify-fail"
: > "$SB/control-actions.log"
CB_FINAL_GO=1 \
CB_STAGE_C_VERIFY="$SB/bin/live-verify-fail" \
CB_RUNTIME_ROOT="$runtime_root" \
CB_RUNTIME_CURRENT="$runtime_root/current" \
CB_FAKE_CONTROL_LOG="$SB/control-actions.log" \
  bash "$ROOT/adoption/claude-proxy/migrate.sh" >/dev/null 2>&1
rc=$?
check "failed live verifier returns attention" "$rc" "10"
check "failed live verifier invokes off-ramp" "$(paste -sd, "$SB/control-actions.log")" "enable,rollback"
check "failed live verifier restores prior runtime selector" "$(readlink "$runtime_root/current")" "$old_runtime"

echo "=== real-install non-interference ==="
check "real bundle unchanged" "$(sha "$real_bundle")" "$real_bundle_before"
check "real settings unchanged" "$(sha "$HOME/.claude/settings.json")" "$real_settings_before"
check "real MCP config unchanged" "$(sha "$HOME/.claude.json")" "$real_mcp_before"
check "real LaunchAgent files unchanged" "$(find "$HOME/Library/LaunchAgents" -maxdepth 1 -name 'com.atighi.context-bonsai*' -type f -exec shasum -a 256 {} \; | sort | shasum -a 256 | awk '{print $1}')" "$real_agents_before"

echo
echo "RESULT: $pass passed, $fail failed"
echo "Retained fixture evidence: $SB"
[ "$fail" = "0" ]
