#!/usr/bin/env bash
# Network-free, model-free incident schedule fixtures. Evidence is retained.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="${CB_INCIDENT_TEST_ROOT:-$DIR/../../.staging/auto-maintenance/incident-reminders}"
ROOT="$TEST_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-$$"
STATE="$ROOT/state"
EVIDENCE1="$ROOT/evidence/first"
EVIDENCE2="$ROOT/evidence/latest"
CAPTURE="$ROOT/notification.args"
mkdir -p "$STATE" "$EVIDENCE1" "$EVIDENCE2"
printf '# incident reminder fixture\n' > "$STATE/last-run.md"

pass=0; fail=0
check() {
  if [ "$2" = "$3" ]; then
    printf '  PASS: %s\n' "$1"; pass=$((pass+1))
  else
    printf "  FAIL: %s (got '%s', want '%s')\n" "$1" "$2" "$3"; fail=$((fail+1))
  fi
}

run_reminder() {
  CB_STATE="$STATE" \
  CB_INCIDENT_NOW="$1" \
  CB_NOTIFY_CAPTURE="$CAPTURE" \
  CB_TERMINAL_NOTIFIER="$DIR/test-support/capture-notifier.sh" \
  CB_OSASCRIPT="/not-used" \
    bash "$DIR/incident-reminder.sh" "${@:2}"
}

diagnosis='source: candidate setup failed — runtime unchanged (escalate)'
safe_state='The last certified Bonsai runtime remains selected; no runtime change was made.'
lane="$STATE/incidents/lanes/source.json"

printf '%s\n' '=== first detection ==='
run_reminder 1000 observe source "$diagnosis" "$safe_state" "$EVIDENCE1"
check 'record active' "$(jq -r '.status' "$lane")" 'active'
check 'fingerprint is SHA-256' "$(jq -r '.fingerprint | length' "$lane")" '64'
check 'first-seen is durable' "$(jq -r '.firstSeenEpoch' "$lane")" '1000'
check 'first notification advances stage' "$(jq -r '.notificationStage' "$lane")" '1'
check 'one-hour reminder scheduled' "$(jq -r '.nextNotifyAtEpoch' "$lane")" '4600'
check 'notification contains diagnosis' "$(grep -Fc "$diagnosis" "$CAPTURE")" '1'
check 'notification contains safe state' "$(grep -Fc "$safe_state" "$CAPTURE")" '1'
check 'notification contains evidence' "$(grep -Fc "$EVIDENCE1" "$CAPTURE")" '1'
check 'notification disclaims agent invocation' "$(grep -Fc 'no agent was invoked' "$CAPTURE")" '1'

printf '%s\n' '=== same incident does not reset or spam ==='
printf '%s\n' 'not-called' > "$CAPTURE"
run_reminder 1200 observe source "$diagnosis" "$safe_state" "$EVIDENCE2"
check 'same fingerprint keeps first-seen' "$(jq -r '.firstSeenEpoch' "$lane")" '1000'
check 'latest evidence is refreshed' "$(jq -r '.evidencePath' "$lane")" "$EVIDENCE2"
check 'same incident does not notify early' "$(cat "$CAPTURE")" 'not-called'

printf '%s\n' 'not-called' > "$CAPTURE"
run_reminder 4599 tick
check 'tick before one hour is quiet' "$(cat "$CAPTURE")" 'not-called'

printf '%s\n' '=== one-hour escalation ==='
run_reminder 4600 tick
check 'one-hour title' "$(grep -c 'still unresolved (1h)' "$CAPTURE")" '1'
check 'one-hour stage advances' "$(jq -r '.notificationStage' "$lane")" '2'
check 'four-hour reminder scheduled from first-seen' "$(jq -r '.nextNotifyAtEpoch' "$lane")" '15400'

printf '%s\n' '=== four-hour escalation ==='
run_reminder 15400 tick
check 'four-hour title' "$(grep -c 'still unresolved (4h)' "$CAPTURE")" '1'
check 'four-hour stage advances' "$(jq -r '.notificationStage' "$lane")" '3'
check 'daily reminder follows 24h later' "$(jq -r '.nextNotifyAtEpoch' "$lane")" '101800'

printf '%s\n' '=== daily escalation ==='
run_reminder 101800 tick
check 'daily title' "$(grep -c 'daily reminder' "$CAPTURE")" '1'
check 'daily cadence remains 24h' "$(jq -r '.nextNotifyAtEpoch' "$lane")" '188200'

printf '%s\n' '=== automatic resolution ==='
run_reminder 102000 resolve source
check 'resolved state retained' "$(jq -r '.status' "$lane")" 'resolved'
check 'resolved timestamp retained' "$(jq -r '.resolvedAtEpoch' "$lane")" '102000'
check 'resolved incident has no due reminder' "$(jq -r '.nextNotifyAtEpoch' "$lane")" 'null'
printf '%s\n' 'not-called' > "$CAPTURE"
run_reminder 200000 tick
check 'resolved incident stays quiet' "$(cat "$CAPTURE")" 'not-called'

printf '%s\n' '=== a recurrence is a new incident ==='
old_id="$(jq -r '.incidentId' "$lane")"
run_reminder 200000 observe source "$diagnosis" "$safe_state" "$EVIDENCE2"
new_id="$(jq -r '.incidentId' "$lane")"
check 'recurrence gets a new incident id' "$([ "$old_id" != "$new_id" ] && printf yes || printf no)" 'yes'
check 'recurrence gets a fresh first-seen' "$(jq -r '.firstSeenEpoch' "$lane")" '200000'
check 'both immutable incident records retained' "$(find "$STATE/incidents/records" -type f -name '*.json' | wc -l | tr -d ' ')" '2'

printf '%s\n' '=== failed delivery remains immediately due ==='
set +e
CB_STATE="$STATE" \
CB_INCIDENT_NOW=300000 \
CB_NOTIFY_CAPTURE="$CAPTURE" \
CB_TERMINAL_NOTIFIER="/usr/bin/false" \
CB_OSASCRIPT="/usr/bin/false" \
  bash "$DIR/incident-reminder.sh" observe codex \
    'codex 9.9.9: certification failed — install untouched (attention)' \
    'The Codex install is untouched; its prior working state remains selected.' \
    "$EVIDENCE2"
delivery_rc=$?
set -e
codex_lane="$STATE/incidents/lanes/codex.json"
check 'failed delivery reports attention' "$delivery_rc" '10'
check 'failed delivery does not advance stage' "$(jq -r '.notificationStage' "$codex_lane")" '0'
check 'failed delivery remains due' "$(jq -r '.nextNotifyAtEpoch' "$codex_lane")" '300000'

check 'no Codex agent invocation in reminder' \
  "$(grep -Ec 'codex[[:space:]]+exec|run-agentic-rebase' "$DIR/incident-reminder.sh" || true)" '0'
check 'no Claude model invocation in reminder' \
  "$(grep -Ec 'claude[[:space:]]+(-p|--print)' "$DIR/incident-reminder.sh" || true)" '0'

printf 'Evidence retained: %s\n' "$ROOT"
printf 'RESULT: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = "0" ]
