## Judge's Assessment

**Story**: rebase-cycle-3d26252cded4c110f525e1082ee591b4963cba5f — Rebase Cycle 3d26252cded4c110f525e1082ee591b4963cba5f onto OpenCode v1.18.3
**Iteration**: 1 of 5
**Date**: 2026-07-18

---

### Summary

| Verdict | Count |
|---------|-------|
| APPROVED (must fix) | 2 |
| APPROVED (should fix) | 9 |
| REJECTED (over-engineering) | 0 |
| REJECTED (out of scope) | 0 |
| REJECTED (not valid) | 0 |

All 11 reviewer findings are approved. No findings were rejected.

| Finding | Severity | Verdict |
|---|---|---|
| C1 | Critical | APPROVED (must fix) |
| C2 | Critical | APPROVED (must fix) |
| H1 | High | APPROVED (should fix) |
| H2 | High | APPROVED (should fix) |
| H3 | High | APPROVED (should fix) |
| M1 | Medium | APPROVED (should fix) |
| M2 | Medium | APPROVED (should fix) |
| M3 | Medium | APPROVED (should fix) |
| L1 | Low | APPROVED (minor fix) |
| L2 | Low | APPROVED (minor fix) |
| L3 | Low | APPROVED (minor fix) |

### Verified Validation Results

This subsection is the **sole** location for the judge's validation verdict.

- **Starting commit:** `127bdb30784d508cc556c71a0f32b508a3061517` (reviewer-verified, disposable scratch worktree at upstream `v1.18.3`)
- **Pre-existing failures (reviewer-reproduced):** none
- **HEAD results:** 5 / 0 pass
- **Regressions:** none
- **Regression gate:** clear — the bonsai-reviewer target-resolution rehearsal applied the full replay sequence, ran the canonical validation set, and all commands passed.

---

### Overall Verdict

**APPROVED AS-IS**

The revised plan adequately resolves every reviewer finding from iteration 1. The classification table, replay-set artifact, and implementation phases have been updated to address the critical path omissions (missing `target_paths` entry and the build-time version override), to add the required pre-publish install gate and worktree cleanup, to correct the tag/E2E ordering, to remove ambiguous credential handling, and to fix the local-installation edge cases. The target-resolution rehearsal passed all post-replay validation commands with no regressions. The plan is fit for orchestration and commit.

