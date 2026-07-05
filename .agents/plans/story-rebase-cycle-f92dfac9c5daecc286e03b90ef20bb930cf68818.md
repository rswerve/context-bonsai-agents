# Story: Forward-Port Claude Code Context Bonsai To 2.1.200

> **STAGED FOR PARENT.** This plan and its validation artifacts are drafted in the side repo `tweakcc_context_bonsai/.agents/plans/` because the run-5 pause forbids additions to the parent tree while the GPT-5.5 pilot lives. Their durable home is the parent repo's `.agents/plans/`; Phase 8 (Parent Landing) relocates them after run-5 exit. Until then, every path in this plan written as `.agents/plans/…` resolves inside the side repo.

## Goal

Forward-port the Claude Code/tweakcc Context Bonsai integration from side-repo source `SOURCE_HEAD_SHA=f92dfac9c5daecc286e03b90ef20bb930cf68818` (`tweakcc_context_bonsai` `main`) onto the frozen npm target `@anthropic-ai/claude-code@2.1.200`, using the closed-artifact shape of the parent repo's `docs/agent-specs/forward-port-spec.md` (Part 1 core, Part 3 shape, §4.3 slot). The sealed outcome: side-repo `HEAD` contains only the approved changes needed to bind the frozen 2.1.200 target — anchors re-verified or semantically re-derived, tooling and docs updated, full live e2e evidence recorded — followed, after run-5 exit, by parent landing (staged artifacts re-homed, submodule pin advanced, final verification).

**Generation provenance**: generated and §1.15-validated on the stronger (Fable-class) tier per the branch-1 tiering decision and the owner's 2026-07-03 Claude Code direction (`docs/meta-loop-direction.md` §"Next Step", parent repo). The executing tier for calibration runs is an **Opus 4.8 subagent at low effort**; every command below is bound so that execution requires no judgment call this plan does not resolve.

**Execution-mode rule (fixed).** The invoker's launch context must state exactly one of:

- `REAL-CYCLE` — execute against the absolute paths bound in this plan. Runs once; Phase 8 requires the Landing Authorization.
- `CALIBRATION` with an explicit scratch clone root — the invoker pre-clones this side repo to that root before launch; the executor substitutes the scratch root for `/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai` in every side-repo command (a mechanical path substitution, nothing else changes). frozen artifacts under `/tmp/cc-bonsai-artifacts/` are shared across runs and treated read-only except where Phase 2's rerun-safety rule fires; `/tmp/cc-bonsai-e2e/` is runtime evidence output, not a frozen artifact — each run writes, and may overwrite, its own outputs there; the invoker runs calibration executions serially — concurrent runs against the shared `/tmp` artifacts are forbidden. Phase 8 never runs in calibration (Landing Authorization is absent by construction). Phase 9's maintenance report is still written — inside the scratch clone, for the observing chain to collect. Nothing in a calibration run reads from or writes to the real side-repo working tree.

If the launch context states neither mode, STOP and request it from the invoker.

## Non-Goal

Do not change Context Bonsai behavior. Do not edit the parent repo's `docs/agent-specs/forward-port-spec.md` at any point, or ANY parent-repo file before Phase 8's landing authorization (run-5 pause). Do not upgrade, patch, restore, or otherwise touch the live installed `claude` CLI (2.1.198 at generation) or anything under `~/.local/share/claude/` — all target-version work runs against the frozen downloaded artifacts under `/tmp/cc-bonsai-artifacts/` (owner constraint, 2026-07-03). Do not weaken `minScore`/`minMargin` or any ambiguity check to make the target pass.

## Execution Outcome Statement

Final side-repo `HEAD` on `main` is a descendant of `f92dfac9c5daecc286e03b90ef20bb930cf68818` containing only: this cycle's implementation commits (targets enumerated below), the staged plan/validation artifacts, and relay hand-off documents under the drift allowlist. The frozen 2.1.200 target validates green through the canonical validation set and the immutable live e2e scope, evidenced against the pinned `/tmp` artifacts. Parent `main` advances the `tweakcc_context_bonsai` pin only in Phase 8, after landing authorization.

## Frozen Inputs

- `SOURCE_REF`: `refs/heads/main` in `tweakcc_context_bonsai/`
- `SOURCE_HEAD_SHA`: `f92dfac9c5daecc286e03b90ef20bb930cf68818`
- Prior executed cycle: `95c24228c302948139ef7c9240d50f1b18b3c5cf` → target 2.1.156 (plan in parent `.agents/plans/story-rebase-cycle-95c24228….md`). This is the next routine cycle, not a §1.9 supersession; the intervening source commits are the post-prune message-ordering fix work and relay/docs commits, all already on `main` at the frozen SHA.
- `TARGET_PACKAGE`: `@anthropic-ai/claude-code@2.1.200`
  - tarball `https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.200.tgz`
  - integrity `sha512-dDVQM1R7riEwBqARrIOr9nigtqgZ/uVDu7lsvU3EnQCMrRmT5KosYf79fngLyaNlu066tG8zOo7/zkkztBmjOA==`
  - shasum `ccf9aff84ef3dc569af0198b3f0ea75d59733f9d`
- `PLATFORM_PACKAGE`: `@anthropic-ai/claude-code-linux-x64@2.1.200` (the wrapper's `optionalDependencies` pin it lockstep at `2.1.200`)
  - tarball `https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64/-/claude-code-linux-x64-2.1.200.tgz`
  - integrity `sha512-w9sFQ2WinV504FTmkf7ApIsje/XSjIWp4778WjVEGGrXJKNurubkoY5b+lSRxHcnbEw8ROXD9qnxbKWocctlQA==`
  - shasum `f75a0d48e68796ed3cea520ff06c6ae073446ff3`
- Freeze provenance: resolved once at freeze time 2026-07-03 as npm dist-tag `latest` (owner direction: "current npm latest"). Observed dist-tags at freeze: `latest=2.1.200`, `next=2.1.200`, `stable=2.1.193`. `latest` selected; `stable` deliberately not (the owner direction names latest). No later re-resolution: all commands use the frozen literals above.
- `TARGET_NATIVE_BINARY`: `/tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/claude-2.1.200` — the `package/claude` member of the platform tarball; binary sha256 `26e42a3268979f0c5a3b6c0f375b15dd7decfaae4bb02774390d6a23f4cd51ad`; reports `2.1.200 (Claude Code)`.
- `EXTRACTED_BUNDLE`: `/tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/extracted.js` — sha256 `60e1c6cfc6d3931bf44020bfdb397d925a786365b8743a9760f2098aca9d7597`, 18698041 bytes, extracted with tweakcc `4.0.13` under bun `1.3.14`.
- `MANIFEST`: `/tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/manifest.json` (§3.1 fields; written at generation, re-verified at execution).
- **Runtime target binding (slot adaptation, recorded)**: the live installed CLI is 2.1.198 and is untouchable, so §4.3's literal `claude --version | grep '<version>'` preflight cannot bind this cycle. Per §3.1's explicit-frozen-install-path clause, the runtime under test is `TARGET_NATIVE_BINARY`; every live-validation command asserts `"$TARGET_NATIVE_BINARY" --version` reports `2.1.200` and launches the target by that explicit path. Flagged for §1.16 maintenance as a §4.3 slot fact (the slot assumed live == target).
- `VALIDATION_MODE`: `committed-final`.
- **Relay-drift allowlist (§1.1 invoker confirmation, recorded at generation)**: the hand-off relay commits bookkeeping to side-repo `main` between generation and execution. Commits after `SOURCE_HEAD_SHA` are pre-confirmed as non-drift **iff** they touch only paths matching `^(HAND_OFF|HANDOFF_|\.agents/plans/)`. Preflight check (from the side repo): `test -z "$(git diff --name-only f92dfac9c5daecc286e03b90ef20bb930cf68818..HEAD | grep -Ev '^(HAND_OFF|HANDOFF_|\.agents/plans/)')"`. Empty output: proceed, the port source is bytewise identical to the frozen SHA outside bookkeeping paths. Non-empty output: genuine source drift — STOP per §1.9; a fresh plan keyed to the new SHA is required, never a patch to this one. Flagged for §1.16 maintenance as a shape-gap candidate (Part 3 §3.5 drift handling assumed no interleaved bookkeeping commits).
- Pre-existing dirty paths (§1.10): side repo — none (clean at generation; this plan's own staged artifacts are enumerated cycle artifacts once committed). Parent repo (Phase 8 only) — ` M tweakcc_context_bonsai` submodule pin (untouchable except by Phase 8's own pin advance) plus, until run-5 exit, the gitignored `.agents/pilot/gpt55-v1.17.13-*` live run files (untouchable always; Phase 8 is blocked while they exist).

All commands below use these frozen identities. Do not substitute moving refs, `HEAD`-relative resolution of the inputs, `latest`, or a newly resolved dist-tag.

## User Model

### User Gamut

- Claude Code users needing long-session pruning without archived-content leaks, on current Claude Code releases.
- Maintainers carrying a closed-source runtime patch across ~44 fast-cadence releases in one hop.
- Reviewers auditing semantic anchor evidence against the real minified 2.1.200 bundle.
- The Opus-4.8-low calibration executor, which must be able to run every step without judgment calls.
- Operators running live e2e in an authenticated environment where credentials never enter artifacts.

### User-Needs Gamut

- Deterministic target freezing: exact package, tarball, integrity, binary and bundle checksums.
- Fail-closed anchor behavior when 44 releases of drift break a selector — never weakened thresholds.
- Live release-gate evidence (prune hides, retrieve restores, secret oracle holds) against the real 2.1.200 runtime.
- The message-ordering guarantees preserved exactly (see Behavioral Constraints below).
- A live development CLI that keeps working: nothing this cycle touches the operator's installed Claude Code.

### Ambiguities From User Model

- Target-not-installed is resolved by the frozen `/tmp` platform-package binary plus §3.1's explicit-path clause (recorded above), not by installing or upgrading anything.
- The generation-time anchor scan already shows one ambiguous anchor; its resolution path is fixed in the Inventory section — semantic re-derivation with scorer strengthening, thresholds unchanged, hard STOP if uniqueness cannot be established semantically.

## Behavioral Constraints Carried From The Claude Code Spec

These are load-bearing constraints from the parent repo's `docs/agent-specs/claude-code-context-bonsai-spec.md` (the message-ordering rules especially — scar tissue from the post-prune ordering defects fixed in this repo's `story-post-prune-message-ordering-fix` work). The forward-port must preserve every one; any 2.1.200-required change to these code paths is in scope only to keep these behaviors true, and the regression suites named must keep exercising them. None may be paraphrased away, narrowed, or dropped by this cycle. If implementation evidence suggests one is obsolete in 2.1.200, quote it to the owner via the watchdog and STOP that thread — do not delete or bypass it.

