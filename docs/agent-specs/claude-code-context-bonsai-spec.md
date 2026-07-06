# Claude Code Context Bonsai Spec

## Purpose

This document specializes the shared Context Bonsai contract for Anthropic's Claude Code (the CLI / IDE agent host). Unlike the other four ports, Claude Code is closed-source — there is no agent repo to fork or patch. The integration surface is MCP plus a transcript-rewrite seam in the locally-installed Claude Code binary via [`tweakcc`](https://github.com/Piebald-AI/tweakcc), or an equivalent seam. The bonsai implementation lives in the [`tweakcc_context_bonsai/`](/home/basil/projects/context-bonsai-agents/tweakcc_context_bonsai) side repo: the `context-bonsai` MCP server, tweakcc patch apply/restore tooling, and shared TypeScript libraries.

This is the **contract half** of the per-harness spec: the obligations and posture decisions that change only when the product's behavior contract changes or an integration-posture re-run revises them. The structural facts that realize these obligations — harness file paths, function names, storage locations, JSON shapes — live in the sibling [`claude-code-context-bonsai-bindings.md`](claude-code-context-bonsai-bindings.md) and are referenced here by `binding key`; the bindings document is the derivation pipeline's rewritable layer (`derivation-pipeline-spec.md` §2.2) and may change without an edit here so long as each referenced obligation still holds.

## User Model

### User Gamut

- Claude Code CLI users in long terminal/IDE sessions
- Users who can install MCP servers via the host's MCP registration surface (binding: `mcp-registration`) and can apply a local transcript-rewrite seam to Claude Code
- Users who need the tweakcc patch, or an equivalent seam, for the context-reduction guarantee
- Operators relying on Claude Code's session JSONL exports for resumption and audit

### User-Needs Gamut

- Deterministic prune/retrieve over Claude Code's persisted session transcript (binding: `session-transcript`)
- Archive metadata that survives session reload, restart, and `claude --resume`
- Pattern-matching that reaches tool-call name, args, and output (per Pattern Matching Contract bullet 1, MUST since commit `9f1ca61`)
- Fail-closed behavior when the session transcript cannot be located or written
- A required transcript-rewrite seam that ensures archived follower messages are removed from the model-facing transcript

### Ambiguities From User Model

- Whether the gauge can be delivered in-band without a tweakcc patch. Claude Code does not expose a public token-budget API to MCP servers; in-band gauge delivery requires the patch or a workaround (e.g. injecting gauge text into prune/retrieve tool responses).
- Whether system guidance can be injected at all from MCP. Claude Code has no MCP-side system-prompt API; the prune/retrieve tool descriptions are the only model-visible MCP-controlled text. Guidance currently relies on the model's prior knowledge plus tool descriptions.

## Integration Posture

### Required architecture stance

- Claude Code Context Bonsai MUST be MCP-first. There is no agent-repo to mirror; the MCP server is the only authoritative integration seam (binding: `mcp-registration`).
- A transcript-rewrite seam is REQUIRED for the context-reduction guarantee in the shared spec: after prune, archived follower messages must be omitted from the next model-facing transcript. The current seam is the bound realization (binding: `transcript-rewrite-seam`); an equivalent seam may satisfy the same requirement.
- The MCP server alone is not sufficient to guarantee context reduction. When the required seam is absent or cannot be verified, prune MUST fail closed with a deterministic plain-text error and MUST NOT write archive state.
- All bonsai logic lives in the side repo (`tweakcc_context_bonsai`); the local Claude Code install is modified only at the minimal transcript-rewrite seam needed to satisfy the shared spec.

### Prune and retrieve contract

