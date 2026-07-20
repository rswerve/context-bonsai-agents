#!/usr/bin/env bash
# Reconcile our durable Bonsai forks with their upstream main branches.
#
# Transaction boundary:
#   remote discovery -> isolated merge -> certification -> remote CAS pushes
#   -> isolated runtime packaging -> atomic runtime/current advance -> verify.
# Nothing in the development checkout is modified. Every candidate/run directory
# is retained as audit evidence.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib.sh"

PARENT_ORIGIN_URL="${CB_SOURCE_PARENT_ORIGIN_URL:-https://github.com/rswerve/context-bonsai-agents.git}"
PARENT_UPSTREAM_URL="${CB_SOURCE_PARENT_UPSTREAM_URL:-https://github.com/Vibecodelicious/context-bonsai-agents.git}"
TWEAK_ORIGIN_URL="${CB_SOURCE_TWEAK_ORIGIN_URL:-https://github.com/rswerve/tweakcc_context_bonsai.git}"
TWEAK_UPSTREAM_URL="${CB_SOURCE_TWEAK_UPSTREAM_URL:-https://github.com/Vibecodelicious/tweakcc_context_bonsai.git}"
BRANCH="${CB_SOURCE_BRANCH:-main}"
SCRATCH_ROOT="${CB_SOURCE_SCRATCH_ROOT:-$HOME/.local/state/context-bonsai/source-maintenance/runs}"
INSTALL_ROOT="${CB_SOURCE_INSTALL_ROOT:-$HOME/.local/share/context-bonsai}"
RUNTIME_ROOT="$INSTALL_ROOT/runtime"
CURRENT="$RUNTIME_ROOT/current"
RUNTIME_HISTORY="${CB_SOURCE_RUNTIME_HISTORY:-$HOME/.local/state/context-bonsai/runtime-history}"
CERTIFIER="${CB_SOURCE_CERTIFY_COMMAND:-$SCRIPT_DIR/certify-candidate.sh}"
BEFORE_PUSH="${CB_SOURCE_BEFORE_PUSH_COMMAND:-}"
POST_VERIFY="${CB_SOURCE_POST_VERIFY_COMMAND:-}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
RUN_DIR="$SCRATCH_ROOT/$RUN_ID"
LOG="$RUN_DIR/reconcile.log"

mkdir -p "$RUN_DIR" "$RUNTIME_HISTORY"

say() { printf '%s\n' "$1"; exit "$2"; }
record() { printf '%s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "$LOG"; }
run() {
  record "RUN: $*"
  "$@" >> "$LOG" 2>&1
}
valid_oid() { [[ "$1" =~ ^[0-9a-f]{40}$ ]]; }
remote_oid() {
  local url="$1" ref="$2" out
  out="$(git ls-remote --exit-code "$url" "refs/heads/$ref" 2>> "$LOG")" || return 1
  printf '%s\n' "${out%%[[:space:]]*}"
}
retain_rollback() {
  local staged="$1" label="$2"
  [[ -L "$staged" ]] || return 0
  mv "$staged" "$RUNTIME_HISTORY/source-$label-$RUN_ID" >> "$LOG" 2>&1 || true
}
rollback_runtime() {
  local staged="$1" previous="$2" expected="$3"
  local actual=""
  actual="$(readlink "$CURRENT" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" && -L "$staged" ]]; then
    mv -fh "$staged" "$CURRENT" >> "$LOG" 2>&1 || return 1
    [[ "$(readlink "$CURRENT" 2>/dev/null || true)" == "$previous" ]] || return 1
    return 0
  fi
  record "rollback refused: runtime/current drifted (actual=$actual expected=$expected)"
  return 1
}

if [[ "${CB_SOURCE_DISABLE:-0}" == "1" ]]; then
  say "source: disabled for this run" 0
fi

if [[ ! -x "$CERTIFIER" ]]; then
  record "certifier missing or not executable: $CERTIFIER"
  say "source: certifier unavailable — runtime unchanged (escalate)" 10
fi
[[ -L "$CURRENT" && -f "$CURRENT/runtime-manifest.json" ]] ||
  say "source: managed runtime pointer missing — nothing changed (escalate)" 10

# Discover all four refs before cloning. Any unavailable remote is a benign,
# fail-closed skip; the current runtime and both fork refs remain untouched.
PARENT_ORIGIN_OLD="$(remote_oid "$PARENT_ORIGIN_URL" "$BRANCH")" ||
  say "source: fork or upstream unavailable — runtime unchanged" 20
PARENT_UPSTREAM="$(remote_oid "$PARENT_UPSTREAM_URL" "$BRANCH")" ||
  say "source: fork or upstream unavailable — runtime unchanged" 20
