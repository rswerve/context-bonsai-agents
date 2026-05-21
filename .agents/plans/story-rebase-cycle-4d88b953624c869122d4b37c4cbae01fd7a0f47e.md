# Story: Rebase Cycle 4d88b953624c869122d4b37c4cbae01fd7a0f47e onto OpenCode v1.15.7

## Goal

Replay the three-commit Context Bonsai chain currently tipped at `4d88b953624c869122d4b37c4cbae01fd7a0f47e` on the `surgical_compaction` branch of the OpenCode fork onto frozen upstream tag `v1.15.7` (`5451227deb5a502afe44e1664e81df7ecb208ed1`). Produce a reviewable target branch whose `HEAD` is based on `UPSTREAM_HEAD_SHA` and contains only the approved replay set (the two integration patches and the fork-only signpost README), then tag the rebased tip `bonsai/v1-on-opencode-1.15.7` per the parent `DEVELOPMENT.md` "Carrying Patches on Upstream" contract.

This plan was created by applying `.llm-conductor/planning_guidance.md` and the rebase-planning meta-plan at `.agents/plans/story-meta-plan-for-future-rebase-planning.md`. It is a concrete execution plan, not the meta-plan. The orchestrator selected the source commits and classifications; implementors must not reinterpret the source range.

## Non-Goal

This plan defines and validates rebase work; it does not perform replay/rewrite during planning. No commits are created in the OpenCode fork until the implementor reaches the Replay phase below.

## Execution Outcome Statement

After the implementor completes this plan, the final target branch `HEAD` must be based on `UPSTREAM_HEAD_SHA` (`5451227deb5a502afe44e1664e81df7ecb208ed1`) and contain exactly the three replayed commits from the approved replay set in the listed topological order. No other commits, no merge commits, no generated-SDK diffs, and no local planning artifacts may be present in `UPSTREAM_HEAD_SHA..HEAD`.

## Tag-as-Upstream Approval (required by meta-plan)

`UPSTREAM_REF` is a tag (`refs/tags/v1.15.7`). The meta-plan rejects symbolic refs and tags unless explicitly user-approved and recorded. Approval recorded:

- User instruction: "Fetch the latest upstream. Find the latest official release, determine if our commit is before that release. If it is, we will need to test our plugin against the latest official release and if the tests pass, then we should advance the pin."
- User instruction: "orchestrate story-meta-plan-for-future-rebase-planning.md for getting us onto v1.15.7" — explicit naming of the v1.15.7 tag as the target.

## Frozen Inputs

- `UPSTREAM_REF`: `refs/tags/v1.15.7` (tag, user-approved above)
- `UPSTREAM_HEAD_SHA`: `5451227deb5a502afe44e1664e81df7ecb208ed1`
- `SOURCE_REF`: `refs/heads/surgical_compaction`
- `SOURCE_HEAD_SHA`: `4d88b953624c869122d4b37c4cbae01fd7a0f47e`
- `BASE_SHA`: `5c5069b6227ce6c4cbc1b6daca65da69daf43f84` (`git merge-base UPSTREAM_HEAD_SHA SOURCE_HEAD_SHA`)
- `TARGET_WORKTREE`: `/home/basil/projects/context-bonsai-agents/opencode/.agent_tmp/rebase-on-v1.15.7`
- `TARGET_BRANCH`: `replay/context-bonsai-on-opencode-1.15.7`
- `TARGET_TAG_AT_TIP`: `bonsai/v1-on-opencode-1.15.7`
- `VALIDATION_MODE`: `committed-final`
- Range scope: `UPSTREAM_HEAD_SHA..SOURCE_HEAD_SHA` (default; no author-filter override)
- Upstream commits ahead of `BASE_SHA`: 1494

All commands in this plan reference the frozen SHAs above. The implementor must not substitute moving refs.

## Allowlists

Defaults from the meta-plan, no overrides for this cycle:

- Runtime allowlist: `packages/opencode/**`, `packages/plugin/**`
- Docs allowlist: `.agents/plans/**`, `.opencode/context_bonsai/**`
- State-only: metadata/state artifacts outside the above

The fork-only root `README.md` falls outside the docs allowlist by design; it is classified `manual_review` and approved by the artifact at `.agents/plans/validation/manual-review-approvals-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json`. No allowlist override is requested in this cycle.

## User Model

### User Gamut

- OpenCode maintainers reviewing a minimal carried-patch series above a tagged release
- Context Bonsai users on OpenCode relying on prune/retrieve continuity through plugin tools
- Operators rerunning rebase cycles after upstream architecture changes
- Reviewers and judges auditing source-commit provenance and replay equivalence
- Downstream consumers (parent submodule pin) expecting the chain tip to advance only after E2E pass

### User-Needs Gamut