- Tool names: `context-bonsai-prune` and `context-bonsai-retrieve`, surfaced through MCP as `mcp__context-bonsai__context-bonsai-prune` and `mcp__context-bonsai__context-bonsai-retrieve` respectively (Claude Code's standard MCP-prefix format).
- Archive metadata MUST persist to the bound archive store (binding: `archive-store`) so that the transcript-rewrite seam can hide archived ranges across session reloads.
- Prune archive-state writes MUST cover every string-`uuid` row from the original archived interval, not just `user`/`assistant` rows, because the host maps some transcript metadata rows into provider-visible entries and the provider-bound filter operates per row (binding: `provider-filter-coverage`).
- Retrieve MUST clear archive state for the same restored inclusive interval derived from the summary `compactMetadata`, including UUID-bearing system/meta rows, while preserving unrelated archive state from other pruned ranges.
- Per shared spec Pattern Matching Contract, the prune-wrapper filter on the ambiguity path MUST exclude prune-wrapper messages from the candidate set on ambiguity (binding: `prune-wrapper-filter`).
- Per shared spec Pattern Matching Contract bullet 1 (MUST since commit `9f1ca61`), the searchable-text layer MUST include each tool call's name, input, and output so pattern matching can target tool-call payloads (binding: `searchable-text`).

### Transcript mutation path

- The MCP server rewrites the live transcript to insert a placeholder `summary`-typed entry replacing the archived range (binding: `transcript-mutation`).
- Without the transcript-rewrite seam, the original archived `tool_use`/`tool_result` blocks remain in the persisted transcript and are visible in subsequent transcript loads; prune must therefore fail closed before writing archive state. With the seam, they are hidden from the live transcript view.
- The provider-bound filter must hide all provider-bound rows inside the archived interval, including host metadata rows mapped through the provider-side path. Filtering only `user`/`assistant` rows can leave orphan provider `system` messages and violate Anthropic ordering rules (binding: `provider-filter-coverage`).
- Mutations are written atomically and only while the model is paused (the natural state during a tool call), mitigating the host's append-during-mutation race (binding: `transcript-mutation`).

### System guidance path

- Bonsai guidance is delivered via tool descriptions. Direct system-prompt injection is not available (binding: `guidance-channel`).
- Future enhancement: explore whether the tweakcc patch can inject system-instruction text without breaking Claude Code's update path.

### Gauge path

- Without tweakcc patch: gauge text is delivered inside prune/retrieve tool response bodies. This violates the cross-agent spec's "in-band" preference but is the only available channel (binding: `gauge-channel`).
- With tweakcc patch: gauge can be rendered in the Claude Code UI from internal token-budget state (binding: `gauge-channel`).
- Cadence and severity bands match the cross-agent spec §7.

## Fail-Closed Requirements

- If the session transcript cannot be located (no process-discovery match, no persisted session file — bindings: `session-discovery`, `session-transcript`), the MCP tool MUST return a structured error and refuse to mutate.
- If the transcript schema does not match the expected shape (e.g. major Claude Code version drift; binding: `session-transcript`), the MCP tool MUST refuse to mutate and return a "compatibility error" per the cross-agent spec §"Compatibility error".
- If the transcript-rewrite seam is absent or cannot be verified, the prune tool MUST return a deterministic plain-text error and MUST NOT write the archive store or mutate the session transcript.
- If the archive store cannot be written (filesystem permissions, disk full), the MCP tool MUST roll back any partial transcript mutation and return an error.
- Pattern ambiguity, after the prune-wrapper filter, MUST return the deterministic plain-text error verbatim per the cross-agent spec.
- Every deterministic prune/retrieve failure or refusal MUST be returned as an MCP result with `isError: true` so Claude Code does not render the refusal as a successfully-completed tool call. This sets the error flag only; the body stays plain text per the cross-agent spec §2 Output rules. The patch-presence guard that decides whether a prune may proceed MUST identify the running Claude binary independent of launch shape — directly-invoked version-named native binary, `claude` shim, or `claude --resume` — and MUST fail closed when no Claude ancestor binary can be identified (binding: `session-discovery`).

## Patch-Anchor Evidence Requirements

- Claude Code patch anchors MUST be chosen by semantic analysis of the pinned target bundle, not by trusting a generic matcher. For each anchor, the implementation must explain which Claude Code behavior the code controls and why that behavior is the required seam.
- `archived-filter` must anchor to the actual provider-bound transcript visibility path. `message-content-ids` must anchor to the actual provider-bound message-content construction path. `context-bonsai-gauge` must anchor to the actual model-visible gauge/reminder/attachment paths required by its story.
- Required evidence must identify plausible nearby or similar-looking Claude Code candidates and explain why they are wrong; ambiguous or no-match cases must fail closed.
- Synthetic fixtures may test helper mechanics, but happy-path or made-up fixtures are not acceptance evidence for Claude Code anchor correctness. A check that only shows a sentinel appears exactly once is necessary but not sufficient, because the sentinel proves insertion at the selected location rather than semantic correctness of the selected anchor.
- Reviewers should report missing semantic anchor analysis, missing rejection of plausible wrong anchors, or reliance on synthetic fixtures/sentinel checks as HIGH findings by default, and CRITICAL findings when the evidence is used to claim the native Claude Code release gate passed.
- Fail-closed thresholds such as `minScore` and `minMargin` must remain mandatory; do not lower them or bypass ambiguity errors to make the pinned target pass.

## Parity Gaps Against Shared Spec

- In-band gauge delivery without the tweakcc patch is best-effort (text in tool responses, not a separate signal).
- System guidance is constrained to tool descriptions; the cross-agent spec's six-bullet guidance contract (§1) is delivered partially via the tool description and the model's prior knowledge.
- No agent-repo to verify; behavior is validated entirely through end-to-end testing against a live Claude Code session.

## Specified Implementation Direction

- Preferred: MCP server in `tweakcc_context_bonsai/` plus the tweakcc transcript-rewrite patch, with prune guarded by patch-presence verification.
- Acceptable: replacing the tweakcc patch with an equivalent transcript-rewrite seam that satisfies the shared spec's placeholder and follower-omission requirements.
- Not acceptable: shipping prune as successful when no transcript-rewrite seam is present; that silently leaves archived content in the model-facing transcript.

## E2E Priorities

- Prune/retrieve roundtrip on a real Claude Code session transcript
- Pattern-matching by tool name, input, AND output across a transcript with diverse tool-use blocks
- Persistence: archive survives `claude --resume`
- Compatibility error on missing transcript or schema drift
- Secret-prune oracle: pruned content is not recoverable from active context alone

See `tweakcc_context_bonsai/docs/e2e-protocol.md` for the canonical step-by-step procedure.

## Key References

Structural references (source files, storage locations, seam sites) live in [`claude-code-context-bonsai-bindings.md`](claude-code-context-bonsai-bindings.md) §Key References.
