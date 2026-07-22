#!/usr/bin/env bash
# Quota-free, local reminder state machine for unresolved maintenance incidents.
# It never invokes a model or a reconciler and never touches a Claude/Codex path.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

INCIDENT_ROOT="${CB_INCIDENT_ROOT:-$CB_STATE/incidents}"
LANE_ROOT="$INCIDENT_ROOT/lanes"
RECORD_ROOT="$INCIDENT_ROOT/records"
EVENT_LOG="$INCIDENT_ROOT/events.jsonl"
mkdir -p "$LANE_ROOT" "$RECORD_ROOT"

now_epoch() {
  local value="${CB_INCIDENT_NOW:-}"
  if [ -z "$value" ]; then value="$(date +%s)"; fi
  case "$value" in *[!0-9]*|'') cb_log "incident reminder: invalid epoch: $value"; return 1;; esac
  printf '%s' "$value"
}

iso_epoch() {
  local value="$1" rendered
  rendered="$(date -u -r "$value" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"
  if [ -z "$rendered" ]; then
    rendered="$(date -u -d "@$value" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"
  fi
  [ -n "$rendered" ] || rendered="epoch-$value"
  printf '%s' "$rendered"
}

lane_name() {
  case "$1" in
    source) printf 'Source';;
    claude) printf 'Claude';;
    codex) printf 'Codex';;
    *) return 1;;
  esac
}

fingerprint() {
  local lane="$1" diagnosis="$2" safe_state="$3"
  printf '%s\0%s\0%s' "$lane" "$diagnosis" "$safe_state" | shasum -a 256 | awk '{print $1}'
}

atomic_json_from_file() {
  local source="$1" destination="$2" tmp
  tmp="$(dirname "$destination")/.incident-$(basename "$destination").$$"
  jq -e . "$source" > "$tmp" || return 1
  mv "$tmp" "$destination"
}

append_event() {
  local event="$1" lane="$2" incident_id="$3" at="$4" detail="${5:-}"
  jq -cn \
    --arg event "$event" --arg lane "$lane" --arg incidentId "$incident_id" \
    --arg at "$at" --arg detail "$detail" \
    '{event:$event,lane:$lane,incidentId:$incidentId,at:$at,detail:$detail}' >> "$EVENT_LOG"
}

save_record() {
  local candidate="$1" lane_file="$2" record_file="$3"
  atomic_json_from_file "$candidate" "$record_file" || return 1
  jq -e . "$candidate" >/dev/null || return 1
  mv "$candidate" "$lane_file"
}

validate_record() {
  local file="$1"
  jq -e '
    .schemaVersion == 1 and
    (.lane == "source" or .lane == "claude" or .lane == "codex") and
    (.status == "active" or .status == "resolved") and
    (.fingerprint | type == "string" and length == 64) and
    (.incidentId | type == "string" and length > 64) and
    (.diagnosis | type == "string" and length > 0) and
    (.safeState | type == "string" and length > 0) and
    (.evidencePath | type == "string" and length > 0) and
    (.firstSeen | type == "string" and length > 0) and
    (.firstSeenEpoch | type == "number" and floor == .) and
    (.notificationStage | type == "number" and . >= 0 and floor == .) and
    ((.nextNotifyAtEpoch == null) or (.nextNotifyAtEpoch | type == "number" and floor == .))
  ' "$file" >/dev/null 2>&1
}

record_problem() {
  local file="$1"
  cb_notify "Context Bonsai — reminder state needs attention" \
    "The unresolved-incident record is invalid. Claude and Codex were not changed. Evidence: $file" \
    "Basso" "$file"
}

