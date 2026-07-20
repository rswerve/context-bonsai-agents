# Codex Context Bonsai staged adoption

> Historical bootstrap package: the installed system now uses the
> content-addressed 0.144.x artifacts managed by `adoption/auto-maintenance/`.
> Do not run this directory's legacy `enable.sh` over the active newer fork.

This directory is the **unexecuted** Codex half of the global adoption switch.
It targets upstream Codex `rust-v0.144.5` / commit
`87db9bc18ba5bc82c1cb4e4381b44f693ee35623` on Apple Silicon macOS.

Nothing here edits `~/.codex/config.toml`. The runtime stores recoverable
archives under `$CODEX_HOME/context-bonsai/archives/v1/<thread-id>/` only after
the model calls `context-bonsai-prune`.

## Staged artifacts

- `codex-0.144.5-bonsai.patch`: source patch against the exact upstream commit.
  The patch now includes the autonomous startup-guidance and five-user-turn
  gauge wiring used as the forward-port baseline.
- `build-staged.sh`: rebuilds the release binary from an exact clean source
  checkout supplied by the operator.
- `verify-staged.sh`: checks version, checksum, architecture, and tool strings.
- `enable.sh`: the unexecuted adoption switch. It preserves any existing
  `~/.local/bin/codex` entry and points that path at the staged binary.
- `rollback.sh`: the off-ramp. It moves the Bonsai symlink into switch history
  and restores the exact prior entry; it deletes nothing.

The built binary and checksum are intentionally outside both version control
and the development checkout at:

```text
~/.local/share/context-bonsai/artifacts/codex/0.144.5/bin/codex
~/.local/share/context-bonsai/artifacts/codex/0.144.5/bin/codex.sha256
```

## Safety contract

Do not run `enable.sh` until Maz explicitly authorizes the global flip. Running
the verifier is read-only. The enable/rollback scripts refuse ambiguous state,
record their actions under `~/.local/state/context-bonsai/codex-switch`, and
never alter the Homebrew installation.

Existing Codex processes keep their current executable. New terminal and
AgentBridge sessions resolve the staged fork because `~/.local/bin` precedes
Homebrew on Maz's PATH. Restart bridge sessions in the joint runbook; do not
restart unrelated live pairs during staging.

## Verified behavior

- gpt-5.6-sol subscription auth works with an isolated `$CODEX_HOME`.
- A real model-driven prune persisted a `0600` archive, a fresh process resumed
  the same thread, retrieve loaded the sidecar, and the model reproduced an
  exact token available only in the restored range.
- AgentBridge round-trip passed on the same no-wire-change fork architecture.
- Stock and fork app-server schema bundles contain 337 files each and are
  semantically identical; the aggregate JSON differs only in object-key order.

Known scope boundary: archives are intentionally thread-scoped. Resume is
verified. A forked child that inherits a parent placeholder cannot retrieve the
parent archive until lineage-aware archive lookup is implemented.