TWEAK_ORIGIN_OLD="$(remote_oid "$TWEAK_ORIGIN_URL" "$BRANCH")" ||
  say "source: fork or upstream unavailable — runtime unchanged" 20
TWEAK_UPSTREAM="$(remote_oid "$TWEAK_UPSTREAM_URL" "$BRANCH")" ||
  say "source: fork or upstream unavailable — runtime unchanged" 20
for oid in "$PARENT_ORIGIN_OLD" "$PARENT_UPSTREAM" "$TWEAK_ORIGIN_OLD" "$TWEAK_UPSTREAM"; do
  valid_oid "$oid" || say "source: invalid remote metadata — runtime unchanged (escalate)" 10
done
record "discovered parent origin=$PARENT_ORIGIN_OLD upstream=$PARENT_UPSTREAM"
record "discovered tweakcc origin=$TWEAK_ORIGIN_OLD upstream=$TWEAK_UPSTREAM"

PARENT="$RUN_DIR/parent"
run git clone --filter=blob:none --no-recurse-submodules --branch "$BRANCH" "$PARENT_ORIGIN_URL" "$PARENT" ||
  say "source: fork or upstream unavailable — runtime unchanged" 20
run git -C "$PARENT" remote add upstream "$PARENT_UPSTREAM_URL" ||
  say "source: candidate setup failed — runtime unchanged (escalate)" 10
run git -C "$PARENT" fetch --filter=blob:none upstream "$BRANCH" ||
  say "source: fork or upstream unavailable — runtime unchanged" 20
[[ "$(git -C "$PARENT" rev-parse "origin/$BRANCH")" == "$PARENT_ORIGIN_OLD" ]] ||
  say "source: fork changed during discovery — runtime unchanged (retry)" 20

git -C "$PARENT" config user.name "Context Bonsai maintenance"
git -C "$PARENT" config user.email "context-bonsai-maintenance@users.noreply.github.com"
if ! git -C "$PARENT" merge-base --is-ancestor "upstream/$BRANCH" HEAD >> "$LOG" 2>&1; then
  if ! run git -C "$PARENT" merge --no-ff --no-commit "upstream/$BRANCH"; then
    printf '%s\n' '{"reason":"parent merge conflict"}' > "$RUN_DIR/NEEDS_ATTENTION.json"
    say "source: parent merge conflict — candidate retained, runtime unchanged (escalate)" 10
  fi
fi

# Clone the tweakcc fork inside the parent candidate, merge its upstream, and
# stage the resulting exact gitlink in the parent candidate.
TWEAK="$PARENT/tweakcc_context_bonsai"
run git clone --filter=blob:none --no-recurse-submodules --branch "$BRANCH" "$TWEAK_ORIGIN_URL" "$TWEAK" ||
  say "source: fork or upstream unavailable — runtime unchanged" 20
run git -C "$TWEAK" remote add upstream "$TWEAK_UPSTREAM_URL" ||
  say "source: candidate setup failed — runtime unchanged (escalate)" 10
run git -C "$TWEAK" fetch --filter=blob:none upstream "$BRANCH" ||
  say "source: fork or upstream unavailable — runtime unchanged" 20
[[ "$(git -C "$TWEAK" rev-parse "origin/$BRANCH")" == "$TWEAK_ORIGIN_OLD" ]] ||
  say "source: fork changed during discovery — runtime unchanged (retry)" 20
git -C "$TWEAK" config user.name "Context Bonsai maintenance"
git -C "$TWEAK" config user.email "context-bonsai-maintenance@users.noreply.github.com"
if ! git -C "$TWEAK" merge-base --is-ancestor "upstream/$BRANCH" HEAD >> "$LOG" 2>&1; then
  if ! run git -C "$TWEAK" merge --no-ff --no-commit "upstream/$BRANCH"; then
    printf '%s\n' '{"reason":"tweakcc merge conflict"}' > "$RUN_DIR/NEEDS_ATTENTION.json"
    say "source: tweakcc merge conflict — candidate retained, runtime unchanged (escalate)" 10
  fi
  run git -C "$TWEAK" commit -m "merge upstream Context Bonsai updates" ||
    say "source: tweakcc merge commit failed — runtime unchanged (escalate)" 10
fi
TWEAK_CANDIDATE="$(git -C "$TWEAK" rev-parse HEAD)"

# Our fork URL and custom tweakcc commit are invariants. An upstream parent
# merge must never silently point the durable runtime back at the upstream fork.
[[ "$(git -C "$PARENT" config -f .gitmodules --get submodule.tweakcc_context_bonsai.path 2>> "$LOG")" == "tweakcc_context_bonsai" ]] ||
  say "source: tweakcc submodule contract drifted — runtime unchanged (escalate)" 10
