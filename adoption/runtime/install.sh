#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly REPO_ROOT="${SCRIPT_DIR:h:h}"
readonly INSTALL_ROOT="${CB_INSTALL_ROOT:-$HOME/.local/share/context-bonsai}"
readonly RUNTIME_ROOT="$INSTALL_ROOT/runtime"
readonly STATE_ROOT="$HOME/.local/state/context-bonsai/runtime-history"

[[ -z "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=no)" ]] || {
  print -u2 "tracked parent checkout is dirty; refusing to package an ambiguous runtime"
  exit 1
}
for submodule in tweakcc_context_bonsai codex_context_bonsai; do
  [[ -d "$REPO_ROOT/$submodule/.git" || -f "$REPO_ROOT/$submodule/.git" ]] || {
    print -u2 "required submodule is not initialized: $submodule"
    exit 1
  }
  [[ -z "$(git -C "$REPO_ROOT/$submodule" status --porcelain --untracked-files=no)" ]] || {
    print -u2 "required submodule is dirty: $submodule"
    exit 1
  }
done

readonly PARENT_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
readonly TWEAKCC_COMMIT="$(git -C "$REPO_ROOT/tweakcc_context_bonsai" rev-parse HEAD)"
readonly CORE_COMMIT="$(git -C "$REPO_ROOT/codex_context_bonsai" rev-parse HEAD)"
readonly TARGET="$RUNTIME_ROOT/$PARENT_COMMIT"
readonly STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
readonly CANDIDATE="$RUNTIME_ROOT/.candidate-$PARENT_COMMIT-$STAMP"

[[ ! -e "$TARGET" ]] || {
  print -u2 "runtime already exists: $TARGET"
  exit 1
}
mkdir -p "$CANDIDATE" "$STATE_ROOT"
git -C "$REPO_ROOT" archive HEAD adoption | tar -x -C "$CANDIDATE"
mkdir -p "$CANDIDATE/tweakcc_context_bonsai" "$CANDIDATE/codex_context_bonsai"
git -C "$REPO_ROOT/tweakcc_context_bonsai" archive HEAD | tar -x -C "$CANDIDATE/tweakcc_context_bonsai"
git -C "$REPO_ROOT/codex_context_bonsai" archive HEAD | tar -x -C "$CANDIDATE/codex_context_bonsai"

(
  cd "$CANDIDATE/tweakcc_context_bonsai"
  bun install --frozen-lockfile
  bun test
  bun run typecheck
)
bun test "$CANDIDATE/adoption/auto-maintenance/codex/reconcile-codex.test.ts"
zsh -n "$CANDIDATE/adoption/codex/"*.sh "$CANDIDATE/adoption/auto-maintenance/codex/"*.sh
bash -n "$CANDIDATE/adoption/claude/"*.sh "$CANDIDATE/adoption/auto-maintenance/"*.sh

jq -n \
  --arg installedAt "$STAMP" \
  --arg parentCommit "$PARENT_COMMIT" \
  --arg tweakccCommit "$TWEAKCC_COMMIT" \
  --arg sharedCoreCommit "$CORE_COMMIT" \
  '{installedAt:$installedAt,parentCommit:$parentCommit,tweakccCommit:$tweakccCommit,sharedCoreCommit:$sharedCoreCommit}' \
  > "$CANDIDATE/runtime-manifest.json"
mv "$CANDIDATE" "$TARGET"

if [[ -L "$RUNTIME_ROOT/current" ]]; then
  ln -s "$(readlink "$RUNTIME_ROOT/current")" "$STATE_ROOT/current-before-$STAMP"
elif [[ -e "$RUNTIME_ROOT/current" ]]; then
  print -u2 "$RUNTIME_ROOT/current exists but is not a managed symlink; runtime staged but not activated"
  exit 1
fi
ln -s "$TARGET" "$RUNTIME_ROOT/.current-$STAMP"
mv "$RUNTIME_ROOT/.current-$STAMP" "$RUNTIME_ROOT/current"
print "Context Bonsai runtime installed and verified: $TARGET"