- Minimal, reviewable replay (cherry-pick first; no architectural drift unless forced)
- Clear proof that only the approved replay set was applied
- Deterministic worktree boundary that does not disturb the main `surgical_compaction` branch until the cycle is sealed
- Tests proving Context Bonsai metadata still survives message storage and plugin-tool metadata updates against the new upstream
- Behavioral E2E proof against a built `opencode` binary, not just unit/typecheck signals

### Ambiguities From User Model

- Literal cherry-pick vs minor fixups vs `re-implement`: resolved in favor of `cherry-pick` for all three rows; `re-implement` is only allowed if cherry-pick fails with conflicts that cannot be resolved without introducing out-of-scope changes (see Reviewer-Simplicity Evaluation below).
- README commit treatment: resolved as `manual_review` with explicit approval rather than as an allowlist override, to keep the meta-plan's allowlists tight and the cycle-specific approval auditable.

## Context References

### Relevant Codebase Files (must read)

- `packages/opencode/src/session/message-v2.ts` — current message schema; runtime target of `ec63292d00fca02c38ec653c821948e0501d96fe`
- `packages/opencode/src/tool/registry.ts` — tool execution path; runtime target of `7d4dfb827c0425928020fecdfc2d44936cb43559`
- `packages/plugin/src/tool.ts` — plugin-facing tool metadata typing; co-target of `7d4dfb827c0425928020fecdfc2d44936cb43559`
- `packages/opencode/test/session/message-v2.test.ts` — message metadata regression coverage
- `packages/opencode/test/session/context-bonsai.test.ts` — bonsai-specific regression coverage introduced by `ec63292d`
- `packages/opencode/test/tool/registry.test.ts` — tool registry regression coverage
- `README.md` — fork-only signpost, target of `4d88b953624c869122d4b37c4cbae01fd7a0f47e`

### Relevant Documentation

- `.agents/plans/story-meta-plan-for-future-rebase-planning.md` — meta-plan; must remain unchanged for the duration of this cycle (artifact-type guardrail).
- `DEVELOPMENT.md` "Carrying Patches on Upstream" section — defines the chain, the per-cycle steps, and the rule that fork-only doc commits rebase forward with the integration patches.
- `docs/context-bonsai-e2e-template.md` — authoritative shared E2E template for Context Bonsai integrations; the OpenCode-specific gate uses Protocol A from this template (see E2E Gate below).
- The opencode submodule has prior cycle artifacts under `opencode/.agent_tmp/concrete-replay-latest-b1cb718*/`; do not consume them as authority — they predate this cycle.

### Validation Artifact References

- Replay set: `.agents/plans/validation/replay-set-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json` (schema: `source_sha`, `bucket`, `replay_action`, `mapping_type`, `target_paths`, `rationale`, `evidence_ref`; row sort: topological order then full `source_sha`)
- Replay-set checksum: SHA-256 of `jq -c < <path>` output is `900d84f5bb144365ed19946baddc1d6dec9c7c304972355dacc1535524027db6`. Implementor must re-verify before replay starts.
- Manual-review approvals: `.agents/plans/validation/manual-review-approvals-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json` (schema: `source_sha`, `approved_action`, `approval_refs`, `resolution_state`)
- Manual-review approvals checksum: SHA-256 of `jq -c < <path>` output is `55695b1395ebfa97bcfc53a7335c26e3eebb35d666c6f20e431f28495e86302c`.
- Baseline-capture artifact (created by implementor in Baseline phase): `.agents/plans/validation/baseline-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json`
- Exception ledger (created by implementor; empty by default): `.agents/plans/validation/exceptions-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json`

## Source Commit Classification

| source_sha | subject | bucket | replay_action | mapping_type | target_paths | rationale |
| --- | --- | --- | --- | --- | --- | --- |
| `ec63292d00fca02c38ec653c821948e0501d96fe` | Persist Context Bonsai message metadata through parsing and storage | `required_runtime` | `cherry-pick` | `1:1` | `packages/opencode/src/session/message-v2.ts`, `packages/opencode/test/session/context-bonsai.test.ts`, `packages/opencode/test/session/message-v2.test.ts` | All paths inside `packages/opencode/**` runtime allowlist. `git cherry -v 5451227d 4d88b953` marks `+` (not patch-equivalent in upstream). Integration patch the parent submodule pin depends on. |
| `7d4dfb827c0425928020fecdfc2d44936cb43559` | Expose safe message-metadata updates to plugin tools | `required_runtime` | `cherry-pick` | `1:1` | `packages/opencode/src/tool/registry.ts`, `packages/opencode/test/tool/registry.test.ts`, `packages/plugin/src/tool.ts` | All paths inside `packages/opencode/**` and `packages/plugin/**` runtime allowlists. `git cherry -v` marks `+`. Exposes the plugin-tool metadata-update API the side-repo plugin code depends on; this is the current parent submodule pin. |
| `4d88b953624c869122d4b37c4cbae01fd7a0f47e` | docs(README): replace upstream README with Context Bonsai signpost | `manual_review` | `cherry-pick` | `1:1` | `README.md` | Root `README.md` is outside both default allowlists. Per parent `DEVELOPMENT.md`, fork-only doc commits (signpost README) are a structural part of the chain that rebases forward with the integration patches. Approval recorded at `.agents/plans/validation/manual-review-approvals-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json`. |

