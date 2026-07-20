#!/usr/bin/env bash
# Disable + remove BOTH Context Bonsai auto-maintenance LaunchAgents (daily + claude-watch).
# This ONLY stops the auto-updater. Bonsai itself stays exactly as-is (use adoption/*/rollback.sh to remove Bonsai).
set -uo pipefail
for LABEL in com.atighi.context-bonsai-maintenance com.atighi.context-bonsai-maintenance-claudewatch; do
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
  echo "Removed $LABEL"
done
echo "Auto-maintenance stopped. Bonsai itself is untouched."
echo "To remove Bonsai entirely: adoption/codex/rollback.sh + adoption/claude/rollback.sh."
