#!/usr/bin/env bash
# End-to-end local-remote simulations for source/reconcile.sh.
# All repositories, runtimes, and retained candidates live under ignored .staging.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ROOT="$REPO_ROOT/.staging/auto-maintenance/source-simulations/$(date -u +%Y%m%dT%H%M%SZ)-$$"
BASE="$ROOT/base"
mkdir -p "$BASE"

pass=0
fail=0
check() {
  if [[ "$2" == "$3" ]]; then
    printf '  PASS: %s\n' "$1"; pass=$((pass + 1))
  else
    printf '  FAIL: %s (got %q want %q)\n' "$1" "$2" "$3"; fail=$((fail + 1))
  fi
}
git_identity() {
  git -C "$1" config user.name "Context Bonsai fixture"
  git -C "$1" config user.email "fixture@invalid"
}
commit_file() {
  local repo="$1" path="$2" content="$3" message="$4"
  printf '%s\n' "$content" > "$repo/$path"
  git -C "$repo" add "$path"
  git -C "$repo" commit -q -m "$message"
}

# Shared-core seed.
git init -q -b main "$BASE/core-seed"
git_identity "$BASE/core-seed"
commit_file "$BASE/core-seed" Cargo.toml '[workspace]' 'seed core'
git clone -q --bare "$BASE/core-seed" "$BASE/core.git"

# Tweakcc seed and its two independent remotes.
git init -q -b main "$BASE/tweak-seed"
git_identity "$BASE/tweak-seed"
commit_file "$BASE/tweak-seed" README.md 'base tweakcc' 'seed tweakcc'
git clone -q --bare "$BASE/tweak-seed" "$BASE/tweak-origin.git"
git clone -q --bare "$BASE/tweak-seed" "$BASE/tweak-upstream.git"

# Parent seed with the two runtime submodules and minimal fixture installer.
git init -q -b main "$BASE/parent-seed"
git_identity "$BASE/parent-seed"
printf 'base\n' > "$BASE/parent-seed/conflict.txt"
mkdir -p "$BASE/parent-seed/adoption/runtime"
cat > "$BASE/parent-seed/adoption/runtime/install.sh" <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail
root="${CB_INSTALL_ROOT:?}"
repo="$(cd "$(dirname "$0")/../.." && pwd)"
parent="$(git -C "$repo" rev-parse HEAD)"
tweak="$(git -C "$repo/tweakcc_context_bonsai" rev-parse HEAD)"
core="$(git -C "$repo/codex_context_bonsai" rev-parse HEAD)"
target="$root/runtime/$parent"
mkdir -p "$target/adoption/runtime" "$root/runtime"
cp "$repo/adoption/runtime/verify.sh" "$target/adoption/runtime/verify.sh"
jq -n --arg parent "$parent" --arg tweak "$tweak" --arg core "$core" \
  '{parentCommit:$parent,tweakccCommit:$tweak,sharedCoreCommit:$core}' > "$target/runtime-manifest.json"
ln -s "$target" "$root/runtime/.candidate-$$"
mv -fh "$root/runtime/.candidate-$$" "$root/runtime/current"
INSTALL
cat > "$BASE/parent-seed/adoption/runtime/verify.sh" <<'VERIFY'
#!/usr/bin/env bash
set -euo pipefail
runtime="${CB_RUNTIME_PATH:-${CB_INSTALL_ROOT:?}/runtime/current}"
test -f "$runtime/runtime-manifest.json"
VERIFY
chmod +x "$BASE/parent-seed/adoption/runtime/install.sh" "$BASE/parent-seed/adoption/runtime/verify.sh"
git -C "$BASE/parent-seed" add conflict.txt adoption
git -C "$BASE/parent-seed" commit -q -m 'seed parent'
GIT_ALLOW_PROTOCOL=file git -C "$BASE/parent-seed" submodule add -q "$BASE/tweak-origin.git" tweakcc_context_bonsai
GIT_ALLOW_PROTOCOL=file git -C "$BASE/parent-seed" submodule add -q "$BASE/core.git" codex_context_bonsai
git -C "$BASE/parent-seed" commit -q -am 'add runtime submodules'
git clone -q --bare "$BASE/parent-seed" "$BASE/parent-origin.git"
git clone -q --bare "$BASE/parent-seed" "$BASE/parent-upstream.git"

