#!/bin/zsh
set -euo pipefail

readonly INSTALL_ROOT="${CB_INSTALL_ROOT:-$HOME/.local/share/context-bonsai}"
readonly RUNTIME="${CB_RUNTIME_PATH:-$INSTALL_ROOT/runtime/current}"
readonly MANIFEST="$RUNTIME/runtime-manifest.json"

if [[ -n "${CB_RUNTIME_PATH:-}" ]]; then
  [[ -d "$RUNTIME" && -f "$MANIFEST" ]] || {
    print -u2 "candidate runtime or manifest is missing"
    exit 1
  }
else
  [[ -L "$RUNTIME" && -f "$MANIFEST" ]] || {
    print -u2 "managed runtime/current or manifest is missing"
    exit 1
  }
fi
jq -e '.parentCommit and .tweakccCommit and .sharedCoreCommit and .sharedCoreTreeSha256' "$MANIFEST" >/dev/null
[[ -x "$RUNTIME/adoption/auto-maintenance/run-daily.sh" ]]
[[ -x "$RUNTIME/adoption/auto-maintenance/source/reconcile.sh" ]]
[[ -x "$RUNTIME/adoption/auto-maintenance/source/certify-candidate.sh" ]]
[[ -x "$RUNTIME/adoption/auto-maintenance/incident-reminder.sh" ]]
[[ -f "$RUNTIME/tweakcc_context_bonsai/mcp-server/index.ts" ]]
[[ -f "$RUNTIME/codex_context_bonsai/Cargo.toml" ]]
[[ -f "$RUNTIME/shared-core-tree.txt" ]]
bun "$RUNTIME/adoption/auto-maintenance/codex/verify-shared-core.ts" "$RUNTIME" >/dev/null
bun test "$RUNTIME/adoption/auto-maintenance/codex/reconcile-codex.test.ts" >/dev/null
print "Context Bonsai runtime verified: $(readlink "$RUNTIME")"
