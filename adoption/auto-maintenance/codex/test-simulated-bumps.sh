#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly REPO_ROOT="${SCRIPT_DIR:h:h:h}"
readonly LIVE_LINK="$HOME/.local/bin/codex"
readonly BEFORE="$(readlink "$LIVE_LINK")"

# The successful-forward-port notification path sources the shared Bash helper
# from this zsh wrapper. Prove that the explicit source directory avoids zsh's
# unset BASH_SOURCE diagnostic under nounset.
mkdir -p "$REPO_ROOT/.staging/auto-maintenance/simulations"
readonly LIB_STDERR="$REPO_ROOT/.staging/auto-maintenance/simulations/zsh-lib-$(date -u +%Y%m%dT%H%M%SZ)-$$.stderr"
readonly LIB_SOURCE="$(
  zsh -uc 'SCRIPT_DIR="$1"; CB_AM_SOURCE="${SCRIPT_DIR:h}"; source "$SCRIPT_DIR/../lib.sh"; print -r -- "$CB_AM_SOURCE"' \
    -- "$SCRIPT_DIR" 2> "$LIB_STDERR"
)"
[[ "$LIB_SOURCE" == "${SCRIPT_DIR:h}" && ! -s "$LIB_STDERR" ]] || {
  print -u2 "FAIL: zsh notification helper source is not clean"
  exit 1
}

bun test "$SCRIPT_DIR/reconcile-codex.test.ts"
bun test "$SCRIPT_DIR/semantic-surface-guard.test.ts"

# Exercise the production wrapper/one-line stdout contract against a fully
# synthetic same-version install. All state is retained under .staging.
readonly FIXTURE_ROOT="$REPO_ROOT/.staging/auto-maintenance/simulations/wrapper-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$FIXTURE_ROOT/bin" "$FIXTURE_ROOT/state" "$FIXTURE_ROOT/artifacts" "$FIXTURE_ROOT/scratch"
readonly FAKE_CODEX="$FIXTURE_ROOT/codex-0.144.5"
{
  print '#!/bin/zsh'
  print 'if [[ "${1:-}" == "--version" ]]; then print "codex-cli 0.144.5"; exit 0; fi'
  print '# context-bonsai-prune context-bonsai-retrieve CONTEXT BONSAI ENFORCED excluded_messages='
  print 'exit 0'
} > "$FAKE_CODEX"
chmod +x "$FAKE_CODEX"
shasum -a 256 "$FAKE_CODEX" > "$FIXTURE_ROOT/codex.sha256"
ln -s "$FAKE_CODEX" "$FIXTURE_ROOT/bin/codex"
readonly RELEASE_JSON="$FIXTURE_ROOT/latest-stable.json"
print -r -- '{"tag_name":"rust-v0.144.5","name":"0.144.5","draft":false,"prerelease":false,"published_at":"2026-07-20T00:00:00Z","assets":[{"name":"codex-aarch64-apple-darwin.tar.gz","browser_download_url":"https://github.com/openai/codex/releases/download/rust-v0.144.5/codex-aarch64-apple-darwin.tar.gz","digest":"sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","size":123456}]}' > "$RELEASE_JSON"

readonly SUMMARY="$(
  CB_CODEX_RELEASE_JSON="$RELEASE_JSON" \
  CB_CODEX_LINK_PATH="$FIXTURE_ROOT/bin/codex" \
  CB_CODEX_MAINTENANCE_STATE="$FIXTURE_ROOT/state" \
  CB_CODEX_ARTIFACT_ROOT="$FIXTURE_ROOT/artifacts" \
  CB_CODEX_SCRATCH_ROOT="$FIXTURE_ROOT/scratch" \
  "$SCRIPT_DIR/reconcile.sh"
)"
[[ "$SUMMARY" == 'codex 0.144.5: Bonsai already current' ]] || {
  print -u2 "FAIL: wrapper summary contract drifted: $SUMMARY"
  exit 1
}
[[ "$(print -r -- "$SUMMARY" | wc -l | tr -d ' ')" == "1" ]] || {
  print -u2 "FAIL: wrapper emitted more than one stdout line"
  exit 1
}

# A failed stable-release network check is a benign skip: rc=20, one summary
# line, no source/build attempt, and the managed link remains byte-identical.
readonly OFFLINE_ROOT="$REPO_ROOT/.staging/auto-maintenance/simulations/offline-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$OFFLINE_ROOT/bin" "$OFFLINE_ROOT/state" "$OFFLINE_ROOT/artifacts" "$OFFLINE_ROOT/scratch"
cp "$FAKE_CODEX" "$OFFLINE_ROOT/codex-0.144.5"
chmod +x "$OFFLINE_ROOT/codex-0.144.5"
shasum -a 256 "$OFFLINE_ROOT/codex-0.144.5" > "$OFFLINE_ROOT/codex.sha256"
ln -s "$OFFLINE_ROOT/codex-0.144.5" "$OFFLINE_ROOT/bin/codex"
readonly OFFLINE_BEFORE="$(readlink "$OFFLINE_ROOT/bin/codex")"
set +e
OFFLINE_SUMMARY="$(
  CB_CODEX_RELEASE_API_URL='http://127.0.0.1:9/repos/openai/codex/releases/latest' \
  CB_CODEX_RELEASE_CONNECT_TIMEOUT=1 \
  CB_CODEX_RELEASE_MAX_TIME=2 \
  CB_CODEX_LINK_PATH="$OFFLINE_ROOT/bin/codex" \
  CB_CODEX_MAINTENANCE_STATE="$OFFLINE_ROOT/state" \
  CB_CODEX_ARTIFACT_ROOT="$OFFLINE_ROOT/artifacts" \
  CB_CODEX_SCRATCH_ROOT="$OFFLINE_ROOT/scratch" \
  "$SCRIPT_DIR/reconcile.sh" 2> "$OFFLINE_ROOT/reconcile.stderr"
)"
OFFLINE_RC=$?
set -e
[[ "$OFFLINE_RC" == "20" ]] || {
  print -u2 "FAIL: offline stable check returned rc=$OFFLINE_RC, expected 20"
  exit 1
}
[[ "$OFFLINE_SUMMARY" == 'codex 0.144.5: stable upstream unavailable — current fork unchanged' ]] || {
  print -u2 "FAIL: offline summary contract drifted: $OFFLINE_SUMMARY"
  exit 1
}
[[ "$(readlink "$OFFLINE_ROOT/bin/codex")" == "$OFFLINE_BEFORE" ]] || {
  print -u2 "FAIL: offline stable check changed its fixture link"
  exit 1
}
[[ -z "$(find "$OFFLINE_ROOT/artifacts" -mindepth 1 -print -quit)" ]] || {
  print -u2 "FAIL: offline stable check staged an artifact"
  exit 1
}
[[ "$(find "$OFFLINE_ROOT/scratch" -name 'FINAL-benign-skip.json' -type f | wc -l | tr -d ' ')" == "1" ]] || {
  print -u2 "FAIL: offline stable check did not retain exactly one benign-skip record"
  exit 1
}
[[ "$(find "$OFFLINE_ROOT/scratch" -name source -type d | wc -l | tr -d ' ')" == "0" ]] || {
  print -u2 "FAIL: offline stable check attempted a source checkout"
  exit 1
}

