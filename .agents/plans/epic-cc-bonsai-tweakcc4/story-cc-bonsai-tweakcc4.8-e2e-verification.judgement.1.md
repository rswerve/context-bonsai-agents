## Judge's Assessment

**Story**: 8 - End-to-end verification for native Claude Code
**Iteration**: 1 of 5 maximum
**Date**: 2026-05-18

---

### Summary

| Verdict | Count |
|---------|-------|
| APPROVED (must fix) | 1 |
| APPROVED (should fix) | 0 |
| REJECTED (over-engineering) | 0 |
| REJECTED (out of scope) | 0 |
| REJECTED (not valid) | 0 |

### Verified Validation Results

- **Starting commit:** parent `ca76683d0e32c8b9c7162d8bbde82c96776b5694`, side repo `3a11284dcdbfc2604608e244c5b6030d530ac5e0` (reviewer-verified)
- **Pre-existing failures (reviewer-reproduced):** none reported
- **HEAD results:** 0 / 2 release-gate checks passed; `E2E-00 Clean install procedure` failed and `Pinned-target artifact evidence` failed, with downstream Story 8 scenarios blocked by the failed native patch apply
- **Regressions:** none reported
- **Regression gate:** clear

---

### Overall Verdict

**NEEDS REVISION**

C1 is valid and release-blocking. Story 8 correctly recorded an honest pinned-native release-gate failure, so this is not a Story 8 harness or evidence-integrity defect; it is an underlying Story 3/4 discovery and archived-filter implementation failure discovered by Story 8.

---

### Finding-by-Finding Evaluation

#### [C1] Epic release gate fails on pinned native Claude Code
- **Reviewer's Issue**: The Story 8 run failed against native Claude Code `2.1.143`: `bun run apply` could not apply `archived-filter` because session-id helper discovery failed, and pinned-target artifact evidence also failed with an ambiguous visibility-switch anchor.
- **Verdict**: APPROVED
- **Reasoning**: The issue is supported by the committed run record. Story 8 acceptance requires a full PASS release gate on native Claude Code `2.1.143`, including clean install and pinned-target artifact evidence. The recorded FAIL means the epic is not shippable, and the failures map directly to the Story 3 discovery contract and Story 4 archived-filter patch contract.
- **If Approved**: Fix the underlying side-repo patch implementation, not just the Story 8 evidence. The next developer should update Story 3/4 code so native Claude Code `2.1.143` can uniquely resolve the session-id getter and the archived-filter visibility-switch anchor, with fail-closed behavior preserved. After that, rerun Story 8 from a fresh sprite and replace the failure evidence only with real PASS evidence from the rerun.

---

### Loop/Conflict Detection

**Previous Iterations**: none for Story 8
**Recurring Issues**: none detected in this Story 8 review cycle
**Conflicts Detected**: none
**Assessment**: This is a healthy review result. The e2e story exposed a real integration failure before release, and the fix should be routed to the implementation layer that owns anchor/runtime-helper discovery.

---

### Recommendations

The developer should address these approved items:

1. Touch Story 3/4 side-repo code: improve `patches/discovery.ts` runtime-helper discovery for Claude Code native `2.1.143`, especially `sessionIdFunc` resolution.
2. Touch Story 3/4 side-repo code: improve `archived-filter` anchor disambiguation so the intended model-visible transcript switch is selected uniquely on the pinned native bundle, without weakening fail-closed ambiguity checks.
3. Add or update deterministic verification around the pinned native extracted bundle or equivalent fixture/hook so the helper and anchor selections are reproducible.
4. Rerun Story 8 from a fresh sprite after the code fix. Only then update Story 8 evidence to record the new run result.

Focus ONLY on approved items. Do not edit Story 8 evidence to change verdicts without a real rerun, and do not treat downstream blocked scenarios as separate defects until native patch application and artifact evidence pass.

---

### Complexity Guard Notes

- No reviewer recommendations were rejected for over-engineering.
- The required fix should remain narrow: make the existing discovery and archived-filter patch resilient for the pinned native target rather than introducing a new patching architecture or bypassing the fail-closed contract.
