# Claude Code Context Bonsai Bindings

This is the exploration-derived bindings layer for the Claude Code port: the structural facts about the harness and the side repo (file paths, function names, storage locations, JSON shapes) that realize the obligations in [`claude-code-context-bonsai-spec.md`](claude-code-context-bonsai-spec.md). It is the derivation pipeline's Stage 1 output (`derivation-pipeline-spec.md` §4) and the demotion target for `structural-*` escalation codes (§2.2): on a structural break, everything in this document becomes an untrusted prior and may be rewritten from fresh exploration. The sibling contract spec changes only when the product's behavior contract changes or a Stage 2/3 re-run revises the posture; it references this document by binding key, never the reverse direction for obligations.

Evidence in this document was verified against Claude Code 2.1.x (Story 7 era, `~/.claude.json` MCP registration) and the side repo `tweakcc_context_bonsai/`; per-release re-verification runs through `forward-port-spec.md` §4.3's cycle machinery, whose seam/anchor registry — not this document — is authoritative for patch anchors.

## Capability Evidence Matrix

| Area | Status | Notes |
|---|---|---|
| MCP tool registration | Verified | Story 7 confirmed current Claude Code 2.1.x uses `~/.claude.json`: top-level `mcpServers` is a map, and per-project entries under `projects` can also contain `mcpServers` maps. |
| Persistent transcript | Verified | `~/.claude/projects/<project-hash>/<session-id>.jsonl` is append-only JSONL of `tool_use` / `tool_result` / text blocks |
| Session discovery from MCP | Verified | `mcp-server/index.ts` walks `/proc/<pid>` to find the Claude Code ancestor process. Session id comes from `--resume <session-id>` when present; otherwise discovery falls back to a cwd-based match against `history.jsonl`, so it does not depend on `--resume`. The patch-presence guard identifies the running binary via each ancestor's `/proc/<pid>/exe`, independent of launch shape |
| In-band gauge | Partial | No public token-budget API. tweakcc patch can read internal state; otherwise gauge is delivered only as text inside prune/retrieve tool responses |
| System-guidance injection | Gap | No MCP-side system-prompt API. Tool descriptions are the only model-visible MCP-controlled text |
| Transcript mutation | Verified (with caveat) | The MCP server can rewrite the JSONL on disk to insert placeholder messages and mark archived ranges. A transcript-rewrite seam, currently the tweakcc `archivedFilter` patch or an equivalent, is required to hide archived ranges in the live transcript view |
| Archive persistence across resume | Verified | Archive state persists in the session JSONL rows themselves (embedded `archived`/`archivedAt`/`archivedBy` fields) and is read by tweakcc's `archivedFilter` on session reload; older builds used a marker file at `~/.claude/archived-<session-id>.json` |

## Verified Host Primitives

- MCP server registration: `~/.claude.json` `mcpServers.context-bonsai.{command,args}` or per-project `projects.<project>.mcpServers.context-bonsai.{command,args}` — stdio MCP transport; tool names exposed as `mcp__context-bonsai__context-bonsai-prune` / `mcp__context-bonsai__context-bonsai-retrieve` per Claude Code's MCP-prefix convention.
- Session JSONL location: `~/.claude/projects/<project-hash>/<session-id>.jsonl`. Each line is one of `{ type: "user" | "assistant" | "summary", uuid, parentUuid, timestamp, message?, summary?, ... }`. See `tweakcc_context_bonsai/src/types.ts` for the canonical `SessionMessage` union.
- Process discovery: `/proc/<pid>` walk from the MCP server's parent process up the chain. Session discovery parses `cmdline` for `--resume <session-id>` when present, and otherwise falls back to a cwd-based `history.jsonl` match, so it works for directly-launched sessions with no `--resume`. The patch-presence guard identifies the running binary by reading each ancestor's `/proc/<pid>/exe` link, independent of `argv[0]` naming or `--resume`. See `tweakcc_context_bonsai/mcp-server/index.ts`.
- Archive state: current builds embed `archived: true`, `archivedAt`, and `archivedBy` fields on each archived JSONL row — written by `markMessagesArchived` / `compactSession` in `tweakcc_context_bonsai/src/lib/compact.ts` and read by the required transcript-rewrite seam, which groups flagged rows into inclusive spans by `archivedBy` to hide them from the live transcript. Older builds recorded a marker file at `~/.claude/archived-<session-id>.json`. In either shape, archive-state coverage MUST include every original archived-interval JSONL row with a string `uuid`, including UUID-bearing `type: "system"` rows such as `local_command`, `turn_duration`, and `away_summary`; the appended summary placeholder is outside the original interval and MUST NOT be flagged for that prune.

## Unverified Or Weak Areas

- No public token-budget API for the gauge. The tweakcc patch can extract internal state; without the patch, gauge delivery is restricted to text inside prune/retrieve tool responses (out-of-band of the natural prompt flow).
- No MCP-side system-prompt injection. The bonsai guidance text in the cross-agent spec §1 cannot be force-injected; it depends on tool-description text and the model's prior knowledge.
- Atomic JSONL rewrite under concurrent Claude Code writes is non-trivial. The MCP server uses `writeJsonlAtomic` (write-and-rename) but Claude Code may append between read and write. Failure mode is documented; mitigation is to perform prune/retrieve only when the model is paused (the natural state during a tool call).
- Claude Code may evolve its JSONL schema between versions. The MCP server depends on the current shape; a major Claude Code update could break it. The fail-closed contract requires the MCP server to detect schema drift and refuse to mutate.