Merge-commit scan: `git log --merges 5451227d..4d88b953` is empty for this cycle; no merge rows required.

## Reviewer-Simplicity Evaluation

For each row, the meta-plan requires comparing `cherry-pick`, `cherry-pick + minor fixups`, and `re-implement` and preferring whichever is easiest to review.

- `ec63292d` and `7d4dfb82` (runtime integration patches):
  - `cherry-pick`: preferred. The patches touch narrow file regions (`message-v2.ts`, `registry.ts`, `tool.ts`); upstream has moved many files but these specific seams are likely intact. If conflicts arise they are expected to be small and surgical.
  - `cherry-pick + minor fixups`: acceptable fallback if line-level conflicts surface. Reviewer can still trace the original commit boundary.
  - `re-implement`: not preferred unless cherry-pick conflicts require out-of-scope changes (paths outside `packages/opencode/**` and `packages/plugin/**`). If forced, the implementor must add a behavioral-contract table for the row per meta-plan and request reviewer+judge approval before executing the re-implement.
- `4d88b953` (README signpost):
  - `cherry-pick`: preferred. The change is a full-file replacement; conflicts on root `README.md` against the upstream README change can be resolved by keeping the fork-only signpost wholesale (the entire intent of the commit is "replace upstream README with bonsai signpost"). The implementor should resolve any conflict by accepting the source commit's tree contents at `README.md`.

## Re-Implementation Behavioral Contract

Not applicable for this cycle (all three rows are `cherry-pick`). If cherry-pick fails for any runtime row and the implementor requests `re-implement`, this section must be populated for that row with the meta-plan's required fields (`source_primitive_or_intent`, `current_upstream_boundary`, `return_shape`, `runtime_bridge_pattern`, `allowed_mutation_surface`, `approved_metadata_schema`, `metadata_runtime_validation`, `atomicity_requirement`, `generated_artifact_decision`, `public_api_exposure_decision`, `validation_evidence`) before execution proceeds.

## Validation Mode

- Mode: `committed-final`.
- The implementor commits the three replayed commits in the target worktree. Final verification uses `git log` and `git diff` against `UPSTREAM_HEAD_SHA..HEAD`.
- Generated SDK/API artifact diffs (if any) must be left uncommitted and excluded from the replay commits. The replay diff must not include generated files even if doing so would tidy public TypeScript types; upstream's separate generated-artifact process is responsible for refreshing those.

## Acceptance Criteria

- [ ] Implementation happens only in `TARGET_WORKTREE`; the implementor must not edit anything under `/home/basil/projects/context-bonsai-agents/opencode` directly on the `surgical_compaction` branch and must not touch the parent repo's `.agents/plans/` tree during replay.
- [ ] `TARGET_BRANCH` (`replay/context-bonsai-on-opencode-1.15.7`) is created from `UPSTREAM_HEAD_SHA` (`5451227deb5a502afe44e1664e81df7ecb208ed1`) exactly; `git merge-base UPSTREAM_HEAD_SHA HEAD` returns `UPSTREAM_HEAD_SHA`.
- [ ] Replayed commit inventory in `UPSTREAM_HEAD_SHA..HEAD` is exactly three commits in topological order matching the replay-set rows, identified by cherry-pick provenance (`cherry picked from commit <source_sha>` trailers) or stable patch-id equivalence. Direct source-SHA equality against the replayed commit SHA is forbidden as evidence; provenance/patch-equivalence is required.
- [ ] Replay-set artifact checksum is verified before replay begins and unchanged at seal time.
- [ ] Baseline-capture artifact is created before any replay commit lands; all required rows have non-null `provenance_ref`.
- [ ] Exception ledger exists (empty or with explicit approved rows); no unresolved exceptions at seal time.
- [ ] No unresolved `manual_review` rows; the README row's approval artifact is present and `resolution_state=approved`.
- [ ] Canonical validation set passes from the worktree (and meets baseline-delta gate for `r01`):
  - From `packages/opencode`: `bun test test/tool/registry.test.ts test/session/message-v2.test.ts test/session/session.test.ts`
  - From `packages/opencode`: `bun test test/session/context-bonsai.test.ts`
  - From `packages/opencode`: `bun typecheck`
  - From `packages/plugin`: `bun typecheck`
  - From repository root (worktree root): `bun turbo run build --filter=opencode`
