#!/usr/bin/env bash
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pass=0
fail=0

check() {
  local name="$1" got="$2" expected="$3"
  if [ "$got" = "$expected" ]; then
    pass=$((pass + 1))
    echo "  ok - $name"
  else
    fail=$((fail + 1))
    echo "  FAIL - $name: got '$got', expected '$expected'"
  fi
}

run_refusal() {
  local command="$1" output rc
  output="$(bash -c "$command" 2>&1)"
  rc=$?
  printf '%s\t%s' "$rc" "$output"
}

result="$(run_refusal "CB_FINAL_GO=1 '$DIR/control.sh' enable")"
check "direct proxy activation is retired" "${result%%$'\t'*}" "2"
check "direct refusal is explicit" "${result#*$'\t'}" \
  "Claude proxy activation is retired; the live-model harness was removed."

result="$(run_refusal "CB_FINAL_GO=1 '$DIR/enable.sh'")"
check "enable wrapper is retired" "${result%%$'\t'*}" "2"

result="$(run_refusal "CB_FINAL_GO=1 '$DIR/migrate.sh'")"
check "migration harness is retired" "${result%%$'\t'*}" "2"
check "migration refusal is explicit" "${result#*$'\t'}" \
  "Claude proxy migration is retired; no live-model harness will run."

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
PROXY_LABEL="com.atighi.context-bonsai-proxy"
WATCH_LABEL="com.atighi.context-bonsai-maintenance-claudewatch"
PROXY_URL="http://127.0.0.1:8399"
PORT="$(cd "$DIR/../../tweakcc_context_bonsai" && pwd)"
PROXY_SCRIPT="$PORT/proxy-prototype/proxy.mjs"
CORRELATE_SCRIPT="$PORT/proxy-prototype/correlate.mjs"
HOOK_SCRIPT="$PORT/hooks/context-bonsai-gauge.ts"
HOOK_REGISTER="$PORT/hooks/register-gauge-hooks.sh"
BUILD_ID="$({ cat "$PROXY_SCRIPT"; printf '\0'; cat "$CORRELATE_SCRIPT"; } | shasum -a 256 | awk '{print $1}')"

sha() { shasum -a 256 "$1" | awk '{print $1}'; }
backup_for() {
  local root="$1" bundle="$root/bundle"
  printf '%s/backups/%s.backup' "$root" "$(printf '%s' "$bundle" | sed 's/[^a-zA-Z0-9._-]/_/g')"
}
tree_state() {
  local root="$1"
  {
    find "$root" -type d -exec stat -f 'dir %N %Lp' {} +
    find "$root" -type f ! -name .lock ! -name maintenance.log \
      -exec stat -f 'file %N %i:%m:%Lp' {} +
    find "$root" -type f ! -name .lock ! -name maintenance.log \
      -exec shasum -a 256 {} +
    find "$root" -type l -exec sh -c \
      'for path do printf "link %s %s\n" "$path" "$(readlink "$path")"; done' sh {} +
  } | sed "s|$root||g" | LC_ALL=C sort
}
tree_digest() { tree_state "$1" | shasum -a 256 | awk '{print $1}'; }

