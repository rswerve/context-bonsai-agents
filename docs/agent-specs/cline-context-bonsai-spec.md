# Cline Context Bonsai Spec

## Purpose

This document specializes the shared Context Bonsai contract for Cline.
Cline has real hook infrastructure, but the authoritative history, truncation, and compaction behavior still live in first-party core state. The seam question is now resolved: hooks can add advisory model-visible context, but full bonsai prune/retrieve requires a small core seam because extension-side hooks do not own canonical transcript replacement or persistence.

This is the **contract half** of the per-harness spec: the obligations and posture decisions that change only when the product's behavior contract changes or an integration-posture re-run revises them. The structural facts that realize these obligations — harness file paths, function names, storage locations, JSON shapes — live in the sibling [`cline-context-bonsai-bindings.md`](cline-context-bonsai-bindings.md) and are referenced here by `binding key`; the bindings document is the derivation pipeline's rewritable layer (`derivation-pipeline-spec.md` §2.2) and may change without an edit here so long as each referenced obligation still holds.

## User Model

### User Gamut

- VS Code users running long Cline tasks with approval-gated tools
- users relying on task resume, checkpoints, and restored task state
- teams using hooks and MCP to extend Cline behavior
- users sensitive to visible task-history correctness after compaction or restore

### User-Needs Gamut

- prune and retrieve must align with persisted API conversation history, not only transient UI messages
- archive placeholders must survive resume and checkpoint flows
- hooks should remain useful, but not be treated as the sole source of truth for transcript mutation
- built-in compaction and bonsai must not corrupt one another's history state

### Ambiguities From User Model

- The remaining design choice is not whether a core seam is needed, but how narrowly bonsai can extend the existing checkpoint/history-overwrite machinery while leaving guidance and tool ergonomics extension-side.

## Integration Posture

### Required architecture stance

- Cline Context Bonsai MUST preserve canonical-history correctness, not merely mutate a parallel hook-side transcript.
- Cline Context Bonsai SHOULD keep guidance, gauge, and tool ergonomics extension-side where possible.
- Cline Context Bonsai MUST use a narrow core seam for authoritative prune/retrieve transcript mutation and persistence, because no extension-side surface currently owns the canonical history.
- Hooks MAY provide guidance, observability, and lightweight context injection, but prune/retrieve state MUST be reflected in persisted API conversation history.

### Prune and retrieve contract

- The model-facing tool contract remains `context-bonsai-prune` and `context-bonsai-retrieve`.
- Archive metadata SHOULD be stored alongside or in a structure directly correlated with API conversation history.
- Retrieval MUST restore visibility in the same history layer used for actual request construction.
- The narrowest implementation path is to extend the existing core history-overwrite flow rather than inventing a separate transcript store (binding: `history-overwrite-seam`).
- Per shared spec Pattern Matching Contract, the prune-wrapper filter on the ambiguity path MUST be implemented inside the side-repo pattern resolver, operating on the conversation-history snapshot the applier feeds into pattern resolution (binding: `prune-wrapper-filter`).
- Per shared spec Pattern Matching Contract bullet 1, the tool_use searchable-text representation MUST include each tool call's name AND a stable representation of its `input` arguments in the searchable text (binding: `searchable-text`); `tool_result` block extraction is compliant for the output side.

### Transcript mutation path

- Hook-side and extension-side paths are insufficient for authoritative history replacement; they can only append advisory context.
- Placeholder rendering must occur in the same transcript path that reaches actual request construction (binding: `history-overwrite-seam`).
- The preferred core seam is an extension of the existing core history-overwrite and persistence path (binding: `history-overwrite-seam`).

### System guidance path

- System guidance SHOULD be injected through the internal prompt-building path.
- Hooks MAY augment, but should not be the only location for core bonsai instructions.

### Gauge path

- Gauge logic SHOULD reuse existing context-window information and task token accounting.
- Hook-delivered context is acceptable for gauge nudges if it is reliably model-visible, but cadence and severity must be driven from authoritative context data.
- Gauge does not need the same core seam as prune/retrieve if hook delivery remains sufficient and correctly ordered.

## Fail-Closed Requirements

- If the canonical history overwrite seam is unavailable, prune/retrieve MUST fail closed (binding: `history-overwrite-seam`).
- If archive state and checkpoint restore could diverge, the implementation must reject the mutation rather than risk split-brain task history.
- Gauge remains silent when context data is unavailable.

## Parity Gaps Against Shared Spec

- Hooks are strong for guidance, but not sufficient by themselves for prune/retrieve parity.
- Existing condense and truncate behavior could conflict with bonsai unless explicitly integrated into the same overwrite path.
- Dual persistence of UI and API histories makes authoritative-path discipline mandatory.

## Specified Implementation Direction

- Preferred: hybrid design where hooks own guidance and gauge delivery while a minimal core seam extends the existing history-overwrite behavior for prune/retrieve (binding: `history-overwrite-seam`).
- Acceptable: precompact integration if it preserves deterministic prune/retrieve semantics.
- Not acceptable: a hook-only implementation that leaves canonical API history unchanged.

## E2E Priorities

- prune/retrieve roundtrip against persisted API conversation history
- resume/checkpoint persistence
- gauge visibility without relying only on VS Code UI affordances
- boundary rejection with no history mutation

## Key References

Structural references (source files, storage locations, seam sites) live in [`cline-context-bonsai-bindings.md`](cline-context-bonsai-bindings.md) §Key References.
