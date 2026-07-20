#!/bin/zsh
set -euo pipefail

readonly EXPECTED_COMMIT="87db9bc18ba5bc82c1cb4e4381b44f693ee35623"
readonly SCRIPT_DIR="${0:A:h}"
readonly REPO_ROOT="${SCRIPT_DIR:h:h}"
readonly PATCH_FILE="$SCRIPT_DIR/codex-0.144.5-bonsai.patch"
readonly SHARED_CORE="${CB_CODEX_SHARED_CORE:-$REPO_ROOT/codex_context_bonsai}"
readonly INSTALL_ROOT="${CB_INSTALL_ROOT:-$HOME/.local/share/context-bonsai}"
readonly ARTIFACT_DIR="$INSTALL_ROOT/artifacts/codex/0.144.5/bin"

if (( $# != 1 )); then
  print -u2 "usage: $0 /absolute/path/to/clean/codex-rust-v0.144.5"
  exit 64
fi

readonly SOURCE_ROOT="${1:A}"
readonly CODEX_RS="$SOURCE_ROOT/codex-rs"

[[ -d "$SOURCE_ROOT/.git" ]] || {
  print -u2 "source is not a git checkout: $SOURCE_ROOT"
  exit 1
}
[[ "$(git -C "$SOURCE_ROOT" rev-parse HEAD)" == "$EXPECTED_COMMIT" ]] || {
  print -u2 "source is not exact upstream commit $EXPECTED_COMMIT"
  exit 1
}
[[ -f "$PATCH_FILE" ]] || {
  print -u2 "missing staged patch: $PATCH_FILE"
  exit 1
}

if ! rg -q 'mod context_bonsai;' "$CODEX_RS/core/src/lib.rs"; then
  git -C "$SOURCE_ROOT" apply --check "$PATCH_FILE"
  git -C "$SOURCE_ROOT" apply "$PATCH_FILE"
fi

# The historical certified patch records the original build checkout. Normalize
# that dependency to this runtime's pinned shared core before compiling.
perl -0pi -e 's#codex-context-bonsai = \{ path = "[^"]+" \}#codex-context-bonsai = { path = "'"$SHARED_CORE"'" }#' \
  "$CODEX_RS/core/Cargo.toml"

(
  cd "$CODEX_RS"
  cargo test -p codex-core context_bonsai --lib
  cargo build --release -p codex-cli --bin codex
)

mkdir -p "$ARTIFACT_DIR"
install -m 755 "$CODEX_RS/target/release/codex" "$ARTIFACT_DIR/codex"
shasum -a 256 "$ARTIFACT_DIR/codex" > "$ARTIFACT_DIR/codex.sha256"

print "staged: $ARTIFACT_DIR/codex"
"$SCRIPT_DIR/verify-staged.sh"