[[ "$(git -C "$PARENT" config -f .gitmodules --get submodule.codex_context_bonsai.path 2>> "$LOG")" == "codex_context_bonsai" ]] ||
  say "source: shared-core submodule contract drifted — runtime unchanged (escalate)" 10
[[ "$(git -C "$PARENT" ls-files --stage tweakcc_context_bonsai | awk '{print $1}')" == "160000" ]] ||
  say "source: tweakcc gitlink contract drifted — runtime unchanged (escalate)" 10
[[ "$(git -C "$PARENT" ls-files --stage codex_context_bonsai | awk '{print $1}')" == "160000" ]] ||
  say "source: shared-core gitlink contract drifted — runtime unchanged (escalate)" 10
git -C "$PARENT" config -f .gitmodules submodule.tweakcc_context_bonsai.url "$TWEAK_ORIGIN_URL"
run git -C "$PARENT" add .gitmodules tweakcc_context_bonsai ||
  say "source: failed to stage durable tweakcc pointer — runtime unchanged (escalate)" 10
if [[ -f "$PARENT/.git/MERGE_HEAD" ]] || ! git -C "$PARENT" diff --cached --quiet; then
  run git -C "$PARENT" commit -m "merge upstream Context Bonsai updates" ||
    say "source: parent merge commit failed — runtime unchanged (escalate)" 10
fi
PARENT_CANDIDATE="$(git -C "$PARENT" rev-parse HEAD)"

# The shared core is the only other submodule packaged into the managed runtime.
run git -C "$PARENT" submodule update --init codex_context_bonsai ||
  say "source: shared-core checkout failed — runtime unchanged (escalate)" 10

ACTIVE_PARENT=""
ACTIVE_TWEAK=""
if [[ -f "$CURRENT/runtime-manifest.json" ]]; then
  ACTIVE_PARENT="$(jq -r '.parentCommit // empty' "$CURRENT/runtime-manifest.json" 2>> "$LOG")"
  ACTIVE_TWEAK="$(jq -r '.tweakccCommit // empty' "$CURRENT/runtime-manifest.json" 2>> "$LOG")"
fi
if [[ "$PARENT_CANDIDATE" == "$PARENT_ORIGIN_OLD" &&
      "$TWEAK_CANDIDATE" == "$TWEAK_ORIGIN_OLD" &&
      "$ACTIVE_PARENT" == "$PARENT_CANDIDATE" &&
      "$ACTIVE_TWEAK" == "$TWEAK_CANDIDATE" ]]; then
  say "source: Bonsai upstream already current" 0
fi

record "certifying parent=$PARENT_CANDIDATE tweakcc=$TWEAK_CANDIDATE"
if ! run "$CERTIFIER" "$PARENT" "$RUN_DIR"; then
  printf '%s\n' '{"reason":"candidate certification failed"}' > "$RUN_DIR/NEEDS_ATTENTION.json"
  say "source: certification failed — candidate retained, runtime unchanged (escalate)" 10
fi

# Certification is allowed to create ignored caches and retained fixture data,
# but it must not mutate any tracked candidate source or move either candidate
# commit. Re-check the exact parent->tweakcc binding before any push.
if [[ -n "$(git -C "$PARENT" status --porcelain --untracked-files=no)" ||
      -n "$(git -C "$TWEAK" status --porcelain --untracked-files=no)" ||
      "$(git -C "$PARENT" rev-parse HEAD)" != "$PARENT_CANDIDATE" ||
      "$(git -C "$TWEAK" rev-parse HEAD)" != "$TWEAK_CANDIDATE" ||
      "$(git -C "$PARENT" ls-tree HEAD tweakcc_context_bonsai | awk '{print $3}')" != "$TWEAK_CANDIDATE" ||
      "$(git -C "$PARENT" config -f .gitmodules --get submodule.tweakcc_context_bonsai.url)" != "$TWEAK_ORIGIN_URL" ]]; then
  say "source: candidate changed during certification — runtime unchanged (escalate)" 10
fi

if [[ -n "$BEFORE_PUSH" ]]; then
  if [[ ! -x "$BEFORE_PUSH" ]] || ! run "$BEFORE_PUSH" "$RUN_DIR"; then
    say "source: pre-push safety hook failed — runtime unchanged (escalate)" 10
  fi
fi

# Compare-and-swap guard immediately before the first outward write.
[[ "$(remote_oid "$PARENT_ORIGIN_URL" "$BRANCH")" == "$PARENT_ORIGIN_OLD" &&
   "$(remote_oid "$TWEAK_ORIGIN_URL" "$BRANCH")" == "$TWEAK_ORIGIN_OLD" ]] ||
  say "source: fork changed during certification — runtime unchanged (retry)" 20

if [[ "$TWEAK_CANDIDATE" != "$TWEAK_ORIGIN_OLD" ]]; then
  run git -C "$TWEAK" push origin "HEAD:refs/heads/$BRANCH" ||
    say "source: tweakcc push rejected — runtime unchanged (retry)" 20
