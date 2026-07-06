# Bindings Re-Verification Pass — 2026-07-06

First pass under `bindings-reverification-spec.md`. Six read-only cheap-tier (Sonnet) probes, one per bindings document; dispositions by the owner tier. Result: **36 rows probed, 34 VERIFIED, 2 DEMOTED.** Both demotions are annotated in place in their bindings documents and listed under Follow-Ups.

## claude-code (`claude-code-context-bonsai-bindings.md`)

Probed: `tweakcc_context_bonsai` @ `72363afd2c79`; host claims (`~/.claude.json`, `~/.claude/projects/`) probed on the live machine.

| Binding key | Disposition | Evidence |
|---|---|---|
| `mcp-registration` | VERIFIED | live `~/.claude.json`: top-level `mcpServers` map + per-project `projects.<p>.mcpServers` maps present |
| `session-transcript` | VERIFIED | live JSONL files under `~/.claude/projects/<hash>/`; `SessionMessage` union at `src/types.ts:91` |
| `session-discovery` | VERIFIED | `--resume` parse `mcp-server/index.ts:209-216`; cwd `history.jsonl` fallback `src/lib/session.ts:30`; `/proc/<pid>/exe` walk `mcp-server/index.ts:257-283` |
| `archive-store` | VERIFIED | `markMessagesArchived` `src/lib/compact.ts:133` sets `archived`/`archivedAt`/`archivedBy` (:185-187, :214-216); `compactSession` :264. Marker-file shape is a historical note, not checkable in current source |
| `transcript-rewrite-seam` | VERIFIED | patch-presence error string `mcp-server/index.ts:20`; `archivedFilterPatch` `patches/archived-filter.patch.ts:8` |
| `prune-wrapper-filter` | VERIFIED | `hasPruneToolUse` name check `mcp-server/index.ts:404-406`; ambiguity-path exclusion `:551` |
| `searchable-text` | VERIFIED | `searchableText` `mcp-server/index.ts:370` via generic `flattenUnknown` recursion — reaches `tool_use` id/name/input and `tool_result` fields behaviorally, though by generic flatten rather than field-specific extraction |
| `transcript-mutation` | VERIFIED | three functions `src/lib/compact.ts:133,264,361`; `writeJsonlAtomic` `:60`; mutations only inside `routeContextBonsaiTool` `mcp-server/index.ts:968` |
| `provider-filter-coverage` | VERIFIED | `patches/archived-filter.patch.ts:30` builds spans keyed by `archivedBy`, folds trailing `api_system` rows |
| `gauge-channel` | **DEMOTED** | no gauge/token-budget logic anywhere in `mcp-server/index.ts` or `src/lib/*.ts`; tool response builders contain no gauge-text concatenation |
| `guidance-channel` | VERIFIED | `listContextBonsaiTools` `mcp-server/index.ts:914-961` — description strings only, no system-prompt surface |

## cline (`cline-context-bonsai-bindings.md`)

Probed: `cline` @ `fc6c46fd54bc`; `cline_context_bonsai` @ `37fdf2294806`.

| Binding key | Disposition | Evidence |
|---|---|---|
| `history-overwrite-seam` | VERIFIED | `overwriteApiConversationHistory` `message-state.ts:186`; `restoreCheckpoint` `checkpoints/index.ts:239` with bonsai gate; `api.createMessage` `core/task/index.ts:1997` |
| `prune-wrapper-filter` | VERIFIED | `resolvePattern` `guards.ts:76` with `isPruneWrapper` param; called from `ContextBonsaiApplier.ts:242,244` |
| `searchable-text` | VERIFIED | `extractMessageText` `ContextBonsaiApplier.ts:149`; `[tool_use:${name} ${stableSerialize(input)}]` `:160`; `tool_result` string/array handling `:161-172` |

## codex (`codex-context-bonsai-bindings.md`)

Probed: `codex` @ `79bf2a6e646d`; `codex_context_bonsai` @ `e15634c614f5`.

| Binding key | Disposition | Evidence |
|---|---|---|
| `prune-wrapper-filter` | VERIFIED | `resolve_pattern` `guards.rs:118`; `is_prune_wrapper` filter `:151`; producer `context_bonsai.rs:124` |
| `searchable-text` | VERIFIED | `extract_text` `context_bonsai.rs:154` covers all tool-call-bearing `ResponseItem` variants with name+input/output |
| `prompt-history-path` | VERIFIED | `ContextManager` `history.rs:34`; `for_prompt` `:120`; call sites `turn.rs:437,1062` |
| `app-server-mutation-apis` | VERIFIED | `thread_inject_items` `codex_message_processor.rs:1031/7138`; `thread_rollback` `:3654`; "append-only/suffix-drop only" supported by absence of any arbitrary-range-replacement RPC in app-server source (characterization, not exhaustively proven) |

Non-row observation: several line anchors in the doc's Verified Host Primitives prose have drifted a few lines (`session/mod.rs` `replace_history`/`replace_compacted_history` now at 2482/2491, not 2402/2411; `compact.rs:279` and `rollout_reconstruction.rs:234` a few lines above their call sites). Files and function names remain correct. Not a Binding Sites row — no demotion; refresh anchors at codex's next cycle.

