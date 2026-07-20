# Context Bonsai — Adoption Runbook

Context Bonsai (autonomous, recoverable, in-session context prune/retrieve) is **enabled by default** for all new Claude Code and Codex sessions on this machine, as of the flip. Built and live-verified against this exact setup (macOS, Claude Max + ChatGPT subscriptions, AgentBridge, herdr).

## What the flip did (both reversible)
- **Codex:** `~/.local/bin/codex` points to a certified Bonsai fork (ahead of Homebrew on PATH). New `codex` launches = Bonsai. The stock Homebrew binary is untouched.
- **Claude Code:** the installed bundle is patched in place (original backed up at `~/.context-bonsai/tweakcc-backups/`) + a `context-bonsai` MCP server is registered in `~/.claude.json`. New `claude` launches = Bonsai.

## Activate it
Bonsai takes effect on the **next launch** of a session. Running sessions keep their current binary until restarted. To use it now, start a new session (e.g. `abg claude` / `abg codex`).

## Blast radius
Global — every Claude Code + Codex session on this machine picks it up on next launch, including other running sessions once they restart. **Subscriptions and models are unchanged**: the Codex fork is built on 0.144.5 (keeps `gpt-5.6-sol`); the Claude patch runs in-client on your Max login. AgentBridge and herdr are unaffected (verified live).

## Turn it OFF (off-ramp — non-destructive, archives preserved)
- **Codex:** `adoption/codex/rollback.sh` (moves the Bonsai symlink into switch history and restores the prior `~/.local/bin/codex` entry, if any; otherwise new launches resolve to stock Homebrew Codex).
- **Claude Code:** `adoption/claude/rollback.sh` atomically restores verified stock, removes the MCP entry, and records a persistent disabled state so neither the daily job nor WatchPaths silently turns it back on. Re-enable with `adoption/claude/enable.sh`; it uses the same isolate/certify/atomic-swap reconciler as unattended maintenance.
- Restart sessions afterward. Claude's hidden messages reappear when its patch is removed. Codex's sidecar archives remain intact, but stock Codex cannot retrieve them; run `context-bonsai-retrieve` before rollback when restored Codex context is required.

## Maintenance (script this)
- **Context Bonsai upstream updates:** the daily source lane merges both upstream `main` branches into the corresponding `rswerve` fork `main` branches in isolated clones. It pushes and atomically installs only after the full suite passes; conflicts leave the current runtime selected and notify.
- **Claude Code updates:** WatchPaths detects a new client bundle, locates and certifies all semantic patch points in isolation, and applies only a fully verified candidate. Most client versions therefore need no manual work. Structural anchor drift leaves clean stock active and notifies rather than risking the install. Claude model selection is independent of this process.
- **Codex updates:** the daily stable-release lane forward-ports, builds, and certifies a candidate before atomically advancing the fork symlink. Conflicts or failed gates preserve the prior working fork and notify.

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
