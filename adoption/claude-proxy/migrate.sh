#!/usr/bin/env bash
# Retired after the 2026-07-24 quota incident. Keep this refusal in place so
# old commands fail safely instead of finding another live-model verifier.
echo "Claude proxy migration is retired; no live-model harness will run." >&2
exit 2