cat > "$BASE/cert-ok" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$BASE/cert-fail" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat > "$BASE/verify-ok" <<'EOF'
#!/usr/bin/env bash
test -f "$1/runtime-manifest.json"
EOF
cat > "$BASE/verify-fail" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$BASE/cert-ok" "$BASE/cert-fail" "$BASE/verify-ok" "$BASE/verify-fail"

make_scenario() {
  local name="$1"
  local s="$ROOT/$name"
  mkdir -p "$s/remotes" "$s/runtime/runtime" "$s/history" "$s/scratch"
  git clone -q --bare "$BASE/parent-origin.git" "$s/remotes/parent-origin.git"
  git clone -q --bare "$BASE/parent-upstream.git" "$s/remotes/parent-upstream.git"
  git clone -q --bare "$BASE/tweak-origin.git" "$s/remotes/tweak-origin.git"
  git clone -q --bare "$BASE/tweak-upstream.git" "$s/remotes/tweak-upstream.git"
  # Give both parent remotes the scenario's durable tweakcc-fork URL so URL
  # normalization itself is not mistaken for an upstream feature update.
  git clone -q "$s/remotes/parent-origin.git" "$s/parent-url-work"
  git_identity "$s/parent-url-work"
  git -C "$s/parent-url-work" config -f .gitmodules submodule.tweakcc_context_bonsai.url "$s/remotes/tweak-origin.git"
  git -C "$s/parent-url-work" add .gitmodules
  git -C "$s/parent-url-work" commit -q -m 'set fixture tweakcc fork URL'
  git -C "$s/parent-url-work" push -q origin main
  git -C "$s/parent-url-work" push -q "$s/remotes/parent-upstream.git" main
  local p t active
  p="$(git --git-dir="$s/remotes/parent-origin.git" rev-parse refs/heads/main)"
  t="$(git --git-dir="$s/remotes/tweak-origin.git" rev-parse refs/heads/main)"
  active="$s/runtime/runtime/$p"
  mkdir -p "$active"
  jq -n --arg p "$p" --arg t "$t" '{parentCommit:$p,tweakccCommit:$t,sharedCoreCommit:"fixture"}' > "$active/runtime-manifest.json"
  ln -s "$active" "$s/runtime/runtime/current"
  printf '%s\n' "$s"
}
advance_remote() {
  local bare="$1" path="$2" content="$3" message="$4" work="$5"
  git clone -q "$bare" "$work"
  git_identity "$work"
  commit_file "$work" "$path" "$content" "$message"
  git -C "$work" push -q origin main
}
run_fixture() {
  local s="$1" cert="$2" verify="$3" before_push="${4:-}"
  set +e
  OUTPUT="$(
    GIT_ALLOW_PROTOCOL=file \
    CB_STATE="$s/state" \
    CB_SOURCE_PARENT_ORIGIN_URL="$s/remotes/parent-origin.git" \
    CB_SOURCE_PARENT_UPSTREAM_URL="$s/remotes/parent-upstream.git" \
    CB_SOURCE_TWEAK_ORIGIN_URL="$s/remotes/tweak-origin.git" \
    CB_SOURCE_TWEAK_UPSTREAM_URL="$s/remotes/tweak-upstream.git" \
    CB_SOURCE_SCRATCH_ROOT="$s/scratch" \
    CB_SOURCE_INSTALL_ROOT="$s/runtime" \
    CB_SOURCE_RUNTIME_HISTORY="$s/history" \
    CB_SOURCE_CERTIFY_COMMAND="$cert" \
    CB_SOURCE_POST_VERIFY_COMMAND="$verify" \
    CB_SOURCE_BEFORE_PUSH_COMMAND="$before_push" \
      "$SCRIPT_DIR/reconcile.sh" 2>> "$s/stderr.log"
  )"
  RC=$?
  set -e
}

LIVE_BEFORE="$(readlink "$HOME/.local/share/context-bonsai/runtime/current")"
REAL_PARENT_BEFORE="$(git ls-remote https://github.com/rswerve/context-bonsai-agents.git refs/heads/main | cut -f1)"
REAL_TWEAK_BEFORE="$(git ls-remote https://github.com/rswerve/tweakcc_context_bonsai.git refs/heads/main | cut -f1)"