## Binding Sites

Each key below is referenced from the contract spec's obligations. A key's site column is the current realization; rewriting a site (new path, new function, new storage location) is a bindings-layer change and does not require a contract-spec edit as long as the obligation it realizes still holds.

| Binding key | Current site | Realizes (contract-spec obligation) |
|---|---|---|
| `mcp-registration` | `~/.claude.json` `mcpServers` map (top-level or per-project under `projects`) | Integration Posture: MCP-first stance — the MCP server is the authoritative integration seam |
| `session-transcript` | `~/.claude/projects/<project-hash>/<session-id>.jsonl`; canonical row union `SessionMessage` in `tweakcc_context_bonsai/src/types.ts` | Prune and retrieve contract: deterministic prune/retrieve over the persisted transcript; Fail-Closed: schema-drift compatibility error |
| `session-discovery` | `/proc/<pid>` ancestor walk, `--resume` cmdline parse with cwd-based `history.jsonl` fallback, `/proc/<pid>/exe` binary identification — `tweakcc_context_bonsai/mcp-server/index.ts` | Fail-Closed: locate-or-refuse; patch-presence guard independent of launch shape |
| `archive-store` | Embedded `archived`/`archivedAt`/`archivedBy` fields on archived JSONL rows, written by `markMessagesArchived` / `compactSession` in `tweakcc_context_bonsai/src/lib/compact.ts` (older build shape: marker file `~/.claude/archived-<session-id>.json`) | Prune and retrieve contract: archive metadata persists across reload/resume; Fail-Closed: rollback when the store cannot be written |
| `transcript-rewrite-seam` | tweakcc `archivedFilter` patch on the locally-installed Claude Code binary (anchor registry: `forward-port-spec.md` §4.3) | Integration Posture: REQUIRED seam for the context-reduction guarantee; Fail-Closed: prune refuses without a verified seam |
| `prune-wrapper-filter` | `loadSearchableMessages` / `resolveUniqueBoundary` in `tweakcc_context_bonsai/mcp-server/index.ts`; flags messages whose `tool_use` block has `name === "context-bonsai-prune"` or the MCP-prefixed variant and excludes them from the ambiguity candidate set (the_observer's `prune-call-filtering` story) | Prune and retrieve contract: Pattern Matching Contract prune-wrapper filter on the ambiguity path |
| `searchable-text` | `searchableText` walker in `tweakcc_context_bonsai/mcp-server/index.ts`; surfaces `tool_use` `{ id, name, input }` and `tool_result` `{ tool_use_id, content }` — name, input, and output content all searchable | Prune and retrieve contract: Pattern Matching Contract bullet 1 (tool name, args, output reachable by pattern) |
| `transcript-mutation` | `markMessagesArchived` / `compactSession` / `unarchiveMessages` in `tweakcc_context_bonsai/src/lib/compact.ts`; atomic writes via `writeJsonlAtomic` (temp-file + rename), mutations only during MCP tool calls | Transcript mutation path: placeholder insertion and archived-range marking |
| `provider-filter-coverage` | The tweakcc provider filter hides all provider-bound rows inside archived spans — current shape: rows with `archived === true` grouped into inclusive index spans by `archivedBy` (see `patches/archived-filter.patch.ts`); older marker-shape builds filtered by `__cbMessage.uuid` — including JSONL `type: "system"` metadata rows mapped through the host's provider-side `api_system` branch | Transcript mutation path / Prune and retrieve contract: archive-state coverage of UUID-bearing system/meta rows; Anthropic ordering rules hold post-prune |
| `gauge-channel` | Without the patch: gauge text appended to prune/retrieve tool response bodies. With the patch: rendered from internal token-budget state in the Claude Code UI status line / sidebar | Gauge path: delivery channel for the cross-agent spec §7 bands and cadence |
| `guidance-channel` | Tool-description text only; no system-prompt injection surface | System guidance path: delivery constraint behind the recorded parity gap |

## Key References

- [tweakcc_context_bonsai/mcp-server/index.ts](/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai/mcp-server/index.ts) — MCP server entry; tool registration; prune/retrieve handlers
- [tweakcc_context_bonsai/src/lib/session.ts](/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai/src/lib/session.ts) — JSONL session loader and session path helpers
- [tweakcc_context_bonsai/src/lib/compact.ts](/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai/src/lib/compact.ts) — `markMessagesArchived`, `compactSession`, `unarchiveMessages`, `retrieveSession`
- [tweakcc_context_bonsai/src/types.ts](/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai/src/types.ts) — `SessionMessage`, `CompactMetadata`, `SummaryMessage`
- [tweakcc_context_bonsai/README.md](/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai/README.md), [PRD_CONTEXT_BONSAI_V2.md](/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai/PRD_CONTEXT_BONSAI_V2.md) — operator docs and design background
- [tweakcc_context_bonsai/docs/e2e-protocol.md](/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai/docs/e2e-protocol.md) — end-to-end validation procedure
- [tweakcc](https://github.com/Piebald-AI/tweakcc) — patching tool used to provide the required transcript-rewrite seam
