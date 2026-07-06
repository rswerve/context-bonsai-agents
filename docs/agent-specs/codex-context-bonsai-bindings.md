# Codex Context Bonsai Bindings

This is the exploration-derived bindings layer for the Codex port: the structural facts about the harness and the side repo (file paths, function names, storage locations, JSON shapes) that realize the obligations in [`codex-context-bonsai-spec.md`](codex-context-bonsai-spec.md). It is the derivation pipeline's Stage 1 output (`derivation-pipeline-spec.md` §4) and the demotion target for `structural-*` escalation codes (§2.2): on a structural break, everything in this document becomes an untrusted prior and may be rewritten from fresh exploration. The sibling contract spec changes only when the product's behavior contract changes or a Stage 2/3 re-run revises the posture; it references this document by binding key, never the reverse direction for obligations.

Evidence in this document was verified against Codex's `codex-rs` core in the `codex/` fork repo and the side repo `codex_context_bonsai/`; this harness is not yet bound in `forward-port-spec.md` Part 4, so per-release re-verification does not yet run through that document's cycle machinery — these bindings date from the implementation epic and must be re-verified before any cycle binds them.

## Capability Evidence Matrix

| Area | Status | Notes |
|---|---|---|
| Persistent thread history | Verified | Thread store and rollout-backed persistence exist |
| Tool execution layer | Verified | Tool registry and handler pipeline are strong |
| Hook system | Verified | Hooks can inject additional context/messages |
| Authoritative transcript rewrite outside core | Missing | No verified non-core path can replace arbitrary existing prompt history |
| System guidance path | Verified | Existing hook-added context provides a model-visible guidance path |
| Token/context tracking | Verified | Context manager and session state track usage and windows |
| Replacement-history checkpoint machinery | Verified | Core already has atomic history replacement plus persisted compaction snapshots |

## Verified Host Primitives

- Thread and history persistence exist in [thread-store](/home/basil/projects/context-bonsai-agents/codex/codex-rs/thread-store/src/store.rs) and [types.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/thread-store/src/types.rs).
- Prompt-ready history is produced by [history.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/context_manager/history.rs) and sent from [turn.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/session/turn.rs).
- Tool handling is centralized in [registry.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/tools/registry.rs).
- Initial system and developer context assembly is in [session/mod.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/session/mod.rs).
- Hook runtime exists in [hook_runtime.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/hook_runtime.rs).
- Core exposes authoritative history replacement through [replace_history](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/session/mod.rs#L2402) and [replace_compacted_history](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/session/mod.rs#L2411).
- Existing compaction persists replacement-history checkpoints in [compact.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/compact.rs#L279) and rebuilds them on resume in [rollout_reconstruction.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/session/rollout_reconstruction.rs#L234).

## Unverified Or Weak Areas

- Hooks clearly support additive context and guidance injection, but not transcript replacement.
- App-server surfaces can append items and trigger rollback or compaction, but they do not provide arbitrary contiguous-range replacement for an existing thread.
- The remaining open question is API shape, not whether a core replacement seam is required.
- The message-projection function (binding: `searchable-text`) now emits searchable text for every model-visible `ResponseItem` variant (`extract_text` in `codex/codex-rs/core/src/context_bonsai.rs`, with non-model-visible variants deliberately projecting empty) — closing the v1 gap the original spec recorded (v1 extracted only `FunctionCall.arguments` and `CustomToolCall.input`, returning empty for tool-output and other variants, a spec violation).

## Binding Sites

Each key below is referenced from the contract spec's obligations. A key's site column is the current realization; rewriting a site (new path, new function, new storage location) is a bindings-layer change and does not require a contract-spec edit as long as the obligation it realizes still holds.

| Binding key | Current site | Realizes (contract-spec obligation) |
|---|---|---|
| `prune-wrapper-filter` | Side crate's pattern resolver in `codex_context_bonsai/src/guards.rs`, operating on the projected `MessageForMatching` slice produced by `project_message_for_matching` | Prune and retrieve contract: Pattern Matching Contract prune-wrapper filter on the ambiguity path |
| `searchable-text` | `project_message_for_matching` in `codex/codex-rs/core/src/context_bonsai.rs` | Prune and retrieve contract: Pattern Matching Contract bullet 1 (non-empty searchable text for every tool-call-bearing `ResponseItem` variant, including name and output) |
| `prompt-history-path` | `ContextManager` in [history.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/context_manager/history.rs), whose `for_prompt(...)` output is sent from [turn.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/session/turn.rs) | Transcript mutation path: canonical prompt-history source that any mutation implementation must transform, not shadow |
| `app-server-mutation-apis` | App-server `thread/inject_items` and `thread/rollback` RPCs | Transcript mutation path: noted as insufficient for bonsai parity (append-only / suffix-drop only) |

## Key References

- [history.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/context_manager/history.rs)
- [turn.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/session/turn.rs)
- [session/mod.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/session/mod.rs)
- [registry.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/tools/registry.rs)
- [hook_runtime.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/core/src/hook_runtime.rs)
- [thread-store/src/store.rs](/home/basil/projects/context-bonsai-agents/codex/codex-rs/thread-store/src/store.rs)