new_fixture() {
  local root="$1" backup
  mkdir -p "$root"/{backups,bin,launch-agents,proxy-state,state}
  printf '#!/usr/bin/env bash\necho "2.1.219 (Claude Code)"\n' > "$root/bundle"
  chmod +x "$root/bundle"
  ln -s "$root/bundle" "$root/claude"
  backup="$(backup_for "$root")"
  cp "$root/bundle" "$backup"

  printf '%s\n' "$PROXY_LABEL" > "$root/launch.state"
  printf '<plist><dict><key>Label</key><string>%s</string></dict></plist>\n' \
    "$PROXY_LABEL" > "$root/launch-agents/$PROXY_LABEL.plist"
  printf 'proxy\n' > "$root/state/claude-mode"
  printf '%s\n' \
    '{"model":"opus[1m]","theme":"dark","permissions":{"allow":["Read"]},"plugins":{"fixture":true},"env":{"KEEP_ME":"yes","ANTHROPIC_BASE_URL":"http://127.0.0.1:8399"}}' \
    > "$root/settings.json"
  "$HOOK_REGISTER" add "$root/settings.json" >/dev/null
  printf '%s\n' \
    '{"mcpServers":{"other":{"command":"other","env":{"KEEP":"yes"}},"context-bonsai":{"command":"bun","args":["run","fixture"],"env":{"KEEP_ME":"yes","ANTHROPIC_BASE_URL":"http://127.0.0.1:8399"}}},"projects":{"fixture":{"trusted":true}}}' \
    > "$root/claude.json"

  cat > "$root/bin/launchctl" <<'SH'
#!/usr/bin/env bash
set -u
state="${CB_FIXTURE_LAUNCH_STATE:?}"
case "${1:-}" in
  print)
    label="${2##*/}"
    grep -Fxq "$label" "$state"
    ;;
  bootout)
    [ "${CB_FIXTURE_FAIL_BOOTOUT:-0}" != "1" ] || exit 1
    label="${2##*/}"
    grep -Fvx "$label" "$state" > "$state.next" || true
    mv "$state.next" "$state"
    ;;
  bootstrap)
    [ "${CB_FIXTURE_FAIL_BOOTSTRAP:-0}" != "1" ] || exit 1
    label="$(basename "${3:?}" .plist)"
    { cat "$state"; echo "$label"; } | sort -u > "$state.next"
    mv "$state.next" "$state"
    ;;
  enable|kickstart) exit 0 ;;
  *) exit 2 ;;
esac
SH
  cat > "$root/bin/curl" <<'SH'
#!/usr/bin/env bash
if [ "${CB_FIXTURE_BAD_HEALTH:-0}" = "1" ]; then
  printf '{"status":"error","enforcement":false,"build_id":"bad","pid":999}\n'
else
  printf '{"status":"ok","enforcement":true,"build_id":"%s","pid":999}\n' \
    "${CB_FIXTURE_BUILD_ID:?}"
fi
SH
  chmod +x "$root/bin/launchctl" "$root/bin/curl"
}

run_control() {
  local root="$1" dry="$2" action="$3"; shift 3
  env \
    HOME="$root/home" \
    CB_ADOPT_DRY_RUN="$dry" \
    CB_AM_SOURCE="$DIR/../auto-maintenance" \
    CB_REPO="$DIR/../.." \
    CB_PORT="$PORT" \
    CB_STATE="$root/state" \
    CB_CLAUDE_MODE_FILE="$root/state/claude-mode" \
    CB_CLAUDE_LAUNCHER="$root/claude" \
    CB_CLAUDE_JSON="$root/claude.json" \
    CB_BACKUP_DIR="$root/backups" \
    CB_CLAUDE_SETTINGS="$root/settings.json" \
    CB_PROXY_STATE="$root/proxy-state" \
    CB_LAUNCH_AGENT_DIR="$root/launch-agents" \
    CB_LAUNCH_DOMAIN="gui/fixture" \
    CB_LAUNCHCTL="$root/bin/launchctl" \
    CB_CURL="$root/bin/curl" \
    CB_PROXY_SCRIPT="$PROXY_SCRIPT" \
    CB_CORRELATE_SCRIPT="$CORRELATE_SCRIPT" \
    CB_GAUGE_HOOK="$HOOK_SCRIPT" \
    CB_GAUGE_REGISTER="$HOOK_REGISTER" \
    CB_PROXY_PORT=8399 \
    CB_PROXY_START_DELAYS=0 \
    CB_FIXTURE_LAUNCH_STATE="$root/launch.state" \
    CB_FIXTURE_BUILD_ID="$BUILD_ID" \
    CB_LIB_NO_INIT=0 \
    "$@" \
    bash "$DIR/control.sh" "$action"
}

run_adopt() { run_control "$1" "$2" adopt "${@:3}"; }
run_release() { run_control "$1" "$2" release "${@:3}"; }
run_verify() {
  local root="$1"
  run_control "$root" 0 verify
}

