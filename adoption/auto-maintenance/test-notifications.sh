#!/usr/bin/env bash
# Network-free notification routing tests. All evidence is retained under .staging.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="${CB_NOTIFICATION_TEST_ROOT:-$DIR/../../.staging/auto-maintenance/notification-simulations}"
ROOT="$TEST_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$ROOT/state"
CB_STATE="$ROOT/state"
source "$DIR/lib.sh"

pass=0; fail=0
check() {
  if [ "$2" = "$3" ]; then
    printf '  PASS: %s\n' "$1"; pass=$((pass+1))
  else
    printf "  FAIL: %s (got '%s', want '%s')\n" "$1" "$2" "$3"; fail=$((fail+1))
  fi
}

printf '# retained notification fixture\n' > "$CB_STATUS"
capture="$ROOT/terminal-notifier.args"
CB_NOTIFY_CAPTURE="$capture" \
CB_TERMINAL_NOTIFIER="$DIR/test-support/capture-notifier.sh" \
CB_OSASCRIPT="/not-used" \
  cb_notify "Context Bonsai — Codex failed" \
    "Codex 0.146.0: rebase conflict; current fork unchanged." "Basso" "$CB_STATUS"
check "terminal-notifier receives an open action" "$(grep -c '^-open$' "$capture")" "1"
check "terminal-notifier receives a file URL" "$(grep -c "^$(cb_file_url "$CB_STATUS")$" "$capture")" "1"
check "message includes evidence path" "$(grep -c 'Details: ~/.*/last-run.md' "$capture")" "1"

capture="$ROOT/osascript.args"
CB_NOTIFY_CAPTURE="$capture" \
CB_TERMINAL_NOTIFIER="/not-installed" \
CB_OSASCRIPT="$DIR/test-support/capture-osascript.sh" \
  cb_notify "Context Bonsai — Source failed" \
    "Source candidate setup failed; runtime unchanged." "Basso" "$CB_STATUS"
check "AppleScript fallback receives the full diagnosis" \
  "$(grep -c 'arg=Source candidate setup failed; runtime unchanged.' "$capture")" "1"
check "AppleScript fallback receives the evidence path" \
  "$(grep -c 'Details: ~/.*/last-run.md' "$capture")" "1"
check "AppleScript fallback receives the requested sound" "$(grep -c '^arg=Basso$' "$capture")" "1"

printf 'Evidence retained: %s\n' "$ROOT"
printf 'RESULT: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = "0" ]
