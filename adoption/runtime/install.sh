#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly REPO_ROOT="${SCRIPT_DIR:h:h}"
readonly INSTALL_ROOT="${CB_INSTALL_ROOT:-$HOME/.local/share/context-bonsai}"
readonly RUNTIME_ROOT="$INSTALL_ROOT/runtime"
readonly STATE_ROOT="${CB_RUNTIME_STATE_ROOT:-$HOME/.local/state/context-bonsai/runtime-history}"

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
git -C "$REPO_ROOT/codex_context_bonsai" ls-tree -r --full-tree HEAD > "$CANDIDATE/shared-core-tree.txt"

(
  cd "$CANDIDATE/tweakcc_context_bonsai"
  bun install --frozen-lockfile
  bun test
  bun run typecheck
)
bun test "$CANDIDATE/adoption/auto-maintenance/codex/reconcile-codex.test.ts"
zsh -n "$CANDIDATE/adoption/codex/"*.sh "$CANDIDATE/adoption/auto-maintenance/codex/"*.sh
bash -n "$CANDIDATE/adoption/claude/"*.sh \
  "$CANDIDATE/adoption/auto-maintenance/"*.sh \
  "$CANDIDATE/adoption/auto-maintenance/source/"*.sh

readonly CORE_TREE_SHA256="$(shasum -a 256 "$CANDIDATE/shared-core-tree.txt" | awk '{print $1}')"
jq -n \
  --arg installedAt "$STAMP" \
  --arg parentCommit "$PARENT_COMMIT" \
  --arg tweakccCommit "$TWEAKCC_COMMIT" \
  --arg sharedCoreCommit "$CORE_COMMIT" \
  --arg sharedCoreTreeSha256 "$CORE_TREE_SHA256" \
  '{installedAt:$installedAt,parentCommit:$parentCommit,tweakccCommit:$tweakccCommit,sharedCoreCommit:$sharedCoreCommit,sharedCoreTreeSha256:$sharedCoreTreeSha256}' \
  > "$CANDIDATE/runtime-manifest.json"
bun "$CANDIDATE/adoption/auto-maintenance/codex/verify-shared-core.ts" "$CANDIDATE"
mv "$CANDIDATE" "$TARGET"

previous=""
if [[ -L "$RUNTIME_ROOT/current" ]]; then
  previous="$(readlink "$RUNTIME_ROOT/current")"
  ln -s "$previous" "$STATE_ROOT/current-before-$STAMP"
elif [[ -e "$RUNTIME_ROOT/current" ]]; then
  print -u2 "$RUNTIME_ROOT/current exists but is not a managed symlink; runtime staged but not activated"
  exit 1
fi
ln -s "$TARGET" "$RUNTIME_ROOT/.current-$STAMP"
mv -fh "$RUNTIME_ROOT/.current-$STAMP" "$RUNTIME_ROOT/current"
if [[ "$(readlink "$RUNTIME_ROOT/current")" != "$TARGET" ]]; then
  if [[ -n "$previous" ]]; then
    ln -s "$previous" "$RUNTIME_ROOT/.rollback-$STAMP"
    mv -fh "$RUNTIME_ROOT/.rollback-$STAMP" "$RUNTIME_ROOT/current"
  fi
  print -u2 "runtime current pointer did not advance; previous target restored"
  exit 1
fi
print "Context Bonsai runtime installed and verified: $TARGET"