drift() {
  local root="$1" fact="$2" tmp
  case "$fact" in
    mode) printf 'enabled\n' > "$root/state/claude-mode" ;;
    watch) printf '%s\n' "$WATCH_LABEL" >> "$root/launch.state" ;;
    proxy_agent) grep -Fvx "$PROXY_LABEL" "$root/launch.state" > "$root/launch.next"
      mv "$root/launch.next" "$root/launch.state" ;;
    settings)
      "$HOOK_REGISTER" remove "$root/settings.json" >/dev/null
      tmp="$root/settings.next"
      jq 'del(.env.ANTHROPIC_BASE_URL)' "$root/settings.json" > "$tmp"
      mv "$tmp" "$root/settings.json"
      ;;
    mcp)
      tmp="$root/claude.next"
      jq 'del(.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL)' \
        "$root/claude.json" > "$tmp"
      mv "$tmp" "$root/claude.json"
      ;;
    bundle) printf '\n/*cb:archived-filter:v1*/\n' >> "$root/bundle" ;;
  esac
}

component() {
  local root="$1" name="$2" path
  case "$name" in
    mode) path="$root/state/claude-mode" ;;
    launch) path="$root/launch.state" ;;
    settings) path="$root/settings.json" ;;
    mcp) path="$root/claude.json" ;;
    bundle) path="$root/bundle" ;;
  esac
  printf '%s:%s' "$(stat -f '%i:%m:%Lp' "$path")" "$(sha "$path")"
}

echo "=== adopter: dry-run is literally read-only ==="
root="$SANDBOX/dry-run"; new_fixture "$root"
for fact in mode watch proxy_agent settings mcp bundle; do drift "$root" "$fact"; done
before="$(tree_digest "$root")"
out="$(run_adopt "$root" 1 2>&1)"; rc=$?
after="$(tree_digest "$root")"
check "dry-run exits 0" "$rc" "0"
check "dry-run writes nothing" "$after" "$before"
check "dry-run reports mode" "$(printf '%s' "$out" | grep -c -- 'claude-mode:')" "1"
check "dry-run reports watch" "$(printf '%s' "$out" | grep -c -- "$WATCH_LABEL")" "1"
check "dry-run reports proxy agent" "$(printf '%s' "$out" | grep -c -- "load $PROXY_LABEL")" "1"
check "dry-run reports settings" "$(printf '%s' "$out" | grep -c -- "$root/settings.json")" "1"
check "dry-run reports MCP" "$(printf '%s' "$out" | grep -c -- "$root/claude.json")" "1"
check "dry-run reports bundle" "$(printf '%s' "$out" | grep -c -- 'restore stock 2.1.219')" "1"

echo "=== adopter: each partial fact repairs alone and second run is a no-op ==="
for fact in mode watch proxy_agent settings mcp bundle; do
  root="$SANDBOX/partial-$fact"; new_fixture "$root"; drift "$root" "$fact"
  mode_before="$(component "$root" mode)"
  launch_before="$(component "$root" launch)"
  settings_before="$(component "$root" settings)"
  mcp_before="$(component "$root" mcp)"
  bundle_before="$(component "$root" bundle)"
  out="$(run_adopt "$root" 0 2>&1)"; rc=$?
  check "$fact repair exits 0" "$rc" "0"
  target="$fact"
  case "$fact" in watch|proxy_agent) target=launch ;; esac
  for name in mode launch settings mcp bundle; do
    before_var="${name}_before"
    now="$(component "$root" "$name")"
    if [ "$name" = "$target" ]; then
      [ "$now" != "${!before_var}" ]; changed=$?
      check "$fact changes only $target" "$changed" "0"
    else
      check "$fact preserves $name" "$now" "${!before_var}"
    fi
  done
  if [ "$fact" = "settings" ]; then
    check "settings repair preserves personal preferences" \
      "$(jq -c '{model,theme,permissions,plugins,keep:.env.KEEP_ME}' "$root/settings.json")" \
      '{"model":"opus[1m]","theme":"dark","permissions":{"allow":["Read"]},"plugins":{"fixture":true},"keep":"yes"}'
  fi
  if [ "$fact" = "mcp" ]; then
    check "MCP repair preserves unrelated configuration" \
      "$(jq -c '{other:.mcpServers.other,projects,keep:.mcpServers["context-bonsai"].env.KEEP_ME}' "$root/claude.json")" \
      '{"other":{"command":"other","env":{"KEEP":"yes"}},"projects":{"fixture":{"trusted":true}},"keep":"yes"}'
  fi
  before="$(tree_digest "$root")"
  out="$(run_adopt "$root" 0 2>&1)"; rc=$?
  after="$(tree_digest "$root")"
  check "$fact second run exits 0" "$rc" "0"
  check "$fact second run performs no writes" "$after" "$before"
