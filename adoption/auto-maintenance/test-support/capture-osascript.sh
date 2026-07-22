#!/usr/bin/env bash
set -euo pipefail
script_source="$1"
shift
printf 'source=%s\n' "$script_source" > "$CB_NOTIFY_CAPTURE"
printf 'arg=%s\n' "$@" >> "$CB_NOTIFY_CAPTURE"
while IFS= read -r _; do :; done
