# Gemini CLI Context Bonsai Bindings

This is the exploration-derived bindings layer for the Gemini CLI port: the structural facts about the harness and the side repo (file paths, function names, storage locations, JSON shapes) that realize the obligations in [`gemini-cli-context-bonsai-spec.md`](gemini-cli-context-bonsai-spec.md). It is the derivation pipeline's Stage 1 output (`derivation-pipeline-spec.md` §4) and the demotion target for `structural-*` escalation codes (§2.2): on a structural break, everything in this document becomes an untrusted prior and may be rewritten from fresh exploration. The sibling contract spec changes only when the product's behavior contract changes or a Stage 2/3 re-run revises the posture; it references this document by binding key, never the reverse direction for obligations.

Evidence in this document was verified against the `gemini-cli/` fork repo and the side repo `gemini-cli_context_bonsai/`; this harness is not yet bound in `forward-port-spec.md` Part 4; these bindings date from the implementation epic and must be re-verified before any cycle binds them.

## Capability Evidence Matrix

| Area | Status | Notes |
|---|---|---|
| Persistent transcript | Verified | JSONL session chat records exist |
| Tool execution layer | Verified | Registry, discovered tools, and MCP tools are first-class |
| Hook system | Verified | Hooks can modify LLM requests and responses |
| Extension layer | Verified | Config/extensions participate in runtime behavior |
| Transcript fidelity through hooks | Partial | Stable hook translator is text-oriented |
| Token/context tracking | Verified | Prompt token counts and model limits are already computed |

## Verified Host Primitives

- Session recording and replay-relevant artifacts live in [chatRecordingService.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/services/chatRecordingService.ts).
- Chat history assembly lives in [geminiChat.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/core/geminiChat.ts).
- Tools are provided through [tool-registry.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/tools/tool-registry.ts) and MCP integration in [mcp-client.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/tools/mcp-client.ts).
- Hook mutation surfaces are defined in [hooks/types.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/hooks/types.ts) and [hookSystem.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/hooks/hookSystem.ts).
- Token limit logic exists in [tokenLimits.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/core/tokenLimits.ts).

## Unverified Or Weak Areas

- Hook translators simplify message content, which may limit perfect transcript-fidelity transforms.
- System instruction construction is centralized in core; replacing it cleanly through external hooks is not yet fully proven.
- Existing core compression behavior must be treated as a separate concern from bonsai.

## Binding Sites

Each key below is referenced from the contract spec's obligations. A key's site column is the current realization; rewriting a site (new path, new function, new storage location) is a bindings-layer change and does not require a contract-spec edit as long as the obligation it realizes still holds.

| Binding key | Current site | Realizes (contract-spec obligation) |
|---|---|---|
| `prune-wrapper-filter` | `gemini-cli_context_bonsai/src/guards.ts` (`resolveBoundary`), operating on the agent-side transcript snapshot the bootstrap obtains from `chatRecordingService` before the MCP tool is invoked | Prune and retrieve contract: Pattern Matching Contract prune-wrapper filter on the ambiguity path |
| `searchable-text` | `snapshotTranscriptForResolution` in `gemini-cli/packages/cli/src/utils/contextBonsaiBootstrap.ts` produces `searchText` per `TranscriptMessage`. Current implementation serializes `toolCalls[]` (name/args/result) and extracts content from `functionResponse` parts alongside `MessageRecord.content` text — closing the v1 gap the original spec recorded (v1 walked `.text` properties only via `flattenMessageText`, a spec violation against bullet 1) | Prune and retrieve contract: Pattern Matching Contract bullet 1 (tool name, args, output reachable by pattern) |
| `gauge-channel` | Gauge values sourced from `lastPromptTokenCount`, usage metadata, and model token-limit calculations (see `tokenLimits.ts`) | Gauge path: reuse of existing prompt-token-count and model-limit signals |

## Key References

- [chatRecordingService.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/services/chatRecordingService.ts)
- [geminiChat.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/core/geminiChat.ts)
- [tool-registry.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/tools/tool-registry.ts)
- [mcp-client.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/tools/mcp-client.ts)
- [hooks/types.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/hooks/types.ts)
- [tokenLimits.ts](/home/basil/projects/context-bonsai-agents/gemini-cli/packages/core/src/core/tokenLimits.ts)
