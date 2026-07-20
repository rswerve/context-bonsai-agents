# Context Bonsai — Auto-Maintenance

Keeps Bonsai working across Claude Code / Codex updates, **without ever leaving your install broken.**

## The safety contract (non-negotiable)
Every path is **fail-safe**: the system only ever leaves your install in a *working* state — either Bonsai-on or clean-stock, **never half-patched**. Concretely:
- It builds/certifies a candidate **in isolation**; the live install is touched only after checks pass.
- `apply` is **pre-write atomic** — on any anchor mismatch it throws *before* writing, so the bundle is never partially patched (proven by `test-fixtures.sh`).
- Post-apply it **verifies** (sentinels present + binary runs); on failure it **auto-rolls back** to stock.
- Anything it can't do safely → it **does nothing to the live install** and **notifies** you. Claude stays clean-stock after anchor drift; Codex stays on its last certified Bonsai fork.

## What it does
1. **Claude instant-react:** a `WatchPaths` LaunchAgent notices a new Claude Code version and runs the Claude lane within seconds. It re-certs + re-applies if all anchors match; if they drift, it leaves Claude clean-stock and escalates.
2. **Daily safety net:** a 10:00 LaunchAgent runs both lanes (missed runs fire on wake).
3. **Codex proactive stable updates** (`codex/reconcile.sh`): query the official latest stable release, forward-port in a scratch checkout → build → test against the checksummed same-version official binary → **compare-and-swap the symlink** only if green. Homebrew does not need to be updated first. Offline/rate-limited checks are benign no-ops.
4. Writes a status file (`state/last-run.md`) and posts a notification after a successful maintenance change or whenever attention is needed.

## Handled automatically vs. escalated
- **Automatic (most updates):** the patch anchors usually still match / Codex rebases are usually clean → re-applied with no action from you.
- **Escalated (rare):** an update reshapes the code enough to need intelligent re-derivation (like the one anchor hand-fixed for 2.1.215), or a Codex rebase conflict. Claude remains safely unpatched; Codex keeps using its prior certified fork. You get a notification rather than a silent breakage.
- **Honest limit:** a headless run can't reproduce the deep *live behavioral* test (the model + bridge checks that caught 2 bugs during the build). So auto-apply relies on structural anchor-match + smoke checks + auto-rollback + notifying you — it stays conservative.

Codex follows the official GitHub **stable release** endpoint—not raw tags,
betas, nightlies, or `brew outdated`. It checks once daily; a temporary network
failure leaves the current certified fork selected and retries the next day.

## Use it
```sh
./install-schedule.sh [HOUR]   # install daily + Claude WatchPaths LaunchAgents
./run-daily.sh                 # run once, right now
./run-daily.sh --claude-only   # run only the instant-react Claude lane
./run-daily.sh --codex-only    # run only proactive Codex maintenance
./test-fixtures.sh             # fail-safe fixture tests (never touches the real install)
./test-combined.sh             # both reconcilers + orchestrator, fully isolated
./codex/test-simulated-bumps.sh # Codex conflict/CAS/rollback simulations
./uninstall-schedule.sh        # disable + remove both jobs (Bonsai itself stays as-is)
launchctl kickstart gui/$(id -u)/com.atighi.context-bonsai-maintenance   # trigger a run
```
Status: `state/last-run.md` · Log: `state/maintenance.log`

## Files
`lib.sh` (shared helpers, env-overridable paths for testing) · `reconcile-claude.sh` · `run-daily.sh` (orchestrator with lane selection) · `codex/` (Codex-side reconciler) · `install-schedule.sh` / `uninstall-schedule.sh` (daily + watch agents) · `test-fixtures.sh` · `test-combined.sh`
