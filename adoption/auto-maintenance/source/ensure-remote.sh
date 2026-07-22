#!/usr/bin/env bash
# Add a candidate remote idempotently, but never silently retarget one.
set -euo pipefail

if [[ "$#" != 3 ]]; then
  echo "usage: $0 REPOSITORY REMOTE EXPECTED_URL" >&2
  exit 64
fi

repo="$1"; remote="$2"; expected="$3"
existing="$(git -C "$repo" config --get-all "remote.$remote.url" 2>/dev/null || true)"
if [[ -z "$existing" ]]; then
  exec git -C "$repo" remote add "$remote" "$expected"
fi
if [[ "$existing" == "$expected" ]]; then
  exit 0
fi

echo "remote $remote URL mismatch: expected '$expected', found '$existing'" >&2
exit 10
