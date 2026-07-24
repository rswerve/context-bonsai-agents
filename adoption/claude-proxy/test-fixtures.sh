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

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" = "0" ]