notify_due() {
  local lane_file="$1" now="$2"
  [ -f "$lane_file" ] || return 0
  if ! validate_record "$lane_file"; then record_problem "$lane_file"; return 10; fi
  [ "$(jq -r '.status' "$lane_file")" = "active" ] || return 0

  local due stage lane display diagnosis safe_state evidence first_seen incident_id
  due="$(jq -r '.nextNotifyAtEpoch // 0' "$lane_file")"
  case "$due" in *[!0-9]*|'') record_problem "$lane_file"; return 10;; esac
  [ "$now" -ge "$due" ] || return 0

  stage="$(jq -r '.notificationStage' "$lane_file")"
  lane="$(jq -r '.lane' "$lane_file")"
  display="$(jq -r '.laneName' "$lane_file")"
  diagnosis="$(jq -r '.diagnosis' "$lane_file")"
  safe_state="$(jq -r '.safeState' "$lane_file")"
  evidence="$(jq -r '.evidencePath' "$lane_file")"
  first_seen="$(jq -r '.firstSeen' "$lane_file")"
  incident_id="$(jq -r '.incidentId' "$lane_file")"

  local title lead next_epoch next_stage notified_at candidate record_file
  case "$stage" in
    0)
      title="Context Bonsai — $display needs attention"
      lead="$display maintenance incident detected."
      next_epoch=$(( $(jq -r '.firstSeenEpoch' "$lane_file") + 3600 ))
      ;;
    1)
      title="Context Bonsai — $display still unresolved (1h)"
      lead="$display maintenance has remained unresolved for at least one hour."
      next_epoch=$(( $(jq -r '.firstSeenEpoch' "$lane_file") + 14400 ))
      ;;
    2)
      title="Context Bonsai — $display still unresolved (4h)"
      lead="$display maintenance has remained unresolved for at least four hours."
      next_epoch=$(( now + 86400 ))
      ;;
    *)
      title="Context Bonsai — $display unresolved (daily reminder)"
      lead="$display maintenance is still unresolved."
      next_epoch=$(( now + 86400 ))
      ;;
  esac
  next_stage=$((stage + 1))
  notified_at="$(iso_epoch "$now")"

  if ! cb_notify "$title" \
      "$lead Diagnosis: $diagnosis Safe state: $safe_state Evidence: $evidence First seen: $first_seen. This is a local reminder; no agent was invoked." \
      "Basso" "$CB_STATUS"; then
    cb_log "incident reminder: notification delivery failed; stage remains due for retry"
    return 10
  fi

  candidate="$(dirname "$lane_file")/.notify-$lane-$$.json"
  jq \
    --arg notifiedAt "$notified_at" \
    --argjson notifiedAtEpoch "$now" \
    --argjson notificationStage "$next_stage" \
    --argjson nextNotifyAtEpoch "$next_epoch" \
    '.lastNotifiedAt=$notifiedAt |
     .lastNotifiedAtEpoch=$notifiedAtEpoch |
     .notificationStage=$notificationStage |
     .nextNotifyAtEpoch=$nextNotifyAtEpoch' \
    "$lane_file" > "$candidate" || return 10
  record_file="$RECORD_ROOT/$incident_id.json"
  save_record "$candidate" "$lane_file" "$record_file" || return 10
  append_event "notified" "$lane" "$incident_id" "$notified_at" "stage=$stage"
  return 0
}

