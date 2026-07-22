#!/usr/bin/env bash
# Fully isolated orchestration fixture for actionable multi-lane attention.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="${CB_ATTENTION_TEST_ROOT:-$DIR/../../.staging/auto-maintenance/attention-simulations}"
ROOT="$TEST_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$ROOT/state" "$ROOT/port" "$ROOT/source-runs/retained-source" "$ROOT/codex-runs/retained-codex"
capture="$ROOT/notification.args"

CB_STATE="$ROOT/state" \
CB_PORT="$ROOT/port" \
CB_RUNTIME_CURRENT="$ROOT/no-runtime-advance" \
CB_SOURCE_RECONCILER="$DIR/test-support/source-attention.sh" \
CB_CLAUDE_RECONCILER="$DIR/test-support/claude-ok.sh" \
CB_CODEX_RECONCILER="$DIR/test-support/codex-attention.sh" \
CB_SOURCE_SCRATCH_ROOT="$ROOT/source-runs" \
CB_CODEX_SCRATCH_ROOT="$ROOT/codex-runs" \
CB_INCIDENT_NOW=1000 \
CB_NOTIFY_CAPTURE="$capture" \
CB_TERMINAL_NOTIFIER="$DIR/test-support/capture-notifier.sh" \
CB_OSASCRIPT="/not-used" \
  bash "$DIR/run-daily.sh"
rc=$?

pass=0; fail=0
check() {
  if [ "$2" = "$3" ]; then
    printf '  PASS: %s\n' "$1"; pass=$((pass+1))
  else
    printf "  FAIL: %s (got '%s', want '%s')\n" "$1" "$2" "$3"; fail=$((fail+1))
  fi
}

status="$ROOT/state/last-run.md"
check "orchestrator remains non-fatal" "$rc" "0"
check "status names both failed lanes" "$(grep -c 'Unresolved: Source + Codex' "$status")" "1"
check "status retains the source candidate path" "$(grep -c 'retained-source' "$status")" "1"
check "status retains the Codex candidate path" "$(grep -c 'retained-codex' "$status")" "1"
check "notification names the Codex diagnosis" \
  "$(grep -Fc 'Diagnosis: codex 9.9.9: rebase conflict — candidate isolated, install untouched' "$capture")" "1"
check "notification names the Codex safe state" \
  "$(grep -Fc 'Safe state: The Codex install is untouched; its prior working state remains selected.' "$capture")" "1"
check "notification opens the status file" "$(grep -Fxc "file://$status" "$capture" 2>/dev/null || printf 0)" "1"
source_incident="$ROOT/state/incidents/lanes/source.json"
codex_incident="$ROOT/state/incidents/lanes/codex.json"
check "source incident is durable" "$(jq -r '.status' "$source_incident")" "active"
check "source diagnosis is durable" "$(jq -r '.diagnosis' "$source_incident")" \
  "source: candidate setup failed — runtime unchanged (escalate)"
check "source safe state is explicit" "$(jq -r '.safeState' "$source_incident")" \
  "The last certified Bonsai runtime remains selected; no runtime change was made."
check "Codex incident is durable" "$(jq -r '.status' "$codex_incident")" "active"
check "both first notifications were recorded" \
  "$(jq -s '[.[] | select(.event == "notified")] | length' "$ROOT/state/incidents/events.jsonl")" "2"

# A later clean run clears only by changing durable status. Incident records are retained.
CB_STATE="$ROOT/state" \
CB_PORT="$ROOT/port" \
CB_RUNTIME_CURRENT="$ROOT/no-runtime-advance" \
CB_SOURCE_RECONCILER="$DIR/test-support/claude-ok.sh" \
CB_CLAUDE_RECONCILER="$DIR/test-support/claude-ok.sh" \
CB_CODEX_RECONCILER="$DIR/test-support/claude-ok.sh" \
CB_SOURCE_SCRATCH_ROOT="$ROOT/source-runs" \
CB_CODEX_SCRATCH_ROOT="$ROOT/codex-runs" \
CB_INCIDENT_NOW=2000 \
CB_NOTIFY_CAPTURE="$capture" \
CB_TERMINAL_NOTIFIER="$DIR/test-support/capture-notifier.sh" \
CB_OSASCRIPT="/not-used" \
  bash "$DIR/run-daily.sh"
check "clean source run clears source incident" "$(jq -r '.status' "$source_incident")" "resolved"
check "clean Codex run clears Codex incident" "$(jq -r '.status' "$codex_incident")" "resolved"

printf 'Evidence retained: %s\n' "$ROOT"
printf 'RESULT: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = "0" ]
