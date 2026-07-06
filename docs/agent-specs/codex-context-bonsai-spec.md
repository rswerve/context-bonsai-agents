# Codex Context Bonsai Spec

## Purpose

This document specializes the shared Context Bonsai contract for Codex.
Codex has durable thread state, usage tracking, tools, hooks, and app-server surfaces. The core seam question is now resolved: hook-side and plugin-side paths can inject model-visible guidance, but authoritative prune/retrieve transcript replacement requires a small core seam built on the existing replacement-history compaction machinery.

This is the **contract half** of the per-harness spec: the obligations and posture decisions that change only when the product's behavior contract changes or an integration-posture re-run revises them. The structural facts that realize these obligations — harness file paths, function names, storage locations, JSON shapes — live in the sibling [`codex-context-bonsai-bindings.md`](codex-context-bonsai-bindings.md) and are referenced here by `binding key`; the bindings document is the derivation pipeline's rewritable layer (`derivation-pipeline-spec.md` §2.2) and may change without an edit here so long as each referenced obligation still holds.

## User Model

### User Gamut

- TUI users running long Codex sessions
- users relying on stored threads and rollout history
- teams integrating Codex through MCP or app-server surfaces
- maintainers who need a fail-closed design when runtime seams are still moving

### User-Needs Gamut

- preserved thread correctness after prune and retrieve
- deterministic behavior across local thread storage and exported history
- gauge signals based on real context usage rather than guesswork alone
- implementation paths that do not assume hooks can already rewrite transcript history if they cannot

### Ambiguities From User Model

- The remaining design choice is not whether a core seam is needed, but how narrow that seam can be while keeping most bonsai logic outside core.

## Integration Posture

### Required architecture stance

- Hooks, plugins, or app-server surfaces SHOULD be exhausted first before core patches are proposed.
- Codex Context Bonsai MUST use hooks and plugins for guidance, gauge delivery, and tool exposure wherever possible.
- Codex Context Bonsai MUST use a narrow core seam for authoritative prune/retrieve history replacement, because no non-core path currently reaches the real prompt history with replacement semantics.
- Future implementation planning SHOULD center that seam on the existing replacement-history checkpoint path rather than inventing a broader arbitrary-history mutation mechanism.

### Prune and retrieve contract

- The target model-facing contract is still `context-bonsai-prune` and `context-bonsai-retrieve`.
- Tool definitions SHOULD live in the existing tool registry.
- Tool execution SHOULD delegate to a minimal core capability that installs a new replacement-history snapshot for the live thread and persists the corresponding rollout item.
- Per shared spec Pattern Matching Contract, the prune-wrapper filter on the ambiguity path MUST be implemented inside the side crate's pattern resolver (binding: `prune-wrapper-filter`), operating on the projected message-for-matching slice produced by the message-projection function (binding: `searchable-text`).
- Per shared spec Pattern Matching Contract, the message-projection function (binding: `searchable-text`) MUST emit non-empty searchable text for every `ResponseItem` variant that represents a completed tool call or tool-call output the model can see. The projection MUST include the tool-call name AND output for each variant, in addition to the input.

### Transcript mutation path

- The canonical source of prompt history appears to be the context manager plus session turn assembly (binding: `prompt-history-path`).
- Any implementation MUST mutate or transform the same history path used to build the prompt (binding: `prompt-history-path`), not a parallel shadow log only.
- The preferred mutation mechanism is to reuse the existing replacement-history install path already used by compaction.
- App-server mutation APIs (binding: `app-server-mutation-apis`) are insufficient for bonsai parity because they only append items or drop suffix turns.

### System guidance path

- Bonsai guidance SHOULD use the already-verified hook-side context injection path unless a stronger path is later shown to be necessary.

### Gauge path

- Gauge SHOULD reuse session/context-manager token data and model context window resolution.
- Hook-added context MAY be acceptable for gauge delivery if it is confirmed to be model-visible and ordered correctly.
- Gauge does not require the same core seam as prune/retrieve; it can remain hook-side if cadence and ordering are reliable.

## Fail-Closed Requirements

- If the replacement-history core seam is unavailable, prune/retrieve MUST fail closed rather than degrade into additive summaries.
- Hook-only additive summaries are not sufficient to claim prune parity.
- Any future patch or hook matcher must fail closed when runtime structure changes.

## Parity Gaps Against Shared Spec

- The main gap is that Codex does not currently expose the replacement-history path as a bonsai-oriented capability.
- Tooling, persistence, token tracking, and guidance injection are already strong.
- Codex is viable for bonsai, but unlike Kilo/OpenCode it needs one small core seam before the rest can live outside core.

## Specified Implementation Direction

- Preferred: hybrid design where hooks/plugins own guidance, gauge, and tool exposure, while a minimal core seam installs replacement-history snapshots for prune/retrieve.
- Acceptable: exposing that seam through app-server or internal session APIs, provided the actual history replacement still uses the canonical core path.
- Not acceptable: claiming parity based only on additive hook messages or external sidecar inspection.

## E2E Priorities

- prove placeholder rendering in the exact prompt path sent to the model
- verify thread persistence and retrieval across stored thread resume
- verify gauge delivery in-band
- verify fail-closed behavior when mutation seam is unavailable

## Key References

Structural references (source files, storage locations, seam sites) live in [`codex-context-bonsai-bindings.md`](codex-context-bonsai-bindings.md) §Key References.