observe_incident() {
  local lane="$1" diagnosis="$2" safe_state="$3" evidence="$4"
  local display now seen fingerprint_value lane_file existing_status existing_fingerprint
  local incident_id first_seen record_file candidate
  display="$(lane_name "$lane")" || { cb_log "incident reminder: invalid lane: $lane"; return 64; }
  now="$(now_epoch)" || return 64
  seen="$(iso_epoch "$now")"
  fingerprint_value="$(fingerprint "$lane" "$diagnosis" "$safe_state")"
  lane_file="$LANE_ROOT/$lane.json"

  if [ -f "$lane_file" ]; then
    if ! validate_record "$lane_file"; then record_problem "$lane_file"; return 10; fi
    existing_status="$(jq -r '.status' "$lane_file")"
    existing_fingerprint="$(jq -r '.fingerprint' "$lane_file")"
  else
    existing_status="none"
    existing_fingerprint=""
  fi

  if [ "$existing_status" = "active" ] && [ "$existing_fingerprint" = "$fingerprint_value" ]; then
    incident_id="$(jq -r '.incidentId' "$lane_file")"
    candidate="$LANE_ROOT/.observe-$lane-$$.json"
    jq \
      --arg diagnosis "$diagnosis" --arg safeState "$safe_state" \
      --arg evidencePath "$evidence" --arg lastSeen "$seen" --argjson lastSeenEpoch "$now" \
      '.diagnosis=$diagnosis | .safeState=$safeState | .evidencePath=$evidencePath |
       .lastSeen=$lastSeen | .lastSeenEpoch=$lastSeenEpoch' \
      "$lane_file" > "$candidate" || return 10
  else
    incident_id="$fingerprint_value-$now-$$"
    first_seen="$seen"
    candidate="$LANE_ROOT/.observe-$lane-$$.json"
    jq -n \
      --arg lane "$lane" --arg laneName "$display" --arg fingerprint "$fingerprint_value" \
      --arg incidentId "$incident_id" --arg diagnosis "$diagnosis" --arg safeState "$safe_state" \
      --arg evidencePath "$evidence" --arg statusPath "$CB_STATUS" \
      --arg firstSeen "$first_seen" --argjson firstSeenEpoch "$now" \
      '{schemaVersion:1,lane:$lane,laneName:$laneName,fingerprint:$fingerprint,
        incidentId:$incidentId,status:"active",diagnosis:$diagnosis,safeState:$safeState,
        evidencePath:$evidencePath,statusPath:$statusPath,firstSeen:$firstSeen,
        firstSeenEpoch:$firstSeenEpoch,lastSeen:$firstSeen,lastSeenEpoch:$firstSeenEpoch,
        notificationStage:0,lastNotifiedAt:null,lastNotifiedAtEpoch:null,
        nextNotifyAtEpoch:$firstSeenEpoch,resolvedAt:null,resolvedAtEpoch:null}' > "$candidate" || return 10
  fi

  record_file="$RECORD_ROOT/$incident_id.json"
  save_record "$candidate" "$lane_file" "$record_file" || return 10
  if [ "$existing_status" != "active" ] || [ "$existing_fingerprint" != "$fingerprint_value" ]; then
    append_event "opened" "$lane" "$incident_id" "$seen" "$diagnosis"
  fi
  notify_due "$lane_file" "$now"
}

resolve_incident() {
  local lane="$1" display now resolved_at lane_file status incident_id candidate record_file
  display="$(lane_name "$lane")" || { cb_log "incident reminder: invalid lane: $lane"; return 64; }
  lane_file="$LANE_ROOT/$lane.json"
  [ -f "$lane_file" ] || return 0
  if ! validate_record "$lane_file"; then record_problem "$lane_file"; return 10; fi
  status="$(jq -r '.status' "$lane_file")"
  [ "$status" = "active" ] || return 0
  now="$(now_epoch)" || return 64
  resolved_at="$(iso_epoch "$now")"
  incident_id="$(jq -r '.incidentId' "$lane_file")"
  candidate="$LANE_ROOT/.resolve-$lane-$$.json"
  jq \
    --arg resolvedAt "$resolved_at" --argjson resolvedAtEpoch "$now" \
    '.status="resolved" | .resolvedAt=$resolvedAt | .resolvedAtEpoch=$resolvedAtEpoch |
     .nextNotifyAtEpoch=null' "$lane_file" > "$candidate" || return 10
  record_file="$RECORD_ROOT/$incident_id.json"
  save_record "$candidate" "$lane_file" "$record_file" || return 10
  append_event "resolved" "$lane" "$incident_id" "$resolved_at" "$display lane returned clean"
  cb_log "incident reminder: cleared resolved $lane incident $incident_id"
}

tick_incidents() {
  local now lane rc=0 pid=""
  now="$(now_epoch)" || return 64
  if [ -f "$CB_LOCK" ]; then
    pid="$(sed -n '1p' "$CB_LOCK" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      cb_log "incident reminder: maintenance pid $pid is active — tick deferred"
      return 0
    fi
  fi
  for lane in source claude codex; do
    notify_due "$LANE_ROOT/$lane.json" "$now" || rc=10
  done
  return "$rc"
}

usage() {
  printf 'usage: %s observe LANE DIAGNOSIS SAFE_STATE EVIDENCE | resolve LANE | tick\n' "$0" >&2
  return 64
}

case "${1:-}" in
  observe)
    [ "$#" = "5" ] || { usage; exit $?; }
    observe_incident "$2" "$3" "$4" "$5"
    ;;
  resolve)
    [ "$#" = "2" ] || { usage; exit $?; }
    resolve_incident "$2"
    ;;
  tick)
    [ "$#" = "1" ] || { usage; exit $?; }
    tick_incidents
    ;;
  *) usage; exit $?;;
esac
