#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"

if (( $# != 1 )); then
  print -u2 "usage: $0 /absolute/path/to/failed-run"
  exit 64
fi

readonly RUN_DIR="${1:A}"
readonly REQUEST="$RUN_DIR/NEEDS_AGENT.json"
[[ -f "$REQUEST" ]] || {
  print -u2 "missing agentic request: $REQUEST"
  exit 1
}

readonly SOURCE="$(jq -r '.source' "$REQUEST")"
readonly TARGET_VERSION="$(jq -r '.targetVersion' "$REQUEST")"
readonly TARGET_COMMIT="$(jq -r '.targetCommit' "$REQUEST")"
readonly INPUT_PATCH="$(jq -r '.inputPatch' "$REQUEST")"
readonly AGENT_DIR="$RUN_DIR/agentic-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$AGENT_DIR"
readonly PROMPT="$AGENT_DIR/prompt.md"
readonly REPORT="$AGENT_DIR/report.md"

{
  print -r -- "Forward-port the Context Bonsai patch to Codex $TARGET_VERSION in this isolated checkout."
  print -r -- ""
  print -r -- "Safety and scope:"
  print -r -- "- Work only in $SOURCE. Never touch ~/.local/bin, ~/.codex, AgentBridge, Homebrew, or live processes."
  print -r -- "- Keep HEAD exactly $TARGET_COMMIT; do not commit, fetch, reset, clean, or delete anything."
  print -r -- "- The failed mechanical input is $INPUT_PATCH. Re-implement its intent against current code."
  print -r -- "- You may change only the exact allowlist in $REQUEST. No app-server protocol/schema changes."
  print -r -- "- Preserve the sidecar design and the native replace_compacted_history path."
  print -r -- "- Run focused tests you can afford, but do not claim certification; the deterministic certifier runs afterward."
  print -r -- "- Finish with a concise summary of changes and unresolved uncertainty."
} > "$PROMPT"

print "Starting isolated agentic port attempt. This command cannot activate the result."
codex exec \
  --cd "$SOURCE" \
  --sandbox workspace-write \
  --ephemeral \
  -c 'approval_policy="never"' \
  --output-last-message "$REPORT" \
  "$(<"$PROMPT")"

print "Agent attempt finished. Running deterministic certification; activation remains gated on every check."
bun run "$SCRIPT_DIR/reconcile-codex.ts" certify-agentic "$RUN_DIR"
