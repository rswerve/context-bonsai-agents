#!/usr/bin/env bash
# Combined orchestrator fixture test — runs run-daily.sh with BOTH sides in isolated no-change fixtures.
# Verifies the orchestrator discovers + runs both reconcilers, aggregates, and touches NOTHING real.
# NOTE: the Codex-side fixture env is per Codex's stated interface; adjust if Codex refines it.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"
SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then echo "  PASS: $1"; pass=$((pass+1)); else echo "  FAIL: $1 (got '$2' want '$3')"; fail=$((fail+1)); fi; }

# Real-state snapshot (must be identical after).
real_cbundle="$(readlink "$HOME/.local/bin/claude")"; real_csha="$(shasum -a256 "$real_cbundle" | cut -d' ' -f1)"
real_codexlink="$(readlink "$HOME/.local/bin/codex" 2>/dev/null)"

# --- Claude no-change fixture: a copy of the LIVE (patched) bundle + MCP present → healthy no-op ---
cb1="$SB/cbundle"; cp "$real_cbundle" "$cb1"; chmod +x "$cb1"
ln -sf "$cb1" "$SB/claude"; jq -n '{mcpServers:{"context-bonsai":{command:"bun",args:["run","x"]}}}' > "$SB/c.json"

# --- Codex no-change fixture: fake current == fake stable release → no fetch/build/network ---
mkdir -p "$SB/cur" "$SB/stock" "$SB/artifacts" "$SB/scratch"
cat > "$SB/cur/codex" <<'STUB'
#!/bin/bash
[ "$1" = "--version" ] && echo "codex-cli 0.144.5" && exit 0
exit 0
STUB
printf '\n# context-bonsai-prune context-bonsai-retrieve CONTEXT BONSAI ENFORCED excluded_messages=\n' >> "$SB/cur/codex"; chmod +x "$SB/cur/codex"
shasum -a256 "$SB/cur/codex" | cut -d' ' -f1 > "$SB/cur/codex.sha256"    # bare digest (confirm format w/ Codex)
ln -sf "$SB/cur/codex" "$SB/codexlink"
cat > "$SB/stock/codex" <<'STUB'
#!/bin/bash
[ "$1" = "--version" ] && echo "codex-cli 0.144.5" && exit 0
STUB
chmod +x "$SB/stock/codex"

echo "=== combined orchestrator run (both sides no-change, isolated) ==="
CB_CLAUDE_LAUNCHER="$SB/claude" CB_CLAUDE_JSON="$SB/c.json" CB_BACKUP_DIR="$SB/backups" CB_STATE="$SB/state" \
CB_CODEX_SYMLINK="$SB/codexlink" CB_CODEX_LINK_PATH="$SB/codexlink" CB_CODEX_STABLE_BIN="$SB/stock/codex" \
CB_CODEX_ARTIFACT_ROOT="$SB/artifacts" CB_CODEX_SCRATCH_ROOT="$SB/scratch" \
CB_SOURCE_DISABLE=1 CB_RUNTIME_CURRENT="$DIR/../.." \
  bash "$DIR/run-daily.sh"
rc=$?
echo "  orchestrator rc=$rc"
echo "--- status file ---"; cat "$SB/state/last-run.md" 2>/dev/null

echo ""
echo "=== assertions ==="
ck "orchestrator exit 0" "$rc" "0"
ck "status mentions source" "$(grep -c 'Source:' "$SB/state/last-run.md" 2>/dev/null)" "1"
ck "status mentions claude" "$(grep -c 'Claude:' "$SB/state/last-run.md" 2>/dev/null)" "1"
ck "status mentions codex" "$(grep -c 'Codex:' "$SB/state/last-run.md" 2>/dev/null)" "1"
ck "real Claude bundle untouched" "$(shasum -a256 "$real_cbundle" | cut -d' ' -f1)" "$real_csha"
ck "real Codex symlink untouched" "$(readlink "$HOME/.local/bin/codex" 2>/dev/null)" "$real_codexlink"

echo ""; echo "RESULT: $pass passed, $fail failed"; [ "$fail" = "0" ]
