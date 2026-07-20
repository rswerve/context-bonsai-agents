#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly REPO_ROOT="${SCRIPT_DIR:h:h}"
readonly ARTIFACT_DIR="$REPO_ROOT/.artifacts/context-bonsai/codex/0.144.5/bin"
readonly BINARY="$ARTIFACT_DIR/codex"
readonly CHECKSUM="$ARTIFACT_DIR/codex.sha256"

[[ -x "$BINARY" ]] || {
  print -u2 "staged binary missing or not executable: $BINARY"
  exit 1
}
[[ -f "$CHECKSUM" ]] || {
  print -u2 "staged checksum missing: $CHECKSUM"
  exit 1
}

(
  cd "$ARTIFACT_DIR"
  shasum -a 256 -c "${CHECKSUM:t}"
)

[[ "$($BINARY --version)" == "codex-cli 0.144.5" ]] || {
  print -u2 "unexpected staged Codex version"
  exit 1
}
[[ "$(file -b "$BINARY")" == *"arm64"* ]] || {
  print -u2 "staged binary is not arm64"
  exit 1
}
rg -a -q 'context-bonsai-prune' "$BINARY"
rg -a -q 'context-bonsai-retrieve' "$BINARY"

print "Codex Context Bonsai staged binary verified"