done

reject_unchanged() {
  local name="$1" root="$2"; shift 2
  local before after out rc
  before="$(tree_digest "$root")"
  out="$(run_adopt "$root" 0 "$@" 2>&1)"; rc=$?
  after="$(tree_digest "$root")"
  check "$name exits 10" "$rc" "10"
  check "$name changes nothing" "$after" "$before"
}

echo "=== adopter: hostile preconditions fail before every write ==="
root="$SANDBOX/no-backup"; new_fixture "$root"; drift "$root" bundle
mv "$(backup_for "$root")" "$root/backup-held-aside"
reject_unchanged "missing backup" "$root"

root="$SANDBOX/patched-backup"; new_fixture "$root"; drift "$root" bundle
printf '\n/*cb:archived-filter:v1*/\n' >> "$(backup_for "$root")"
reject_unchanged "patched backup" "$root"

root="$SANDBOX/wrong-backup"; new_fixture "$root"; drift "$root" bundle
printf '#!/usr/bin/env bash\necho "2.1.218 (Claude Code)"\n' > "$(backup_for "$root")"
chmod +x "$(backup_for "$root")"
reject_unchanged "wrong-version backup" "$root"

root="$SANDBOX/malformed-settings"; new_fixture "$root"
printf '{' > "$root/settings.json"
reject_unchanged "malformed settings" "$root"

root="$SANDBOX/foreign-settings"; new_fixture "$root"
tmp="$root/settings.next"
jq '.env.ANTHROPIC_BASE_URL="http://127.0.0.1:9999"' "$root/settings.json" > "$tmp"
mv "$tmp" "$root/settings.json"
reject_unchanged "foreign settings route" "$root"

root="$SANDBOX/foreign-mcp"; new_fixture "$root"
tmp="$root/claude.next"
jq '.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL="http://127.0.0.1:9999"' \
  "$root/claude.json" > "$tmp"
mv "$tmp" "$root/claude.json"
reject_unchanged "foreign MCP route" "$root"

root="$SANDBOX/no-agent"; new_fixture "$root"; drift "$root" proxy_agent
mv "$root/launch-agents/$PROXY_LABEL.plist" "$root/proxy-plist-held-aside"
reject_unchanged "missing proxy LaunchAgent" "$root"

echo "=== adopter: execution failures must not leave partial adoption ==="
root="$SANDBOX/bootstrap-fails"; new_fixture "$root"
for fact in mode proxy_agent settings mcp bundle; do drift "$root" "$fact"; done
out="$(run_adopt "$root" 0 CB_FIXTURE_FAIL_BOOTSTRAP=1 2>&1)"; rc=$?
check "proxy bootstrap failure exits 10" "$rc" "10"
check "bootstrap failure leaves Claude on the direct route" \
  "$(jq -r '.env.ANTHROPIC_BASE_URL // "direct"' "$root/settings.json")" "direct"
check "bootstrap failure leaves the MCP direct" \
  "$(jq -r '.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL // "direct"' "$root/claude.json")" "direct"
check "bootstrap failure leaves the working patch in place" \
  "$(grep -c 'cb:archived-filter' "$root/bundle")" "1"