**Message-ordering / marker-coverage set:**

1. Archive marker coverage MUST include every original archived-interval JSONL row with a string `uuid`, **including UUID-bearing `type: "system"` rows such as `local_command`, `turn_duration`, and `away_summary`**; the appended summary placeholder is outside the original interval and MUST NOT be added to the marker for that prune. (Spec §Verified Host Primitives, archive-marker bullet.)
2. Prune marker writes MUST include every string-`uuid` row from the original archived interval, not just `user`/`assistant` rows, because the provider-bound patch filters by `__cbMessage.uuid` after Claude Code maps some JSONL metadata rows into provider-visible entries. (Spec §Prune and retrieve contract.)
3. Retrieve MUST remove marker entries for the same restored inclusive interval derived from the summary `compactMetadata`, including UUID-bearing system/meta rows, while preserving unrelated marker entries from other pruned ranges. (Spec §Prune and retrieve contract.)
4. The tweakcc provider filter must hide **all** provider-bound rows inside the archived interval, including JSONL `type: "system"` metadata rows that the host maps through its provider-side `api_system` branch. Filtering only `user`/`assistant` rows can leave orphan provider `system` messages and violate Anthropic ordering rules. (Spec §Transcript mutation path.) The `archived-filter.visibility` anchor must therefore keep binding the provider map that carries the `api_system` branch — the generation-time scan confirms that branch exists in the 2.1.200 bundle and the selector requires it structurally.
5. The MCP server rewrites the live JSONL to insert a placeholder `summary`-typed entry replacing the archived range (`markMessagesArchived` / `addArchivedMarkerEntries` in `src/lib/compact.ts`); atomic writes use `writeJsonlAtomic`, and mutations happen only during MCP tool calls while the model is paused. (Spec §Transcript mutation path.)

**Fail-closed / surface set:**

6. Every deterministic prune/retrieve failure or refusal MUST return an MCP result with `isError: true`, body plain text. (Spec §Fail-Closed Requirements.)
7. The prune-wrapper filter on the ambiguity path MUST remain in `mcp-server/index.ts` `loadSearchableMessages` / `resolveUniqueBoundary`, excluding messages whose `tool_use` block has `name === "context-bonsai-prune"` or `name === "mcp__context-bonsai__context-bonsai-prune"` from the candidate set on ambiguity. (Spec §Prune and retrieve contract.)
8. `loadSearchableMessages`/`searchableText` MUST surface each tool call's name, input, AND output content so pattern matching reaches tool-call payloads. (Spec §Prune and retrieve contract, Pattern Matching Contract bullet 1.)
9. The patch-presence guard MUST identify the running Claude binary independent of launch shape (versioned path, shim, `--resume`) via ancestor `/proc/<pid>/exe`, and MUST fail closed when no Claude ancestor binary is identified. (Spec §Fail-Closed Requirements.)
10. Missing session JSONL → structured error, no mutation. JSONL schema drift → compatibility error, no mutation. Transcript-rewrite seam absent or unverifiable → deterministic plain-text error, no archive-state write, no JSONL mutation. Marker-file write failure → roll back partial JSONL mutation. Pattern ambiguity after the prune-wrapper filter → deterministic plain-text error verbatim. (Spec §Fail-Closed Requirements.)

Regression anchors for this set: `mcp-server/index.test.ts` (guard, `isError`, wrapper filter, searchable text), `src/lib/compact.ts` tests under `bun test` (marker coverage incl. system rows, retrieve marker removal), `patches/archived-filter.patch.test.ts` (provider-map filter incl. `api_system` handling). Generation-time review found no constraint that looks obsolete against the tweakcc design; nothing is queued for owner quotation.

## Inventory: Anchor Registry And Generation-Time Drift Scan

Inventory domain (§3.2): the anchor registry `patches/anchors.ts` (5 patch anchors) plus the runtime-helper discovery seams in `patches/discovery.ts` (3 helpers) — the same 8 anchor ids as the executed 2.1.156 cycle. Install-discovery is exercised implicitly by `apply --path` (explicit path this cycle; discovery not relied upon).

Generation-time drift scan, run against `EXTRACTED_BUNDLE` on 2026-07-03 (the exact command is bound in Phase 4; execution re-runs it and must reproduce these outcomes before any edit):

| anchor_id | scan outcome | expected bucket |
|---|---|---|
| `archived-filter.visibility` | selects uniquely: offset `11749461`, score `105`, candidateCount `1`; `tengu_api_cache_breakpoints` + `api_system` branch shape intact | `unchanged_anchor` |
| `message-content-ids.converter` | selects: offset `11690165`, score `110`, candidateCount `24`; user converter now `mVf(e,t=!1,n,r)` — 4-arg signature discriminator intact | `unchanged_anchor` |
| `context-bonsai-gauge.token-usage` | **`AnchorAmbiguousError`: top score 52, second 47, ≤ minMargin 10 — fails closed** | `updated_anchor` after semantic re-derivation (contract below); `removed_or_ambiguous_anchor` + STOP if uniqueness cannot be established |
| `context-bonsai-gauge.attachment-pipeline` | selects: offset `7776901`, score `50`, candidateCount `17`; pipeline now `I8a(e,t)` | `unchanged_anchor` |
| `context-bonsai-gauge.reminder-render` | selects uniquely: offset `14376419`, score `40`, candidateCount `1` | `unchanged_anchor` |
| `runtime-helper.fs` | resolves: `Xt` | `unchanged_anchor` |
| `runtime-helper.config-dir` | resolves: `rr` | `unchanged_anchor` |
| `runtime-helper.session-id` | resolves: `Dt` | `unchanged_anchor` |

Bucket semantics follow the executed 2.1.156 replay-set precedent: a structural selector that still selects the correct seam uniquely (minified identifier renames notwithstanding — identifiers are captured, not hard-coded) is `unchanged_anchor` / `verify-unchanged`; a selector or scorer that needs strengthening to re-establish unique selection is `updated_anchor` / `update-scorer` (or `update-selector`). Expected buckets are generation guidance only — execution assigns buckets from the §3.3 evidence predicates against the real scan it runs.

