# Maintenance Report — 2.1.200 Forward-Port Cycle (§1.16)

- Cycle: forward-port Context Bonsai to `@anthropic-ai/claude-code@2.1.200`
- Source: `f92dfac9c5daecc286e03b90ef20bb930cf68818` (side-repo `main`)
- Executor: Opus-4.8-low, REAL-CYCLE. Standing boundary honored: no outward action (no push/publish); all work in-repo and reversible.
- Outcome: SEAL. Phases 0-7 and 9 executed; Phase 8 did not run (Landing Authorization ABSENT). Seal gates 1-13 pass.

## Changed slot-level facts (with evidence)

1. **`context-bonsai-gauge.token-usage` required scorer strengthening (updated_anchor).** At 2.1.200 the per-request usage accumulator (`a6p(e,t,n)`, 2.1.156 `Wu5` shape) tied with the zero-arg usage-display formatter (`o6p()`) at 52 vs 47, within `minMargin 10`, because both share the identical zero-initialized usage record literal `{inputTokens:0,...,contextWindow:0,maxOutputTokens:0}`; selection fail-closed with `AnchorAmbiguousError`. Re-derived semantically: added `+15` for the accumulator-entry nullish-coalesce init (`??{inputTokens:0`) and `-25` for building a `"Usage"` display string — both grounded inside the captured text (the greedy match ends at the record literal's brace). Post-strengthening `a6p`=62, `o6p`=27, margin 35; `minScore 15`/`minMargin 10` unchanged. Evidence: `docs/semantic-anchor-analysis-2.1.200.md#context-bonsai-gaugetoken-usage`.
2. **Seven anchors unchanged across the ~44-release hop.** `archived-filter.visibility` (105/1), `message-content-ids.converter` (`mVf(e,t=!1,n,r)`, 110/24), `context-bonsai-gauge.attachment-pipeline` (`I8a(e,t)`, 50/17), `context-bonsai-gauge.reminder-render` (40/1), runtime helpers `Xt`/`rr`/`Dt`. Minified identifiers renamed but structural selectors and captured-identifier discipline held. Evidence: Phase-4 drift scan reproduced the generation table exactly.
3. **E2E-05 Constraint-10 regression-anchor gap closed.** The 2.1.156 results claimed unit coverage of the compatibility fail-closed paths that did not exist at the source SHA. This cycle added two net-new tests to `mcp-server/index.test.ts` (missing session JSONL; malformed non-final line). Net scope strengthening.

## Failure attribution (every stumble)

- **prune-effect first invocation "Module not found e2e/native-e2e.ts".** Ran the bound harness command from the seeding work dir instead of the repo root. **EXECUTOR-FAIL.** Self-corrected under the retry rule by re-running from the repo with absolute `--pre-session`/`--session` paths; verdict PASS.
- **E2E-07 first seeding: boundary phrase non-unique (`BETA-START-002` matched 6 string-uuid rows).** The model echoed the capitalized boundary marker in its acknowledgments, inflating the match count past 1 and making the prune ambiguous. Recovered under the Protocol-B capture-step precedent (re-seed with genuinely unique phrases) by instructing the model to reply only "ok" and not repeat the marker; both boundaries then matched uniquely. **SPEC-GAP (minor, Part 3 §3.5 seeding-guidance candidate):** Amendment 2's seeding rule binds only "no ALPHA on the protected first message"; it does not warn that the driven model will echo a capitalized boundary token and break the exactly-one-match precondition. A bound seeding instruction ("instruct the driven model not to repeat the boundary markers; reply-only-ok") would remove this run-to-run recovery step. Flagged, not fixed pre-run (real cycle executes the calibrated artifact unchanged).

## Pre-identified slot flags carried (Part 4 candidates — spec edits deferred past run-5 exit)

- (a) **§4.3 extraction/runtime binding assumes target == live install.** This cycle proved the `/tmp` platform-package route (download the `@…-linux-x64` tarball's `package/claude`, extract with tweakcc, drive by explicit `--path`) as the working generalization when the live install is a different, untouchable version (2.1.198 vs target 2.1.200). Proposed Part 4 edit (text, uncommitted while parent is frozen): §4.3 should name the explicit-frozen-install-path route as a first-class alternative to the live-install assumption, with the `--path`/`--binary`/`--cwd` explicit-flag discipline.
- (b) **§4.3's `claude --version | grep <version>` preflight assumes live == target.** Superseded this cycle by asserting `"$TARGET_NATIVE_BINARY" --version` on the frozen binary. Proposed Part 4 edit: the preflight should assert the version of the runtime-under-test binary by explicit path, not the live shim.
- (c) **Relay-drift allowlist as a Part 3 §3.5 shape-gap candidate.** The hand-off relay commits bookkeeping (`HAND_OFF`/`.agents/plans/`) to `main` between generation and execution; the drift handling assumed no interleaved bookkeeping commits. The allowlist preflight worked cleanly this run (HEAD `b751ace` differed from the frozen SHA only by `HAND_OFF.md` + the plan file). Proposed Part 4 edit: §3.5 should bless a bookkeeping allowlist as the drift-handling shape.
- (d) **The Claude Code installation-e2e instance remains unrecorded anywhere.** E2E-00 was accepted this cycle by its Amendment-1 local README-procedure predicate (apply/mcp-list/restore), not a fresh-sprite full-parity install. The durable installation-e2e instance (§4.2 rule) is still not recorded. Flagged, not invented.

## Disposition deviation from §1.16 (recorded)

The §1.16 default — leave the Part 4 edit uncommitted in the parent working tree — is unavailable while run 5 lives (parent dirt is frozen; the only allowed parent change is Phase 8's own pin advance). This report therefore records the proposed Part 4 diffs as text above; applying them as an uncommitted parent edit happens at Phase 8 landing or later owner review. No slot-level fact changed beyond the pre-identified flags and the token-usage re-derivation recorded above.

## Core / shape gaps for the owner tier

- Core: none. No Behavioral Constraint (1-10) looked obsolete against 2.1.200; none was weakened; no threshold lowered. No FOR-OWNER spec-quotation warranted.
- Shape: the seeding-guidance SPEC-GAP above (marker echo) and the four pre-identified Part 4 candidates.
