# Story: Semantic anchor revalidation for Claude Code 2.1.143

**Epic:** Re-implement Context Bonsai for Claude Code on tweakcc 4.0
**Size:** Medium
**Dependencies:** Stories 3, 4, 5, 6, plus the existing Story 8 blocked run record and mechanical artifact output. This is not a dependency on Story 8 completion: Story 8 final PASS/release-gate completion depends on this remediation. Story 9 may not document a verified install path until both Story 8A and Story 8 final PASS are complete.

## Story Description

Story 8 exposed that the current patch-anchor evidence is not trustworthy enough for release. The existing run record contains a `Pinned-target artifact evidence` PASS, but that PASS is mechanical: it records candidate counts, selected offsets/scores/snippets, and sentinel verification. It does not explain why each selected Claude Code location is the semantically correct behavior seam, why plausible nearby candidates are wrong, or what model-facing/runtime behavior proves the patch works.

This story transitions the epic to the corrected semantic-anchor contract. The implementer must inspect the real pinned Claude Code native `2.1.143` Linux x64 extracted bundle, document each chosen anchor's host-code behavior, reject plausible wrong anchors, and connect the static anchor choice to runtime/model-facing behavior. Temporary searches, scripts, and helper tools may be used during analysis, but they are not the authority. Synthetic fixtures remain useful only for helper mechanics; they are not acceptance evidence for Claude Code anchor correctness.

The output is a committed semantic-anchor analysis report plus harness/reporting changes that prevent future Story 8 evidence from being treated as release-ready without that analysis. Full live model e2e remains owned by Story 8 and is still blocked until fresh-sprite Claude Code login/provider access exists.

## User Model

### User Gamut

Examples only, spanning trust, maintenance, and review lifecycle:

- A maintainer deciding whether the Claude Code port can be shipped after a minified-host patch failure.
- A reviewer who must reject impressive-looking but semantically empty anchor evidence.
- A future contributor forward-porting to a new Claude Code release and needing a concrete example of acceptable anchor analysis.
- An operator who will trust the install only if release evidence proves actual model-facing behavior, not just binary patch insertion.

### User-Needs Gamut

Examples only:

- Trustworthy proof that each patch modifies the actual Claude Code behavior required by the spec.
- A clear distinction between helper/unit tests and release-gate evidence.
- A review artifact that explains anchor choices well enough for another agent to challenge them.
- No committed credentials, auth files, session transcripts, or proprietary full-bundle artifacts.

### Design Implications

- The semantic report is the source of truth for anchor correctness. `patches/anchors.ts` may mechanize those choices, but it does not prove them.
- Release-gate evidence must fail closed if the semantic report is absent or incomplete.
- Existing mechanical Story 8 artifact PASS must be explicitly reclassified as non-release evidence.
- Runtime/model-facing proof is required for final release readiness; JSONL-only or sentinel-only evidence is supporting evidence, not final proof.

## Acceptance Criteria

