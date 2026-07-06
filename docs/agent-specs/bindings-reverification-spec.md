# Bindings Re-Verification Pass

Bindings documents rot: they record exploration-derived structural facts (paths, function names, storage shapes) that drift as harnesses and side repos evolve. Two measured instances motivated this procedure — the contract/bindings split review corrected four stale claims carried from earlier exploration, and the Kilo Stage-5 rehearsal caught three real drifts the bindings had missed. This document specifies a repeatable pass that re-checks every bindings claim against pinned source and records the result as committed evidence, so routine cycle-plan generation can consult binding freshness instead of trusting document age. That consultation is wired in as the bindings-freshness consultation step of `forward-port-spec.md` §1.15: a DEMOTED row the plan would bind blocks generation, and a pass record older than the harness's last cycle start flags the bindings as stale evidence.

## Scope

One pass covers every row of the **Binding Sites** table in each of the six bindings documents in this directory:

`claude-code-context-bonsai-bindings.md`, `cline-context-bonsai-bindings.md`, `codex-context-bonsai-bindings.md`, `gemini-cli-context-bonsai-bindings.md`, `kilo-context-bonsai-bindings.md`, `pi-context-bonsai-bindings.md`

The Capability Evidence Matrix and Verified Host Primitives sections are realized by the same sites the table rows name; they are re-checked only transitively (a demoted row demotes the matrix/primitive claims it cites). OpenCode has no bindings document — its level-2 bindings live in `forward-port-spec.md` Part 4 and are maintained by that spec's own cycle machinery, outside this pass.

## Probe targets

Each document is probed against the **pinned port state**: the parent repo's current submodule commits for that harness's fork and side repo, recorded by SHA in the pass record. The Claude Code port has no fork submodule (closed-artifact shape); its probe target is the `tweakcc_context_bonsai` side repo at its current HEAD, plus the host-level claims (`~/.claude.json` shape, JSONL location) checked against the locally installed Claude Code. Rows naming host-machine state that no pinned repo captures (e.g. a config file's live shape) are probed against the live machine and the evidence says so.

## Tier boundary

- **Cheap tier (probing)**: one read-only subagent per bindings document verifies each row's site cell — file exists, named function/hook/key is present, and each specific factual claim in the cell holds — returning per-row structured verdicts with `file:line` evidence and the probed repo SHAs. Probes never edit anything.
- **Owner tier (judgment)**: disposition of each verdict, any demotion edits to the bindings documents, and the pass record itself. The judgment call a probe cannot make — whether a mismatch is a broken binding or a claim that is merely stated loosely — stays on the owner tier.

## Dispositions

Every row receives exactly one disposition in the pass record:

- **VERIFIED** — every checkable claim in the site cell holds at the probe target. Evidence: `file:line` cites and the probed SHA.
- **DEMOTED** — a claim failed or could not be located. The row's site cell is annotated in place with `**UNVERIFIED (<pass date>):** <what failed>` — the original claim text is preserved, never silently rewritten to a new site — and the pass record gains a follow-up entry naming the harness, the row, and what re-exploration must establish. A demoted row is an untrusted prior: the next cycle for that harness must re-derive it through Stage 1 before binding it.

A pass never repairs bindings. Repair is Stage-1 re-exploration under the derivation pipeline, done by (or ahead of) the harness's next cycle, so the fix carries fresh evidence instead of a spot-patch.

## Pass record

Each pass commits `bindings-reverification-<YYYY-MM-DD>.md` to this directory: per harness, the probed SHAs, a per-row disposition table (binding key, disposition, one-line evidence), and a Follow-Ups section listing every demotion. Routine cycle-plan generation consults the most recent pass record per `forward-port-spec.md` §1.15 (bindings-freshness consultation); a bindings document whose latest pass is older than the harness's last cycle start (per the cadence ledger) is stale evidence and generation records it as such.

## Hygiene

Probes are read-only; the pass creates no scratch state outside the probing agents' own session scratchpads (`forward-port-spec.md` §1.19 imposes nothing further). The only working-tree changes a pass may make are demotion annotations in bindings documents and the new pass record, committed together.