**Token-usage re-derivation contract** (the one planned `updated_anchor`): the executor must (a) enumerate the tied candidates from the scan (the selector's own error output plus a candidate dump), (b) semantically analyze both in the real bundle — which function accumulates the current request's usage record with budget fields (`contextWindow`/`maxOutputTokens`-class) versus what the near-tie actually does, (c) document behavior controlled, why the chosen seam is correct, why the rejected candidate(s) are wrong, in `docs/semantic-anchor-analysis-2.1.200.md`, (d) strengthen `tokenUsagePatterns`/`tokenUsageScorer` in `patches/anchors.ts` with a behavior-grounded discriminator (the 2.1.156 `message-content-ids` 4-arg-signature fix is the precedent), and (e) leave `minScore: 15`/`minMargin: 10` untouched. If semantic analysis cannot establish a unique correct seam, the anchor is `removed_or_ambiguous_anchor` — hard-blocking per §3.3 — and the cycle STOPs pending reviewer+judge resolution recorded in this plan; no threshold is lowered and no candidate is guessed.

Generation evidence for this contract (the aid script was run once at generation; execution performs its own analysis): the top-scoring candidate (score 52) is a usage-display formatter — it builds human-readable `"Usage: … input, … output, … cache read"` strings — while the runner-up (score 47) is `a6p(e,t,n)` whose body matches the 2.1.156 accumulator `Wu5(H,$,q)` shape exactly (`let r=<fn>(n)??{inputTokens:0,outputTokens:0,cacheReadInputTokens:0,cacheCreationInputTokens:0,…}`). The margin check fail-closing here is the machinery working: without it, the patch would have anchored to a display formatter. The executor's semantic analysis must still establish this from behavior in the real bundle, not from this note.

## Replay-Set Materialization

Produced during Phase 4 (after re-derivation), staged at `.agents/plans/validation/replay-set-f92dfac9c5daecc286e03b90ef20bb930cf68818.json`. Canonical JSON array, rows sorted by `anchor_id` then `target_path`, fields in exactly this order (§3.4): `anchor_id`, `source_version` (`2.1.156`), `target_version` (`2.1.200`), `bucket`, `replay_action`, `mapping_type`, `target_paths`, `rationale`, `evidence_ref`. One row per inventory anchor (8 rows). The committed artifact is the classification record (§1.14.4, closed-artifact); no separate approvals or exceptions files exist in this shape (§1.5/§1.7) — hard-blocking approvals and any exceptions are recorded in this plan's acceptance criteria and validation sections. Structural check bound in Phase 7.

## Immutable Live E2E Scope For This Cycle

Implementation may update `docs/e2e-protocol.md` but may not narrow this cycle's acceptance scope. Required live scenario set for a release-gate PASS, per §4.3 and `docs/e2e-protocol.md`:

- E2E-00: clean install procedure using the current README commands, with this cycle's two recorded adaptations: (a) the apply step runs `bun run apply --path "$TARGET_NATIVE_BINARY"` (owner live-install protection + §3.1 explicit path); (b) MCP registration in `~/.claude.json` points at this checkout's `mcp-server/index.ts` per the README block. If a README command fails or diverges, that is a FAIL finding — fix the README, then re-run — never substitute. **Bound verdict path (Amendment 1)**: E2E-00 is driven locally, not on a fly.io sprite — the executed 2.1.156 precedent (`docs/e2e-results-2026-05-29-2.1.156.md`, E2E-00 row) accepted exactly this local README-procedure form, and `docs/e2e-protocol.md`'s sprite framing does not override this plan. Verdict `PASS` (reason code `install-procedure-pass`) iff all of: (a) `bun run apply --path "$TARGET_NATIVE_BINARY"` exits 0 with all three patch sentinels verified; (b) `"$TARGET_NATIVE_BINARY" mcp list` shows `context-bonsai` connected; (c) the end-of-gate `bun run apply --restore --path "$TARGET_NATIVE_BINARY"` returns the binary to its pinned pristine sha256; (d) every command used is the README's (with the two recorded adaptations) and none diverged. These are the same commands Phases 4/6 already bind — E2E-00's verdict maps their outcomes; no extra drive is required. The sprite-based full-parity form stays a §1.16 maintenance flag, not required this cycle.
- E2E-01: contiguous prune success; archived followers hidden from the model-visible transcript.
- E2E-02: ambiguity rejection and prune-wrapper collision filtering without mutation, with pattern targeting that exercises tool-call name, input, AND output reach across diverse tool-use blocks (Behavioral Constraint 8; spec E2E Priorities).
- E2E-03: retrieve by anchor success; restored content visible again.
- E2E-04: gauge cadence and severity (depends on the re-derived `token-usage` anchor; a partial-gauge outcome requires an explicit reviewer+judge exception, never silent omission). **Bound conditional exception (Amendment 1, recorded 2026-07-03)**: live gauge cadence/severity rendering has never been driven in any executed cycle and no bound driver exists. If it is not driven, the executor records `PARTIAL` with reason code `gauge-live-render-not-driven` — not `BLOCKED` — and the exception covers that `PARTIAL` for seal gate 11 **iff** both compensating evidence conditions hold: (a) the gauge anchors select and the gauge patch composes with sentinel verification against the frozen bundle (the Phase 4 `apply`), and (b) at least one live `--output-format json` run this gate surfaces the accumulator usage record (`inputTokens`/`contextWindow`/`maxOutputTokens`-class fields) in `modelUsage`, behaviorally confirming the re-derived token-usage seam. Citation: the executed 2.1.156 precedent (parent plan `story-rebase-cycle-95c24228….md` immutable-scope E2E-04 line "or explicit reviewer+judge exception if gauge remains partial for this cycle"; `docs/e2e-results-2026-05-29-2.1.156.md` §Reason Codes, `gauge-live-render-not-driven`) plus the independent reviewer pass recorded in Validation Loop Results Amendment 1. The owner is notified of this recorded exception; an owner override supersedes it. A bound live gauge driver stays a §1.16 maintenance item.
- E2E-05: compatibility error path without mutation — covering both fail-closed paths distinctly: missing session JSONL → structured error; schema drift → compatibility error (Behavioral Constraint 10). **Bound verdict path (Amendment 1)**: run-1 review found no existing test exercises either compatibility path (the 2.1.156 results row "PASS (unit-verified)" cited `mcp-server/index.test.ts` coverage that does not exist at `SOURCE_HEAD_SHA` — a genuine Constraint-10 regression-anchor gap this cycle closes with net-new coverage, so this binding strengthens rather than narrows the scope). Phase 4 adds two tests to `mcp-server/index.test.ts`, following that file's existing `createSession`/temp-dir fixture and `deps`-injection mechanics (the `handlePruneContext` deps parameter): (1) prune where `discoverSessionPath` resolves to a session JSONL that does not exist → result `isError: true`, body the deterministic compatibility error, and no session file created; (2) prune on a session JSONL containing a malformed (unparseable) non-final line → `readSessionMessages` throws corruption, result `isError: true` with the compatibility error, and the session file's bytes unchanged. Verdict `PASS (unit-verified)` — the executed 2.1.156 precedent semantics — with reason code `compat-error-unit-verified` iff both tests pass in Phase 5's `bun test`. Live in-session fault injection stays a §1.16 maintenance item, not required this cycle.
- E2E-06: persistence across resume (`"$TARGET_NATIVE_BINARY" --resume <session-id>`), archived-state filtering after reload.
- E2E-07 / Protocol A: secret-prune oracle; the secret never enters prune arguments, summary, or index terms.
- E2E-08: bug-shape prune guard via direct versioned-path launch of `"$TARGET_NATIVE_BINARY"` with no `--resume`: launch-shape-independent guard identification, prune with real content removal plus measured input-token-footprint drop, retrieve restoration, `isError` surfacing for deterministic refusals. A transform-EFFECT oracle — never degraded to flag-based or recall-based checks.
- Pinned-target artifact evidence: semantic 2.1.200 anchor analysis plus artifact-evidence JSON against `EXTRACTED_BUNDLE`/`MANIFEST`.

Every scenario drives the frozen `TARGET_NATIVE_BINARY` by explicit path; nothing launches the live `claude` shim. `BLOCKED` is per-scenario with `docs/e2e-protocol.md` reason codes (`credentials-missing-in-harness`, `sprite-unavailable`, `native-runtime-missing`, …); any `BLOCKED` accepted at seal requires the reviewer+judge exception per seal gate 11. No release-gate PASS with an unapproved `BLOCKED` or omitted scenario.

Known-risk note (recorded, accepted): the target binary shares `~/.claude` state (auth, `~/.claude.json`, session storage) with the operator's live 2.1.198 install — the same sharing every prior cycle's live e2e had when live == target. E2E sessions run from scratch project directories; the live install's binaries are never written. If the 2.1.200 binary migrates shared config in a way that disturbs the live CLI, record it as a cycle finding and STOP for owner guidance; do not attempt rollback engineering mid-cycle.

## Evidence Retention Policy

- Committed, staged-for-parent (side repo `.agents/plans/`): this plan; `validation/replay-set-f92dfac….json`; `validation/baseline-f92dfac….json`; `maintenance-report-f92dfac….md`.
- Committed, side repo `docs/`: `semantic-anchor-analysis-2.1.200.md`; `e2e-results-<DATE>-2.1.200.md` (`<DATE>` = UTC run date, `YYYY-MM-DD`, matching the existing `docs/e2e-results-*` convention).
- Local-only (never committed): everything under `/tmp/cc-bonsai-artifacts/claude-code/2.1.200/` (tarball, binary, `extracted.js`, `manifest.json`) and `/tmp/cc-bonsai-e2e/` (`2.1.200-artifact-evidence.json`, `2.1.200-protocol-a-oracle.json`, `2.1.200-prune-effect.json`, scenario logs).

Committed docs summarize local evidence with durable facts: command, exit code, target version, explicit binary path, relevant SHA-256 values, scenario verdicts with reason codes, local artifact paths. No secrets, credentials, auth paths, session transcripts, or extracted bundle contents in any repository artifact.

## Acceptance Criteria

- [ ] Frozen identity recorded and re-verified: both package identities (wrapper + platform), tarball checksums (sha1 + sha512-base64), binary sha256, extracted-bundle sha256, manifest fields, and `"$TARGET_NATIVE_BINARY" --version` = `2.1.200 (Claude Code)`.
- [ ] Live-install protection held: no file under `~/.local/share/claude/` or the npm global install modified; the live `claude --version` still reports its pre-cycle version after the cycle.
- [ ] Relay-drift allowlist check passes at every preflight; any non-allowlisted drift STOPped per §1.9.
- [ ] Anchor drift scan reproduced; every anchor classified per §3.3 evidence predicates; replay-set staged with 8 schema-valid rows.
- [ ] `context-bonsai-gauge.token-usage` resolved per the re-derivation contract: semantic evidence documented, scorer strengthened, `minScore`/`minMargin` unchanged — or the cycle STOPped with the anchor hard-blocked. **Hard-block approval recording (§1.5)**: if any row lands `removed_or_ambiguous_anchor` or `manual_review`, the seal is blocked until this criterion names the row and its reviewer+judge-approved resolution with citation; at generation no such row is approved.
- [ ] `docs/semantic-anchor-analysis-2.1.200.md` exists covering all 8 anchor sections with: pinned identity, behavior controlled, required-seam rationale, plausible wrong candidates rejected, fail-closed evidence, runtime/model-facing evidence (the 2.1.156 analysis is the format precedent).
- [ ] Every Behavioral Constraint (numbered 1–10 above) demonstrably preserved: the named regression suites pass, and any change to those code paths is minimal and 2.1.200-required.
- [ ] `e2e/native-e2e.ts` bound to 2.1.200 with no stale 2.1.156 defaults. Enumerated stale sites (verify line numbers against current source): `defaultBundlePath`/`defaultManifestPath` (lines 21–22, `.artifacts/claude-code/2.1.156/linux-x64/...`), `semanticReportPath` (line 23), the artifact-evidence hard-fail string naming 2.1.156 (line 101), the `?? '2.1.156'` version fallbacks (lines 122, 131), `defaultNativeBinary()` returning the 2.1.156 versioned path (line 348). Replacement rule (fixed): version-bump in place, preserving each site's existing path shape (`.artifacts/claude-code/2.1.200/linux-x64/…`; `~/.local/share/claude/versions/2.1.200`) — these defaults are never exercised by this plan's bound commands, which always pass explicit flags, and the standard-location shapes stay correct for future operators with a real 2.1.200 install. Also enumerated: `patches/discovery.test.ts` fixture paths and the SKIP-message path (lines 20–21, 111) and the `mcp-server/index.test.ts` versioned-path fixture (line 783) — re-point these to 2.1.200. `patches/discovery.test.ts` line 81's test title ("…from native 2.1.156") is historical/descriptive — it documents the release where that code shape was first observed — and stays unchanged.
- [ ] Post-replay `bun test`, `bun run typecheck`, and the artifact-evidence run against the frozen bundle all pass; baseline rows no worse than baseline.
- [ ] Live e2e: the full immutable scope above, PASS or reviewer+judge-excepted, recorded in `docs/e2e-results-<DATE>-2.1.200.md` with reason codes.
- [ ] E2E-00/04/05 resolved per their Amendment-1 bound paths: E2E-00 `PASS` by its local verdict predicate; E2E-04 driven live to PASS or `PARTIAL` covered by the recorded conditional exception (both compensating evidence conditions shown); E2E-05 `PASS (unit-verified)` via the two named Constraint-10 tests.
- [ ] No closed-source extracted bundle, manifest, auth file, credential, or live transcript committed.
- [ ] Side repo committed before any parent change; Phase 8 blocked until Landing Authorization is recorded; parent commit updates only the landed artifacts, any stale-target-evidence parent-spec lines, and the pin.
- [ ] §1.16 maintenance report staged, with the slot-adaptation flags listed in this plan recorded as Part 4 candidates (spec edits themselves deferred past run-5 exit).

## Planned Target Files

### Side repo (implementation)

- `patches/anchors.ts` — in scope only for the token-usage re-derivation (patterns/scorer strengthening) and any comment-accuracy updates the scan evidences; not an invitation to redesign selectors that already select.
- `patches/anchors.test.ts`, `patches/context-bonsai-gauge.patch.test.ts` — extend for the re-derived token-usage evidence; keep fixtures as helper-mechanics tests only.
- `patches/discovery.ts` — verify-only expected (helpers resolve at scan); minimal update only if execution's scan diverges.
- `patches/discovery.test.ts` — stale 2.1.156 fixture paths/names (enumerated above).
- `patches/archived-filter.patch.ts`, `patches/message-content-ids.patch.ts`, `patches/context-bonsai-gauge.patch.ts`, `patches/registry.ts` — verify-only expected; minimal updates only where the 2.1.200 bundle requires.
- `patches/archived-filter.patch.test.ts`, `patches/message-content-ids.patch.test.ts` — add 2.1.200-shaped coverage mirroring the existing 2.1.143/2.1.156 shape tests where selector context changed.
- `e2e/native-e2e.ts`, `e2e/native-e2e.test.ts` — stale-site rebind (enumerated above).
- `mcp-server/index.ts`, `mcp-server/index.test.ts` — in scope only to verify, and if strictly 2.1.200-required minimally adjust, the guard/`isError`/wrapper-filter/searchable-text behaviors (Behavioral Constraints 6–9); fixture path at line 783 may re-point to 2.1.200; `index.test.ts` additionally gains the two E2E-05 compatibility regression tests (Behavioral Constraint 10) bound in the Immutable Live E2E Scope.
- `docs/semantic-anchor-analysis-2.1.200.md` (new), `docs/e2e-results-<DATE>-2.1.200.md` (new), `docs/e2e-protocol.md` (update stale target references; never narrow scope), `README.md`, `DEVELOPMENT.md` (only where they state stale target evidence).
- `.agents/plans/` staged artifacts (this plan, validation JSONs, maintenance report).

### Parent repo (Phase 8 only, after Landing Authorization)

- `.agents/plans/story-rebase-cycle-f92dfac….md` + `.agents/plans/validation/{replay-set,baseline}-f92dfac….json` + `.agents/plans/maintenance-report-f92dfac….md` (landed from staging).
- `docs/agent-specs/claude-code-context-bonsai-spec.md` — only lines stating stale target evidence, if any.
- `tweakcc_context_bonsai` submodule pin.

### Explicit non-targets

- Parent `docs/agent-specs/forward-port-spec.md` (spec immutability, gate 12); parent `docs/agent-specs/context-bonsai-e2e-spec.md`; `opencode/`; every run-5 artifact (`.agents/pilot/**`, the committed run-5 plan/brief/validation files); prior cycle plans (superseded or executed); the live `claude` install and `~/.local/share/claude/**`; any `~/.claude/**` auth/credential/transcript file as a repository artifact; extracted bundles or manifests inside any repository.

## Implementation Phases With Commands

Working directories: "From side repo" = `/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai` (in CALIBRATION mode, the scratch clone root replaces this one path anchor; no other command text changes); "From parent" = `/home/basil/projects/context-bonsai-agents` (Phase 8 only). `"$TARGET_NATIVE_BINARY"` in every command below is a live shell variable, bound by the first Phase 0 command; run each phase's commands in one shell session so the export persists, or re-run the export first.

### Phase 0: Toolchain, Credential, and Clean-State Preflight

- First, in the shell that will run this phase's commands (and again in any new shell): `export TARGET_NATIVE_BINARY=/tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/claude-2.1.200`.
- From side repo: `command -v bun && command -v npm && command -v jq && command -v sha256sum && command -v sha1sum && command -v curl && command -v openssl && command -v tar`.
- From side repo: `bun --version` — record; generation ran under `1.3.14`. A different version is not itself a STOP; record it in the baseline provenance.
- From side repo: `git status --short` — empty, or only this cycle's own not-yet-committed validation artifacts (`baseline-f92dfac….json`, `replay-set-f92dfac….json`, the maintenance report) mid-execution. The plan file itself must already be tracked and committed (see Plan Approval); if it shows as untracked or modified here, STOP — the plan-approval gate has not closed, or the plan was altered.
- From side repo: `test "$(git rev-parse HEAD)" = "f92dfac9c5daecc286e03b90ef20bb930cf68818"` **or** the relay-drift allowlist check from Frozen Inputs passes; otherwise STOP per §1.9.
- From side repo: `bun install` (bootstrap; §4.3), then `cd mcp-server && bun install && cd ..` (README prerequisite).
- Live-install protection probe (must-hold, recorded): `claude --version` — record the live version (2.1.198 at generation); re-run at cycle end and assert unchanged.
- Credentials (e2e phases only): the operator provisions Claude Code sign-in out of band per `docs/e2e-protocol.md` Phase 0 / Pre-Flight; nothing is written into commands or artifacts. MCP registration presence check (from the Pre-Flight, verbatim): `bun -e 'const c=await Bun.file(`${process.env.HOME}/.claude.json`).json(); if(!JSON.stringify(c.mcpServers||{}).includes("context-bonsai")) process.exit(1)'`. Missing preconditions make affected live scenarios `BLOCKED` under the protocol's reason codes — per-scenario, never a plan-wide hard-fail (§4.3).
- Collision checks (§1.14; any hit is a STOP — already-generated/executed cycle — not license to resume or delete): from side repo, `test ! -e docs/semantic-anchor-analysis-2.1.200.md`; `test ! -e .agents/plans/validation/replay-set-f92dfac9c5daecc286e03b90ef20bb930cf68818.json`; `test ! -e .agents/plans/validation/baseline-f92dfac9c5daecc286e03b90ef20bb930cf68818.json`. (This plan file itself exists by design — committed at the plan-approval gate; its presence is not a collision.)

### Phase 1: Freeze Verification

- From side repo: `npm view @anthropic-ai/claude-code@2.1.200 version dist.tarball dist.integrity dist.shasum --json` — every field equals the Frozen Inputs literals.
- From side repo: `npm view @anthropic-ai/claude-code-linux-x64@2.1.200 version dist.tarball dist.integrity dist.shasum --json` — every field equals the Frozen Inputs literals.
- A registry mismatch on either (a republished tarball) is a STOP-and-escalate: frozen identity no longer resolvable.

### Phase 2: Target Artifact Acquisition and Extraction

All from side repo. Rerun safety: if `/tmp/cc-bonsai-artifacts/claude-code/2.1.200/` already exists with matching checksums (generation created it), verification below suffices; on any checksum mismatch, delete only `/tmp/cc-bonsai-artifacts/claude-code/2.1.200/` and re-acquire.

```bash
mkdir -p /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native /tmp/cc-bonsai-artifacts/claude-code/2.1.200/download /tmp/cc-bonsai-e2e
cd /tmp/cc-bonsai-artifacts/claude-code/2.1.200/download
curl -fsSL -o claude-code-linux-x64-2.1.200.tgz "https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64/-/claude-code-linux-x64-2.1.200.tgz"
test "$(sha1sum claude-code-linux-x64-2.1.200.tgz | cut -d' ' -f1)" = "f75a0d48e68796ed3cea520ff06c6ae073446ff3"
test "$(openssl dgst -sha512 -binary claude-code-linux-x64-2.1.200.tgz | base64 -w0)" = "w9sFQ2WinV504FTmkf7ApIsje/XSjIWp4778WjVEGGrXJKNurubkoY5b+lSRxHcnbEw8ROXD9qnxbKWocctlQA=="
tar -xzf claude-code-linux-x64-2.1.200.tgz package/claude
mv -f package/claude ../native/claude-2.1.200
chmod +x ../native/claude-2.1.200
test "$(sha256sum ../native/claude-2.1.200 | cut -d' ' -f1)" = "26e42a3268979f0c5a3b6c0f375b15dd7decfaae4bb02774390d6a23f4cd51ad"
../native/claude-2.1.200 --version | grep -F '2.1.200'
```

Extraction (from side repo; the §4.3 extraction command with the explicit frozen path bound):

```bash
bun --eval "import { tweakccApi } from './apply/tweakcc-api'; const c = await tweakccApi.readContent({ path: '/tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/claude-2.1.200', kind: 'native', version: '2.1.200' }); await Bun.write('/tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/extracted.js', c);"
test "$(sha256sum /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/extracted.js | cut -d' ' -f1)" = "60e1c6cfc6d3931bf44020bfdb397d925a786365b8743a9760f2098aca9d7597"
```

Manifest: ensure `/tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/manifest.json` carries the §3.1 fields with exactly the Frozen Inputs values (package identities, reported version, explicit install path + provenance, extraction command, `tweakcc 4.0.13`, bun version, platform `linux-x64`, extracted path, bundle sha256/bytes). Verify: `jq -e '.claudeCodeVersion=="2.1.200" and .extractedBundleSha256=="60e1c6cfc6d3931bf44020bfdb397d925a786365b8743a9760f2098aca9d7597" and (.installPath|startswith("/tmp/cc-bonsai-artifacts/"))' /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/manifest.json`.

### Phase 3: Baseline Capture

From side repo, before any implementation edit. Emit `.agents/plans/validation/baseline-f92dfac9c5daecc286e03b90ef20bb930cf68818.json` (`mkdir -p .agents/plans/validation` first): JSON array, fields per row in exactly this order: `row_id`, `command`, `frozen_target_package` (`@anthropic-ai/claude-code@2.1.200`), `frozen_source_head_sha` (`f92dfac9c5daecc286e03b90ef20bb930cf68818`), `exit_code`, `result`, `artifact_path`, `provenance_ref`. No empty or `n/a` fields (§1.6). Capture each row's full output under `/tmp/cc-bonsai-e2e/baseline/` (local-only) and reference it as `artifact_path`.

| row_id | command | result mapping | provenance_ref (record its output) |
|---|---|---|---|
| `01` | `bun install` | `pass` if exit 0 | `git rev-parse HEAD` |
| `02` | `bun test` | **must-be-green**: non-zero exit is STOP-and-escalate (pre-existing regression is not this cycle's to fix) | `git rev-parse HEAD` |
| `03` | `bun run typecheck` | **must-be-green**, as row 02 | `jq -r '.scripts.typecheck' package.json` |
| `04` | `bun run e2e/native-e2e.ts artifact-evidence --bundle /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/extracted.js --manifest /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/manifest.json --out /tmp/cc-bonsai-e2e/2.1.200-artifact-evidence.json` | expected non-zero at baseline: the harness still carries 2.1.156 literals and must reject a 2.1.200 manifest; record `result` as `fail-expected-stale-harness` with the exit code as data (§1.6: non-zero exit is data, row not designated green). An exit 0 here is `unexpected-pass` and hard-fails the phase (the stale harness accepting the new target means the version guard is broken). | `sha256sum /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/extracted.js` |

Validate: `jq -e 'length==4 and all(.[]; .row_id and .command and .frozen_target_package and .frozen_source_head_sha and (.exit_code|type=="number") and .result and .artifact_path and .provenance_ref and (.provenance_ref!="n/a") and (.artifact_path!="n/a"))' .agents/plans/validation/baseline-f92dfac9c5daecc286e03b90ef20bb930cf68818.json` and `jq -e 'any(.[]; .row_id=="02" and .exit_code==0) and any(.[]; .row_id=="03" and .exit_code==0)' <same file>`.

Post-replay and live-e2e result rows are appended to this same artifact file per the executed-precedent convention (§4.3), continuing `05`, `06`, … with the same field order.

### Phase 4: Anchor Re-Derivation and Replay (in place, §3.5)

- Re-run the drift scan, verbatim, and compare outcomes to the generation-time table (from side repo):

```bash
bun --eval "
import { readFileSync } from 'node:fs';
import { selectVisibilitySwitchAnchor, selectMessageContentConverterAnchor, selectTokenUsageHelperAnchor, selectAttachmentPipelineAnchor, selectReminderRenderAnchor } from './patches/anchors';
import { findRuntimeHelpers } from './patches/discovery';
const content = readFileSync('/tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/extracted.js', 'utf8');
const probes = {
  'archived-filter.visibility': () => { const a = selectVisibilitySwitchAnchor(content); return { offset: a.index, score: a.score, candidates: a.evidence.candidateCount }; },
  'message-content-ids.converter': () => { const a = selectMessageContentConverterAnchor(content); return { offset: a.index, score: a.score, candidates: a.evidence.candidateCount }; },
  'context-bonsai-gauge.token-usage': () => { const a = selectTokenUsageHelperAnchor(content); return { offset: a.index, score: a.score, candidates: a.evidence.candidateCount }; },
  'context-bonsai-gauge.attachment-pipeline': () => { const a = selectAttachmentPipelineAnchor(content); return { offset: a.index, score: a.score, candidates: a.evidence.candidateCount }; },
  'context-bonsai-gauge.reminder-render': () => { const a = selectReminderRenderAnchor(content); return { offset: a.index, score: a.score, candidates: a.evidence.candidateCount }; },
  'runtime-helpers': () => findRuntimeHelpers(content),
};
for (const [name, fn] of Object.entries(probes)) {
  try { console.log(name, '=>', JSON.stringify(fn())); }
  catch (e) { console.log(name, '=> THREW', e.name + ':', e.message); }
}
"
```

  A scan outcome differing from the generation table (an anchor that selected now throwing, or vice versa) is evidence drift: STOP and record before proceeding — the frozen bundle checksum makes this reproducible, so divergence means a code or environment defect, not a new bundle.
- Worktree artifact check re-run (§1.14.10), immediately before the first edit: `git status --short -- patches/ e2e/ mcp-server/ docs/ README.md DEVELOPMENT.md` and `git ls-files --others --exclude-standard -- patches/ e2e/ mcp-server/ docs/` — any output is a `tracked-dirty`/`existing-untracked` overlap: STOP until approved or deferred with citation.
- Execute the token-usage re-derivation contract (Inventory section). Candidate enumeration aid (not authority — the documented semantic analysis is the authority): a throwaway `bun --eval` script that imports `findCandidates`/`scoreCandidates` from `./patches/discovery` (both are exported there) and **inlines a verbatim copy of `tokenUsagePatterns` and `tokenUsageScorer` pasted from `patches/anchors.ts` at time of use** — those two are module-private in `anchors.ts` and must NOT be exported for this (no `anchors.ts` edit for instrumentation; the inline copy is temporary, non-authoritative, and discarded after use). Print the top candidates with offsets and 200-char snippets for inspection in the real bundle.
- Update the enumerated stale sites in `e2e/native-e2e.ts`, `patches/discovery.test.ts`, `mcp-server/index.test.ts` (Acceptance Criteria list; verify line numbers against current source before editing).
- Add the two E2E-05 compatibility regression tests bound in the Immutable Live E2E Scope to `mcp-server/index.test.ts` (Behavioral Constraint 10; follow the file's existing `createSession`/temp-dir fixture and `deps`-injection mechanics).
- Write `docs/semantic-anchor-analysis-2.1.200.md` — all 8 sections, 2.1.156 doc as format precedent, new offsets/identifiers/scores from the execution scan, the token-usage re-derivation documented with rejected candidates. **Bound format contract (Amendment 2 — this exact shape is machine-validated by `validateSemanticReport` in `e2e/native-e2e.ts`, and mislabeled fields failed the first artifact-evidence attempt in both calibration runs):** each of the 8 sections is headed exactly `## <anchor-id>` (the inventory table's ids, nothing appended); every section contains each of these ten labels verbatim, immediately followed by a colon — `Anchor ID:`, `Patch or helper:`, `Pinned artifact identity:`, `Selected offset and snippet:`, `Host behavior controlled:`, `Required seam rationale:`, `Plausible wrong candidates rejected:`, `Ambiguous/no-match fail-closed evidence:`, `Runtime or model-facing evidence:`, `Reviewer checklist:` — never reworded, extended, or merged into a sentence (the validator matches the literal substring `<label>:` inside each section); and the document contains the phrases `mechanical locator evidence` and `not release-gate` (the validator's reclassification check).
- Verify patch composition end-to-end against the frozen bundle: `bun run apply --path "$TARGET_NATIVE_BINARY"` must complete with sentinel verification (this also exercises §3.6's runtime binding), then `bun run apply --restore --path "$TARGET_NATIVE_BINARY"` to return the artifact to pristine for the baseline-equivalent state (live e2e re-applies in Phase 6). If `apply` fails closed on any anchor, that anchor's classification is wrong — return to re-derivation, never weaken.
- Materialize the replay set (previous section) from the final scan + semantic analysis.
- Update `docs/e2e-protocol.md` target references (2.1.156 → 2.1.200 runtime entry point, versioned-path examples), `README.md`/`DEVELOPMENT.md` only where stale target evidence appears.

### Phase 5: Post-Replay Local Validation

From side repo (§4.3 canonical set; results appended to the baseline artifact as rows 05+):

- `bun test` — no worse than baseline row 02; net-new failures are hard-fail regressions.
- `bun run typecheck`.
- `bun run e2e/native-e2e.ts artifact-evidence --bundle /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/extracted.js --manifest /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/manifest.json --out /tmp/cc-bonsai-e2e/2.1.200-artifact-evidence.json` — must now pass against the frozen bundle.
- `git status --short` — only planned target files modified/added.
- `jq -e 'length==8 and all(.[]; .anchor_id and .source_version=="2.1.156" and .target_version=="2.1.200" and .bucket and .replay_action and .mapping_type and (.target_paths|type=="array") and .rationale and .evidence_ref)' .agents/plans/validation/replay-set-f92dfac9c5daecc286e03b90ef20bb930cf68818.json`.
- `jq -e '[.[] | select(.bucket=="removed_or_ambiguous_anchor" or .bucket=="manual_review")] | length == 0' <same file>` — a non-empty result is the §1.5 hard block: STOP pending the reviewer+judge resolution recorded in Acceptance Criteria.

### Phase 6: Live E2E Gate

From side repo. Credentials/sign-in per Phase 0; scenario-blocking preconditions produce per-scenario `BLOCKED` with reason codes.

- `"$TARGET_NATIVE_BINARY" --version | grep -F '2.1.200'` — re-asserted immediately before live validation (§3.6); stop on mismatch.
- `bun run apply --path "$TARGET_NATIVE_BINARY"` — the §3.6 runtime binding: explicit frozen install path, no discovery reliance.
- `"$TARGET_NATIVE_BINARY" mcp list` — confirm `context-bonsai` MCP registration is visible to the target binary.
- Execute the immutable scope E2E-00 … E2E-08 per `docs/e2e-protocol.md` (as updated in Phase 4 for 2.1.200 paths), all launches via `"$TARGET_NATIVE_BINARY"`. Harness commands, argument shapes read from `bun run e2e/native-e2e.ts` usage output (never assumed):
  - `bun run e2e/native-e2e.ts protocol-a-oracle --session <session-jsonl> --secret <secret> --out /tmp/cc-bonsai-e2e/2.1.200-protocol-a-oracle.json` — the secret is one uncommon word chosen fresh, present in no versioned artifact.
  - E2E-08 direct-launch guard drive, with a fresh scratch project directory created immediately before the run: `E2E_SCRATCH=$(mktemp -d /tmp/cc-bonsai-e2e/scratch-XXXXXX)` then `bun run e2e/native-e2e.ts prune-guard-live --binary "$TARGET_NATIVE_BINARY" --cwd "$E2E_SCRATCH" --out /tmp/cc-bonsai-e2e/2.1.200-prune-guard-live.json`. **`--binary` and `--cwd` must never be omitted**: the harness falls back to a `~/.local/share/claude/versions/` default binary (a live-install-shaped path this cycle forbids as the test subject) and to the invoking directory as `cwd` (which would pollute the repo root with a live project entry and can make session discovery pick up a wrong/stale JSONL). A new `mktemp -d` scratch directory is created for each run — never reused. `--prompt` stays at the harness default unless the scenario procedure says otherwise.
  - E2E-08 content-removal + footprint-drop oracle. `pre.jsonl`/`post.jsonl` are the session copies the protocol's E2E-08 steps 1 and 3 bind (`cp "$SESSION_FILE" pre.jsonl` before the prune drive, `post.jsonl` after). **Seeding rule (Amendment 2)**: the ALPHA boundary phrase must not land on the session's first message — the host attaches protected startup context there and the prune deterministically refuses to archive it (both calibration runs hit this refusal on their first seeding); send at least one ordinary throwaway message before the ALPHA-bearing one. The range UUIDs are extracted from `pre.jsonl` by the boundary phrases the scenario seeded, fail-closed on non-uniqueness (Protocol-B capture-step precedent: zero or multiple matches is a FAIL of the capture step — re-seed with genuinely unique phrases; never guess among candidates):

    ```bash
    # The `.uuid and` guard scopes matching to string-uuid rows: uuid-null metadata rows
    # (`queue-operation`, `last-prompt`) echo prompt text and would otherwise inflate a
    # genuinely-unique phrase's count (calibration run-1 SPEC-GAP fix, Amendment 1).
    test "$(jq -r 'select(.uuid and (tostring | contains("ALPHA-PHRASE-001"))) | .uuid' pre.jsonl | wc -l)" = "1"
    test "$(jq -r 'select(.uuid and (tostring | contains("OMEGA-PHRASE-001"))) | .uuid' pre.jsonl | wc -l)" = "1"
    FROM_UUID=$(jq -r 'select(.uuid and (tostring | contains("ALPHA-PHRASE-001"))) | .uuid' pre.jsonl)
    TO_UUID=$(jq -r 'select(.uuid and (tostring | contains("OMEGA-PHRASE-001"))) | .uuid' pre.jsonl)
    bun run e2e/native-e2e.ts prune-effect --pre-session pre.jsonl --session post.jsonl --from-uuid "$FROM_UUID" --to-uuid "$TO_UUID" --out /tmp/cc-bonsai-e2e/2.1.200-prune-effect.json
    ```
- Record every scenario in `docs/e2e-results-<DATE>-2.1.200.md`: verdict, reason code, command, exit code, explicit binary path, local artifact paths. Retry rule (fixed, all scenarios): a FAIL is recorded with its evidence, then either the identified defect is fixed (in plan scope, with the fix recorded) and the scenario re-run, or the cycle STOPs — silent re-runs hoping for a different outcome are forbidden. Protocol A keeps its stricter rule: failing on a clean build after prior validation passed is a §1.17 escalation, not a retry.
- Live-install protection re-probe: `claude --version` unchanged from Phase 0's recording; `ls ~/.local/share/claude/versions/` unchanged.

### Phase 7: Side-Repo Commit and Seal Gates

- Commit implementation + docs + staged validation artifacts to side-repo `main` (subject + body per repo commit rules; single reviewable concern per commit — anchors/tooling, docs/evidence, staged artifacts may be separate commits).
- Seal-gate checks (mirroring §1.13, closed-artifact bindings), from side repo:
  1. `jq -e 'length==8' .agents/plans/validation/replay-set-f92dfac….json` (every inventory anchor mapped; zero unmapped).
  2. The Phase 5 hard-block `jq` check passes (zero unresolved `manual_review`/`removed_or_ambiguous_anchor`), or the Acceptance-Criteria resolution is recorded with reviewer+judge citation.
  3. No late fixes: the relay-drift allowlist check still passes against `SOURCE_HEAD_SHA` (implementation commits are this cycle's own; anything else STOPs per §1.9).
  4. Replay-set present and schema-valid (Phase 5 `jq`). Checksum: not required by this shape (§1.4 closed-artifact — the committed, diff-tracked file is the frozen input).
  5. Separate approval artifacts: none in this shape (§1.5).
  6. Baseline artifact complete (Phase 3 `jq` checks; no placeholders; provenance present).
  7. Replay verification per shape: `bun run apply --path "$TARGET_NATIVE_BINARY"` composes with sentinel verification against the frozen bundle (§3.5/§3.6 semantic re-derivation evidence; never identity-equality against source).
  8. Post-replay validation no worse than baseline; rows 02/03-equivalents green.
  9. Change-scope: `git diff --name-only f92dfac9c5daecc286e03b90ef20bb930cf68818..HEAD` ⊆ (planned target files ∪ relay-drift allowlist paths). An out-of-scope path already landed without an exception recorded in this plan: STOP and revert.
  10. No unresolved exception records in this plan's validation sections.
  11. E2E gate: `docs/e2e-results-<DATE>-2.1.200.md` shows the full immutable scope PASS, or reviewer+judge-approved exceptions recorded here.
  12. Spec immutability, from parent: `test -f docs/agent-specs/forward-port-spec.md && test -z "$(git diff --name-only -- docs/agent-specs/forward-port-spec.md)"` (read-only check; runs from the parent checkout without modifying it).
  13. Reviewer and judge approvals recorded (Plan Approval section + any per-row citations).
  14. Release-gate ordering (§3.8) = Phase 8, in order, after Landing Authorization.

### Phase 8: Parent Landing (blocked until Landing Authorization)

**Landing Authorization (§1.8-style approval token)**: this phase is blocked while run 5 lives. The invoker (relay chain) records authorization in this plan's Approval section — citing the run-5 exit record commit in the parent repo — before any command below runs. Machine-checkable preconditions, from parent: `git status --short` shows at most ` M tweakcc_context_bonsai`; no `.agents/pilot/gpt55-v1.17.13-*` live files remain untracked (exited runs are archived per the observation protocol).

In order:

1. From side repo: remove the staged copies and commit — `git rm .agents/plans/story-rebase-cycle-f92dfac….md .agents/plans/validation/replay-set-f92dfac….json .agents/plans/validation/baseline-f92dfac….json .agents/plans/maintenance-report-f92dfac….md` with a commit body citing the landing. (The parent copies become the durable record; the side repo returns to implementation-only content. Side-repo `HEAD` after this commit is the pin target.)
2. From parent: copy the four artifacts into parent `.agents/plans/` and `.agents/plans/validation/` from a working copy taken before step 1 (`LAND_TMP=$(mktemp -d /tmp/cc-bonsai-landing-XXXXXX)`; `cp` the four files there first, then step 1, then copy from `$LAND_TMP`); `git add` them; update `docs/agent-specs/claude-code-context-bonsai-spec.md` only where it states stale target evidence; `git add tweakcc_context_bonsai` (pin at the step-1 tip); one commit (subject + body per repo commit rules).
3. Final verification — from side repo: `git log --oneline -5`; `git diff --name-status HEAD~1..HEAD`; `git status --short`. From parent: `git status --short`; `git diff --submodule=short HEAD~1..HEAD`; the spec-immutability check (gate 12).
4. The routine cycle ends here (§3.8): local pin advance plus final verification. Pushing the side repo and parent is a separate, owner-approved step — this shape has no proven publish ladder, and the executor must not invent one.

### Phase 9: Routine Maintenance (§1.16 — mandatory after seal or STOP)

- Write `.agents/plans/maintenance-report-f92dfac9c5daecc286e03b90ef20bb930cf68818.md` (staged-for-parent): changed slot-level facts with evidence; failure-attribution verdicts (`SPEC-GAP`/`EXECUTOR-FAIL`) for every stumble; core/shape gaps flagged for the owner tier.
- Pre-identified slot flags this cycle must carry (generation already knows them): (a) §4.3 extraction/runtime binding assumes target == live install — this cycle's `/tmp` platform-package route is the working generalization; (b) §4.3's `claude --version` preflight line likewise; (c) the relay-drift allowlist as a Part 3 §3.5 shape-gap candidate; (d) the installation-e2e instance for Claude Code remains unrecorded anywhere — flagged, not invented (§4.2's durable rule, applied cross-slot).
- **Disposition deviation from §1.16, recorded**: the §1.16 default (leave the Part 4 edit uncommitted in the parent working tree) is unavailable while run 5 lives — parent dirt is frozen. The maintenance report therefore records the exact proposed Part 4 diffs as text; applying them as an uncommitted parent edit happens at Phase 8 landing (or later owner review), and the report says so explicitly. When no slot-level fact changed beyond the pre-identified flags, record that explicitly rather than skipping.

## Validation Commands

Grouped by working directory; the source of truth for implementation agents.

### Side repo (`/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai`)

- `git status --short`; `git rev-parse HEAD`; the relay-drift allowlist check (Frozen Inputs)
- `npm view @anthropic-ai/claude-code@2.1.200 version dist.tarball dist.integrity dist.shasum --json`
- `npm view @anthropic-ai/claude-code-linux-x64@2.1.200 version dist.tarball dist.integrity dist.shasum --json`
- `bun install`
- `bun test`
- `bun run typecheck`
- `bun run e2e/native-e2e.ts artifact-evidence --bundle /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/extracted.js --manifest /tmp/cc-bonsai-artifacts/claude-code/2.1.200/native/manifest.json --out /tmp/cc-bonsai-e2e/2.1.200-artifact-evidence.json`
- the Phase 4 drift-scan block; the Phase 3/Phase 5 `jq` structural checks
- `"$TARGET_NATIVE_BINARY" --version | grep -F '2.1.200'`; `bun run apply --path "$TARGET_NATIVE_BINARY"`; `"$TARGET_NATIVE_BINARY" mcp list`; the Phase 6 harness commands

### Parent (`/home/basil/projects/context-bonsai-agents`) — read-only until Phase 8

- `test -f docs/agent-specs/forward-port-spec.md && test -z "$(git diff --name-only -- docs/agent-specs/forward-port-spec.md)"`
- Phase 8 only: `git status --short`; `git diff --submodule=short HEAD~1..HEAD`

## E2E Gate

- Authoritative procedure: `docs/e2e-protocol.md` (this repo; updated for 2.1.200 in Phase 4, never narrowed) with `docs/context-bonsai-e2e-template.md#protocol-a-secret-prune-oracle` (parent) as the shared oracle reference.
- Required scenarios: the Immutable Live E2E Scope above (E2E-00 … E2E-08 + pinned-target artifact evidence) — this cycle may not narrow it.
- Runtime under test: `TARGET_NATIVE_BINARY`, always by explicit path. The live `claude` shim is never the test subject.
- Evidence: local under `/tmp/cc-bonsai-e2e/`; committed summary `docs/e2e-results-<DATE>-2.1.200.md`. Verdicts come from session/export/oracle evidence (content genuinely absent, measured footprint drop, restoration visible), never model assertions or green typechecks alone.
- Credentials: operator-provisioned sign-in, out of band, never persisted or logged; missing preconditions → per-scenario `BLOCKED` with reason codes; unapproved `BLOCKED` blocks the seal (gate 11).

## Worktree Artifact Check

- Checked At: 2026-07-03 (generation; the executor re-runs the Phase 4 check immediately before its first edit).
- Side-repo planned target files: all tracked and clean at `f92dfac9c5daecc286e03b90ef20bb930cf68818` (`git status --short` empty at generation). New files (`docs/semantic-anchor-analysis-2.1.200.md`, `docs/e2e-results-<DATE>-2.1.200.md`, the validation JSONs, the maintenance report) verified non-existent at generation — no `tracked-dirty` or `existing-untracked` overlap.
- This plan file itself: created at generation in side-repo staging; no collision (no prior `story-rebase-cycle-f92dfac…` artifact existed in the side repo or parent `.agents/plans/`).
- Parent planned targets: untouched until Phase 8; parent dirt profile at generation is the enumerated pin + gitignored run-5 files.
- `/tmp` artifacts: created at generation with recorded checksums; Phase 2 re-verifies rather than recreating.
- Overlaps Found: none. Escalation Status: none.
- Decision Citation: owner direction 2026-07-03 (`docs/meta-loop-direction.md` §"Next Step", owner-direction entry) — Fable-tier generation of this plan is its first concrete action; the run-5 pause constraint and live-install protection are recorded there and in the relay hand-off.

## Plan Approval and Commit Status

- Approval Status: approved — with the loop-closure caveat recorded in Validation Loop Results: the §1.15 loop ran its full 3-iteration budget and ended at the cap with iteration-3's two blocking findings fixed in-iteration and mechanically fix-verified by the generator, not on a clean fourth reviewer pass (the cap does not permit one). The owner is informed of this exhaustion nuance via the watchdog; if the owner directs a fresh reviewer pass or any other disposition, that supersedes this approval.
- Approval Citation: the full §1.15 loop history is in Validation Loop Results — iteration 1 (three blocking findings, fixed), iteration 2 (missing-details clean; ambiguity two blocking findings, fixed), iteration 3 (two blocking findings, fixed and fix-verified; cap reached). The owner-required source-truth coverage review (iteration 1) verified every ordering-related constraint from the Claude Code spec is carried explicitly (Behavioral Constraints 1–10) with none paraphrased into vagueness or dropped; no finding recurred across iterations. Judge authority: the branch-1 tiering decision and owner direction 2026-07-03 (`docs/meta-loop-direction.md` §"Next Step") place plan generation and validation on the Fable tier with the spec's own reviewer gates; hard-block rows, exceptions, and the Landing Authorization still require their per-event reviewer+judge citations at execution time.
- Plan Commit Hash: the commit introducing this plan on side-repo `main`, made by the generating session immediately after this validation loop closed (a file cannot contain its own hash). The executor verifies it with `git log --format='%H %s' --diff-filter=A -- .agents/plans/story-rebase-cycle-f92dfac9c5daecc286e03b90ef20bb930cf68818.md` — exactly one commit must be returned. Empty output means the plan-approval gate never closed: STOP; execution is blocked per §1.14.11, and the executor never commits the plan itself. More than one commit is likewise a STOP (the plan file was removed and re-added at some point — that history needs invoker review before execution).
- Ready-for-Orchestration: yes for Phases 0–7 (calibration and the real cycle); Phase 8 additionally requires the Landing Authorization below.
- **Landing Authorization**: **GRANTED 2026-07-05** — owner instruction, verbatim "Land the 2.1.200", relayed by the showrunner/watchdog session under verified owner provenance. The run-5 pause this authorization waited on is over: run 5e closed 2026-07-05 at an observer-verified genuine STOP and run 6 closed clean the same day, both recorded in the parent direction doc at commit `d94922f` ("absorb runs 5–6, the sealed CC cycle … into the loop's stated state"). Landing-time reality notes: the pin-advance-and-push portion of landing already happened early under separate explicit owner authorization (parent `7c44a04`, 2026-07-03); the §1.16 Part 4 candidates were already folded into the parent spec by the owner tier (parent `2d541ce`), and the claude-code spec contains no stale-target-evidence lines at landing, so this phase's spec-edit component is empty. Anything outward beyond the already-authorized early push remains owner-gated.

## Validation Loop Results

- Iteration 0 (generation): sources — parent `docs/agent-specs/forward-port-spec.md` (Parts 1, 3, §4.3), parent `docs/agent-specs/claude-code-context-bonsai-spec.md`, the executed 2.1.156 plan + replay-set/baseline artifacts (buckets and row conventions), the Fable-tier OpenCode plan `0dfbeeda…` (structure and §1.15 quality bar), side-repo sources (`patches/anchors.ts`, `patches/discovery.ts`, `apply/apply-bonsai.ts` `--path` support, `apply/tweakcc-api.ts` `readContent` signature, `e2e/native-e2e.ts` stale sites, `docs/e2e-protocol.md`, `README.md`, `docs/semantic-anchor-analysis-2.1.156.md`). Generation executed the freeze for real: npm identities captured and integrity-verified (sha1 + sha512), the platform binary downloaded and version-asserted, the bundle extracted via tweakcc 4.0.13, and all eight anchor selectors probed against the real 2.1.200 bundle — the drift-scan table records live results, not predictions. The live install was never touched.
- Iteration 1 missing-details review (independent reviewer, repository-inspecting): **one blocking finding** — the Plan Approval section claimed a plan commit that did not yet exist, and the bound verification command had no defined outcome on empty output; Phase 0's parenthetical contradicted the Approval section about the plan file's commit state. Fixed: the Approval section now states the commit is made by the generating session immediately after loop closure, empty verification output is a bound STOP, and Phase 0's status-line rule names the plan file as required-committed. Everything else verified correct against reality: all frozen npm values literal-for-literal, all `/tmp` artifact checksums and the binary's version output, every enumerated stale-site line number, every named file and exported symbol, the drift-scan block re-run reproducing the generation table exactly (including the token-usage `AnchorAmbiguousError` at 52 vs 47), all `jq` checks valid, toolchain present, `bun test` (163 pass) and `typecheck` green, and all spec-section citations accurate.
- Iteration 1 ambiguity review (independent reviewer, repository-inspecting): **two blocking findings** — (1) the Goal referenced a "calibration brief" that exists nowhere, leaving calibration executors a genuine fork (invent a remapping vs. mutate the real repo under the calibration label); fixed with the in-plan Execution-mode rule (fixed REAL-CYCLE/CALIBRATION discriminator, mechanical path substitution, serial-runs rule, Phase 8/9 applicability, STOP when unstated). (2) E2E-08's `prune-guard-live` command deferred to harness usage output whose `--binary` flag is optional and falls back to a live-install-shaped default; fixed by binding the literal command with `--binary "$TARGET_NATIVE_BINARY"` mandatory. Non-blocking findings fixed: stale-default replacement rule made explicit (version-bump in place, path shapes preserved); Phase 8 step-2 copy source reduced to one method. Non-blocking finding accepted as-is: Phase 7 commit-count latitude (no downstream check depends on it).
- Iteration 1 source-truth coverage review (owner-required; Claude Code spec constraint coverage, ordering rules especially): **zero blocking findings** — all ordering/marker-coverage constraints, all fail-closed sub-bullets, the patch-anchor evidence requirements, and the threshold-immutability rules carried explicitly at full strength, several verbatim; no forbidden weakening anywhere; independent pass found no spec constraint that looks obsolete (no FOR-OWNER quotation warranted). Two non-blocking scope-granularity notes fixed: E2E-02 now names the tool-call name/input/output pattern-diversity requirement; E2E-05 now names both fail-closed error paths distinctly.
- Iteration 2 missing-details review (fresh reviewer, repository-inspecting): **zero blocking findings.** Re-verified live: every enumerated stale-site line number, the E2E-08 flags (`--binary`/`--cwd`/`--out` all real in `parseArgs`), the Execution-mode rule's decidability, the drift-scan reproduction (token-usage `AnchorAmbiguousError` 52 vs 47 again), `bun test` 163-pass, all checksums and exports, the iteration-1 records' accuracy. One non-blocking hygiene finding: the Approval section pre-declared iteration-2 outcomes before they were recorded — fixed by keeping Approval Status honest at every commit point (it reads `approved` only after the closing iteration's record exists in this section).
- Iteration 2 ambiguity review (fresh reviewer, repository-inspecting): **two blocking findings**, both unbound-value gaps in the family iteration 1 fixed for `--binary`: (1) E2E-08's `--cwd` was an angle-bracket placeholder while the harness defaults to the invoking directory and its session discovery can glob a wrong/stale JSONL — fixed by binding `E2E_SCRATCH=$(mktemp -d /tmp/cc-bonsai-e2e/scratch-XXXXXX)` with `--cwd "$E2E_SCRATCH"`, fresh per run; (2) `$TARGET_NATIVE_BINARY` appeared in ~10 commands but no bound command ever assigned it — fixed with an explicit `export` as Phase 0's first command plus a shell-persistence rule. Non-blocking findings fixed: multi-commit outcome for the plan-commit verification bound as STOP; `discovery.test.ts` line 81's historical test title excluded from the stale-site replacement rule; the CALIBRATION substitution wording tightened to name the single path anchor it redefines. Baseline row 04, the relay-drift allowlist, Phase 8 ordering, and the hard-block boundary re-verified decidable.
- Iteration 3 ambiguity review (fresh reviewer, repository-inspecting; the missing-details pass already returned zero blocking at iteration 2): **two blocking findings**, again in the unbound-value family: (1) `prune-effect`'s `--from-uuid`/`--to-uuid` had no extraction rule in the plan or the protocol doc — fixed by binding `jq` extraction from `pre.jsonl` keyed to the scenario's unique boundary phrases, fail-closed on zero-or-multiple matches (Protocol-B capture-step precedent); (2) the token-usage candidate-enumeration aid told the executor to import `tokenUsagePatterns` from `patches/anchors.ts`, where it is module-private — fixed by binding the aid to import only the exported `findCandidates`/`scoreCandidates` from `patches/discovery.ts` and inline a verbatim, non-authoritative copy of the patterns/scorer, with an explicit no-export-edit rule. Non-blocking findings fixed: Phase 8's landing temp dir bound to `mktemp -d`; a fixed retry rule added for all live scenarios (record-then-fix-or-STOP; Protocol A keeps §1.17). All prior fixes re-verified decidable by this pass; no finding from any iteration recurred.
- **Loop closure (cap reached).** §1.15 allows up to 3 iterations; iteration 3 found blocking findings, so the loop ends at the cap rather than on a clean pass. Closure evidence in lieu of a fourth reviewer pass (which the cap does not permit): both iteration-3 blocking fixes are executability defects and were **mechanically verified by the generator** — the bound `jq` extraction commands were executed against a synthetic session JSONL (uniqueness test passes on unique phrases, correctly fails on duplicates) and the inline-copy aid script was executed against the real frozen 2.1.200 bundle (it runs, and reproduces the 52-vs-47 candidate anatomy now recorded in the Inventory section). Exhaustion anatomy for the record: no finding recurred across iterations; each round surfaced new, progressively narrower gaps (structural → command-binding → command-binding), all fixed in-iteration. This exhaustion nuance is reported to the owner via the watchdog with the plan's staging commit.

- **Amendment 1 (2026-07-03, after calibration run 1; Fable-tier observer).** Run 1 (Opus-4.8-low executor, scratch clone `/tmp/cc-cal-run-1`) executed Phases 0–5 clean — freeze re-verified, baseline captured, drift scan reproduced, token-usage re-derived semantically with thresholds untouched, post-replay validation green — drove 8 of 11 immutable-scope rows to genuine PASS, and STOPped correctly at seal gate 11 over three undriven scenarios. Verdicts: two in-run executor slips (semantic-doc field header broke the exact-substring validator; effect-oracle seeded its boundary on the protected first message) — **EXECUTOR-FAIL**, both self-corrected under the retry rule; the Phase-6 boundary-capture `jq` counting uuid-null metadata rows — **SPEC-GAP**, fixed in place above (string-uuid guard); E2E-00/04/05 left `BLOCKED` under an invented reason code — **SPEC-GAP** (the plan carried no bound verdict path for them; observer note: the executor successfully drove the equally-unbound E2E-01/02/03/06, so the gap is decidability, not possibility). Fixes in this amendment: E2E-00 bound to its local verdict predicate (2.1.156 executed precedent); E2E-05 bound to `PASS (unit-verified)` via two new Constraint-10 tests (run-1 review found the precedent's claimed unit coverage does not exist at `SOURCE_HEAD_SHA`; net-new coverage, scope strengthened); E2E-04 conditional exception recorded (2.1.156 precedent citation; owner notified, override supersedes); `/tmp/cc-bonsai-e2e/` runtime-output clarification in the Execution-mode rule. No frozen input, threshold, behavioral constraint, or bound Phase 0–5 command changed. **Independent reviewer pass (repository-inspecting, Opus tier, 2026-07-03): APPROVE, zero blocking findings** — every factual citation verified against the repo and precedent docs (including the E2E-05 coverage-gap claim and the parent plan's E2E-04 exception allowance), the jq guard verified empirically against uuid-null row shapes, all four bindings judged mechanically decidable, E2E-04's exception judged *stricter* than the bare precedent allowance. This review is the reviewer sign-off the E2E-04 exception cites. Non-blocking observations recorded: (NB1) bound E2E-05 test (2) exercises parse corruption on a non-final line — the closest driveable fail-closed read path; no code path maps valid-but-shape-drifted JSON to the compatibility error, so the scope line's "schema drift" is covered at its enforceable strength, not weakened; (NB2) E2E-04 condition (b)'s field naming is family-level but decidable; (NB3) resolved by this recorded sign-off.
- **Amendment 2 (2026-07-03, after calibration run 2; Fable-tier observer).** Run 2 (Opus-4.8-low, scratch clone `/tmp/cc-cal-run-2`, plan at Amendment 1) was the first fully clean execution: all phases green, zero STOPs, seal gates 1–13 pass, all Amendment-1 bindings exercised as designed (E2E-00 `install-procedure-pass`; E2E-05 `compat-error-unit-verified` via the two net-new tests, 166-test suite green; E2E-04 `PARTIAL` covered by the recorded exception with both compensating conditions evidenced). Observer re-verification: live install and frozen binary pristine, change-scope diff exactly planned-targets ∪ allowlist, the new Constraint-10 tests re-run green independently. Two executor slips recurred identically from run 1 (semantic-doc field labels missing the validator's exact substrings; effect-oracle first seeding on the protected first message), both self-corrected under the retry rule — verdict stays EXECUTOR-FAIL, but two identical recurrences across independent executions mark the judgment as removable, so this amendment binds both: the semantic-doc format contract (section headings and the ten literal field labels, copied verbatim from `validateSemanticReport`'s `requiredSemanticSections`/`requiredSemanticFields` arrays in `e2e/native-e2e.ts` and mechanically re-verified against that source at edit time) and the E2E-08 seeding rule (no ALPHA on the protected first message). No scope, threshold, constraint, exception, or bound command semantics changed — both edits bind existing validator/host behavior the executor already had to satisfy.
- **Calibration closure and REAL-CYCLE authorization (2026-07-03).** Run 3 (Opus-4.8-low, `/tmp/cc-cal-run-3`, plan at Amendment 2) executed clean AND slip-free: zero STOPs, seal gates pass, full immutable e2e scope PASS or exception-covered, neither run-1/2 slip reproduced, observer re-verification clean. Decision, recorded with provenance: the watchdog session, acting for the owner under his standing delegation (owner slacked with an open override window, delivery-verified), ruled the repeated-clean-executions bar MET — two consecutive fully-clean executions with the third slip-free at declining cost — and authorized the REAL-CYCLE execution of this plan by the calibrated Opus-4.8-low tier. **Hard boundary attached to that authorization**: all in-repo work may proceed (commits are reversible), but no outward action — no push to any remote, no package publish, nothing that leaves this machine — executes on it; work parks at any such point pending the owner's explicit go. This boundary is congruent with Phase 8 step 4 (no invented publish ladder) and with the Landing Authorization remaining ABSENT (Phase 8 stays blocked while run 5 lives). Residual looseness carried to §1.16, not amended pre-run (the real cycle executes the calibrated artifact unchanged): Planned Target Files' "extend for the re-derived token-usage evidence" wording for `patches/anchors.test.ts` is permission-shaped, not a bound Phase-4 step — run-to-run variance observed and legal.

## Completion Checklist

- [ ] Plan validation loop closed (3-iteration cap, all findings fixed, iteration-3 fixes mechanically verified; see Validation Loop Results); plan committed to side-repo `main` (staged-for-parent).
- [ ] Freeze re-verified: both npm identities, tarball digests, binary sha256, bundle sha256, manifest fields.
- [ ] Baseline artifact complete: rows 01–04, no placeholders, rows 02–03 green, row 04 `fail-expected-stale-harness`.
- [ ] Drift scan reproduced; replay-set staged with 8 schema-valid rows; zero unresolved hard-blocking rows (or recorded resolution).
- [ ] Token-usage anchor re-derived semantically; thresholds unchanged; `docs/semantic-anchor-analysis-2.1.200.md` complete for all 8 anchors.
- [ ] Behavioral Constraints 1–10 preserved with regression evidence.
- [ ] Post-replay validation green; artifact-evidence passes against the frozen bundle.
- [ ] Live e2e immutable scope recorded with verdicts and reason codes; no unapproved BLOCKED/omission; live install untouched (version probe unchanged).
- [ ] Side-repo commits landed; seal gates 1–13 pass.
- [ ] Phase 8 executed only after Landing Authorization; parent commit = landed artifacts + stale-evidence spec lines + pin; final verification green.
- [ ] §1.16 maintenance report staged with the four pre-identified slot flags and any new verdicts.