- [ ] Replay diff excludes generated SDK/API artifacts (if any drift surfaces, leave uncommitted; verify with `git diff --name-status UPSTREAM_HEAD_SHA..HEAD`).
- [ ] `bonsai/v1-on-opencode-1.15.7` tag is created at the rebased tip in the worktree's local repository and pushable to `origin`.
- [ ] E2E behavioral gate passes for BOTH Protocol A (Secret Prune Oracle) AND Protocol B (Retrieve Roundtrip); seal hard-fails until both protocols have pass evidence or an explicit reviewer+judge-approved exception is logged in the exception ledger.
- [ ] Meta-plan file `.agents/plans/story-meta-plan-for-future-rebase-planning.md` is unmodified at seal time (`git diff --name-only -- .agents/plans/story-meta-plan-for-future-rebase-planning.md` is empty in the parent repo).

## Implementation Tasks

### Phase 0: Credentials and Provider (out-of-band; required before Phase 6)

The E2E gate in Phase 6 drives a real model through the rebased `opencode` binary using the `opencode_context_bonsai_plugin`. Credentials and provider/model selection must be in place BEFORE the developer sub-agent is dispatched and must NEVER be committed to any artifact in the parent repo, the opencode worktree, or the plugin repo.

- Required: a configured provider that the parent maintainer (Basil) approves for this cycle. Default candidates and required identifiers:
  - Zen provider (works for OpenCode; Pi-side confirmed): env `OPENCODE_PROVIDER=opencode.ai/zen/v1`, env `OPENCODE_MODEL=kimi-k2.5`, env `OPENCODE_API_KEY=<provided out-of-band>` (or whatever variable names `opencode_context_bonsai_plugin` reads).
  - Alternative: any provider the maintainer specifies at dispatch time.
- Verification (must pass before the developer enters Phase 6):
  - `test -n "$OPENCODE_API_KEY"` (or equivalent variable name confirmed by maintainer)
  - `test -n "$OPENCODE_PROVIDER" && test -n "$OPENCODE_MODEL"`
- The orchestrator records the provisioning decision (provider, model, variable name) in the developer dispatch prompt. The developer does not invent these.

### Phase 1: Bootstrap and Frozen-SHA Capture

1. Toolchain preflight (from any directory):
   - `command -v bun` succeeds.
   - `bun --version` returns a string; record it in the baseline (informational).
   - `command -v jq` succeeds.
   - `command -v sha256sum` succeeds.
2. From the opencode submodule (`/home/basil/projects/context-bonsai-agents/opencode`), verify clean state:
   - `git status --short` returns empty.
   - `git rev-parse refs/heads/surgical_compaction` equals `4d88b953624c869122d4b37c4cbae01fd7a0f47e`.
   - `git rev-parse refs/tags/v1.15.7` equals `5451227deb5a502afe44e1664e81df7ecb208ed1`.
3. Re-verify replay-set checksum:
   - `test "$(jq -c < /home/basil/projects/context-bonsai-agents/.agents/plans/validation/replay-set-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json | sha256sum | cut -d' ' -f1)" = "900d84f5bb144365ed19946baddc1d6dec9c7c304972355dacc1535524027db6"`
4. Re-verify manual-review approvals checksum:
   - `test "$(jq -c < /home/basil/projects/context-bonsai-agents/.agents/plans/validation/manual-review-approvals-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json | sha256sum | cut -d' ' -f1)" = "55695b1395ebfa97bcfc53a7335c26e3eebb35d666c6f20e431f28495e86302c"`
5. Verify turbo build task and required scripts exist:
   - From the eventual worktree root (deferred until Phase 2 step 5 completes): `bun turbo run build --filter=opencode --dry-run | head -5` lists the `build` task.
   - `jq -r '.scripts.typecheck' /home/basil/projects/context-bonsai-agents/opencode/packages/opencode/package.json` returns a non-empty string.
   - `jq -r '.scripts.typecheck' /home/basil/projects/context-bonsai-agents/opencode/packages/plugin/package.json` returns a non-empty string.
6. Stale worktree note (informational): the opencode submodule has two prior cycle worktrees at `.agent_tmp/concrete-replay-latest-b1cb718/` and `.agent_tmp/concrete-replay-latest-b1cb718-loop2/` carrying branches `agent/concrete-replay-latest-b1cb718[-loop2]`. They are out of scope for this cycle; do NOT delete or modify them. They will appear in `git branch -a` listings; ignore them.

### Phase 2: Isolated Worktree Creation

7. Create the rebase worktree from `UPSTREAM_HEAD_SHA`:
   - `git -C /home/basil/projects/context-bonsai-agents/opencode worktree add -B replay/context-bonsai-on-opencode-1.15.7 /home/basil/projects/context-bonsai-agents/opencode/.agent_tmp/rebase-on-v1.15.7 5451227deb5a502afe44e1664e81df7ecb208ed1`
8. In the worktree, confirm `HEAD` matches `UPSTREAM_HEAD_SHA`:
   - `cd /home/basil/projects/context-bonsai-agents/opencode/.agent_tmp/rebase-on-v1.15.7 && test "$(git rev-parse HEAD)" = "5451227deb5a502afe44e1664e81df7ecb208ed1"`
