#!/usr/bin/env bash
# Fail-safe Claude Code re-cert via ISOLATE -> VERIFY -> ATOMIC-SWAP.
# The live bundle is NEVER touched until a candidate has been built AND verified in isolation, and the
# rollback backup is guaranteed on disk first. Post-swap critical section is minimal (re-verify + MCP).
# Exit: 0 = healthy/applied; 10 = escalate (drift / candidate fail / rolled back); 20 = benign skip.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"

ver="$(cb_claude_version)"; bundle="$(cb_claude_live_bundle)"
if [ -z "$ver" ] || [ -z "$bundle" ] || [ ! -e "$bundle" ]; then
  cb_log "claude: cannot resolve version/bundle — install untouched"; echo "claude: SKIP (could not resolve install)"; exit 20
fi

mcp_present() { jq -e '.mcpServers["context-bonsai"]' "$CB_CLAUDE_JSON" >/dev/null 2>&1; }
register_mcp() { local tmp; tmp="$(mktemp)" || return 1
  jq --arg cmd bun --arg a1 run --arg a2 "$CB_PORT/mcp-server/index.ts" \
    '.mcpServers=(.mcpServers//{}) | .mcpServers["context-bonsai"]={command:$cmd,args:[$a1,$a2]}' \
    "$CB_CLAUDE_JSON" > "$tmp" && mv "$tmp" "$CB_CLAUDE_JSON"; }

# --- Case 1: already patched for the current version → healthy; just ensure MCP present. ---
if cb_bundle_fully_patched "$bundle"; then
  if mcp_present; then cb_log "claude $ver: patched + MCP present — healthy"; echo "claude $ver: healthy (no action)"; exit 0; fi
  if register_mcp; then echo "claude $ver: re-registered MCP"; exit 0; else echo "claude $ver: MCP register failed (escalate)"; exit 10; fi
fi

# --- Case 2: unpatched → ISOLATE, VERIFY, then ATOMIC-SWAP. Live bundle untouched until swap. ---
cb_log "claude $ver: unpatched — building + verifying a candidate in isolation"
cand="$(dirname "$bundle")/.cb-candidate.$$"     # same directory/volume as live bundle → atomic mv
work="$(mktemp -d "${TMPDIR:-/tmp}/cb-claude.XXXXXX")"
# cleanup removes ONLY our own transient artifacts (guarded).
cleanup() { for f in "${cand:-}" "${rbc:-}"; do [ -n "$f" ] && [ -f "$f" ] && rm -f "$f"; done; [ -n "${work:-}" ] && [ -d "${work:-/nonexistent}" ] && rm -rf "$work"; }
trap cleanup EXIT

esc() { # escalate: live bundle untouched, Bonsai left safely off
  cb_log "claude $ver: $1 — live bundle untouched; Bonsai safely off"
  cb_notify "Context Bonsai" "Claude Code $ver: $2 Bonsai is safely OFF, install untouched." "Basso"
  echo "claude $ver: $3 — install untouched (safe)"; exit 10
}

# 1. Stage a candidate = copy of the live (stock) bundle; anchor-check it READ-ONLY first.
cp "$bundle" "$cand" 2>/dev/null && chmod +x "$cand" 2>/dev/null || { cb_log "claude $ver: could not stage candidate"; echo "claude $ver: SKIP (stage failed)"; exit 20; }
if ! ( cd "$CB_AM" && bun run anchor-check.ts "$cand" ) >"$work/anchors.txt" 2>&1; then
  drifted="$(grep -c '^DRIFT' "$work/anchors.txt" 2>/dev/null || echo '?')"
  cp "$work/anchors.txt" "$CB_STATE/claude-drift-$ver.txt" 2>/dev/null || true
  esc "anchor drift ($drifted; diag saved to state/claude-drift-$ver.txt)" "needs a patch re-derivation ($drifted anchor(s) drifted; see state/)." "NEEDS RE-DERIVATION ($drifted anchor(s) drifted)"
fi

# 2. Patch + verify the CANDIDATE (never the live bundle).
( cd "$CB_PORT" && bun run apply/apply-bonsai.ts --path "$cand" --backup "$work/cand.backup" ) >>"$CB_LOG" 2>&1 \
  || esc "candidate patch failed (anchors matched but apply threw)" "candidate build failed." "candidate build failed (escalate)"