- [ ] A committed `tweakcc_context_bonsai/docs/semantic-anchor-analysis-2.1.143.md` exists and is tied to the pinned native Claude Code `2.1.143` Linux x64 extracted bundle by version, extraction tool/version, reproduction command or harness entry point, checksum, timestamp, and operator.
- [ ] The report includes exactly eight required evidence sections: `archived-filter.visibility`, `message-content-ids.converter`, `context-bonsai-gauge.token-usage`, `context-bonsai-gauge.attachment-pipeline`, `context-bonsai-gauge.reminder-render`, `runtime-helper.fs`, `runtime-helper.config-dir`, and `runtime-helper.session-id`.
- [ ] Each required evidence section contains these labeled fields: `Anchor ID`, `Patch or helper`, `Pinned artifact identity`, `Selected offset and snippet`, `Host behavior controlled`, `Required seam rationale`, `Plausible wrong candidates rejected`, `Ambiguous/no-match fail-closed evidence`, `Runtime or model-facing evidence`, and `Reviewer checklist`.
- [ ] The report explicitly reclassifies the existing Story 8 `Pinned-target artifact evidence` PASS as mechanical locator evidence only, not release-gate acceptance evidence.
- [ ] For `archived-filter`, the report identifies the actual provider-bound transcript visibility seam, explains why it controls messages sent to the model, lists plausible similar `switch(type)` candidates that are not the seam, and records behavior evidence that archived messages are omitted from provider-bound context.
- [ ] For `message-content-ids`, the report identifies the actual provider-bound message-content construction seam, explains why it affects model-visible content, lists plausible similar converters that are wrong, and records behavior evidence that `[msg:<uuid>]` tags appear only under the compaction-mode marker.
- [ ] For `context-bonsai-gauge`, the report identifies the actual token/gauge, attachment, and model-visible reminder seams, explains why each affects model-visible behavior, lists plausible wrong token/attachment/reminder candidates, and records behavior evidence that gauge/reminder text reaches model context.
- [ ] For runtime helpers, the report identifies the `fs`, config-dir, and session-id helpers semantically, explains why plausible similar functions are wrong, and records ambiguity/no-match fail-closed behavior.
- [ ] `tweakcc_context_bonsai/e2e/native-e2e.ts` or its evidence output is updated so `artifact-evidence` fails closed or marks itself non-release-ready unless the semantic-anchor analysis report is present and complete.
- [ ] `patches/anchors.ts` is documented or adjusted so it is an implementation of documented anchor choices, not the trusted source of proof. If this requires code simplification or comments, keep the change minimal.
- [ ] Synthetic fixture tests are retained only as helper-mechanics tests or renamed/reworded to avoid implying they prove Claude Code anchor correctness.
- [ ] Pinned native apply and artifact evidence are rerun after the report/harness update; release evidence may PASS only if it links to the semantic report and still excludes credentials, auth files, session transcripts, and full extracted bundle content unless explicitly approved.
- [ ] Story 8A evidence distinguishes acceptable tiers: pinned extracted-bundle semantic analysis plus artifact harness proof is required for this remediation; JSONL, sentinels, candidate counts, scores, and synthetic fixtures are supporting evidence only; live provider/model proof remains Story 8.
- [ ] Story 8 remains BLOCKED, not PASS, until fresh-sprite Claude Code login enables the live model scenarios and Protocol A.
- [ ] `bun run typecheck` and `bun test` pass in `tweakcc_context_bonsai/`.

## Context References

### Relevant Codebase Files (must read)

- `docs/context-bonsai-agent-spec.md:309` - semantic anchor discovery requirement.
- `docs/agent-specs/claude-code-context-bonsai-spec.md:96` - Claude Code-specific anchor evidence requirements.
- `.agents/plans/epic-cc-bonsai-tweakcc4/epic-cc-bonsai-tweakcc4.md:60` - Target Release And Artifact Contract.
- `tweakcc_context_bonsai/docs/e2e-results-2026-05-18-story8.md` - current mechanical PASS and prior FAIL evidence to reclassify.
- `tweakcc_context_bonsai/e2e/native-e2e.ts` - artifact evidence harness to gate on semantic analysis.
- `tweakcc_context_bonsai/patches/anchors.ts` - current mechanized anchor location helpers.
- `tweakcc_context_bonsai/patches/archived-filter.patch.ts`, `message-content-ids.patch.ts`, `context-bonsai-gauge.patch.ts` - patch modules whose anchors need semantic analysis.

### New Files to Create

- `tweakcc_context_bonsai/docs/semantic-anchor-analysis-2.1.143.md` - committed semantic analysis report.

### Report Schema

The semantic analysis report must contain these top-level sections:

1. `Pinned Artifact Identity` - Claude Code version, platform/install kind, extraction tool/version, reproduction command or harness entry point, extracted bundle checksum, timestamp, operator, and credential boundary statement.
2. `Current Story 8 Evidence Reclassification` - states that the previous `Pinned-target artifact evidence` PASS is mechanical locator evidence only and is not release-gate acceptance evidence.
3. `Evidence Tier Boundary` - states that pinned extracted-bundle semantic analysis plus artifact harness proof is required for Story 8A; JSONL, sentinel, candidate-count, score, and synthetic-fixture evidence is supporting only; live provider/model proof remains Story 8.
4. One section for each required anchor/helper ID: `archived-filter.visibility`, `message-content-ids.converter`, `context-bonsai-gauge.token-usage`, `context-bonsai-gauge.attachment-pipeline`, `context-bonsai-gauge.reminder-render`, `runtime-helper.fs`, `runtime-helper.config-dir`, `runtime-helper.session-id`.

Each anchor/helper section must include these exact field labels:

- `Anchor ID`
- `Patch or helper`
- `Pinned artifact identity`
- `Selected offset and snippet`
- `Host behavior controlled`
- `Required seam rationale`
- `Plausible wrong candidates rejected`
- `Ambiguous/no-match fail-closed evidence`
- `Runtime or model-facing evidence`
- `Reviewer checklist`

The `Plausible wrong candidates rejected` field must name at least one plausible wrong candidate for every patch anchor. For runtime helpers, it must name plausible helper-like functions or explain why none were present after inspecting the pinned artifact. Empty boilerplate is not acceptable.

### Relevant Documentation

- `.llm-conductor/planning_guidance.md` "Semantic Discovery For Host Internals".
- `docs/context-bonsai-agent-spec.md` "Policy and Safety Constraints" and "Evidence Expectations".
- Story 8 plan and run records.

## Implementation Plan

### Phase 1: Foundation

- Confirm the pinned target artifact source: `tweakcc_context_bonsai/.artifacts/claude-code/2.1.143/linux-x64/extracted.js` or a fresh sprite-generated extract using the documented Story 8 harness. Do not commit the full extracted bundle unless explicitly approved.
- Read current patch modules, `anchors.ts`, `native-e2e.ts`, and Story 8 run records.
- Create the semantic report skeleton with one required checklist per anchor/helper.

### Phase 2: Semantic Anchor Analysis

- Inspect the real pinned extracted bundle. Temporary scripts/searches are allowed, but the report must explain behavior, not just tool output.
- For each patch anchor/helper, record selected location evidence, surrounding semantic context, why it is the required seam, plausible wrong candidates and why they are wrong, fail-closed ambiguity/no-match behavior, and runtime/model-facing proof.
- Explicitly reclassify the existing Story 8 mechanical artifact PASS as non-release evidence.

### Phase 3: Harness And Code Alignment

- Update `native-e2e.ts` so artifact evidence validates the semantic report's required section IDs and field labels, or clearly reports non-release-ready status.
- Add minimal comments or adjustments to `patches/anchors.ts` clarifying that it mechanizes documented anchor choices and is not proof by itself.
- Rename or reword synthetic fixture tests if needed so they are helper-mechanics tests, not acceptance evidence.

### Phase 4: Testing And Validation

- Rerun pinned native apply and artifact evidence after the semantic report/harness update.
- Run side-repo validation commands.
- Record Story 8 state as BLOCKED unless live model scenarios and Protocol A actually run on a logged-in fresh sprite.

## Step-by-Step Tasks

1. Read the required specs, epic contract, current patch modules, `anchors.ts`, `native-e2e.ts`, and Story 8 run records.
2. Produce or locate the pinned native `2.1.143` extracted bundle through the approved artifact path or fresh sprite harness.
3. Create `tweakcc_context_bonsai/docs/semantic-anchor-analysis-2.1.143.md` with the required schema.
4. Analyze and document `archived-filter` provider-bound transcript visibility anchor and plausible wrong candidates.
5. Analyze and document `message-content-ids` provider-bound message-content construction anchor and plausible wrong candidates.
6. Analyze and document all three `context-bonsai-gauge` anchors and plausible wrong candidates.
7. Analyze and document `fs`, config-dir, and session-id helper discovery and plausible wrong candidates.
8. Update `native-e2e.ts` so `artifact-evidence` cannot be mistaken for release evidence without a complete semantic report; the command must check the required eight section IDs and field labels.
9. Add minimal comments or wording changes around `anchors.ts`/tests to demote synthetic fixtures to helper-mechanics coverage only.
10. Rerun pinned artifact evidence and side-repo validation, then update the Story 8 run record with PASS/BLOCKED/FAIL language that matches the evidence.