printf '%s\n' '=== idempotent candidate remote setup ==='
remote_fixture="$ROOT/remote-helper"
git init -q "$remote_fixture"
"$SCRIPT_DIR/ensure-remote.sh" "$remote_fixture" upstream https://example.invalid/upstream.git
first_rc=$?
"$SCRIPT_DIR/ensure-remote.sh" "$remote_fixture" upstream https://example.invalid/upstream.git
second_rc=$?
set +e
"$SCRIPT_DIR/ensure-remote.sh" "$remote_fixture" upstream https://example.invalid/different.git >/dev/null 2>&1
mismatch_rc=$?
set -e
check 'new remote is added' "$first_rc" '0'
check 'matching pre-existing remote is accepted' "$second_rc" '0'
check 'mismatched pre-existing remote is rejected' "$mismatch_rc" '10'
check 'mismatch does not retarget remote' \
  "$(git -C "$remote_fixture" remote get-url upstream)" \
  'https://example.invalid/upstream.git'

printf '%s\n' '=== source no-change ==='
s="$(make_scenario no-change)"; before="$(readlink "$s/runtime/runtime/current")"
run_fixture "$s" "$BASE/cert-ok" "$BASE/verify-ok"
check 'no-change rc' "$RC" '0'
check 'no-change summary' "$OUTPUT" 'source: Bonsai upstream already current'
check 'no-change runtime' "$(readlink "$s/runtime/runtime/current")" "$before"

printf '%s\n' '=== clean upstream update ==='
s="$(make_scenario clean-update)"
advance_remote "$s/remotes/tweak-upstream.git" feature.txt 'new tweak feature' 'upstream tweak feature' "$s/tweak-upstream-work"
advance_remote "$s/remotes/parent-upstream.git" feature.txt 'new parent feature' 'upstream parent feature' "$s/parent-upstream-work"
old="$(readlink "$s/runtime/runtime/current")"
run_fixture "$s" "$BASE/cert-ok" "$BASE/verify-ok"
check 'clean update rc' "$RC" '0'
check 'clean update summary' "$(printf '%s' "$OUTPUT" | grep -c 'upstream merged + runtime verified')" '1'
if [[ "$(readlink "$s/runtime/runtime/current")" != "$old" ]]; then advanced=yes; else advanced=no; fi
check 'clean update advanced runtime' "$advanced" 'yes'
new_parent="$(git --git-dir="$s/remotes/parent-origin.git" rev-parse main)"
new_tweak="$(git --git-dir="$s/remotes/tweak-origin.git" rev-parse main)"
check 'runtime parent matches pushed main' "$(jq -r .parentCommit "$s/runtime/runtime/current/runtime-manifest.json")" "$new_parent"
check 'runtime tweak matches pushed main' "$(jq -r .tweakccCommit "$s/runtime/runtime/current/runtime-manifest.json")" "$new_tweak"

printf '%s\n' '=== offline upstream ==='
s="$(make_scenario offline)"; before="$(readlink "$s/runtime/runtime/current")"
mv "$s/remotes/parent-upstream.git" "$s/remotes/parent-upstream-unavailable.git"
run_fixture "$s" "$BASE/cert-ok" "$BASE/verify-ok"
check 'offline rc' "$RC" '20'
check 'offline summary' "$OUTPUT" 'source: fork or upstream unavailable — runtime unchanged'
check 'offline runtime' "$(readlink "$s/runtime/runtime/current")" "$before"

printf '%s\n' '=== merge conflict ==='
s="$(make_scenario conflict)"
advance_remote "$s/remotes/parent-origin.git" conflict.txt 'fork edit' 'fork conflict side' "$s/parent-origin-work"
advance_remote "$s/remotes/parent-upstream.git" conflict.txt 'upstream edit' 'upstream conflict side' "$s/parent-upstream-work"
# Align the fixture runtime with its now-advanced fork base before reconciliation.
fork_tip="$(git --git-dir="$s/remotes/parent-origin.git" rev-parse main)"
active="$s/runtime/runtime/$fork_tip"; mkdir -p "$active"
jq -n --arg p "$fork_tip" --arg t "$(git --git-dir="$s/remotes/tweak-origin.git" rev-parse main)" \
  '{parentCommit:$p,tweakccCommit:$t,sharedCoreCommit:"fixture"}' > "$active/runtime-manifest.json"
ln -s "$active" "$s/runtime/runtime/.conflict-current"; mv -fh "$s/runtime/runtime/.conflict-current" "$s/runtime/runtime/current"
before="$(readlink "$s/runtime/runtime/current")"; origin_before="$fork_tip"
run_fixture "$s" "$BASE/cert-ok" "$BASE/verify-ok"
check 'conflict rc' "$RC" '10'
check 'conflict summary' "$OUTPUT" 'source: parent merge conflict — candidate retained, runtime unchanged (escalate)'
check 'conflict origin unchanged' "$(git --git-dir="$s/remotes/parent-origin.git" rev-parse main)" "$origin_before"
check 'conflict runtime unchanged' "$(readlink "$s/runtime/runtime/current")" "$before"

