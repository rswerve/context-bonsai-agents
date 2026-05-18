## Judge's Assessment

**Story**: 2 - tweakcc 4.0 foundation and apply harness
**Iteration**: 1 of 5 maximum
**Date**: 2026-05-17

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

- **Starting commit:** parent `ffeaac1695940bcbfb756afc28b222e83810749c`, submodule `a3c5c81c8b7c5b1e882a9c9f43fb31de8e37568e` (reviewer-verified)
- **Pre-existing failures (reviewer-reproduced):** `not itemized in supplied review report`: exact pre-existing failure set reproduced
- **HEAD results:** 3 pass / 2 fail
- **Regressions:** none
- **Regression gate:** clear

---

### Overall Verdict

**NEEDS REVISION**

The critical finding is valid, in scope, and proportionate. It breaks the story's explicit safe/reversible install requirement during a normal idempotent re-apply scenario, and the likely fix is small.

---

### Finding-by-Finding Evaluation

#### [C1] Re-running apply on an already-patched install overwrites the original backup with the patched binary
- **Reviewer's Issue**: `applyBonsai` backs up the installation before reading/classifying the content. On a second apply to an already-patched install, the existing backup can be overwritten with the patched executable, so `--restore` no longer returns to the stock install.
- **Verdict**: APPROVED (must fix)
- **Reasoning**: The issue exists in the implementation: `apply/apply-bonsai.ts` calls `backupFile` before `readContent` and before the `already-patched` early return. The test currently locks in this unsafe order by expecting `['detect', 'backup', 'read']` for already-patched installs. The tweakcc API implementation uses plain `copyFile`, so an existing backup path is clobbered. This directly conflicts with the story user need that a backup is always taken and `--restore` always works.
- **If Approved**: Preserve the first stock backup when the install is already patched. A minimal acceptable fix is to read/classify before calling `backupFile` and return for `already-patched` without backing up, while keeping backup-before-write for unpatched/reverted installs. Update the harness test so the already-patched path does not call backup.

---

### Loop/Conflict Detection

**Previous Iterations**: none for Story 2
**Recurring Issues**: none
**Conflicts Detected**: none
**Assessment**: This is the first review cycle and the approved fix is narrowly scoped.

---

### Recommendations

**If NEEDS REVISION:**
The developer should address these approved items:
1. Change the apply flow so already-patched installs do not overwrite an existing stock backup.
2. Update tests to assert the safe call order for already-patched installs.

Focus ONLY on approved items. Rejected items should NOT be addressed.

---

### Complexity Guard Notes

- No findings were rejected for over-engineering.
- Avoid broad backup-versioning or state-file schemes unless needed; the required behavior can be satisfied by preserving the original backup and skipping backup on the already-patched path.