**Approval citation** (to record in the plan's "Plan Approval and Commit Status" section):

> Approved by bonsai-judge on 2026-07-18 for iteration 1 of story `rebase-cycle-3d26252cded4c110f525e1082ee591b4963cba5f`. Verdict: **APPROVED AS-IS**. All 11 reviewer findings (2 critical, 3 high, 3 medium, 3 low) are resolved in the revised plan. The bonsai-reviewer target-resolution rehearsal passed all canonical validation commands on a disposable scratch worktree at `127bdb30784d508cc556c71a0f32b508a3061517` with no regressions. The plan may be committed and executed.

---

### Finding-by-Finding Evaluation

#### [C1] Replay-set `target_paths` omitted `packages/schema/src/v1/session.ts`
- **Severity:** Critical
- **Reviewer's Issue:** The replay-set row for `00ebeb266...` did not include `packages/schema/src/v1/session.ts`, even though the commit adds `metadata` to shared `User`/`Assistant` schemas. Without this path, the scope check and allowlist analysis would be incomplete, and the commit could not be faithfully replayed.
- **Verdict:** APPROVED (must fix)
- **Reasoning:** This is a real, blocking correctness gap. The schema change is required for prune/retrieve continuity, and the commit's `name-status` shows it. The spec's scope check (§1.13 gate 9) requires the realized diff to match the union of `target_paths`.
- **If Approved:** The fix is already present: the path has been added to the replay-set row and the classification table, and the replay-set checksum has been recomputed to `00e80b73639c2d9152fdf2a7340f47316a407a2d2a5f42137027551c4b010fed`. Ensure the implementor re-verifies that checksum before replay.

#### [C2] Binary `--version` assertion required `OPENCODE_VERSION=1.18.3` on builds
- **Severity:** Critical
- **Reviewer's Issue:** The canonical validation build and the local-install build did not set `OPENCODE_VERSION=1.18.3`. The rehearsed binary reported a version string lacking the target version, which would fail the acceptance criterion that `opencode_dev` reports `v1.18.3`.
- **Verdict:** APPROVED (must fix)
- **Reasoning:** The acceptance criteria explicitly require the invoked binary to report `v1.18.3`. The target-resolution rehearsal produced `0.0.0--202607182005` without the override, proving the override is necessary. This is a straightforward, proportionate fix.
- **If Approved:** The fix is already present: `OPENCODE_VERSION=1.18.3` is now bound to all build commands (worktree validation, local install). Verify the smoke test in Phase 8 still reads the expected version.

#### [H1] Pre-publish install gate missing
- **Severity:** High
- **Reviewer's Issue:** The plan lacked the pre-publish install gate required by `DEVELOPMENT.md` and `docs/installation-e2e-template.md` for the closed-artifact / local-installation path.
- **Verdict:** APPROVED (should fix)
- **Reasoning:** The final user outcome depends on a working `opencode_dev` installation, and the spec's release-gate ordering (§1.13 / Part 2 §2.9) requires the install gate before sealing. The gate is proportionate and directly protects the local-landing acceptance criteria.
- **If Approved:** The fix is already present: Phase 7 now includes a pre-publish install gate run against the pin-advanced pair, with `PASS`/`FAIL`/`BLOCKED` recording. Ensure the gate is recorded before seal.

#### [H2] Replay worktree cleanup missing
- **Severity:** High
- **Reviewer's Issue:** The plan did not remove the isolated replay worktree after the branch and tag were recorded.
- **Verdict:** APPROVED (should fix)
- **Reasoning:** `forward-port-spec` §1.19 requires cycle-scoped scratch to be removed once its durable refs are recorded. Leaving the worktree behind is a scope/artifact-integrity risk and would consume the per-user tmpfs quota.
- **If Approved:** The fix is already present: Phase 8 step 29 explicitly removes the worktree with `git worktree remove --force`. Ensure this is executed only after the tag and branch are verified and recorded.

#### [H3] Tag/E2E ordering inverted
- **Severity:** High
- **Reviewer's Issue:** The original plan ran the E2E gate before creating the rebase-point tag, which is the reverse of the required release-gate ordering.
- **Verdict:** APPROVED (should fix)
- **Reasoning:** The spec's shape binding (Part 2 §2.9) and `DEVELOPMENT.md` require the tag to be created before the E2E behavioral gate. E2E evidence must be produced against the sealed, tagged tip, not a floating worktree `HEAD`.
- **If Approved:** The fix is already present: Phase 6 now creates `bonsai/v1-on-opencode-1.18.3`, and Phase 7 runs the E2E protocols against the tagged tip. Verify the E2E evidence paths reference the tagged state.

#### [M1] Ambiguous credential fallback
- **Severity:** Medium
- **Reviewer's Issue:** The credentials preflight contained an ambiguous fallback or placeholder that could lead to an executor silently using the wrong credentials.
- **Verdict:** APPROVED (should fix)
- **Reasoning:** E2E drives a real model; credentials must be explicit, out-of-band, and never committed. Removing ambiguity prevents both execution failures and accidental credential leakage.
- **If Approved:** The fix is already present: Phase 0 now requires `OPENCODE_PROVIDER`, `OPENCODE_MODEL`, and `OPENCODE_API_KEY` with `test -n` and delegates the provisioning decision to the orchestrator. No fallback is listed.

#### [M2] `.opencode/opencode.jsonc` restoration
- **Severity:** Medium
- **Reviewer's Issue:** The plan modified `.opencode/opencode.jsonc` for the worktree E2E plugin wiring but did not restore it afterward.
- **Verdict:** APPROVED (should fix)
- **Reasoning:** The worktree must remain based on the upstream tag at seal; leaving an uncommitted config mutation would violate the clean-state and scope gates. Restoration is required.
- **If Approved:** The fix is already present: Phase 7 step 28 restores the file with `git checkout -- .opencode/opencode.jsonc`. Ensure this is executed after the E2E and install gates, regardless of their outcome.

#### [M3] Plugin symlink case not handled
- **Severity:** Medium
- **Reviewer's Issue:** The local-installation plugin wiring assumed `LOCAL_PLUGIN_DIR` was a separate clone and did not handle the case where it is a symlink.
- **Verdict:** APPROVED (should fix)
- **Reasoning:** The local installation may be wired through a symlink; resolving it before writing the plugin path prevents a broken `file://` reference and keeps the smoke test deterministic.
- **If Approved:** The fix is already present: Phase 8 step 31 resolves the path with `readlink -f` before updating the `"plugin"` entry in `LOCAL_INSTALL_DIR/.opencode/opencode.jsonc`. If the directory is a separate clone, the plan updates it via a local fetch; if it is a symlink, no separate update is needed. Ensure the path written matches the actual resolved directory.

#### [L1] Local remote path pointed to the wrong repository
- **Severity:** Low
- **Reviewer's Issue:** The local-installation fetch step used a path to the parent repository or a non-submodule gitdir instead of the actual OpenCode submodule gitdir.
- **Verdict:** APPROVED (minor fix)
- **Reasoning:** The local install must fetch the new tag from the isolated submodule repository, not from the parent repo's gitdir. Using the wrong path would make the local fetch fail.
- **If Approved:** The fix is already present: Phase 8 step 30 adds the remote at `/home/basil/projects/context-bonsai-agents/.git/modules/opencode`, which is the actual submodule gitdir. Verify this path exists before the implementor runs it.

#### [L2] Baseline provenance working directory
- **Severity:** Low
- **Reviewer's Issue:** The baseline row for the existence probe recorded `provenance_ref` from the wrong working directory.
- **Verdict:** APPROVED (minor fix)
- **Reasoning:** The baseline artifact must be generated from the correct directory so the provenance ref is meaningful. The probe runs from `packages/opencode`, and the provenance check should run from the same directory.
- **If Approved:** The fix is already present: Phase 3 row `r02` now runs the probe from `packages/opencode` and records `provenance_ref` with `git ls-files test/session/context-bonsai.test.ts` from that same directory.

#### [L3] JSONC-safe edit method
- **Severity:** Low
- **Reviewer's Issue:** The plugin-wiring instructions for `.opencode/opencode.jsonc` did not use a JSONC-safe edit method, which could strip comments or corrupt the file.
- **Verdict:** APPROVED (minor fix)
- **Reasoning:** The file is JSONC and contains comments. A naive JSON parser or a sed-based edit could break the file or remove comments. Using a JSONC-aware parser or a bounded, comment-preserving text replacement is appropriate.
- **If Approved:** The fix is already present: Phase 7 step 22 and Phase 8 step 31 both describe a JSONC-safe edit method (JSONC-aware parser, or replace the final `}` with a comma-separated plugin entry). Ensure the implementor does not use a naive JSON round-trip.

---

### Loop/Conflict Detection

**Previous Iterations:** 0
**Recurring Issues:** none
**Conflicts Detected:** none
**Assessment:** This is the first iteration. The plan author addressed all reviewer findings in one revision. No contradictory feedback or unhealthy loops detected.

---

### Recommendations

**If APPROVED AS-IS:**
The implementation meets requirements. The plan should proceed to orchestration and execution. Minor execution-only checks are:
1. Re-verify the replay-set checksum and the manual-review approvals checksum before Phase 4.
2. Confirm `OPENCODE_VERSION=1.18.3` is present in the environment for every build command.
3. Confirm the E2E and install gates are recorded before seal.

---

### Complexity Guard Notes

No findings were rejected. No over-engineering, premature abstraction, or scope creep was introduced. All approved changes are directly tied to the acceptance criteria or the forward-port spec's required gates.