## Testing Strategy

- Static semantic evidence: committed report tied to pinned target checksum and selected snippets/offsets, without committing credentials, transcripts, auth/config, or the full extracted bundle.
- Negative semantic evidence: plausible wrong candidates are named and rejected by behavior, not only by score.
- Runtime/model-facing evidence: patch behavior is demonstrated on the pinned target where possible; full live model scenarios remain Story 8 and are BLOCKED without fresh-sprite login.
- Helper tests remain useful, but are explicitly not acceptance evidence for anchor correctness.

## Validation Commands

- `cd tweakcc_context_bonsai && bun run typecheck`
- `cd tweakcc_context_bonsai && bun test`
- `cd tweakcc_context_bonsai && bun run e2e/native-e2e.ts artifact-evidence --out .agent_tmp/semantic-anchor-artifact-evidence.json`
- `cd tweakcc_context_bonsai && bun run e2e/native-e2e.ts artifact-evidence --bundle .artifacts/claude-code/2.1.143/linux-x64/extracted.js --manifest .artifacts/claude-code/2.1.143/linux-x64/manifest.json --out .agent_tmp/semantic-anchor-artifact-evidence.json`
- `grep -niE 'mechanical locator evidence|not release-gate|semantic anchor|plausible wrong|provider-bound|model-visible' tweakcc_context_bonsai/docs/semantic-anchor-analysis-2.1.143.md tweakcc_context_bonsai/docs/e2e-results-2026-05-18-story8.md`
- `grep -nE 'Anchor ID|Patch or helper|Pinned artifact identity|Selected offset and snippet|Host behavior controlled|Required seam rationale|Plausible wrong candidates rejected|Ambiguous/no-match fail-closed evidence|Runtime or model-facing evidence|Reviewer checklist' tweakcc_context_bonsai/docs/semantic-anchor-analysis-2.1.143.md`

## Worktree Artifact Check

- Checked At: `2026-05-19T00:00:00Z`
- Planned Target Files: `tweakcc_context_bonsai/docs/semantic-anchor-analysis-2.1.143.md`, `tweakcc_context_bonsai/e2e/native-e2e.ts`, `tweakcc_context_bonsai/patches/anchors.ts`, `tweakcc_context_bonsai/docs/e2e-results-2026-05-18-story8.md`, `tweakcc_context_bonsai/patches/anchors.test.ts`, `tweakcc_context_bonsai/patches/discovery.test.ts`, `tweakcc_context_bonsai/patches/archived-filter.patch.test.ts`, `tweakcc_context_bonsai/patches/message-content-ids.patch.test.ts`, `tweakcc_context_bonsai/patches/context-bonsai-gauge.patch.test.ts`
- Overlaps Found (path + class): `none` from `git status --porcelain=v1` in the isolated worktree at plan creation; new analysis file absent.
- Escalation Status: `none`
- Decision Citation: `none`

## Plan Approval and Commit Status

- Approval Status: `approved`
- Approval Citation: `User request: "Yes. Use planning_guidance.md to make that plan" (2026-05-19)`
- Plan Commit Hash: `0180107ee6b0321ea57eded71e6e99690a81f767`
- Ready-for-Orchestration: `yes`

## Completion Checklist

- [ ] All acceptance criteria met
- [ ] Validation commands pass or are explicitly BLOCKED with safe reason
- [ ] Plan approved and committed before orchestration begins
- [ ] User-model ambiguities resolved or escalated
- [ ] Worktree artifact overlaps resolved (approved direction or explicit deferral)