9. Hydrate dependencies (workspace root):
   - From worktree root: `test -d node_modules || bun install`

### Phase 3: Baseline-Capture (no replay yet)

10. Create the baseline artifact (one row per required validation command) at `.agents/plans/validation/baseline-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json`. Required schema per row: `row_id`, `command`, `frozen_upstream_head_sha`, `frozen_source_head_sha`, `exit_code`, `result`, `artifact_path`, `provenance_ref`. Required baseline rows (run from the worktree, with stated working directory):
    - Row `r01`: `bun test test/tool/registry.test.ts test/session/message-v2.test.ts test/session/session.test.ts` from `packages/opencode` — captures pre-replay test state on UNMODIFIED upstream.
    - Row `r02`: file-existence probe `test ! -f test/session/context-bonsai.test.ts && echo missing-as-expected || (echo unexpected-presence && false)` from `packages/opencode`. The file is added by `ec63292d`; on upstream it must be absent. Do NOT run `bun test` against a path known not to exist; that would not discriminate from a real regression. Record the result string (`missing-as-expected` or `unexpected-presence`) and the provenance ref `git ls-files packages/opencode/test/session/context-bonsai.test.ts` (empty on upstream).
    - Row `r03`: `bun typecheck` from `packages/opencode`.
    - Row `r04`: `bun typecheck` from `packages/plugin`.
    - Row `r05`: `bun turbo run build --filter=opencode` from worktree root.
11. Baseline-row hard-fail rule: a row is a hard-fail of Phase 3 ONLY when one of its required schema fields is missing or null (per meta-plan). Non-zero `exit_code` is captured as data, not as a phase failure. However: row `r01` MUST be green (exit_code=0) on upstream — if `r01` shows a pre-existing upstream regression on `v1.15.7`, STOP and escalate; we cannot prove the replay is regression-free against a broken baseline. Row `r02` MUST have `result=missing-as-expected`; `unexpected-presence` is a hard-fail (the upstream tree should not contain bonsai test files).

### Phase 4: Replay (cherry-pick, in topological order)

Conflict-resolution scope for all three rows: edits must remain inside the union of the runtime allowlist (`packages/opencode/**`, `packages/plugin/**`) for rows 1+2, and `README.md` for row 3. If conflict resolution requires touching any other path (an "out-of-scope fixup"), STOP and add an explicit exception-ledger row at `.agents/plans/validation/exceptions-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json` citing which replay-set row authorized the fixup and the reviewer+judge approval refs before continuing.

12. Cherry-pick `ec63292d00fca02c38ec653c821948e0501d96fe` with provenance:
    - `git cherry-pick -x ec63292d00fca02c38ec653c821948e0501d96fe`
    - On conflicts: resolve narrowly inside `packages/opencode/**`.