# Simulate an upstream version bump whose source no longer matches the port.
# This must produce an agentic escalation bundle, rc=10, and zero link change.
readonly CONFLICT_ROOT="$REPO_ROOT/.staging/auto-maintenance/simulations/conflict-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$CONFLICT_ROOT/upstream" "$CONFLICT_ROOT/bin" "$CONFLICT_ROOT/state" "$CONFLICT_ROOT/artifacts" "$CONFLICT_ROOT/scratch"
git -C "$CONFLICT_ROOT/upstream" init -q
git -C "$CONFLICT_ROOT/upstream" config user.name 'Context Bonsai simulation'
git -C "$CONFLICT_ROOT/upstream" config user.email 'simulation@invalid'
print 'simulated structurally incompatible upstream' > "$CONFLICT_ROOT/upstream/README.md"
git -C "$CONFLICT_ROOT/upstream" add README.md
git -C "$CONFLICT_ROOT/upstream" commit -q -m 'simulated Codex 0.145.0'
git -C "$CONFLICT_ROOT/upstream" tag rust-v0.145.0

readonly OLD_FAKE="$CONFLICT_ROOT/codex-0.144.5"
readonly NEW_STABLE_FAKE="$CONFLICT_ROOT/codex-0.145.0"
for spec in "$OLD_FAKE:0.144.5" "$NEW_STABLE_FAKE:0.145.0"; do
  fake_path="${spec%%:*}"; fake_ver="${spec##*:}"
  {
    print '#!/bin/zsh'
    print "if [[ \"\${1:-}\" == \"--version\" ]]; then print \"codex-cli $fake_ver\"; exit 0; fi"
    print '# context-bonsai-prune context-bonsai-retrieve CONTEXT BONSAI ENFORCED excluded_messages='
    print 'exit 0'
  } > "$fake_path"
  chmod +x "$fake_path"
done
shasum -a 256 "$OLD_FAKE" > "$CONFLICT_ROOT/codex.sha256"
ln -s "$OLD_FAKE" "$CONFLICT_ROOT/bin/codex"
readonly CONFLICT_BEFORE="$(readlink "$CONFLICT_ROOT/bin/codex")"
set +e
CONFLICT_SUMMARY="$(
  CB_CODEX_STABLE_BIN="$NEW_STABLE_FAKE" \
  CB_CODEX_LINK_PATH="$CONFLICT_ROOT/bin/codex" \
  CB_CODEX_MAINTENANCE_STATE="$CONFLICT_ROOT/state" \
  CB_CODEX_ARTIFACT_ROOT="$CONFLICT_ROOT/artifacts" \
  CB_CODEX_SCRATCH_ROOT="$CONFLICT_ROOT/scratch" \
  CB_CODEX_UPSTREAM_URL="$CONFLICT_ROOT/upstream" \
  "$SCRIPT_DIR/reconcile.sh" 2> "$CONFLICT_ROOT/reconcile.stderr"
)"
CONFLICT_RC=$?
set -e
[[ "$CONFLICT_RC" == "10" ]] || {
  print -u2 "FAIL: simulated conflict returned rc=$CONFLICT_RC, expected 10"
  exit 1
}
[[ "$CONFLICT_SUMMARY" == 'codex 0.145.0: rebase conflict — candidate isolated, install untouched (escalate)' ]] || {
  print -u2 "FAIL: conflict summary contract drifted: $CONFLICT_SUMMARY"
  exit 1
}
[[ "$(readlink "$CONFLICT_ROOT/bin/codex")" == "$CONFLICT_BEFORE" ]] || {
  print -u2 "FAIL: simulated rebase conflict changed its fixture link"
  exit 1
}
[[ "$(find "$CONFLICT_ROOT/scratch" -name NEEDS_AGENT.json -type f | wc -l | tr -d ' ')" == "1" ]] || {
  print -u2 "FAIL: simulated conflict did not emit exactly one NEEDS_AGENT.json"
  exit 1
}

readonly AFTER="$(readlink "$LIVE_LINK")"
[[ "$AFTER" == "$BEFORE" ]] || {
  print -u2 "FAIL: simulation touched the live Codex symlink"
  exit 1
}
print "PASS: simulated bumps stayed isolated; live Codex target unchanged"