printf '%s\n' '=== certification failure ==='
s="$(make_scenario cert-fail)"
advance_remote "$s/remotes/parent-upstream.git" certified.txt 'candidate' 'clean upstream candidate' "$s/parent-upstream-work"
before="$(readlink "$s/runtime/runtime/current")"; origin_before="$(git --git-dir="$s/remotes/parent-origin.git" rev-parse main)"
run_fixture "$s" "$BASE/cert-fail" "$BASE/verify-ok"
check 'cert failure rc' "$RC" '10'
check 'cert failure summary' "$OUTPUT" 'source: certification failed — candidate retained, runtime unchanged (escalate)'
check 'cert failure origin unchanged' "$(git --git-dir="$s/remotes/parent-origin.git" rev-parse main)" "$origin_before"
check 'cert failure runtime unchanged' "$(readlink "$s/runtime/runtime/current")" "$before"

printf '%s\n' '=== remote drift during certification ==='
s="$(make_scenario remote-drift)"
advance_remote "$s/remotes/parent-upstream.git" candidate.txt 'candidate' 'candidate update' "$s/parent-upstream-work"
cat > "$s/drift-hook" <<EOF
#!/usr/bin/env bash
set -e
git clone -q '$s/remotes/parent-origin.git' '$s/drift-work'
git -C '$s/drift-work' config user.name fixture
git -C '$s/drift-work' config user.email fixture@invalid
printf 'drift\n' > '$s/drift-work/drift.txt'
git -C '$s/drift-work' add drift.txt
git -C '$s/drift-work' commit -q -m drift
git -C '$s/drift-work' push -q origin main
EOF
chmod +x "$s/drift-hook"
before="$(readlink "$s/runtime/runtime/current")"
run_fixture "$s" "$BASE/cert-ok" "$BASE/verify-ok" "$s/drift-hook"
check 'remote drift rc' "$RC" '20'
check 'remote drift summary' "$OUTPUT" 'source: fork changed during certification — runtime unchanged (retry)'
check 'remote drift runtime unchanged' "$(readlink "$s/runtime/runtime/current")" "$before"

printf '%s\n' '=== post-install verification rollback ==='
s="$(make_scenario post-verify-fail)"
advance_remote "$s/remotes/parent-upstream.git" candidate.txt 'candidate' 'candidate update' "$s/parent-upstream-work"
before="$(readlink "$s/runtime/runtime/current")"
run_fixture "$s" "$BASE/cert-ok" "$BASE/verify-fail"
check 'post-verify failure rc' "$RC" '10'
check 'post-verify failure summary' "$OUTPUT" 'source: post-install verification failed — previous runtime restored (escalate)'
check 'post-verify rollback exact' "$(readlink "$s/runtime/runtime/current")" "$before"

printf '%s\n' '=== retained-runtime recovery after rollback ==='
run_fixture "$s" "$BASE/cert-ok" "$BASE/verify-ok"
check 'retained-runtime recovery rc' "$RC" '0'
check 'retained-runtime recovery summary' "$(printf '%s' "$OUTPUT" | grep -c 'upstream merged + runtime verified')" '1'
check 'retained-runtime recovery activates fork main' \
  "$(jq -r .parentCommit "$s/runtime/runtime/current/runtime-manifest.json")" \
  "$(git --git-dir="$s/remotes/parent-origin.git" rev-parse main)"

printf '%s\n' '=== real state invariants ==='
check 'live runtime untouched' "$(readlink "$HOME/.local/share/context-bonsai/runtime/current")" "$LIVE_BEFORE"
check 'real parent fork untouched' "$(git ls-remote https://github.com/rswerve/context-bonsai-agents.git refs/heads/main | cut -f1)" "$REAL_PARENT_BEFORE"
check 'real tweakcc fork untouched' "$(git ls-remote https://github.com/rswerve/tweakcc_context_bonsai.git refs/heads/main | cut -f1)" "$REAL_TWEAK_BEFORE"

printf '\nRESULT: %s passed, %s failed\n' "$pass" "$fail"
printf 'Retained fixtures: %s\n' "$ROOT"
[[ "$fail" == "0" ]]
