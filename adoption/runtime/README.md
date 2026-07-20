# Installed runtime

`install.sh` packages only committed parent and submodule source into a
versioned runtime under `~/.local/share/context-bonsai/runtime/<commit>`, runs
the full tweakcc suite plus Codex transaction tests and script syntax checks,
then atomically advances `runtime/current`. Previous runtime pointers are kept
under `~/.local/state/context-bonsai/runtime-history/`; nothing is deleted.

Because `git archive` intentionally omits `.git`, the package also contains a
`shared-core-tree.txt` generated from the exact `codex_context_bonsai` commit.
Its checksum is pinned in `runtime-manifest.json`. Installation, runtime
verification, and every Codex forward-port verify the archive's exact paths,
file modes, and Git blob hashes before trusting it, and verify it again after
the build. This preserves commit-level integrity without making the live
runtime depend on a mutable Git checkout.

The live MCP entry and LaunchAgents should point through `runtime/current`, not
through a development checkout. Codex binaries live separately under
`~/.local/share/context-bonsai/artifacts/codex/` and are selected by the managed
`~/.local/bin/codex` symlink. This keeps branch switches, fresh clones, and
upstream merges from becoming runtime events.

The daily source reconciler invokes this installer only after an isolated merge
passes the full certification suite. `CB_INSTALL_ROOT`, `CB_RUNTIME_STATE_ROOT`,
and `CB_RUNTIME_PATH` let fixtures certify candidate installs without touching
the live runtime. If a packaged commit already exists after an interrupted run,
the reconciler verifies and reuses that immutable target rather than deleting or
overwriting it.
