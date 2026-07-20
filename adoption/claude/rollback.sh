#!/usr/bin/env bash
# Context Bonsai — Claude Code ROLLBACK (off-ramp).
# Restores the stock Claude Code bundle + removes the MCP server. Non-destructive.
# After running, restart Claude Code sessions; any pruned history reappears in full.
set -euo pipefail

PORT="/Users/atighi/dev/context-bonsai-agents/tweakcc_context_bonsai"
CFG="$HOME/.claude.json"

echo "[1/2] Restoring the original Claude Code bundle from backup ..."
( cd "$PORT" && bun run apply:restore )

echo "[2/2] Removing the context-bonsai MCP server from $CFG ..."
tmp="$(mktemp)"
jq 'if .mcpServers then .mcpServers |= del(.["context-bonsai"]) else . end' "$CFG" > "$tmp" && mv "$tmp" "$CFG"

echo "DONE. Restart Claude Code sessions. (Non-destructive: nothing was lost — archived ranges are inert once the patch is gone.)"