## gemini-cli (`gemini-cli-context-bonsai-bindings.md`)

Probed: `gemini-cli` @ `38c55c18fe09`; `gemini-cli_context_bonsai` @ `ac8a3f45a415`.

| Binding key | Disposition | Evidence |
|---|---|---|
| `prune-wrapper-filter` | VERIFIED | `resolveBoundary` `guards.ts:129`; BeforeTool hook `contextBonsaiBootstrap.ts:309-363` snapshots then resolves; wrapper exclusion on ambiguity path `guards.ts:148-167` |
| `searchable-text` | VERIFIED | `snapshotTranscriptForResolution` `contextBonsaiBootstrap.ts:490-499`; `searchText` build `:506-529` incl. toolCalls name/args/result and `functionResponse` parts `:575-584`; v1 `flattenMessageText` absent from both trees (consistent with superseded claim) |
| `gauge-channel` | VERIFIED | `readTokenGaugeInputs` `contextBonsaiBootstrap.ts:625-650` reads `getLastPromptTokenCount()` and `tokenLimit(model)`; `lastPromptTokenCount` maintained in `geminiChat.ts:250,919,1020` |

## kilo (`kilo-context-bonsai-bindings.md`)

Probed: `kilo` @ `feb401284609`; `kilo_context_bonsai` @ `7dc25905b816`.

| Binding key | Disposition | Evidence |
|---|---|---|
| `message-transform-hook` | VERIFIED | trigger in `session/prompt.ts:1548` |
| `system-transform-hook` | VERIFIED | trigger in `session/llm.ts:128` |
| `prune-wrapper-filter` | VERIFIED | `resolvePattern` `guards.ts:26-48` filters `nonWrapperHits` on ambiguity branch; fed from transform input via `buildMessageTexts` `factory.ts:236-242,466-477` |
| `searchable-text` | VERIFIED | `getText` `factory.ts:176-207` emits `tool:<name>`/`input:`/`output:` (completed) and `error:` segments with `stableSerialize` input |

## pi (`pi-context-bonsai-bindings.md`)

Probed: `pi` @ `4de250a5d350`; `pi_context_bonsai` @ `00de6646062e`.

| Binding key | Disposition | Evidence |
|---|---|---|
| `extension-discovery` | VERIFIED | `loader.ts:579-598` (user-global, project-local, explicit paths); `config.ts:190,209-217` |
| `extension-api` | VERIFIED | `ExtensionAPI` `types.ts:1066`; factory loading `loader.ts:420-442` |
| `archive-store` | VERIFIED | `appendEntry` `types.ts:1174`; `appendCustomEntry` `session-manager.ts:897`; custom-type tags in side repo `src/schema.ts:45` (`ARCHIVE_CUSTOM_TYPE = "context-bonsai:archive"`, clear type at `:13`) |
| `message-correlation` | VERIFIED | `SessionEntry.id` `session-manager.ts:33/46/170`; outgoing message shapes carry role+timestamp, no id (`packages/ai/src/types.ts`); `getBranch` `session-manager.ts:1034` |
| `sequential-execution` | VERIFIED | `executionMode` `types.ts:447`; selection `agent-loop.ts:347` |
| `transcript-mutation` | VERIFIED | `transformContext` `agent-loop.ts:249-250`; `context` event `runner.ts:814-830` |
| `guidance-channel` | VERIFIED | `before_agent_start` `types.ts:620,1092`; chaining `runner.ts:894-923` |
| `gauge-channel` | VERIFIED | channel: `context` transform (above); injection shape confirmed in side repo `src/gauge.ts:53,100` — `<system-reminder>` block appended to last user message (`src/context-transform.ts:154`) |
| `usage-api` | VERIFIED | `getContextUsage` `types.ts:317,1475`; impl `agent-session.ts:2932,2206`. Post-compaction unavailability note is a behavioral claim consistent with the matrix's existing "Partial" wording, not freshly re-derived |
| `host-compat-surface` | VERIFIED | `getBranch` `:1034`, `getEntries` `:1066`, `appendEntry` `types.ts:1174`, `context` transform path |
| `searchable-text` | **DEMOTED** | field names wrong at pinned schema: `ToolCall` has `name`/`arguments` (not `input`); `ToolResultMessage` has `toolName`/`content` (not name/`output`) — `packages/ai/src/types.ts` ~166-220. Structural claim (tool data present in `AgentMessage[]`) directionally correct |

## Follow-Ups

1. **claude-code `gauge-channel`** — the next Claude Code cycle's Stage-1 re-exploration must re-derive the gauge delivery channel: establish whether any gauge exists in the current port (none found in source), and either bind the real mechanism or record the row as a designed-but-unimplemented channel. Until then the row is an untrusted prior.
2. **pi `searchable-text`** — the next Pi cycle's Stage-1 re-exploration must re-derive the tool-call/tool-result field names against the pinned `@mariozechner/pi-ai` schema (`name`/`arguments`, `toolName`/`content`) and confirm the side repo's extraction code matches; then rewrite the row with fresh evidence.
3. **codex line anchors** (non-demotion) — refresh the Verified Host Primitives line anchors at codex's next cycle (see codex section note).
