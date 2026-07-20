# Codex Bonsai auto-maintenance

`reconcile-codex.ts` keeps the already-adopted Codex Bonsai fork aligned with
the latest official **stable** Codex release. It is a fail-closed proactive
daily updater: Maz does not need to update Homebrew first.

## Transaction

1. Snapshot and verify the current `~/.local/bin/codex` symlink and its Bonsai
   tools plus its adoption checksum/maintenance manifest. Refuse unmanaged
   files, broken links, prereleases, and downgrades.
2. Query GitHub's official latest-release endpoint. Accept only a non-draft,
   non-prerelease exact `rust-vX.Y.Z` tag with the expected macOS arm64 asset,
   byte count, official URL, and SHA-256 digest. A network/rate-limit failure is
   a benign skip: leave the active fork untouched and retry tomorrow.
3. If stable and Bonsai versions match, record `up-to-date` and stop.
4. Clone the exact official `rust-v<stable-version>` tag into a unique
   `.staging/auto-maintenance/codex/<run-id>/` directory.
5. Apply the last certified Bonsai patch mechanically. Conflicts emit
   `NEEDS_AGENT.json`, leave the live symlink byte-for-byte unchanged, and exit
   `10`.
6. Download the same release's official macOS arm64 binary into the isolated
   run, verify its release-published digest and metadata, and use it as the
   app-server wire-schema baseline. Homebrew is not read or changed.
7. Certify the source and binary in isolation.
8. Copy a green candidate to a content-addressed, versioned artifact directory.
   Its binary, generated lock, and forward-port patch are checksum-pinned. Old
   source trees and binaries are retained; the routine deletes nothing.
9. Compare-and-swap the symlink only if it is unchanged since step 1. Preserve
   the prior link in history. Verify the new target after the swap. Any failure
   atomically restores the prior link and records `rolled-back`.

The next port's patch lineage is recovered from the current binary's immutable
artifact manifest, not solely from mutable active-state metadata. A hard process
exit immediately after a verified atomic symlink swap therefore cannot strand
the next run on an older patch lineage.

## Required green gates

- exact official stable tag and unchanged upstream `HEAD`;
- exact eight-file Bonsai allowlist, clean diff, no source symlinks/executables,
  and no app-server protocol edits;
- clean, commit-pinned shared `codex_context_bonsai` core;
- isolated Cargo lock resolution followed by `--locked` for every test, clippy,
  and build command; no build-time source mutation beyond the recorded lock;
- shared-core test suite;
- focused `codex-core` Context Bonsai tests;
- full `codex-core --lib` suite with the required larger Rust test stack;
- `codex-app-server-protocol` tests;
- `cargo clippy -p codex-core --lib`;
- release `arm64` build whose reported version equals the latest stable tag;
- both model-facing tool strings in the binary;
- canonical, file-for-file parity between the candidate and the checksummed
  same-version official stable binary's **experimental app-server JSON schema**;
- pre-commit symlink compare-and-swap invariant;
- post-commit checksum, version, tool strings, and app-server startup/help smoke.

## Invocation and exit codes

```sh
adoption/auto-maintenance/codex/reconcile.sh
```

- `0`: already current or a new candidate was activated and post-verified;
- `10`: attention required: conflict, failed certification, unsafe invariant,
  or a post-apply failure that was automatically rolled back;
- `20`: benign skip because stable release metadata/source/binary was
  temporarily unavailable; the current fork remains selected.

Stdout is exactly one human-readable summary line for the shared orchestrator.
Detailed diagnostics go to stderr and the retained run evidence.

Every run has append-only `events.jsonl`, command logs, and one
`FINAL-<status>.json`. The orchestrator notifies on a successful forward port
and alerts on `needs-agent`, `certification-failed`, `rolled-back`, or
`invariant-failed`. `up-to-date` and benign network skips need no alert.

Run the network-free, scratch-only bump simulations with:

```sh
adoption/auto-maintenance/codex/test-simulated-bumps.sh
```

## Release cadence and fixture seams

The default source is
`https://api.github.com/repos/openai/codex/releases/latest`, checked once by the
daily job. This follows GitHub's stable release cadence rather than raw tags,
betas, nightlies, or Homebrew availability. One unauthenticated request per day
is far below GitHub's normal unauthenticated rate limit; an offline, timeout, or
rate-limit response exits `20` without cloning, building, or switching.

Tests can set `CB_CODEX_RELEASE_JSON` to read captured release metadata without
network access. `CB_CODEX_STABLE_BIN` (and the legacy alias
`CB_CODEX_STOCK_BIN`) provides a same-version fixture binary for isolated test
runs only; production deliberately has no installed-stock fallback.

## Agentic conflict route

The orchestrator may invoke:

```sh
adoption/auto-maintenance/codex/run-agentic-rebase.sh <failed-run-dir>
```

The headless Codex run is constrained to the isolated source checkout with a
workspace-write sandbox. It cannot authorize activation. Its edits must still
pass the exact allowlist, HEAD, tests, clippy, binary, and schema gates before
the same transactional symlink switch is allowed. If the agent cannot produce
a certifiable result, the current working fork stays selected and the failure
is reported.

## Residual safety boundary

Passing tests cannot prove a forward port is semantically perfect. The narrow
file allowlist, wire-schema parity, preserved native compaction primitive, and
post-swap rollback sharply limit risk, but structural upstream rewrites should
remain fail-closed rather than broadening the allowlist automatically. Builds
are intentionally retained because this repository forbids unattended
deletion; periodic storage cleanup requires Maz's explicit approval.
