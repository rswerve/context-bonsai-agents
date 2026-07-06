# Pi Context Bonsai Spec

## Purpose

This document specializes the shared Context Bonsai contract for Pi.
Pi is an unusually strong fit for a first-party extension implementation because its `ExtensionAPI` already exposes model-facing tools, context transforms, system-prompt mutation, custom session entries, usage data, and session lifecycle events. The main implementation constraint is not host capability; it is preserving Pi's in-tree extension architecture and accounting for the fact that LLM messages do not carry stable message ids.

This is the **contract half** of the per-harness spec: the obligations and posture decisions that change only when the product's behavior contract changes or an integration-posture re-run revises them. The structural facts that realize these obligations — harness file paths, function names, storage locations, JSON shapes — live in the sibling [`pi-context-bonsai-bindings.md`](pi-context-bonsai-bindings.md) and are referenced here by `binding key`; the bindings document is the derivation pipeline's rewritable layer (`derivation-pipeline-spec.md` §2.2) and may change without an edit here so long as each referenced obligation still holds.

## User Model

### User Gamut

- Pi terminal users running long coding sessions through print mode, TUI mode, or RPC automation
- Pi maintainers reviewing an opt-in first-party workspace extension
- extension authors using bonsai as an example of context transforms plus custom session state
- release-gate reviewers who need model-visible evidence rather than UI-only status

### User-Needs Gamut

- surgical context reclamation without losing recoverability
- durable archive state across reload, resume, and process restart
- pattern matching over text and tool-call structures, not text-only transcripts
- gauge signals delivered in-band to the model, including headless/print-mode runs
- minimal or no Pi core changes while preserving deterministic fail-closed behavior

### Ambiguities From User Model

- Whether Pi should intentionally diverge from the shared same-step retrieve guard. Pi intentionally keeps the simpler same-turn prune+retrieve no-op behavior.
- Whether bonsai should integrate with Pi's built-in compaction strategy. This spec leaves that out of scope; bonsai remains an opt-in surgical pruning extension.

## Integration Posture

### Required architecture stance

- Pi Context Bonsai MUST be implemented as a standalone extension package in the `pi_context_bonsai` side repository. It MUST NOT live in-tree inside pi-mono.
- The extension is loaded through Pi's extension discovery (binding: `extension-discovery`). The wiring MUST work regardless of the directory Pi is launched from.
- Pi requires no fork. The extension integrates entirely through Pi's public extension API (binding: `extension-api`) and makes no modification to pi-mono source. A pinned pi-mono reference MAY be kept for testing, but it carries no Context Bonsai code.
- Pi core changes are not required and none are present. If a future capability genuinely cannot be delivered through the extension API, a narrow core change is the last resort per the shared spec, and the missing primitive MUST be identified before implementation.
- The implementation MUST use Pi-native session custom entries for archive records and tombstones (binding: `archive-store`) rather than an external shadow store as the authority.

### Prune and retrieve contract

- The model-facing tools MUST be `context-bonsai-prune` and `context-bonsai-retrieve`.
- The prune tool MUST use pattern boundaries with required `from_pattern`, `to_pattern`, `summary`, and `index_terms`, plus optional `reason`.
- Pattern matching MUST include stable searchable representations of normal message text and tool-call structures (binding: `searchable-text`).
- Per shared spec Pattern Matching Contract, ambiguous pattern handling MUST apply the prior prune-wrapper filter before returning ambiguity, so retry attempts are not poisoned by echoed `from_pattern` / `to_pattern` text.
- Archive records MUST include anchor/range-end identifiers, summary, index terms, optional reason, and enough correlation metadata to find those messages in later outgoing transcript transforms (binding: `message-correlation`).
- Retrieve in Pi intentionally supports same-turn prune+retrieve as a no-op: prune writes archive state, retrieve writes tombstone state, and tombstone precedence makes the range visible again immediately.
- Prune and retrieve tools MUST set sequential tool execution (binding: `sequential-execution`).

### Transcript mutation path

- Placeholder rendering and follower-message elision MUST happen through the extension's context-transform hook (binding: `transcript-mutation`).
- The transform MUST correlate archive anchors using the bound correlation strategy, not by positional zip against the branch entry list (binding: `message-correlation`).
- If an archive's anchor or range end cannot be located in a given outgoing transcript, the transform SHOULD skip that archive for the turn without deleting persisted state.
- The placeholder MUST retain the canonical information: anchor id, range-end id, summary, and index terms.

### System guidance path

- Bonsai guidance SHOULD be appended by extending the effective system prompt (binding: `guidance-channel`).
- Guidance semantics MUST remain aligned with the shared spec: protected context, ranking, drift, non-destructive pruning, and retrieval rules must be model-visible.

### Gauge path

- Gauge delivery MUST be in-band (binding: `gauge-channel`).
- The gauge MUST use the shared spec's four locked bands: `<30%`, `30-60%`, `61-80%`, and `>80%` with `PRUNE NOW` in the urgent band.
- Gauge cadence SHOULD be every 5 turns by default.
- If usage data is unavailable or null, the gauge MUST remain silent (binding: `usage-api`).
- Human-visible TUI status may be added but cannot substitute for the model-visible gauge.

## Fail-Closed Requirements

- If required host primitives are unavailable or incompatible (binding: `host-compat-surface`), prune/retrieve MUST fail closed with explicit deterministic compatibility errors.
- Failed prune or retrieve calls MUST leave archive state and model-visible transcript state unchanged.
- Runtime hook or shape changes MUST not silently no-op while reporting success.
- Gauge capability gaps may degrade to partial parity, but prune/retrieve capability gaps must be explicit errors.

## Parity Gaps Against Shared Spec

- Host capability gaps are minimal; Pi exposes the required primitives through first-party extension APIs.
- The main parity risk is message identity: Pi requires archive records to bridge durable session-entry ids and id-less outgoing messages through correlation (binding: `message-correlation`).
- The second risk is transcript shape fidelity: tool calls and tool results must be included in pattern-matching text extraction, not just visible text blocks.
- The third risk is interaction with built-in compaction and branch summaries; transform tests must cover synthetic context entries.

## Specified Implementation Direction

- Preferred: a standalone extension in the `pi_context_bonsai` side repository, owning prompt guidance, tools, archive store, context transform, gauge, and tests.
- Acceptable: narrow Pi core seam only if a required primitive becomes unavailable or proves insufficient, with the missing capability documented before implementation.
- Not acceptable: an external sidecar-only implementation that cannot rewrite the actual outgoing transcript, a text-only matcher that ignores tool structures, or a UI-only gauge.

## E2E Priorities

- extension load and tool registration through Pi's extension discovery
- prune success with a persisted archive record (binding: `archive-store`) and model-visible placeholder on the next turn
- retrieve success with a persisted tombstone record (binding: `archive-store`) and restored visible transcript
- reload/resume persistence across a new Pi process
- gauge cadence and four-band severity text in the outgoing model-visible transcript
- same-turn prune+retrieve no-op behavior
- secret/sensitive-content prune oracle proving active context no longer contains pruned content

## Key References

Structural references (source files, storage locations, seam sites) live in [`pi-context-bonsai-bindings.md`](pi-context-bonsai-bindings.md) §Key References.
