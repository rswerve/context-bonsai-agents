#!/usr/bin/env bash
# Add a candidate remote idempotently, but never silently retarget one.
set -euo pipefail

if [[ "$#" != 3 ]]; then
  echo "usage: $0 REPOSITORY REMOTE EXPECTED_URL" >&2
  exit 64
fi

repo="$1"; remote="$2"; expected="$3"
existing="$(git -C "$repo" config --get-all "remote.$remote.url" 2>/dev/null || true)"
if [[ -z "$existing" ]]; then
  # The add is advisory, not authoritative. This script ENSURES a remote, so what
  # matters is the end state, not whether our own add produced it.
  #
  # We do not get this repository to ourselves. VS Code's GitHub Pull Requests
  # extension discovers a fresh clone and adds the fork parent as `upstream` itself.
  # On 2026-07-24 both sides raced, once each: on the parent candidate our add won and
  # its add failed; on the tweak candidate it opened the repo at 10:00:12.182, wrote
  # branch.main.vscode-merge-base at .387, and logged a successful `git remote add
  # upstream` at .635 — after which our add failed and, via `exec`, took the whole
  # reconcile down with it. It escalated hourly while the runtime sat unchanged.
  #
  # A second, independently reachable shape produces the identical rc=3: `git remote
  # add` refuses whenever a remote.<name> SECTION exists, while the check above looks
  # only for a url KEY, so a section holding just a fetch refspec reads as absent here
  # and present to git. Both are handled below; neither was ever a reason to fail.
  if ! git -C "$repo" remote add "$remote" "$expected" 2>/dev/null; then
    # A failed add does NOT prove the section is url-less — the racing actor may have
    # just written a COMPLETE remote pointing somewhere else. Re-read before assuming,
    # so the mismatch guard below still sees it.
    existing="$(git -C "$repo" config --get-all "remote.$remote.url" 2>/dev/null || true)"
    if [[ -z "$existing" ]]; then
      # Genuinely url-less: nothing to preserve, so completing it retargets nothing.
      # --add, never --replace-all: if a url lands between the read above and this
      # write, appending makes the result multi-valued and the guard rejects it,
      # whereas replacing would silently clobber another actor's remote.
      git -C "$repo" config --add "remote.$remote.url" "$expected" 2>/dev/null || true
    fi
  fi
  existing="$(git -C "$repo" config --get-all "remote.$remote.url" 2>/dev/null || true)"
  if [[ -z "$existing" ]]; then
    echo "remote $remote could not be created in $repo" >&2
    exit 10
  fi
fi
if [[ "$existing" == "$expected" ]]; then
  exit 0
fi

echo "remote $remote URL mismatch: expected '$expected', found '$existing'" >&2
exit 10
