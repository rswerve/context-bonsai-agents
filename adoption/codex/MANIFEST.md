# Staged artifact manifest

This records the historical 0.144.5 bootstrap. The source patch below has been
upgraded to the autonomous controller baseline; the listed release binary is
the retained pre-upgrade bootstrap binary and is **not** a build of that newer
patch. Production activation and verification use the content-addressed
artifacts under the auto-maintenance system, not this legacy pair.

- Built: 2026-07-19 (America/Chicago)
- Platform: Apple Silicon macOS (`arm64`)
- Upstream tag: `rust-v0.144.5`
- Upstream commit: `87db9bc18ba5bc82c1cb4e4381b44f693ee35623`
- Shared core commit: `4228054c8d137c29ae12faf97b6feba2ca4b0ef2`
- Source patch SHA-256: `37ee4993dee3d7c0252769186cc2ee11b9ee6e3206f4684dcacc19230df87855`
- Release binary SHA-256: `2781a198fc0ada549b920b24d7c6a16098c1d79314fca777fb92c72bbc1ffc92`
- Release binary bytes: `355151720`
- Release binary path: `~/.local/share/context-bonsai/artifacts/codex/0.144.5/bin/codex`

Verification evidence:

- focused Context Bonsai tests: 6 passed, 0 failed;
- full `codex-core` library suite: 2018 passed, 0 failed, 3 ignored
  (`RUST_MIN_STACK=8388608` required by an unrelated upstream agent test);
- `cargo clippy -p codex-core --lib`: passed with one pre-existing
  `codex-core-plugins` warning;
- live subscription test on gpt-5.6-sol: prune persisted, process exited,
  resume/retrieve restored exact token;
- experimental app-server schema: 337 files, canonical JSON SHA-256
  `f9a8ef7d74f6dd20ddb54484104e64188fde8589790e5f585d5098dd846ee744`
  for both stock and staged release;
- isolated enable/rollback smoke: passed, prior stock link restored, no deletes.
