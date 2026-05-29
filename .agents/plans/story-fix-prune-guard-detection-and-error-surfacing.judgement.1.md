## Judge's Assessment

**Story**: fix-prune-guard-detection-and-error-surfacing — Make Prune Success Trustworthy (Defect A: launch-shape-independent patch detection; Defect B: deterministic failures via MCP `isError`)
**Iteration**: 1 of 5 maximum
**Date**: 2026-05-29

---

### Summary

| Verdict | Count |
|---------|-------|
| APPROVED (must fix) | 1 |
| APPROVED (should fix) | 1 |
| REJECTED (over-engineering) | 0 |
| REJECTED (out of scope) | 0 |
| REJECTED (not valid) | 1 |

### Verified Validation Results

- **Starting commit:** `bfb12e3` (reviewer-verified; confirmed: `git show bfb12e3:mcp-server/index.test.ts` carries the `Buffer.from(metadataBlock![1], ...)` line that produces the baseline TS2769).
- **Pre-existing failures (reviewer-reproduced):** `bun run typecheck`: `mcp-server/index.test.ts` TS2769 (Buffer overload on the base64 metadata test). Confirmed present at `bfb12e3`; line shifted 169→173 only because this story added lines above it. Unrelated to the story; approved as the exception the AC ("Side-repo gates green") explicitly permits.
- **HEAD results:** `bun test` 158 pass / 0 fail (verified by rerun). `bun run typecheck` exits 0 with the single baseline TS2769 carried.
- **Regressions:** none.
- **Regression gate:** clear.

---

### Overall Verdict

**NEEDS REVISION**

Defects A and B are correctly and minimally fixed, behaviorally proven from authoritative host state, and well-tested. The discovery layer now walks ancestors to pid 1 and scans each `/proc/<pid>/exe`, dropping argv-derived candidates to close the false-positive vector — exactly the spec'd, launch-shape-independent shape. Defect B routes all deterministic failure sites through an `isError` helper (verified: only `successResponse` still uses `plainText`). The spec clause landed first, in its own parent commit, and reconciles correctly with the existing "plain text" wording. The live E2E-08 verdict is sound because it rests on authoritative host state (marker-file range listing + placeholder, the ≈9018-token model-visible footprint drop 26704→17686, and a cross-check against the stock unpatched binary) — not the tool's success string and not a recall oracle.

One genuine defect blocks "as-is": the automated effect/secret oracles this same story shipped (`analyzePruneEffect` / `protocol-a-oracle`) read a per-row field the product never writes, so they systematically false-FAIL on every correct live prune and their unit tests pass only because the fixtures inject the wrong shape. The story's explicit deliverable — chosen by the user as a single story with a HARD live automated gate — is a *trustworthy* automated gate; an oracle that returns the wrong verdict on correct behavior does not meet that bar. The fix is small and scoped, so this is a must-fix in-story, not a follow-up.

The behavioral verdict itself is not in question and there is no regression; the revision is to make the automated oracle agree with the host-state truth so E2E-08 passes through its own written rule.

---

### Finding-by-Finding Evaluation