cb_bundle_fully_patched "$cand" && "$cand" --version >/dev/null 2>&1 \
  || esc "candidate failed verification (needs all 3 sentinels + a runnable binary)" "candidate failed verification." "candidate verify failed (escalate)"

# 3. Candidate verified. BEFORE the point of no return, guarantee both the restore backup AND a pre-verified
#    rollback candidate on the live bundle's volume — so a rollback (if ever needed) is a single already-prepared
#    atomic mv that cannot fail on prep.
backup="$CB_BACKUP_DIR/$(printf '%s' "$bundle" | sed 's/[^a-zA-Z0-9._-]/_/g').backup"
mkdir -p "$CB_BACKUP_DIR" || esc "could not create backup dir" "backup prep failed." "backup prep failed (escalate)"
if [ ! -f "$backup" ]; then cp "$bundle" "$backup" || esc "could not write rollback backup" "backup prep failed." "backup prep failed (escalate)"; fi
rbc="$(dirname "$bundle")/.cb-rollback.$$"
cp "$backup" "$rbc" 2>/dev/null && chmod +x "$rbc" 2>/dev/null && "$rbc" --version >/dev/null 2>&1 \
  || esc "could not pre-stage a verified rollback candidate" "rollback prep failed." "rollback prep failed (escalate)"

# 4. ATOMIC SWAP (minimal critical section). On post-swap failure, rollback is ONE pre-staged atomic mv + stock re-verify.
if mv "$cand" "$bundle"; then
  cand=""   # consumed by mv; do not clean
  swap_ok=1
  cb_bundle_fully_patched "$bundle"               || { swap_ok=0; cb_log "claude $ver: post-swap sentinel check failed (need all 3)"; }
  "$CB_CLAUDE_LAUNCHER" --version >/dev/null 2>&1  || { swap_ok=0; cb_log "claude $ver: post-swap binary does not run"; }
  if [ "$swap_ok" = "1" ] && ! mcp_present && ! register_mcp; then swap_ok=0; cb_log "claude $ver: MCP registration FAILED after swap"; fi
  if [ "$swap_ok" = "1" ]; then
    [ -n "${rbc:-}" ] && [ -f "$rbc" ] && rm -f "$rbc"; rbc=""      # activation OK — remove owned rollback candidate
    cb_log "claude $ver: candidate swapped in, live re-verified (3 sentinels + runs), MCP registered"
    cb_notify "Context Bonsai" "Re-applied to Claude Code $ver. Worth a quick prune/retrieve check when convenient."
    echo "claude $ver: RE-APPLIED (isolate-verify-swap) + verified"; exit 0
  fi
  # Post-swap check failed → single pre-staged atomic rollback, then verify stock runs.
  if mv "$rbc" "$bundle" 2>/dev/null; then
    rbc=""
    if "$CB_CLAUDE_LAUNCHER" --version >/dev/null 2>&1; then
      cb_log "claude $ver: post-swap check failed — rolled back to stock (atomic) + stock runs"
      cb_notify "Context Bonsai" "Claude $ver: patch failed post-swap check; rolled back to stock (verified). Needs attention." "Basso"
      echo "claude $ver: post-swap check failed — ROLLED BACK + verified (escalate)"; exit 10
    fi
    cb_log "claude $ver: rolled back but STOCK DOES NOT RUN — MANUAL ATTENTION (backup at $backup)"
    cb_notify "Context Bonsai" "Claude $ver: rolled back but stock won't run — MANUAL ATTENTION." "Basso"
    echo "claude $ver: rolled back but stock unrunnable (URGENT)"; exit 10
  fi
  cb_log "claude $ver: post-swap check failed AND rollback mv FAILED — patched candidate still active — MANUAL ATTENTION (backup at $backup)"
  cb_notify "Context Bonsai" "Claude $ver: post-swap rollback FAILED — needs manual attention now." "Basso"
  echo "claude $ver: post-swap check failed + ROLLBACK FAILED (URGENT — manual)"; exit 10
fi
esc "atomic swap failed" "could not swap in the patched candidate." "swap failed (escalate)"
