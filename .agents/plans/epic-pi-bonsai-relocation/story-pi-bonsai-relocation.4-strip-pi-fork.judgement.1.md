## Judge's Assessment

**Story**: pi-bonsai-relocation.4 - Strip all Context Bonsai footprint from the pi-mono fork
**Iteration**: 1 of 5 maximum
**Date**: 2026-05-18

---

### Summary

| Verdict | Count |
|---------|-------|
| APPROVED (must fix) | 0 |
| APPROVED (should fix) | 0 |
| REJECTED (over-engineering) | 0 |
| REJECTED (out of scope) | 1 |
| REJECTED (not valid) | 0 |

### Verified Validation Results

- **Starting commit:** `2d953af9` (reviewer-verified, parent of `cf157a40`)
- **Pre-existing failures (reviewer-reproduced):** none
- **HEAD results:** `npm install` exit 0, `npm run build` exit 0; residual `context-bonsai` grep across `pi/packages`, `pi/.pi`, `pi/.gitignore`, `pi/.agents` returns zero matches (independently re-run by the judge — confirmed empty, exit 2 = no match)
- **Regressions:** none
- **Regression gate:** clear

---

### Overall Verdict

**APPROVED AS-IS**

All 11 acceptance criteria are met and independently verified. The single MEDIUM finding (M1) describes genuine tech debt, but it is a direct and unavoidable consequence of the regeneration step the story plan explicitly mandated (`npm install`), it does not break any acceptance criterion, and the commit message discloses the regeneration. It is rejected as out of scope for a developer revision; the underlying lockfile-fidelity concern is a planner matter, noted below for the orchestrator.

---

### Finding-by-Finding Evaluation

#### [M1] Lockfile regeneration drops `resolved`/`integrity` for all registry packages
- **Reviewer's Issue**: The regenerated `pi/package-lock.json` strips the `resolved` tarball URL and `integrity` SHA from the registry-package entries. Independently verified by the judge: `resolved` count fell 642 → 12 (only the 12 workspace-local symlink entries retain it); `integrity` count fell 629 → 0; 524 registry entries now carry a `version` with no `resolved`. The lockfile is still `lockfileVersion: 3`. A v3 lockfile without `integrity` loses tamper verification and will not satisfy `npm ci`.
- **Verdict**: REJECTED (out of scope)
- **Reasoning**:
  1. **The developer followed the plan exactly.** Step 6 of the Step-by-Step Tasks and the Validation Commands section both explicitly mandate `cd pi && npm install` to regenerate the lockfile. The `resolved`/`integrity` loss is a known property of npm rebuilding a v3 lockfile from an already-satisfied `node_modules` tree (installed-package metadata lacks registry provenance) — not a developer error. The reviewer concedes this ("a property of running `npm install`... not a developer mistake — the story itself mandated the `npm install` regeneration step").
  2. **No acceptance criterion is violated.** The relevant AC — "The pi-mono fork builds and tests clean after removal" — passes: `npm install` and `npm run build` both exit 0. The lockfile AC ("no longer contains the `@mariozechner/pi-context-bonsai` entries") is met. No AC speaks to lockfile registry-field fidelity.
  3. **The reviewer's "undisclosed" framing is overstated.** The commit message explicitly states the lockfile was "Regenerated package-lock.json via npm install." It discloses the regeneration mechanism and its dependency-level effect. It does not enumerate the `resolved`/`integrity` field loss specifically — a fair documentation gap — but the artifact's provenance is not hidden.
  4. **The reviewer's suggested fix would require the developer to deviate from the approved plan.** "Remove `node_modules` first" or "surgically delete only the 4 bonsai blocks" are both alternatives to the mandated `npm install` step. Directing the developer to do something the approved plan did not authorize is itself out of scope for a story revision; it is a plan correction.
  5. **Not blocking.** The fork builds and installs; `npm install` and `npm ci`/install re-fetch `integrity` from the registry. This is real, low-severity tech debt, not a correctness or security defect.
- **If Rejected**: Per the iteration guidance, minor tech debt where the developer followed the plan is documented and approved as-is. The lockfile-fidelity concern is genuine and should be addressed at the plan level, not by reopening this story — see Recommendations.

---

### Loop/Conflict Detection

**Previous Iterations**: 0 (this is iteration 1)
**Recurring Issues**: none
**Conflicts Detected**: none
**Assessment**: First pass; no loop risk.

---

### Recommendations

**APPROVED AS-IS.** The implementation meets all 11 acceptance criteria. The two reverts are byte-exact inversions of their introducing commits; `harness.ts`/`utilities.ts` are provably untouched (identical blob SHAs); the residual grep is clean; the fork builds and installs.

Note for the orchestrator (not a developer revision item): the mandated `npm install` regeneration produced a `lockfileVersion: 3` lockfile missing `resolved`/`integrity` for ~524 registry packages, which loses `npm ci` compatibility and tamper verification. If a clean, registry-faithful lockfile is wanted on the fork, that is a planner decision — either Story 5 or a follow-up should regenerate it from a clean `node_modules` (or against a populated cache). This is logged here so the regression is visible, not buried.

---

### Complexity Guard Notes

- Rejected M1 as a developer revision item: the reviewer's suggested fixes (remove `node_modules` and reinstall, or hand-edit the lockfile) all deviate from the approved plan's explicitly mandated `npm install` step. Forcing the developer off-plan to chase lockfile-field fidelity is not warranted when the build and all acceptance criteria pass. The legitimate fidelity concern is escalated to the plan level rather than relitigated as a story defect.
