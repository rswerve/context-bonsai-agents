# Hermes Agent Context Bonsai Bindings

This is the exploration-derived bindings layer for the Hermes Agent port: the structural facts about the harness (file paths, function names, storage locations, hook names) that will realize the obligations in the sibling contract spec (`hermes-agent-context-bonsai-spec.md`, produced at Stage 3). It is the derivation pipeline's Stage 1 output (`derivation-pipeline-spec.md` §4) and the demotion target for `structural-*` escalation codes (§2.2): on a structural break, everything in this document becomes an untrusted prior and may be rewritten from fresh exploration.

**Frozen harness identity**: git upstream `https://github.com/NousResearch/hermes-agent`, tag `v2026.7.1`, SHA `7c1a029553d87c43ecff8a3821336bc95872213b`. All file:line citations below resolve against this SHA. Hermes Agent is a Python CLI agent (MIT, Nous Research); the exploration clone lives at `/tmp/hermes-bonsai-derivation/hermes-agent` during the derivation and is disposable — the identity above, not the clone, is the evidence root.

This harness is not yet bound in `forward-port-spec.md` Part 4 (§4.8 unbound set). The Binding Sites table is intentionally absent at this stage: Stage 3 names the binding keys and Stage 4 records the realized sites (pipeline spec §4's output contract).

## Capability Evidence Matrix

One row per behavior-contract capability the port depends on (pipeline spec §4's normalized probe list, mapped to the contract's Runtime Capability Matrix).

| # | Area | Status | Summary |
|---|---|---|---|
| 1 | Persistent transcript | Verified | Canonical SQLite store (`~/.hermes/state.db`, WAL) with `sessions` + `messages` tables; JSON session-index sidecar; documented resume/rehydration path |
| 2 | Tool execution layer | Verified | Central registry dispatch (`model_tools.py`); first-class external MCP server support (config `mcp_servers:` block, startup discovery, schema normalization to native tool shape) |
| 3 | Hook / plugin / extension system | Verified | In-process plugin system with read-only hooks (`pre_tool_call`, `pre_llm_call`, …) and behavior-changing middleware (`llm_request`, `tool_request`, execution wrappers); drop-in dirs, project plugins, pip entry points |
| 4 | Token / context-usage tracking | Verified | Provider usage parsed per response; canonical percent-of-context computation exposed programmatically; live compaction threshold machinery |
| 5 | Transcript-rewrite capability | Partial | Authoritative history replacement exists in core (`archive_and_compact`: non-destructive soft-archive + compacted-set reload; `replace_messages`: destructive) and `llm_request` middleware can replace the full provider payload per request — but no dedicated plugin hook performs authoritative persisted replacement; a plugin would compose core APIs in-process |
| 6 | System guidance path | Verified | Tiered system-prompt builder (stable/context/volatile) with AGENTS.md/CLAUDE.md folding; per-turn plugin injection via `pre_llm_call` appends to the user message (no plugin hook mutates the system prompt itself) |

## Verified Host Primitives

Row 1 — persistent transcript:

- `hermes_state.py:123` — `DEFAULT_DB_PATH = get_hermes_home() / "state.db"`.
- `hermes_state.py:695-765` — `SCHEMA_SQL`: `sessions` and `messages` tables; message rows carry `role`, `content`, `tool_calls`, reasoning fields, and `observed` / `active` / `compacted` flags.
- `hermes_state.py:3095-3153` — `append_message`: the per-turn write path (JSON-encodes multimodal content and structured fields).
- `hermes_state.py:3721-3735` — `get_messages_as_conversation`: the rehydration read path ("used by the gateway to restore conversation history"); filters `active=1` by default, `include_inactive=True` returns full history.
- `docs/session-lifecycle.md:190-203` — storage layout: SQLite is the "canonical transcript store"; `sessions.json` maps session keys to ids; legacy per-session JSONL is a degradation fallback only.
- `docs/session-lifecycle.md:165-172` — resume machinery: `get_or_create_session()`, `switch_session()` (backs `/resume`), `suspend_recently_active()` crash recovery.

Row 2 — tool execution layer:

- `model_tools.py:904` — `handle_function_call(...)`: the dispatcher routing model tool calls to the registry; `model_tools.py:1142` — the nested `_dispatch` closure calling `registry.dispatch(...)`.
- `model_tools.py:945` — `coerce_tool_args(...)`: schema-driven argument coercion before dispatch.
- `model_tools.py:961-1023` — tool-search bridge (`tool_search` / `tool_describe` / `tool_call`) re-dispatches through `handle_function_call` so hooks see the real tool name.
- `tools/mcp_tool.py:1155-1156` and `:3761` — `_normalize_mcp_input_schema`: MCP `inputSchema` normalized into the same name/description/parameters shape as native tools.
- `cli-config.yaml.example:878-891` — the `mcp_servers:` config block (stdio command/args/env or remote url); `hermes_cli/mcp_startup.py:14-118` — startup discovery connecting to configured servers and pulling tool catalogs.
- `mcp_serve.py:1-27` — the opposite direction (Hermes exposing its own tools as an MCP server); distinct from consuming external servers.

Row 3 — hooks, plugins, middleware:

- `hermes_cli/plugins.py:135-160` — `VALID_HOOKS`: `pre_tool_call`, `post_tool_call`, `transform_tool_result`, `transform_llm_output`, `pre_llm_call`, `post_llm_call`, `on_session_start`, and a verification-loop gate.
- `hermes_cli/plugins.py:1109-1123` — `register_hook(hook_name, callback)`; `:1128-1144` — `register_middleware(kind, callback)`.
- `hermes_cli/middleware.py:77-110` — `apply_llm_request_middleware`: registered `llm_request` middleware may return `{"request": {...}}` to **replace the effective provider kwargs** (including `messages`) before Hermes sends them.
- `agent/conversation_loop.py:1079-1096` — the live provider-call site applying `llm_request` middleware to `api_kwargs` (with session/turn/model context passed in) and sending `_llm_request_mw.payload`.
- `docs/middleware/README.md:43-50, 96-108, 169-188` — middleware kinds (`llm_request`, `tool_request`, `llm_execution`, `tool_execution`), the documented tool-call order (parse/coerce → `tool_request` → guardrails/approval → `tool_execution` → `post_tool_call` → `transform_tool_result`), and a worked arg-mutation example; `model_tools.py:1026-1033` wires `apply_tool_request_middleware` into real dispatch.
- `hermes_cli/plugins.py:1276-1324` — plugin loading: bundled `plugins/<name>/plugin.yaml`, user `~/.hermes/plugins/`, project `./.hermes/plugins/` (gated by `HERMES_ENABLE_PROJECT_PLUGINS`), pip entry points. Plugins are in-process Python.

Row 4 — token / context tracking:

- `agent/context_compressor.py:1043-1047` — parses provider `usage` (`prompt_tokens`, completion, total) and compares against `threshold_tokens`; `:1104` — `should_compress()` trigger.
- `agent/context_engine.py:64` — `threshold_percent: float = 0.75` default; `:205-208` — canonical percentage computation (`last_prompt / context_length * 100`) exposed via `get_status()`.
- `agent/conversation_loop.py:2018` — per-response session token accumulation (prompt/completion/cache/reasoning in the surrounding block).
- `run_agent.py:2208-2221` — `_usage_summary_for_api_request_hook`: normalized usage exposed to `post_api_request` plugin hooks.
- `cli.py:9414-9419` — status display computing percent from `compressor.context_length`.

Row 5 — transcript rewrite:

- `hermes_state.py:3346-3395` — `archive_and_compact(session_id, compacted)`: non-destructive authoritative replacement — soft-archives active rows (`active=0, compacted=1`) and atomically inserts the compacted rows as the live set under the same session id; the model reloads only the compacted set through the `active=1` filter.
- `hermes_state.py:3284-3330` — `replace_messages`: destructive DELETE+reinsert (used by `/retry`, `/undo`, `/compress` per docstring).
- `agent/conversation_compression.py:394-415` — `compress_context`: the live compaction entry point (manual `/compress` plus auto-compaction); `:371-391` — `conversation_history_after_compression` rewrites the in-memory baseline so the next turn sees the compacted list; `:682` — the call site tying the persisted rewrite (`agent._session_db.archive_and_compact(...)`) to the in-memory compacted list.
- Compaction call sites are core-code only: `cli.py:9325` (`/compress`), `agent/conversation_loop.py:3013,3259,3482,4614` (auto), `agent/turn_context.py:403`, plus the gateway/TUI/ACP servers.
- `trajectory_compressor.py:743-877` — **not** the live mechanism: an offline ShareGPT-format training-data post-processor; its only caller is `scripts/sample_and_compress.py:270-281`.

Row 6 — system guidance:

- `agent/system_prompt.py:113-131` — `build_system_prompt_parts()`: stable / context / volatile tiers, joined by `build_system_prompt()` at `:470`; module docstring (`:9-18`) notes per-session caching with rebuild on compression.
- `agent/prompt_builder.py:1852-1868` — `_load_agents_md()` folds `AGENTS.md` into the context tier; a `_load_claude_md` sibling follows.
- `agent/turn_context.py:431-456` — per-turn `pre_llm_call` hook results joined and **appended to the user message** ("not system prompt", comment at `:113`) — the supported per-turn guidance-injection channel.
- `plugins/security-guidance/__init__.py:1-27` — precedent plugin appending guidance text via `transform_tool_result`.

## Unverified Or Weak Areas

- **No plugin hook mutates the system prompt.** `VALID_HOOKS` has no system-prompt entry; plugin guidance enters via the user-turn append path or `llm_request` middleware rewriting the outgoing payload. Whether guidance delivered through those channels satisfies the contract's system-guidance obligation is a Stage 2/3 decision, not settled here.
- **Plugin-side authoritative rewrite is composed, not native.** No hook performs persisted history replacement; a plugin would import and call the core `hermes_state` APIs (`archive_and_compact`) in-process, plus rely on the in-memory baseline rewrite behavior that today lives inside `conversation_compression.py`. Whether the in-memory `conversation_history` can be refreshed from the store mid-session by plugin-reachable means was **not** established — this is the port's highest-risk open question and the first thing Stage 2 must resolve against the matrix.
- **`llm_request` middleware rewrites are per-request only**: the persisted transcript and the in-memory baseline are untouched (`payload` vs `original_payload` at `agent/conversation_loop.py:1094-1095`); middleware alone is presentation-layer, not authoritative replacement.
- Middleware payload copying falls back from `deepcopy` to shallow copy on non-copyable payloads (`hermes_cli/middleware.py:60-74`) — a mutation-aliasing hazard for any middleware that edits nested structures in place.
- The exact merge site where MCP-discovered tool dicts join `get_tool_definitions()` output before the provider send was inferred from shape, not read; the JSONL-fallback write path for the legacy store was likewise not traced.
- `normalize_usage` internals (`agent/usage_pricing.py`) were not read in detail; MCP sub-tool calls have a separate usage path (`tools/mcp_tool.py:1052-1208`).
- Full-skill-body runtime injection (`skill_manage`) and the complete hook registrations of all ~15 bundled plugins were not exhaustively enumerated (three adapters sampled; the pattern is context-injection/observability, no hidden history-replace hook found).

## Key References

- `hermes_state.py` — canonical SQLite transcript store, `archive_and_compact`, `replace_messages`
- `agent/conversation_compression.py` — live compaction (`compress_context`), in-memory baseline rewrite
- `agent/conversation_loop.py` — provider call site, `llm_request` middleware application, usage accumulation
- `hermes_cli/plugins.py`, `hermes_cli/middleware.py`, `docs/middleware/README.md` — plugin/hook/middleware surface
- `model_tools.py`, `tools/mcp_tool.py`, `hermes_cli/mcp_startup.py`, `cli-config.yaml.example` — tool registry and MCP consumption
- `agent/system_prompt.py`, `agent/prompt_builder.py`, `agent/turn_context.py` — guidance assembly and per-turn injection
- `agent/context_engine.py`, `agent/context_compressor.py` — context-usage tracking and compaction thresholds
- `docs/session-lifecycle.md` — storage layout and resume semantics
