# Claude zero-patch proxy migration

This is the staged replacement for Claude Code's four binary patches. It is
not active until Maz explicitly runs the guarded Stage-C migration.

## What runs

- `proxy.mjs` filters archived ranges from Claude's outbound `messages[]`.
- The MCP tool result carries origin-authenticated boundary directives; the
  proxy accepts them only when paired to the exact Bonsai tool name and
  tool-use ID.
- Claude's stock binary remains untouched. The gauge runs as ordinary
  `UserPromptSubmit` / `PostToolUse` hooks.
- AgentBridge is independent: it remains on the Claude↔Codex local channel;
  this proxy listens on `127.0.0.1:18399` only for Claude↔Anthropic requests.

The daily source+Codex maintenance LaunchAgent stays loaded. Only Claude's
WatchPaths patch trigger is suppressed by persistent Claude mode `proxy`.

## Safety model

Filtering errors fail open: the original request body is forwarded unchanged.
The daemon is kept alive by launchd and exposes a source+correlator build ID.
When a runtime update changes that ID, the guard waits for a five-second idle
request seam before restarting it.

A static localhost route cannot literally forward while its process is down.
If launchd cannot recover the daemon, the guard atomically removes the proxy
route, gauge hooks, and MCP registration and records Claude mode `disabled`.
New sessions then start on clean stock with Bonsai safely off. An already-running
process inherited the old URL and may need a retry or restart; the notification
says so explicitly.

The cutover is a transaction:

1. Package and certify an immutable runtime containing MCP markers, the shared
   hash module, proxy, hooks, and these scripts.
2. Atomically advance `runtime/current`.
3. Start and health/build-check proxy supervision.
4. Stage exact rollback copies, suppress only Claude patch maintenance, restore
   verified stock, and atomically install the route/hooks settings.
5. Re-verify every invariant. Any failure restores the patched bundle, settings,
   mode, WatchPaths state, and prior runtime selector.

Settings candidates preserve the original file mode (0600 on this machine).
Prior binaries, settings, runtime selectors, plists, and fixture evidence are
retained; these scripts delete none of them.

## Commands

Pre-cutover verification:

```sh
node tweakcc_context_bonsai/proxy-prototype/correlate.test.mjs
node tweakcc_context_bonsai/proxy-prototype/proxy.test.mjs
adoption/claude-proxy/test-fixtures.sh
```

Final migration is deliberately armed by an environment flag and must wait for
Stage B plus Maz's explicit go:

```sh
CB_FINAL_GO=1 \
CB_STAGE_C_VERIFY=/path/to/approved-live-model-and-agentbridge-verifier \
  adoption/claude-proxy/migrate.sh
```

The lower-level `enable.sh` / `control.sh enable` path enforces the same flag;
there is no alternate activation entry point without `CB_FINAL_GO=1`.

The verifier is mandatory. A nonzero result invokes the certified patch
off-ramp and restores the prior runtime selector; the migration cannot declare
success from structural checks alone.

Off-ramp:

```sh
adoption/claude-proxy/rollback.sh
```

The off-ramp re-certifies the host patch before removing the route and leaves
the proxy supervised for sessions that already inherited its URL. After all
Claude sessions have restarted:

```sh
CB_CONFIRM_DRAINED=1 adoption/claude-proxy/control.sh retire
```

`retire` unloads supervision but retains its plists and evidence.

## Required pre-activation proof

Stage B must use a real transcript copy and captured wire body to prove:

- MCP-side boundary hashes equal proxy-side hashes for the same messages;
- the real marker is paired to the namespaced Bonsai tool on the wire;
- prune lowers same-process provider input tokens;
- retrieve restores the exact byte slice; and
- AgentBridge round-trips before and after.

No cutover is acceptable from replay-only or self-reported evidence.
