# Context Bonsai — Adoption Runbook

Context Bonsai (autonomous, recoverable, in-session context prune/retrieve) is **enabled by default** for all new Claude Code and Codex sessions on this machine, as of the flip. Built and live-verified against this exact setup (macOS, Claude Max + ChatGPT subscriptions, AgentBridge, herdr).

## What the flip did (both reversible)
- **Codex:** `~/.local/bin/codex` → the Bonsai fork of Codex `0.144.5` (ahead of Homebrew on PATH). New `codex` launches = Bonsai. The stock Homebrew binary is untouched.
- **Claude Code:** the installed `2.1.215` bundle is patched in place (original backed up at `~/.context-bonsai/tweakcc-backups/`) + a `context-bonsai` MCP server is registered in `~/.claude.json`. New `claude` launches = Bonsai.

## Activate it
Bonsai takes effect on the **next launch** of a session. Running sessions keep their current binary until restarted. To use it now, start a new session (e.g. `abg claude` / `abg codex`).

## Blast radius
Global — every Claude Code + Codex session on this machine picks it up on next launch, including other running sessions once they restart. **Subscriptions and models are unchanged**: the Codex fork is built on 0.144.5 (keeps `gpt-5.6-sol`); the Claude patch runs in-client on your Max login. AgentBridge and herdr are unaffected (verified live).

## Turn it OFF (off-ramp — non-destructive, archives preserved)
- **Codex:** `adoption/codex/rollback.sh` (moves the Bonsai symlink into switch history and restores the prior `~/.local/bin/codex` entry, if any; otherwise new launches resolve to stock Homebrew Codex).
- **Claude Code:** `adoption/claude/rollback.sh` (restores the stock bundle + removes the MCP entry). A Claude Code auto-update also reverts the patch on its own.
- Restart sessions afterward. Claude's hidden messages reappear when its patch is removed. Codex's sidecar archives remain intact, but stock Codex cannot retrieve them; run `context-bonsai-retrieve` before rollback when restored Codex context is required.

## Maintenance (script this)
- **Context Bonsai upstream updates:** the daily source lane merges both upstream `main` branches into the corresponding `rswerve` fork `main` branches in isolated clones. It pushes and atomically installs only after the full suite passes; conflicts leave the current runtime selected and notify.
- **Claude Code updates:** the patch is certified for `2.1.215`; `adoption/claude/enable.sh` refuses a version mismatch. After a CC update: re-derive anchors (`tweakcc_context_bonsai/patches/anchors.ts`) + re-run `enable.sh`. An auto-update silently reverts to stock until re-applied (fails *off*, never broken).
- **Codex updates:** rebuild the fork on the new upstream (`adoption/codex/build-staged.sh`) + re-run `adoption/codex/enable.sh` to repoint the symlink.

## Known limitations
- A child **fork** of a thread cannot yet retrieve a parent thread's archive (archives are thread-scoped).
- The **active turn** is excluded from prune-matching (fix for `gpt-5.6-sol` repeating chosen boundary text in current-turn reasoning) — so the most recent turn is never pruned.

## How it was verified
Both harnesses were built and **live-verified against AgentBridge** on your real setup before this flip: byte-exact prune → placeholder → retrieve round-trips in bridged sessions, with the patched/forked binary as a live bridge endpoint. Two real bugs were caught and fixed by that testing (`gpt-5.6-sol` boundary repetition; `CLAUDE_CONFIG_DIR` session-path discovery).

See `adoption/codex/` and `adoption/claude/` for the per-side enable/rollback scripts and build details.

## Durable runtime

The Git checkout is source, not installation state. `adoption/runtime/install.sh`
builds and certifies a versioned runtime under
`~/.local/share/context-bonsai/runtime/`; Claude's MCP entry and both
LaunchAgents point through its atomic `current` symlink. Codex binaries live
under `~/.local/share/context-bonsai/artifacts/`. Branch switches and upstream
merges therefore cannot break new or running sessions.