out="$(run_adopt "$root" 0 2>&1)"; rc=$?
check "rerun after bootstrap failure converges" "$rc" "0"

root="$SANDBOX/unhealthy-proxy"; new_fixture "$root"
for fact in mode settings mcp; do drift "$root" "$fact"; done
reject_unchanged "unhealthy existing proxy preflight" "$root" CB_FIXTURE_BAD_HEALTH=1

echo "=== control lock: apply never plans against changing state ==="
root="$SANDBOX/adopt-busy"; new_fixture "$root"
printf '{' > "$root/settings.json"
printf '%s\n' "$$" > "$root/state/.lock"
before="$(tree_digest "$root")"
out="$(run_adopt "$root" 0 2>&1)"; rc=$?
after="$(tree_digest "$root")"
check "busy adopt exits 20 before preflight" "$rc" "20"
check "busy adopt changes nothing" "$after" "$before"

root="$SANDBOX/release-busy"; new_fixture "$root"
printf '{' > "$root/settings.json"
printf '%s\n' "$$" > "$root/state/.lock"
before="$(tree_digest "$root")"
out="$(run_release "$root" 0 2>&1)"; rc=$?
after="$(tree_digest "$root")"
check "busy release exits 20 before preflight" "$rc" "20"
check "busy release changes nothing" "$after" "$before"

echo "=== release: reverse only Bonsai-owned state, then re-adopt ==="
root="$SANDBOX/release"; new_fixture "$root"
bundle_before="$(component "$root" bundle)"
before="$(tree_digest "$root")"
out="$(run_release "$root" 1 2>&1)"; rc=$?
after="$(tree_digest "$root")"
check "release dry-run exits 0" "$rc" "0"
check "release dry-run writes nothing" "$after" "$before"
check "release dry-run reports settings" "$(printf '%s' "$out" | grep -c "$root/settings.json")" "1"
check "release dry-run reports MCP" "$(printf '%s' "$out" | grep -c "$root/claude.json")" "1"
check "release dry-run reports proxy" "$(printf '%s' "$out" | grep -c "unload $PROXY_LABEL")" "1"
check "release dry-run reports mode" "$(printf '%s' "$out" | grep -c 'claude-mode: proxy -> disabled')" "1"

out="$(run_release "$root" 0 2>&1)"; rc=$?
check "release exits 0" "$rc" "0"
check "release removes only its settings route" \
  "$(jq -c '{url:(.env.ANTHROPIC_BASE_URL // null),keep:.env.KEEP_ME,model,theme,permissions,plugins}' "$root/settings.json")" \
  '{"url":null,"keep":"yes","model":"opus[1m]","theme":"dark","permissions":{"allow":["Read"]},"plugins":{"fixture":true}}'
check "release removes both exact gauge hooks" \
  "$(jq --arg cmd "bun run $HOOK_SCRIPT" \
    '[.hooks[]?[]?.hooks[]? | select(.command==$cmd)] | length' "$root/settings.json")" "0"
check "release removes only its MCP route" \
  "$(jq -c '{url:(.mcpServers["context-bonsai"].env.ANTHROPIC_BASE_URL // null),keep:.mcpServers["context-bonsai"].env.KEEP_ME,other:.mcpServers.other,projects}' "$root/claude.json")" \
  '{"url":null,"keep":"yes","other":{"command":"other","env":{"KEEP":"yes"}},"projects":{"fixture":{"trusted":true}}}'
check "release unloads only the proxy" "$(cat "$root/launch.state")" ""
check "release persists disabled mode" "$(cat "$root/state/claude-mode")" "disabled"
check "release leaves the stock bundle byte-identical" "$(component "$root" bundle)" "$bundle_before"

before="$(tree_digest "$root")"
out="$(run_release "$root" 0 2>&1)"; rc=$?
after="$(tree_digest "$root")"
check "release second run exits 0" "$rc" "0"
check "release second run performs no writes" "$after" "$before"
out="$(run_adopt "$root" 0 2>&1)"; rc=$?
check "released machine can re-adopt" "$rc" "0"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" = "0" ]
