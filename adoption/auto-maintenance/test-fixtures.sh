#!/usr/bin/env bash
# Fail-safe fixture tests for reconcile-claude. Exercises the re-apply + failure branches against
# SCRATCH copies only, and asserts the REAL Claude install is byte-identical before and after.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"
SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
STOCK_BACKUP="$HOME/.context-bonsai/tweakcc-backups/_Users_atighi_.local_share_claude_versions_2.1.215.backup"

real_bundle="$(readlink "$HOME/.local/bin/claude")"
real_before="$(shasum -a256 "$real_bundle" | cut -d' ' -f1)"
real_mcp_before="$(jq -c '.mcpServers["context-bonsai"]' "$HOME/.claude.json" 2>/dev/null)"
real_backups_before="$(ls -1 "$HOME/.context-bonsai/tweakcc-backups/" 2>/dev/null | sort | md5)"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "  PASS: $1"; pass=$((pass+1)); else echo "  FAIL: $1 (got '$2' want '$3')"; fail=$((fail+1)); fi; }

echo "=== FIXTURE 1: unpatched stock bundle → reconcile RE-APPLIES + verifies (scratch only) ==="
if [ -f "$STOCK_BACKUP" ]; then
  b1="$SANDBOX/bundle1"; cp "$STOCK_BACKUP" "$b1"; chmod +x "$b1"
  ln -sf "$b1" "$SANDBOX/claude1"; echo '{}' > "$SANDBOX/c1.json"
  out=$(CB_CLAUDE_LAUNCHER="$SANDBOX/claude1" CB_CLAUDE_JSON="$SANDBOX/c1.json" \
        CB_BACKUP_DIR="$SANDBOX/backups" CB_STATE="$SANDBOX/state" \
        bash "$DIR/reconcile-claude.sh" 2>/dev/null); rc=$?
  echo "  -> $out (rc=$rc)"
  check "exit 0 (applied via isolate-verify-swap)" "$rc" "0"
  check "scratch bundle patched (candidate swapped in)" "$(grep -ca 'cb:archived-filter' "$b1")" "1"
  check "scratch bundle still runs" "$("$b1" --version 2>/dev/null | grep -c 'Claude Code')" "1"
  check "scratch MCP registered" "$(jq -c '.mcpServers["context-bonsai"] != null' "$SANDBOX/c1.json")" "true"
  check "rollback backup written to SCRATCH (not real)" "$(ls -1 "$SANDBOX/backups"/*.backup 2>/dev/null | wc -l | tr -d ' ')" "1"
  check "no leftover candidate temp" "$(ls -1 "$SANDBOX"/.cb-candidate.* 2>/dev/null | wc -l | tr -d ' ')" "0"
else
  echo "  SKIP: stock backup fixture not found ($STOCK_BACKUP)"
fi

echo "=== FIXTURE 2: apply on an unpatchable (garbage) bundle MUST throw + leave the file UNTOUCHED ==="
b2="$SANDBOX/bundle2"; head -c 200000 /dev/urandom > "$b2"; b2_before="$(shasum -a256 "$b2" | cut -d' ' -f1)"
if ( cd "$CB_PORT" && bun run apply/apply-bonsai.ts --path "$b2" ) >/dev/null 2>&1; then arc=0; else arc=1; fi
check "apply throws on garbage (nonzero)" "$arc" "1"
check "garbage file byte-identical after failed apply" "$(shasum -a256 "$b2" | cut -d' ' -f1)" "$b2_before"

echo "=== FIXTURE 3: post-swap MCP-register failure → single pre-staged atomic rollback to stock ==="
if [ -f "$STOCK_BACKUP" ]; then
  b3="$SANDBOX/bundle3"; cp "$STOCK_BACKUP" "$b3"; chmod +x "$b3"; b3_stock="$(shasum -a256 "$b3" | cut -d' ' -f1)"
  ln -sf "$b3" "$SANDBOX/claude3"
  out3=$(CB_CLAUDE_LAUNCHER="$SANDBOX/claude3" CB_CLAUDE_JSON="/no-such-dir-$$/x.json" \
         CB_BACKUP_DIR="$SANDBOX/backups3" CB_STATE="$SANDBOX/state3" \
         bash "$DIR/reconcile-claude.sh" 2>/dev/null); rc3=$?
  echo "  -> $out3 (rc=$rc3)"
  check "rollback path exits 10 (escalate)" "$rc3" "10"
  check "bundle rolled back to STOCK (byte-identical to pre-swap)" "$(shasum -a256 "$b3" | cut -d' ' -f1)" "$b3_stock"
  check "no leftover rollback/candidate temp" "$(ls -1 "$SANDBOX"/.cb-rollback.* "$SANDBOX"/.cb-candidate.* 2>/dev/null | wc -l | tr -d ' ')" "0"
else
  echo "  SKIP: no stock fixture"
fi

echo "=== CRITICAL: the REAL install was never touched by any fixture ==="
check "real bundle sha unchanged" "$(shasum -a256 "$real_bundle" | cut -d' ' -f1)" "$real_before"
check "real MCP entry unchanged" "$(jq -c '.mcpServers["context-bonsai"]' "$HOME/.claude.json" 2>/dev/null)" "$real_mcp_before"
check "real backups dir unchanged" "$(ls -1 "$HOME/.context-bonsai/tweakcc-backups/" 2>/dev/null | sort | md5)" "$real_backups_before"

echo ""
echo "RESULT: $pass passed, $fail failed"
[ "$fail" = "0" ]