#### [M1] Live PASS contradicts the E2E-08 oracle the same commit wrote; oracle reads a field the product never writes
- **Reviewer's Issue**: `isArchivedRow`/`analyzePruneEffect` (`e2e/native-e2e.ts:334-336,361-418`) detect archival via per-row `row.context_bonsai_v2.archived`, but the runtime (`src/lib/compact.ts:278-280,307-309`) sets a TOP-LEVEL `message.archived` per in-range row and hides rows via the marker file `~/.claude/archived-<sid>.json` — it never writes `context_bonsai_v2.archived` per row. The oracle therefore false-FAILs on every correct live prune; its unit test passes only because `e2e/native-e2e.test.ts` fixtures inject `context_bonsai_v2: { archived: true }` (the shape the product never produces). The recorded live verdict had to be grounded in host state instead of the oracle.
- **Verdict**: APPROVED (must fix)
- **Reasoning**: Independently verified at the code level:
  - `src/lib/compact.ts:278-280` and `:307-309` set `message.archived = true; message.archivedAt = ...; message.archivedBy = ...` (top-level), and `markMessagesArchived` calls `addArchivedMarkerEntries` (`:326`) to write the marker file. Nowhere is `context_bonsai_v2.archived` written per row.
  - `e2e/native-e2e.ts:334-336` `isArchivedRow` returns `row.context_bonsai_v2?.archived === true` — reading the field the product never writes. `analyzePruneEffect` uses it for both `archivedRangeVisiblePost` (`:378-381`) and `visibleFootprintChars` (`:349-357`), so on live data it concludes the range is "still visible" and the footprint "did not drop" → FAIL on correct behavior.
  - `e2e/native-e2e.test.ts:10,19` inject `context_bonsai_v2: { archived: true }`, which is why the unit PASS is hollow.
  - The reviewer's two supporting claims are both correct: (a) the live verdict is authoritative independent of the oracle — the evidence doc grounds Scenario 2 in the marker file listing the range UUIDs + placeholder and the model-visible input-token footprint drop (≈9018; 26704→17686 cache_read) plus a stock-binary cross-check, which is transform-EFFECT evidence, not a flag-based or recall oracle (the `NOT_IN_CONTEXT` recall is explicitly corroborating, not load-bearing); and (b) the developer did NOT let the oracle false-PASS — they detected the false-FAIL, disclosed it as harness debt in the evidence doc and commit, and reached the verdict from host state.
  - Why this is a must-fix in-story rather than a follow-up: the user resolved the Open Scope Decision as "(a) single story, hard live gate," and the story title/goal is literally "make prune success trustworthy." The deliverable includes a working automated gate (scenario E2E-08, which this same commit added to `docs/e2e-protocol.md`). An automated oracle that returns the wrong verdict on correct behavior — and whose inverse failure mode would false-PASS — is not a trustworthy gate; it is the exact "looked like it worked but didn't" failure class the story exists to eliminate, transplanted into the verification instrument. The fix is small and proportionate (point `isArchivedRow` + the footprint sum at the marker file and/or top-level `archived`; correct both fixture shapes; re-run so E2E-08 PASSes through its own oracle), so the cost does not justify deferring.
