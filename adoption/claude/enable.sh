#!/usr/bin/env bash
# Context Bonsai — Claude Code ENABLE.
# GLOBAL change: affects every Claude Code session on its NEXT launch (running sessions keep going).
# Reversible anytime via ./rollback.sh. Built + certified for Claude Code 2.1.215 on macOS (arm64).
# Prereqs: bun on PATH; Claude Code 2.1.215 installed and signed in (Keychain).
set -euo pipefail

PORT="/Users/atighi/dev/context-bonsai-agents/tweakcc_context_bonsai"
CFG="$HOME/.claude.json"

# --- Guard: the patch anchors are certified for one Claude Code version. Refuse to patch a mismatch. ---
ver="$(claude --version 2>/dev/null | grep -oE '2\.1\.[0-9]+' | head -1 || true)"
if [ "$ver" != "2.1.215" ]; then
  echo "ERROR: installed Claude Code is '${ver:-unknown}', but this patch is certified for 2.1.215." >&2
  echo "Re-derive the anchors for '${ver:-your version}' (tweakcc_context_bonsai/patches/anchors.ts) before enabling." >&2
  exit 1
fi

echo "[1/2] Patching the live Claude Code 2.1.215 bundle (tweakcc auto-backs up to ~/.context-bonsai/tweakcc-backups/) ..."
( cd "$PORT" && bun run apply )

echo "[2/2] Registering the context-bonsai MCP server in $CFG ..."
tmp="$(mktemp)"
jq --arg cmd bun --arg a1 run --arg a2 "$PORT/mcp-server/index.ts" \
  '.mcpServers = (.mcpServers // {}) | .mcpServers["context-bonsai"] = {command:$cmd, args:[$a1,$a2]}' \
  "$CFG" > "$tmp" && mv "$tmp" "$CFG"

echo "DONE. Restart Claude Code sessions to load Bonsai. Reverse anytime: ./rollback.sh"
