# Context Bonsai — Auto-Maintenance

Keeps Bonsai working across Claude Code / Codex updates, **without ever leaving your install broken.**

## The safety contract (non-negotiable)
Every path is **fail-safe**: the system only ever leaves your install in a *working* state — either Bonsai-on or clean-stock, **never half-patched**. Concretely:
- It builds/certifies a candidate **in isolation**; the live install is touched only after checks pass.
- `apply` is **pre-write atomic** — on any anchor mismatch it throws *before* writing, so the bundle is never partially patched (proven by `test-fixtures.sh`).
- Post-apply it **verifies** (sentinels present + binary runs); on failure it **auto-rolls back** to stock.
- It also certifies the autonomous controller and live enforcement evidence:
  Codex must wire the canonical startup guidance and five-user-turn gauge and
  carry the post-prune process/archive/excluded-count acknowledgement; Claude
  must contain the provider-bound, multi-serialization-safe five-user-turn
  injector plus the same-process archive filter. Tool registration alone is not
  accepted as healthy.
- Anything it can't do safely → it **does nothing to the live install** and **notifies** you. Claude stays clean-stock after anchor drift; Codex stays on its last certified Bonsai fork.

## What it does
1. **Bonsai source updates** (`source/reconcile.sh`): compare both fork `main` branches with their upstreams, merge in isolated clones, certify the complete candidate, compare-and-swap the two fork refs, package an immutable runtime, and atomically advance `runtime/current`. The development checkout is never modified.
2. **Claude instant-react:** a `WatchPaths` LaunchAgent notices a new Claude Code version and runs the Claude lane within seconds. It re-certs + re-applies if all anchors match; if they drift, it leaves Claude clean-stock and escalates.
3. **Daily safety net:** a 10:00 LaunchAgent runs source sync followed by both harness lanes (missed runs fire on wake).
4. **Unresolved-incident reminders:** an `rc=10` creates a durable local record containing its fingerprint, diagnosis, safe state, evidence path, and first-seen time. A third LaunchAgent checks those records every 15 minutes and reminds at detection, 1 hour, 4 hours, and every 24 hours thereafter. A clean `rc=0` for that lane marks the incident resolved; records and event history are retained. This path invokes no model, agent, or reconciler and consumes no subscription quota.
5. **Codex proactive stable updates** (`codex/reconcile.sh`): query the official latest stable release, forward-port in a scratch checkout → build → test against the checksummed same-version official binary → **compare-and-swap the symlink** only if green. Homebrew does not need to be updated first. Offline/rate-limited checks are benign no-ops.
6. Writes a status file (`state/last-run.md`) and posts a notification after a successful maintenance change or whenever attention is needed. Failure notifications name every failed lane, state whether its install/runtime was unchanged or rolled back, and give the exact status/evidence path. If `terminal-notifier` is available, clicking the notification opens that status file; if that backend fails, notification delivery falls through to AppleScript. The display-only fallback carries the same complete diagnosis and path.

The experimental semantic guard is shipped as dormant, reviewable code only.
No scheduled or reconciliation path invokes it or `run-agentic-rebase.sh`; an
unresolved incident never starts an agent automatically.

## Persistent Claude controls

The manual Claude controls and unattended maintenance share one implementation:

```sh
adoption/claude/rollback.sh  # verified stock + MCP removal; stays disabled
adoption/claude/enable.sh    # clear disabled intent + safe reconciliation
```

The operator mode is stored in the durable maintenance state directory. A
disabled Claude lane is reported as a healthy no-op by both the daily job and
the WatchPaths job; source and Codex maintenance continue normally. The old
fixed-2.1.215 direct patch path has been retired.

## Source-update transaction
The source lane trusts the configured GitHub upstream repositories, but never
blindly runs `git pull` in a working checkout. It discovers immutable ref IDs,
clones the fork and upstream branches into a retained scratch run, merges the
parent and tweakcc histories, preserves the durable tweakcc-fork URL, and runs:

- tweakcc install, tests, and both TypeScript typechecks;
- Codex transaction/policy tests and simulated bumps;
- Claude and combined fail-safe fixtures;
- shell syntax checks; and
- a complete isolated runtime package + verification.

Only then may it fast-forward `rswerve/tweakcc_context_bonsai:main`, followed by
`rswerve/context-bonsai-agents:main`. Remote refs are checked again immediately
before each outward write. A runtime rollback symlink is pre-staged before the
atomic activation; post-activation failure restores the exact previous target.
Partial cross-repository pushes are safe: the live runtime does not advance,
and the next run converges the remaining parent pointer.

The user's local development checkout is deliberately not updated by the
background job. To catch it up after an automatic source update, use
`git fetch origin && git merge --ff-only origin/main` from a clean local `main`.

## Handled automatically vs. escalated
- **Automatic (most updates):** the patch anchors usually still match / Codex rebases are usually clean → re-applied with no action from you.
- **Escalated (rare):** a Bonsai source merge conflicts, its certification fails, an update reshapes the Claude code enough to need intelligent re-derivation (like the one anchor hand-fixed for 2.1.215), or a Codex rebase conflicts. The prior runtime remains selected, Claude remains safely unpatched when appropriate, and Codex keeps using its prior certified fork. You get a notification rather than a silent breakage.
- **Honest limit:** a headless run can't reproduce the deep *live behavioral* test (the model + bridge checks that caught 2 bugs during the build). So auto-apply relies on structural anchor-match + smoke checks + auto-rollback + notifying you — it stays conservative.

The current ports have additionally passed a real subscription-backed model
probe: both harnesses received their canonical Bonsai guidance/gauge in model
context, including Claude's repeated provider-serialization path.

Codex follows the official GitHub **stable release** endpoint—not raw tags,
betas, nightlies, or `brew outdated`. It checks once daily; a temporary network
failure leaves the current certified fork selected and retries the next day.

## Use it
```sh
./install-schedule.sh [HOUR]   # install daily + Claude WatchPaths + local reminder LaunchAgents
./run-daily.sh                 # run once, right now
./run-daily.sh --source-only   # sync/certify upstream Bonsai source only
./run-daily.sh --claude-only   # run only the instant-react Claude lane
./run-daily.sh --codex-only    # run only proactive Codex maintenance
./test-fixtures.sh             # fail-safe fixture tests (never touches the real install)
./test-combined.sh             # both reconcilers + orchestrator, fully isolated
./test-notifications.sh        # actionable + display-only notification fixtures
./test-incident-reminder.sh    # 0h → 1h → 4h → daily + auto-clear fixtures
./codex/test-simulated-bumps.sh # Codex conflict/CAS/rollback simulations
./source/test-source-reconcile.sh # local fake-remotes; source CAS/rollback simulations
./uninstall-schedule.sh        # stop + remove all three jobs (Bonsai itself stays as-is)
launchctl kickstart gui/$(id -u)/com.atighi.context-bonsai-maintenance   # trigger a run
```
Status: `~/.local/state/context-bonsai/auto-maintenance/last-run.md` · Log:
`~/.local/state/context-bonsai/auto-maintenance/maintenance.log`

## Files
`lib.sh` (shared helpers, env-overridable paths for testing) · `source/` (upstream source transaction) · `reconcile-claude.sh` · `run-daily.sh` (orchestrator with lane selection) · `incident-reminder.sh` (quota-free durable escalation schedule) · `codex/` (Codex-side reconciler) · `install-schedule.sh` / `uninstall-schedule.sh` (daily + watch + reminder agents) · `test-fixtures.sh` · `test-combined.sh`