- **If Approved**: Correct `isArchivedRow` (and the `visibleFootprintChars` / `analyzePruneEffect` paths that depend on it, plus `protocol-a-oracle`'s per-row archived check) to recognize archival the way the product actually records it — the `~/.claude/archived-<sid>.json` marker file as the authoritative hidden-row set, and/or the top-level `message.archived` flag — rather than `context_bonsai_v2.archived`. Fix the `native-e2e.test.ts` fixtures to use the real product shape. Re-run `prune-effect`/`protocol-a-oracle` against the existing live pre/post snapshots (or equivalent fixtures matching the real shape) so E2E-08 reaches PASS through its own automated rule, and update the evidence doc's harness-oracle notes to reflect the corrected oracle. Keep the change scoped to the e2e harness + its test + the evidence doc; do not touch `src/lib/compact.ts` or the Defect A/B source.

#### [M2] Evidence doc's stated cause of the oracle bug is imprecise (omits the top-level `archived` stamping)
- **Reviewer's Issue**: The evidence doc says the runtime hides via marker file leaving rows in the JSONL, but omits that the runtime ALSO stamps top-level `archived`/`archivedAt`/`archivedBy` per in-range row (`src/lib/compact.ts:278,307`); the oracle simply read the wrong field name. Could misdirect the eventual fix.
- **Verdict**: APPROVED (should fix)
- **Reasoning**: Verified accurate — `src/lib/compact.ts:278-280,307-309` do stamp top-level `archived`/`archivedAt`/`archivedBy`. The evidence doc's harness-oracle notes (`:133-142,167-171`) describe only the marker-file mechanism and frame the oracle bug as "rows physically remain in the JSONL," which is true but incomplete: the more precise statement is that an archived row is identifiable by top-level `archived` and by the marker file, while the oracle reads a `context_bonsai_v2.archived` field that is never written. This is small and naturally folds into the M1 fix (correcting the oracle and re-documenting will resolve it), so it is a should-fix coupled to M1 rather than independent work.
- **If Approved**: When updating the evidence doc's harness-oracle notes as part of M1, state precisely that an archived row is recorded as top-level `message.archived` (plus the marker file), not `context_bonsai_v2.archived`.

#### [L1] `e2e/native-e2e.test.ts` (new file) not enumerated in the plan's Worktree Artifact Check
- **Reviewer's Issue**: The plan's Worktree Artifact Check listed `e2e/native-e2e.ts` to extend but did not enumerate the new colocated `e2e/native-e2e.test.ts`.
- **Verdict**: REJECTED (not valid as a defect)
- **Reasoning**: STANDARDS.md mandates colocated `*.test.ts` test files; adding a test alongside an extended source file is the required convention, not an unplanned artifact. The Worktree Artifact Check exists to detect cross-story file overlap/collision risk, and a brand-new test file in this story's own e2e directory carries no overlap risk. The reviewer themselves rated it benign and required no fix. No action.

---

### Loop/Conflict Detection

**Previous Iterations**: 0 (this is iteration 1).
**Recurring Issues**: none.
**Conflicts Detected**: none.
**Assessment**: First pass. The source fixes are strong; the single must-fix is a contained correctness defect in the verification harness, not in the product. No loop risk.

---

### Recommendations

**NEEDS REVISION** — the developer should address these approved items:

1. **[M1, must-fix]** Correct the e2e archival-detection oracle so it recognizes archival the way the product actually records it (the `~/.claude/archived-<sid>.json` marker file as the authoritative hidden-row set, and/or top-level `message.archived`), not the never-written `context_bonsai_v2.archived` per-row field. Fix `isArchivedRow` and the `visibleFootprintChars`/`analyzePruneEffect` paths and `protocol-a-oracle`; fix the `native-e2e.test.ts` fixtures to the real product shape; re-run the oracles against the existing live snapshots (or real-shape fixtures) so E2E-08 PASSes through its own automated rule. Scope to the e2e harness + its test + the evidence doc; do NOT modify the Defect A/B source.
2. **[M2, should-fix, folded into M1]** When updating the evidence doc's harness-oracle notes, state precisely that the runtime records archival as top-level `message.archived` (plus the marker file), not `context_bonsai_v2.archived`.

Focus ONLY on these. The behavioral verdict, Defect A source fix, Defect B source fix, spec clause, and all unit/integration tests are approved as-is and must not be reworked. The Defect A/B commits and the spec commit do not need to change. Do NOT address L1.

**Note on pin discipline:** The parent pin is still recorded at `bfb12e3` (the working-tree submodule has advanced to `7035701` but the parent index/HEAD has not been committed), and nothing is pushed — correct for a story still in review. Because this verdict is NEEDS REVISION, the pin should NOT be advanced yet; advance it in the judgment turn only once the revision lands and is re-judged APPROVED.

---

### Complexity Guard Notes

- Did NOT require any new abstraction, configuration, or generalization for the M1 fix — the correction is to read the field/file the product already writes, which is strictly less code-coupling than the current wrong-field read.
- Rejected L1 specifically to avoid treating a STANDARDS-required colocated test file as a planning deviation; enforcing artifact-list completeness for mandatory test files would be process overhead with no overlap-risk benefit.
- Did NOT approve any reviewer suggestion to rework the source fixes or re-run the live model-driven e2e; the behavioral evidence is authoritative and there is no product regression, so the live run need not be repeated for the source — only the offline oracle and its re-run against existing snapshots.
