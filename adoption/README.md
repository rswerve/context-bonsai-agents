# Context Bonsai — Adoption Runbook

Context Bonsai (autonomous, recoverable, in-session context prune/retrieve) is **enabled by default** for all new Claude Code and Codex sessions on this machine, as of the flip. Built and live-verified against this exact setup (macOS, Claude Max + ChatGPT subscriptions, AgentBridge, herdr).

## What the flip did (both reversible)
- **Codex:** `~/.local/bin/codex` points to a certified Bonsai fork (ahead of Homebrew on PATH). New `codex` launches = Bonsai. The stock Homebrew binary is untouched.
- **Claude Code:** the installed bundle stays stock. A supervised local proxy filters archived ranges from outgoing Anthropic requests, the `context-bonsai` MCP is registered in `~/.claude.json`, and gauge hooks are registered in `~/.claude/settings.json`.

## Activate it
Bonsai takes effect on the **next launch** of a session. Running sessions keep their current binary until restarted. To use it now, start a new session (e.g. `abg claude` / `abg codex`).

## Blast radius
Global — every Claude Code + Codex session on this machine picks it up on next launch, including other running sessions once they restart. **Subscriptions and models are unchanged**: the Codex fork is built on 0.144.5 (keeps `gpt-5.6-sol`); the Claude patch runs in-client on your Max login. AgentBridge and herdr are unaffected (verified live).

## Turn it OFF (off-ramp — non-destructive, archives preserved)
- **Codex:** `adoption/codex/rollback.sh` (moves the Bonsai symlink into switch history and restores the prior `~/.local/bin/codex` entry, if any; otherwise new launches resolve to stock Homebrew Codex).
- **Claude Code:** `adoption/claude-proxy/control.sh release` removes only the Bonsai-owned proxy route and gauge hooks, stops the proxy, and records a persistent disabled state. Re-enable with `adoption/claude-proxy/control.sh adopt`; inspect first with `CB_ADOPT_DRY_RUN=1 adoption/claude-proxy/control.sh adopt`.
- Restart sessions afterward. Claude's archived messages reappear when proxy filtering stops. Codex's sidecar archives remain intact, but stock Codex cannot retrieve them; run `context-bonsai-retrieve` before rollback when restored Codex context is required.

## Maintenance (script this)
- **Context Bonsai upstream updates:** the daily source lane merges both upstream `main` branches into the corresponding `rswerve` fork `main` branches in isolated clones. It pushes and atomically installs only after the full suite passes; conflicts leave the current runtime selected and notify.
- **Claude Code updates:** the client bundle is unmodified, so Claude auto-updates do not require re-patching. Runtime advances certify the MCP, proxy, hooks, and adopter before atomically advancing `runtime/current`; when proxy code changes, the installer restarts it so its build id remains aligned with the MCP.
- **Codex updates:** the daily stable-release lane forward-ports, builds, and certifies a candidate before atomically advancing the fork symlink. Conflicts or failed gates preserve the prior working fork and notify.

## Known limitations
- A child **fork** of a thread cannot yet retrieve a parent thread's archive (archives are thread-scoped).
- The **active turn** is excluded from prune-matching (fix for `gpt-5.6-sol` repeating chosen boundary text in current-turn reasoning) — so the most recent turn is never pruned.

## How it was verified
Both routes were **live-verified against AgentBridge** on the real setup. Claude's proxy has enforced a real autonomous prune with a matching process/build acknowledgement and 63 dropped messages. Codex's compiled fork completed a byte-exact prune/retrieve round-trip as a live bridge endpoint.

See `adoption/codex/` and `adoption/claude-proxy/` for the per-side controls and build details.

## Durable runtime

The Git checkout is source, not installation state. `adoption/runtime/install.sh`
builds and certifies a versioned runtime under
`~/.local/share/context-bonsai/runtime/`; Claude's MCP entry and both
LaunchAgents point through its atomic `current` symlink. Codex binaries live
under `~/.local/share/context-bonsai/artifacts/`. Branch switches and upstream
merges therefore cannot break new or running sessions.
