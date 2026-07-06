# Gemini CLI Context Bonsai Spec

## Purpose

This document specializes the shared Context Bonsai contract for Gemini CLI.
Gemini CLI is the strongest non-OpenCode host in this workspace for a hook-led bonsai design, but the spec must treat hooks, extensions, MCP, and core compression as distinct layers rather than collapsing everything into MCP.

This is the **contract half** of the per-harness spec: the obligations and posture decisions that change only when the product's behavior contract changes or an integration-posture re-run revises them. The structural facts that realize these obligations — harness file paths, function names, storage locations, JSON shapes — live in the sibling [`gemini-cli-context-bonsai-bindings.md`](gemini-cli-context-bonsai-bindings.md) and are referenced here by `binding key`; the bindings document is the derivation pipeline's rewritable layer (`derivation-pipeline-spec.md` §2.2) and may change without an edit here so long as each referenced obligation still holds.

## User Model

### User Gamut

- terminal-first Gemini CLI users in long coding sessions
- users extending Gemini CLI through hooks, extensions, and MCP
- operators depending on resumable JSONL chat records
- maintainers who want bonsai without invasive core patching when hooks can do the job

### User-Needs Gamut

- deterministic archive/retrieve behavior over persisted chat logs
- real in-band gauge signals before context overflow
- use native extensibility where it is sufficient
- avoid pretending MCP alone can solve transcript transformation when it cannot

### Ambiguities From User Model

- Whether full bonsai parity can be achieved through hook request mutation alone, or whether a narrow core touch is still needed for full-fidelity non-text transcript behavior.

## Integration Posture

### Required architecture stance

- Gemini CLI Context Bonsai MUST be specified as hooks-first, extension-aware, MCP-assisted.
- MCP is for tool exposure, not for transcript transformation.
- Existing core compression behavior must be explicitly accounted for, not ignored.
- Core changes should be avoided unless hooks and extension seams prove insufficient for full-fidelity transcript mutation.

### Prune and retrieve contract

- `context-bonsai-prune` and `context-bonsai-retrieve` SHOULD be surfaced through the native tool registry, either directly or through extension/MCP registration.
- Archive metadata SHOULD persist in a host-owned durable store correlated with session chat records.
- Per shared spec Pattern Matching Contract, the prune-wrapper filter on the ambiguity path MUST be implemented in the side-repo pattern resolver (binding: `prune-wrapper-filter`), operating on the agent-side transcript snapshot the bootstrap obtains before the MCP tool is invoked.
- Per shared spec Pattern Matching Contract bullet 1, the searchable-text layer MUST include each tool call's name, args, and result/output so pattern matching can target tool-call payloads (binding: `searchable-text`).

### Transcript mutation path

- The preferred mutation point is the hook path that can modify LLM request contents before the API call.
- If hook-translated text-only content is insufficient for full placeholder fidelity, a narrow core extension point may be added, but hook-first remains the default target.

### System guidance path

- Bonsai guidance SHOULD be injected through hook-based request modification or a small core-supported system-instruction extension point.

### Gauge path

- Gauge SHOULD reuse existing prompt-token-count and model-limit signals (binding: `gauge-channel`).
- Gauge delivery MUST be in-band in request contents, not merely logged.

## Fail-Closed Requirements

- If request mutation hooks are unavailable, prune/retrieve MUST not claim parity.
- MCP-only configurations without transcript mutation are partial implementations and must be labeled accordingly.
- Gauge remains silent when usage metadata or model limits are unavailable.

## Parity Gaps Against Shared Spec

- Hook-translated message fidelity is the main technical risk.
- Existing core compression and checkpoint behaviors need explicit coexistence rules.
- Clean external replacement of system instructions is not yet fully evidenced.

## Specified Implementation Direction

- Preferred: hook-led transcript mutation plus native tool registration, with MCP available as a transport option.
- Acceptable: small core seam to preserve full-fidelity placeholder rendering where hooks are too lossy, with the seam kept narrower than the bonsai logic that sits on top of it.
- Not acceptable: MCP-only tool exposure without request-context mutation.

## E2E Priorities

- prune/retrieve roundtrip against JSONL session records
- gauge cadence from real prompt-token counts
- compatibility failure when hooks are disabled or unavailable
- proof that placeholders are model-visible in the actual request path

## Key References

Structural references (source files, storage locations, seam sites) live in [`gemini-cli-context-bonsai-bindings.md`](gemini-cli-context-bonsai-bindings.md) §Key References.
