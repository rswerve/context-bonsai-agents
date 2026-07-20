#!/usr/bin/env bash
# Install (or refresh) the Context Bonsai auto-maintenance LaunchAgents:
#   1. daily (both sides) at HOUR:00
#   2. claude-watch — instant Claude re-patch the moment Claude Code auto-updates (WatchPaths)
# Usage: ./install-schedule.sh [HOUR]   (HOUR 0-23, default 10). Runs in the user GUI session.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"
HOUR="${1:-10}"
mkdir -p "$HOME/Library/LaunchAgents" "$CB_STATE"
chmod +x "$DIR"/*.sh 2>/dev/null || true
PATHVAL="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
CLAUDE_VERSIONS="$HOME/.local/share/claude/versions"

load() {  # $1=label $2=plist
  launchctl bootout "gui/$(id -u)/$1" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$2"
  launchctl enable "gui/$(id -u)/$1" 2>/dev/null || true
}

# --- 1. daily (both sides) ---
L1=com.atighi.context-bonsai-maintenance
P1="$HOME/Library/LaunchAgents/$L1.plist"
cat > "$P1" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$L1</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$DIR/run-daily.sh</string></array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>$HOUR</integer><key>Minute</key><integer>0</integer></dict>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$PATHVAL</string><key>HOME</key><string>$HOME</string></dict>
  <key>StandardOutPath</key><string>$CB_STATE/launchd.out.log</string>
  <key>StandardErrorPath</key><string>$CB_STATE/launchd.err.log</string>
  <key>ProcessType</key><string>Background</string><key>LowPriorityIO</key><true/>
</dict></plist>
EOF
load "$L1" "$P1"

# --- 2. claude-watch (instant re-patch on Claude Code auto-update) ---
L2=com.atighi.context-bonsai-maintenance-claudewatch
P2="$HOME/Library/LaunchAgents/$L2.plist"
cat > "$P2" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$L2</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$DIR/run-daily.sh</string><string>--claude-only</string></array>
  <key>WatchPaths</key><array><string>$CLAUDE_VERSIONS</string><string>$HOME/.local/bin/claude</string></array>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$PATHVAL</string><key>HOME</key><string>$HOME</string></dict>
  <key>StandardOutPath</key><string>$CB_STATE/launchd.out.log</string>
  <key>StandardErrorPath</key><string>$CB_STATE/launchd.err.log</string>
  <key>ProcessType</key><string>Background</string><key>LowPriorityIO</key><true/>
</dict></plist>
EOF
load "$L2" "$P2"

echo "Installed 2 LaunchAgents:"
echo "  • $L1               — daily at ${HOUR}:00 (Claude + Codex)"
echo "  • $L2  — instant Claude re-patch on Claude Code auto-update (WatchPaths)"
echo "  Log: $CB_LOG"
echo "  Status: $CB_STATUS"
echo "  Disable both: $DIR/uninstall-schedule.sh"
