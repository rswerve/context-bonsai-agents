# Claude zero-patch route

This is the live Claude route: a **stock, unmodified Claude binary** plus a local wire
proxy that drops archived ranges from outgoing requests. It replaced the host-patch stack
on 2026-07-24, which ends the re-patch treadmill — Claude auto-updates no longer wipe
anything, because nothing is patched.

Codex is unaffected. It runs a compiled fork; this proxy speaks Anthropic's wire format
and cannot serve it.

## Operating it

```sh
control.sh adopt      # put a machine into the route, or repair one that has drifted
control.sh verify     # read-only health check
control.sh release    # off-ramp: Bonsai off, and staying off
```

Prefix either mutating command with `CB_ADOPT_DRY_RUN=1` to print what would change and
write nothing at all.

`adopt` asserts six facts and repairs only those that differ, so it is safe to re-run and
safe on a machine that is already correct:

| fact | desired state |
|---|---|
| `mode` | `claude-mode=proxy`, which stops the reconciler re-patching |
| `watch` | the WatchPaths re-patch agent is unloaded |
| `proxy_agent` | the proxy LaunchAgent is loaded **and serving a matching build** |
| `settings` | `ANTHROPIC_BASE_URL` routed, gauge hooks registered |
| `mcp` | the `context-bonsai` MCP routed at the same proxy |
| `bundle` | the live Claude binary carries no patch markers |

Preflight validates every planned fact before the first write and refuses wholesale
otherwise. The bundle swap runs last and only against a backup proven both clean and
version-matched. Apply **converges rather than transacts**: if a later fact fails, earlier
ones stay applied, the run exits non-zero, and re-running finishes the job. There is no
rollback path by design — a second mutation path that runs approximately never is the code
that is wrong when it finally runs.

`release` reverses only Bonsai-owned state, in the inverse order so routing stops before
the proxy does. Permissions, plugins, model, theme and any other route survive: the base
URL is removed only when it is ours, hooks only by exact command. It deliberately leaves
the binary stock and the WatchPaths agent unloaded, and sets `claude-mode=disabled` rather
than `enabled` — reloading that agent would re-patch the binary, which is the treadmill
this route exists to end.

## Retired

`enable`, `rollback`, and `migrate.sh` all exit `2` without changing state. `enable` was
the patched→stock transaction, superseded by `adopt`. `rollback` would have re-patched the
binary and silently undone the migration. Use `release` as the off-ramp.

## Gotchas

- A runtime advance that changes `proxy.mjs` or `correlate.mjs` changes the proxy's build
  id, and the MCP refuses to enforce unless the two agree. `install.sh` restarts the proxy
  for you; if you move `runtime/current` by hand, kickstart it or every prune fails closed
  until you do.
- Anything launched from a Claude session inherits `ANTHROPIC_BASE_URL`, including test
  suites. Tests that depend on the mode must clear it explicitly.

## Tests

`test-fixtures.sh` covers the six repairable facts, idempotency, zero-write dry runs,
hostile preconditions, convergence after an injected failure, and off-ramp ownership.
`adoption/runtime/install.sh` runs it, so a runtime advance cannot ship a broken adopter.
