# Kilo Context Bonsai Bindings

This is the exploration-derived bindings layer for the Kilo port: the structural facts about the harness and the side repo (file paths, function names, storage locations, JSON shapes) that realize the obligations in [`kilo-context-bonsai-spec.md`](kilo-context-bonsai-spec.md). It is the derivation pipeline's Stage 1 output (`derivation-pipeline-spec.md` §4) and the demotion target for `structural-*` escalation codes (§2.2): on a structural break, everything in this document becomes an untrusted prior and may be rewritten from fresh exploration. The sibling contract spec changes only when the product's behavior contract changes or a Stage 2/3 re-run revises the posture; it references this document by binding key, never the reverse direction for obligations.

Evidence in this document was verified against the Kilo fork repo `kilo/` and the side repo `kilo_context_bonsai/`; this harness is not yet bound in `forward-port-spec.md` Part 4; these bindings date from the implementation epic and must be re-verified before any cycle binds them.

## Capability Evidence Matrix

| Area | Status | Notes |
|---|---|---|
| Persistent transcript | Verified | Session/message/part tables and session entries exist |
| Tool execution layer | Verified | Registry and execution wrapping exist |
| Message transform hook | Verified | `experimental.chat.messages.transform` exists |
| System transform hook | Verified | `experimental.chat.system.transform` exists |
| Token/context tracking | Verified | Usage and overflow checks exist |
| Upstream compatibility pressure | Verified | Repo explicitly minimizes divergence from OpenCode |

## Verified Host Primitives

- Session persistence is in [session.sql.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/session/session.sql.ts) and [message-v2.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/session/message-v2.ts).
- Tool registry and execution are in [tool/registry.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/tool/registry.ts) and [tool/tool.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/tool/tool.ts).
- Plugin hooks are declared in [packages/plugin/src/index.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/plugin/src/index.ts).
- System transform is applied in [session/llm.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/session/llm.ts).
- Message transform is applied in [session/prompt.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/session/prompt.ts).

## Unverified Or Weak Areas

- The main uncertainty is not host capability; it is how to keep the Kilo fork aligned with upstream OpenCode while adding bonsai behavior.
- Kilo-specific products on top of the CLI may introduce extra UX expectations, but that should not force CLI-core divergence unless necessary.

## Binding Sites

Each key below is referenced from the contract spec's obligations. A key's site column is the current realization; rewriting a site (new path, new function, new storage location) is a bindings-layer change and does not require a contract-spec edit as long as the obligation it realizes still holds.

| Binding key | Current site | Realizes (contract-spec obligation) |
|---|---|---|
| `message-transform-hook` | `experimental.chat.messages.transform`, applied in [session/prompt.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/session/prompt.ts) | Transcript mutation path: placeholder rendering and archived-range elision; also realizes Capability Evidence Matrix "Message transform hook" |
| `system-transform-hook` | `experimental.chat.system.transform`, applied in [session/llm.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/session/llm.ts) | System guidance path: bonsai guidance injection; also realizes Capability Evidence Matrix "System transform hook" |
| `prune-wrapper-filter` | Plugin's pattern resolver in `kilo_context_bonsai/src/guards.ts` (or the side-repo equivalent), operating on the message-transform input the plugin already receives | Prune and retrieve contract: Pattern Matching Contract prune-wrapper filter on the ambiguity path |
| `searchable-text` | `getText` in `kilo_context_bonsai/src/factory.ts`. Current implementation includes tool parts — `tool:<name>`, stable-serialized `input`, and completed `output` (or `error`) segments — closing the v1 gap the original spec recorded (v1 skipped non-text parts, a Pattern Matching Contract violation) | Prune and retrieve contract: Pattern Matching Contract text-extraction layer must include tool part name, input, and output |

## Key References

- [session.sql.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/session/session.sql.ts)
- [message-v2.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/session/message-v2.ts)
- [registry.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/tool/registry.ts)
- [tool.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/opencode/src/tool/tool.ts)
- [packages/plugin/src/index.ts](/home/basil/projects/context-bonsai-agents/kilo/packages/plugin/src/index.ts)
- [AGENTS.md](/home/basil/projects/context-bonsai-agents/kilo/AGENTS.md)