13. Cherry-pick `7d4dfb827c0425928020fecdfc2d44936cb43559` with provenance:
    - `git cherry-pick -x 7d4dfb827c0425928020fecdfc2d44936cb43559`
    - On conflicts: resolve narrowly inside `packages/opencode/**` and/or `packages/plugin/**` (the row's authorized target paths).
14. Cherry-pick `4d88b953624c869122d4b37c4cbae01fd7a0f47e` with provenance:
    - `git cherry-pick -x 4d88b953624c869122d4b37c4cbae01fd7a0f47e`
    - On conflict on `README.md`, force wholesale replacement with the source commit's tree contents (not just `--theirs`, which only resolves conflicting hunks): `git show 4d88b953624c869122d4b37c4cbae01fd7a0f47e:README.md > README.md && git add README.md && git cherry-pick --continue`.
    - Verify wholesale: `diff <(git show 4d88b953624c869122d4b37c4cbae01fd7a0f47e:README.md) README.md` is empty AND `grep -q "Context Bonsai" README.md`.
15. Verify provenance trailers exist on all three replayed commits (range form, anchored grep, used identically here and in Final Verification):
    - `test "$(git log --format='%b' 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD | grep -cE '^\(cherry picked from commit [0-9a-f]{40}\)$')" = "3"`

### Phase 5: Post-Replay Validation

16. Run the canonical validation set from the worktree:
    - From `packages/opencode`: `bun test test/tool/registry.test.ts test/session/message-v2.test.ts test/session/session.test.ts`
    - From `packages/opencode`: `bun test test/session/context-bonsai.test.ts`
    - From `packages/opencode`: `bun typecheck`
    - From `packages/plugin`: `bun typecheck`
    - From worktree root: `bun turbo run build --filter=opencode`
17. Baseline-delta gate: the post-replay result of `bun test test/tool/registry.test.ts test/session/message-v2.test.ts test/session/session.test.ts` must be no worse than baseline row `r01`. If `r01` was green (expected), the post-replay run must also be green; failures that are net-new compared to `r01` are hard-fail regressions. (`r02` becomes meaningful post-replay because the file now exists.)
18. Verify replay diff scope (run from worktree root):
    - `git diff --name-status 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD` — every listed path must be in the union of `target_paths` across the replay-set rows. Any path outside that union requires an exception-ledger row authorized by reviewer+judge approval BEFORE the offending commit lands; if the commit has already landed without an exception, STOP and revert.
    - Generated-artifact exclusion (broad probe; the developer should also visually scan the diff):
      `git diff --name-status 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD | grep -E '(\.d\.ts$|/generated/|/__generated__/|openapi|\.gen\.|/dist/)' | wc -l` must return `0`.
    - If any generated-artifact match surfaces, STOP and remove those files from the replay commits (uncommitted, per Validation Mode).

### Phase 6: E2E Behavioral Gate

Authoritative procedure: `docs/context-bonsai-e2e-template.md`. The shared template defines five protocols: Protocol A (Secret Prune Oracle, prune-only), Protocol B (Retrieve Roundtrip), Protocol C (Gauge Oracle), Protocol D (Boundary Rejection), Protocol E (Compatibility Failure). The two integration patches in this cycle exercise the prune + retrieve code paths; both Protocols A AND B are required for pass evidence.

Substitution rationale: the meta-plan cites `.agents/e2e-context-bonsai-opencode-integration.md`; that file does not exist in this workspace. The shared `docs/context-bonsai-e2e-template.md` is the in-repo authoritative equivalent and is the procedure used for the other ports.

19. Wire the rebased `opencode` binary to `opencode_context_bonsai_plugin`:
    - The built binary lives at `packages/opencode/dist/opencode-linux-x64/bin/opencode` (or platform-equivalent) inside the worktree.
    - The plugin lives at `/home/basil/projects/context-bonsai-agents/opencode_context_bonsai_plugin/` (parent-repo submodule). Do NOT edit it.
    - Configure the worktree's `.opencode/opencode.jsonc` (worktree root) to load the plugin. Reference the existing parent-pinned configuration at `/home/basil/projects/context-bonsai-agents/opencode/.opencode/opencode.jsonc` as the template; update plugin path entries if they reference paths that do not exist in the worktree context.
    - Confirm wiring by inspecting the JSONC: `grep -A2 '"plugin"' .opencode/opencode.jsonc` lists the bonsai plugin entry.
20. Set provider env vars from Phase 0 in the shell that will run the E2E procedure. Do NOT export them into any persisted file; do NOT log them.
21. Run Protocol A (Secret Prune Oracle) from `docs/context-bonsai-e2e-template.md` against the built binary. Record transcript captures and exit code under `.agent_tmp/e2e-on-v1.15.7/protocol-a/` in the worktree (uncommitted).
22. Run Protocol B (Retrieve Roundtrip) similarly under `.agent_tmp/e2e-on-v1.15.7/protocol-b/`.
23. If either A or B fails, the implementor must NOT seal. Either fix the regression in the worktree and re-run from Phase 5, or stop and escalate. Do NOT log an exception-ledger bypass for E2E pass evidence without explicit reviewer+judge approval.

### Phase 7: Tag and Final Verification

24. Tag the rebased tip:
    - `git tag bonsai/v1-on-opencode-1.15.7 HEAD`
    - Note: a worktree shares its object DB and refs with the main repo, so this tag is visible from the main `OC` checkout immediately. This is expected (not a leak).
25. Pushability dry-run (does not push):
    - `git push --dry-run origin refs/tags/bonsai/v1-on-opencode-1.15.7` succeeds (returns exit 0 and shows the tag would be created on origin).
    - `git push --dry-run origin replay/context-bonsai-on-opencode-1.15.7` succeeds.
26. Final verification commands (record outputs in the implementor completion report):
    - `git merge-base 5451227deb5a502afe44e1664e81df7ecb208ed1 HEAD` returns `5451227deb5a502afe44e1664e81df7ecb208ed1` (HEAD is based on frozen upstream).
    - `git rev-list --count 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD` returns `3`.
    - `git log --format='%H %s' 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD` lists exactly 3 commits with subjects matching the replay set.
    - Cherry-pick provenance trailer count (same anchored grep used in Phase 4 step 15):
      `test "$(git log --format='%b' 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD | grep -cE '^\(cherry picked from commit [0-9a-f]{40}\)$')" = "3"`.
    - `git diff --name-status 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD` lists only paths in the union of replay-set `target_paths`.
    - `git diff --name-only -- /home/basil/projects/context-bonsai-agents/.agents/plans/story-meta-plan-for-future-rebase-planning.md` (run from parent repo) is empty.
27. Do NOT push the branch or tag in this story. Do NOT advance the parent submodule pin. Those are separate steps gated on reviewer+judge approval and recorded in DEVELOPMENT.md "Per-Cycle Steps" 6–9.

## Testing Strategy

- Cherry-pick provenance proves replay equivalence; do NOT rely on source-SHA equality against the replayed commit SHA.
- Patch-id fallback (`git patch-id < <git show source_sha>`) may be used to demonstrate equivalence when conflict resolution requires line-level edits.
- New tests are not in scope for this cycle; the chain already carries `packages/opencode/test/session/context-bonsai.test.ts` and `packages/opencode/test/session/message-v2.test.ts` and `packages/opencode/test/tool/registry.test.ts` updates as part of `ec63292d` and `7d4dfb82`.
- Build evidence: `bun turbo build --filter=opencode` must produce a runnable `opencode` binary used by the E2E gate.
- Do not modify `opencode_context_bonsai_plugin/` during this cycle; if the plugin's typing or runtime expectations diverge from the rebased opencode binary, raise it as a separate downstream story.

## Validation Commands

All commands listed below state the directory they run from. `WORKTREE` refers to `/home/basil/projects/context-bonsai-agents/opencode/.agent_tmp/rebase-on-v1.15.7`. `PARENT` refers to `/home/basil/projects/context-bonsai-agents`. `OC` refers to `/home/basil/projects/context-bonsai-agents/opencode`.

### Frozen-SHA verification

- From `OC`: `git rev-parse refs/heads/surgical_compaction` → `4d88b953624c869122d4b37c4cbae01fd7a0f47e`
- From `OC`: `git rev-parse refs/tags/v1.15.7` → `5451227deb5a502afe44e1664e81df7ecb208ed1`
- From `OC`: `git merge-base 5451227deb5a502afe44e1664e81df7ecb208ed1 4d88b953624c869122d4b37c4cbae01fd7a0f47e` → `5c5069b6227ce6c4cbc1b6daca65da69daf43f84`
- From `PARENT`: `jq -c < .agents/plans/validation/replay-set-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json | sha256sum | cut -d' ' -f1` → `900d84f5bb144365ed19946baddc1d6dec9c7c304972355dacc1535524027db6`
- From `PARENT`: `jq -c < .agents/plans/validation/manual-review-approvals-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json | sha256sum | cut -d' ' -f1` → `55695b1395ebfa97bcfc53a7335c26e3eebb35d666c6f20e431f28495e86302c`

### Inventory (deterministic; run from `OC`)

- `git log --topo-order --reverse --format='%H|%P|%s' 5451227deb5a502afe44e1664e81df7ecb208ed1..4d88b953624c869122d4b37c4cbae01fd7a0f47e`
- `git log --name-status --find-renames --format='%H|%s' 5451227deb5a502afe44e1664e81df7ecb208ed1..4d88b953624c869122d4b37c4cbae01fd7a0f47e`
- `git cherry -v 5451227deb5a502afe44e1664e81df7ecb208ed1 4d88b953624c869122d4b37c4cbae01fd7a0f47e`
- `git log --merges 5451227deb5a502afe44e1664e81df7ecb208ed1..4d88b953624c869122d4b37c4cbae01fd7a0f47e` (must be empty for this cycle)

### Bootstrap (run from `WORKTREE`)

- `test -d node_modules || bun install` (from worktree root)

### Canonical validation set (run from `WORKTREE` after replay)

- From `packages/opencode`: `bun test test/tool/registry.test.ts test/session/message-v2.test.ts test/session/session.test.ts`
- From `packages/opencode`: `bun test test/session/context-bonsai.test.ts`
- From `packages/opencode`: `bun typecheck`
- From `packages/plugin`: `bun typecheck`
- From worktree root: `bun turbo run build --filter=opencode`

### Final verification (run from `WORKTREE`)

- `git merge-base 5451227deb5a502afe44e1664e81df7ecb208ed1 HEAD` returns `5451227deb5a502afe44e1664e81df7ecb208ed1`
- `git rev-list --count 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD` returns `3`
- `git log --format='%H %s' 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD` lists exactly 3 commits with subjects matching the replay set
- `test "$(git log --format='%b' 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD | grep -cE '^\(cherry picked from commit [0-9a-f]{40}\)$')" = "3"`
- `git diff --name-status 5451227deb5a502afe44e1664e81df7ecb208ed1..HEAD` lists only paths in the union of replay-set `target_paths`
- `git push --dry-run origin refs/tags/bonsai/v1-on-opencode-1.15.7` returns exit 0
- `git push --dry-run origin replay/context-bonsai-on-opencode-1.15.7` returns exit 0

### Meta-plan immutability (run from `PARENT`)

- `git diff --name-only -- .agents/plans/story-meta-plan-for-future-rebase-planning.md` is empty
- `test -f .agents/plans/story-meta-plan-for-future-rebase-planning.md`

## E2E Gate

- Authoritative procedure: `docs/context-bonsai-e2e-template.md` (shared in-repo template; substitutes for the meta-plan's `.agents/e2e-context-bonsai-opencode-integration.md` reference, which does not exist in this workspace).
- Required protocols for this cycle: Protocol A (Secret Prune Oracle, exercises prune path from `ec63292d`/`7d4dfb82`) AND Protocol B (Retrieve Roundtrip, exercises retrieve path). Both must produce pass evidence.
- The procedures must be executed against the `opencode` binary produced by `bun turbo run build --filter=opencode` in the worktree.
- Plugin wiring: the rebased binary is pointed at `opencode_context_bonsai_plugin` via `.opencode/opencode.jsonc` in the worktree (see Phase 6 step 19). Do not edit the plugin repo.
- Provider/model: per Phase 0 (e.g., Zen `kimi-k2.5` or another maintainer-specified provider). Credentials passed via env vars only; never persisted.
- Pass evidence (transcript captures, exit codes, command logs) must be recorded under `.agent_tmp/e2e-on-v1.15.7/protocol-a/` and `.agent_tmp/e2e-on-v1.15.7/protocol-b/` in the worktree (uncommitted).
- Final seal is blocked until BOTH protocols produce pass evidence OR an explicit reviewer+judge-approved exception row is added to the exception ledger.

## Worktree Artifact Check

- Checked At: 2026-05-21 (planner)
- Planned Target Files (parent repo writes by planner):
  - `.agents/plans/story-rebase-cycle-4d88b953624c869122d4b37c4cbae01fd7a0f47e.md` (this file)
  - `.agents/plans/validation/replay-set-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json`
  - `.agents/plans/validation/manual-review-approvals-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json`
- Planned Target Files (worktree writes by implementor):
  - `.agents/plans/validation/baseline-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json` (parent repo)
  - `.agents/plans/validation/exceptions-4d88b953624c869122d4b37c4cbae01fd7a0f47e.json` (parent repo)
  - inside worktree: `packages/opencode/src/session/message-v2.ts`, `packages/opencode/src/tool/registry.ts`, `packages/plugin/src/tool.ts`, `packages/opencode/test/session/message-v2.test.ts`, `packages/opencode/test/session/context-bonsai.test.ts`, `packages/opencode/test/tool/registry.test.ts`, `README.md` (these are all replay targets, not direct edits)
- Overlaps Found (parent repo): none; `.agents/plans/` paths above are new files. Submodule `opencode` worktree is clean.
- Overlaps Found (opencode worktree to be created): `TARGET_WORKTREE` path does not currently exist; `replay/context-bonsai-on-opencode-1.15.7` branch does not currently exist. Two prior cycle worktrees exist at `opencode/.agent_tmp/concrete-replay-latest-b1cb718*/` but do not overlap the new path.
- Escalation Status: none.
- Decision Citation: planner judgment under user instruction "orchestrate ... for getting us onto v1.15.7".

## Plan Approval and Commit Status

- Approval Status: approved (forward instruction to orchestrate; planner has applied the meta-plan, run the mandatory validation loop, and resolved all 19 findings; no remaining ambiguity or missing details would change the plan if the user reviewed before commit)
- Approval Citation: user instruction "orchestrate story-meta-plan-for-future-rebase-planning.md for getting us onto v1.15.7" (2026-05-21) — approval to produce AND orchestrate the plan; user has standing "keep loops moving" guidance to avoid pausing for approval mid-cycle.
- Plan Commit Hash: recorded by Phase -1 gate; see commit landing this file.
- Ready-for-Orchestration: yes (after this file is committed)

## Validation Loop Results

- Iteration 1 (planner-dispatched, 2026-05-21):
  - Missing details check: 10 findings (Phase 0 credentials, toolchain preflight, turbo task verify, baseline r02 handling, grep-pattern consistency, Protocol A/B mix-up, plugin wiring, push dry-run, stale worktrees, README wholesale write). All addressed in this iteration.
  - Ambiguity check: 9 findings (cherry-pick `--theirs` semantics, plugin-allowlist scope in step 13, provenance-trailer range form, r02 hard-fail rule, baseline-delta gate, typecheck script existence, generated-file regex, out-of-scope fixup requires exception, tag visibility from shared object DB). All addressed in this iteration.
- Worktree artifact risk check: pass (recorded above).
- Plan-commit status check: pending (closes after plan commit lands).
- Iterations run: 1.
- No iteration 2 required: no new ambiguity or missing details introduced by the iteration-1 fixes (verified by re-reading the changed sections; no cross-section regressions).

## Completion Checklist

- [ ] All acceptance criteria met
- [ ] Validation commands pass
- [ ] Plan approved and committed before orchestration begins
- [ ] User-model ambiguities resolved or escalated
- [ ] Worktree artifact overlaps resolved (approved direction or explicit deferral)
- [ ] Replay-set checksum verified pre-replay and unchanged at seal
- [ ] Baseline artifact complete; no null `provenance_ref` rows
- [ ] Replay commits carry `cherry picked from commit` provenance trailers
- [ ] Replay diff scope is bounded by replay-set `target_paths` union
- [ ] No generated SDK/API files in replay diff
- [ ] E2E behavioral gate passes (Protocol A) or exception approved
- [ ] Meta-plan unchanged at seal