fi
if [[ "$PARENT_CANDIDATE" != "$PARENT_ORIGIN_OLD" ]]; then
  # Recheck parent after the child push. A parent push failure may leave the
  # child fork safely ahead, but the live runtime remains unchanged and the
  # next run will converge the parent pointer.
  [[ "$(remote_oid "$PARENT_ORIGIN_URL" "$BRANCH")" == "$PARENT_ORIGIN_OLD" ]] ||
    say "source: parent fork changed before push — runtime unchanged (retry)" 20
  run git -C "$PARENT" push origin "HEAD:refs/heads/$BRANCH" ||
    say "source: parent push rejected — runtime unchanged (retry)" 20
fi

PREVIOUS="$(readlink "$CURRENT")"
EXPECTED="$RUNTIME_ROOT/$PARENT_CANDIDATE"
ROLLBACK="$RUNTIME_ROOT/.source-rollback-$RUN_ID"
ln -s "$PREVIOUS" "$ROLLBACK" ||
  say "source: could not pre-stage runtime rollback — forks updated, runtime unchanged (escalate)" 10

export CB_INSTALL_ROOT="$INSTALL_ROOT"
export CB_RUNTIME_STATE_ROOT="$RUNTIME_HISTORY"
install_ok=0
if [[ -d "$EXPECTED" ]]; then
  # A prior run may have packaged this immutable commit and then failed after
  # packaging (for example, a killed process or post-swap verification failure).
  # Re-certify the retained target instead of overwriting or deleting it.
  if [[ "$(jq -r '.parentCommit // empty' "$EXPECTED/runtime-manifest.json" 2>> "$LOG")" == "$PARENT_CANDIDATE" &&
        "$(jq -r '.tweakccCommit // empty' "$EXPECTED/runtime-manifest.json" 2>> "$LOG")" == "$TWEAK_CANDIDATE" ]] &&
     run env CB_INSTALL_ROOT="$INSTALL_ROOT" CB_RUNTIME_PATH="$EXPECTED" "$EXPECTED/adoption/runtime/verify.sh"; then
    if [[ "$(readlink "$CURRENT" 2>/dev/null || true)" == "$PREVIOUS" ]]; then
      ln -s "$EXPECTED" "$RUNTIME_ROOT/.source-current-$RUN_ID" &&
        mv -fh "$RUNTIME_ROOT/.source-current-$RUN_ID" "$CURRENT" &&
        [[ "$(readlink "$CURRENT" 2>/dev/null || true)" == "$EXPECTED" ]] && install_ok=1
    fi
  fi
else
  run "$PARENT/adoption/runtime/install.sh" && install_ok=1
fi
if [[ "$install_ok" != "1" ]]; then
  actual="$(readlink "$CURRENT" 2>/dev/null || true)"
  if [[ "$actual" == "$EXPECTED" ]]; then
    rollback_runtime "$ROLLBACK" "$PREVIOUS" "$EXPECTED" ||
      say "source: runtime install failed and rollback needs attention" 10
  else
    retain_rollback "$ROLLBACK" "install-failed"
  fi
  say "source: runtime install failed — previous runtime retained (escalate)" 10
fi

if [[ -n "$POST_VERIFY" ]]; then
  verify_cmd=("$POST_VERIFY" "$CURRENT" "$PARENT_CANDIDATE" "$TWEAK_CANDIDATE")
else
  verify_cmd=("$CURRENT/adoption/runtime/verify.sh")
fi
if ! run "${verify_cmd[@]}" ||
   [[ "$(jq -r '.parentCommit // empty' "$CURRENT/runtime-manifest.json" 2>> "$LOG")" != "$PARENT_CANDIDATE" ]] ||
   [[ "$(jq -r '.tweakccCommit // empty' "$CURRENT/runtime-manifest.json" 2>> "$LOG")" != "$TWEAK_CANDIDATE" ]]; then
  rollback_runtime "$ROLLBACK" "$PREVIOUS" "$EXPECTED" ||
    say "source: post-install verification failed and rollback needs attention" 10
  say "source: post-install verification failed — previous runtime restored (escalate)" 10
fi
retain_rollback "$ROLLBACK" "verified"

printf '%s\n' "{\"parent\":\"$PARENT_CANDIDATE\",\"tweakcc\":\"$TWEAK_CANDIDATE\"}" > "$RUN_DIR/FINAL-verified.json"
cb_notify "Context Bonsai" "Upstream Bonsai source merged, certified, and activated."
say "source: upstream merged + runtime verified (parent ${PARENT_CANDIDATE:0:8}, tweakcc ${TWEAK_CANDIDATE:0:8})" 0
