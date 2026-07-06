# Cline Context Bonsai Bindings

This is the exploration-derived bindings layer for the Cline port: the structural facts about the harness and the side repo (file paths, function names, storage locations, JSON shapes) that realize the obligations in [`cline-context-bonsai-spec.md`](cline-context-bonsai-spec.md). It is the derivation pipeline's Stage 1 output (`derivation-pipeline-spec.md` §4) and the demotion target for `structural-*` escalation codes (§2.2): on a structural break, everything in this document becomes an untrusted prior and may be rewritten from fresh exploration. The sibling contract spec changes only when the product's behavior contract changes or a Stage 2/3 re-run revises the posture; it references this document by binding key, never the reverse direction for obligations.

Evidence in this document was verified against Cline's fork repo (`cline/`) and the side repo (`cline_context_bonsai/`); this harness is not yet bound in `forward-port-spec.md` Part 4, so per-release re-verification does not yet run through that document's cycle machinery — these bindings date from the implementation epic and must be re-verified before any cycle binds them.

## Capability Evidence Matrix

| Area | Status | Notes |
|---|---|---|
| Persistent transcript | Verified | API and UI histories are both stored on disk |
| Tool execution layer | Verified | Centralized coordinator and handlers exist |
| Hook system | Verified | Lifecycle hooks can inject additional context |
| Full transcript rewrite via hooks | Missing | Hooks can append context but do not replace canonical transcript history |
| System prompt assembly | Verified | Prompt assembly is internal and direct |
| Token/context tracking | Verified | Context window and truncation utilities already exist |
| Canonical history overwrite path | Verified | Core already persists and reloads overwritten conversation history |

## Verified Host Primitives

- Canonical task history lives in [message-state.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/task/message-state.ts) and [disk.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/storage/disk.ts).
- Tools are centralized through [ToolExecutor.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/task/ToolExecutor.ts) and [ToolExecutorCoordinator.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/task/tools/ToolExecutorCoordinator.ts).
- Hooks exist and can append context through [hook-factory.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/hooks/hook-factory.ts) and task-side hook handling in [index.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/task/index.ts).
- Context sizing and truncation logic already exists in [ContextManager.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/context/context-management/ContextManager.ts).
- Core already exposes canonical overwrite and restore mechanisms through [overwriteApiConversationHistory](/home/basil/projects/context-bonsai-agents/cline/src/core/task/message-state.ts#L186) and checkpoint restore flows in [checkpoints/index.ts](/home/basil/projects/context-bonsai-agents/cline/src/integrations/checkpoints/index.ts#L661).

## Unverified Or Weak Areas

- Hook APIs do not own canonical full-history replacement before every model call.
- Bonsai cannot safely rely on UI transcript state alone because API conversation history is the authoritative model-facing source.
- Existing `conversationHistoryDeletedRange` and context-history updates are optimized for cumulative truncation, not arbitrary bonsai archive placeholders, so a narrow extension is still needed.

## Binding Sites

Each key below is referenced from the contract spec's obligations. A key's site column is the current realization; rewriting a site (new path, new function, new storage location) is a bindings-layer change and does not require a contract-spec edit as long as the obligation it realizes still holds.

| Binding key | Current site | Realizes (contract-spec obligation) |
|---|---|---|
| `history-overwrite-seam` | `overwriteApiConversationHistory` in `cline/src/core/task/message-state.ts`; checkpoint restore in `cline/src/integrations/checkpoints/index.ts`; persistence/update path in `cline/src/core/context/context-management/ContextManager.ts`; the request-construction path that reaches `api.createMessage(...)` | Integration Posture: narrow core seam requirement; Prune and retrieve contract: narrowest-implementation extension path; Transcript mutation path: placeholder rendering site and preferred seam; Fail-Closed: unavailable-seam fail-closed trigger; Specified Implementation Direction: preferred hybrid design |
| `prune-wrapper-filter` | Side-repo pattern resolver in `cline_context_bonsai/src/guards.ts`, operating on the conversation-history snapshot `ContextBonsaiApplier` feeds into pattern resolution | Prune and retrieve contract: Pattern Matching Contract prune-wrapper filter on the ambiguity path |
| `searchable-text` | `extractMessageText` in `cline/src/core/task/ContextBonsaiApplier.ts`. Current implementation renders `tool_use` blocks as `[tool_use:${name} ${stableSerialize(input)}]` — name and input both reachable, closing the v1 gap the original spec recorded (v1 dropped `input` entirely, a Pattern Matching Contract bullet 1 violation). `tool_result` block extraction includes inner text and is compliant for the output side | Prune and retrieve contract: Pattern Matching Contract bullet 1 (tool name and input arguments reachable by pattern) |

## Key References

- [message-state.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/task/message-state.ts)
- [disk.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/storage/disk.ts)
- [ToolExecutor.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/task/ToolExecutor.ts)
- [ToolExecutorCoordinator.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/task/tools/ToolExecutorCoordinator.ts)
- [ContextManager.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/context/context-management/ContextManager.ts)
- [index.ts](/home/basil/projects/context-bonsai-agents/cline/src/core/task/index.ts)
