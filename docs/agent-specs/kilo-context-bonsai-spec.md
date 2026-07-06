# Kilo Context Bonsai Spec

## Purpose

This document specializes the shared Context Bonsai contract for Kilo CLI, the OpenCode-derived runtime under `kilo`.
Kilo is the strongest native-fit host in this workspace because it already exposes the core transform hooks bonsai needs. The main constraint is fork discipline: plugin-first, shared-core-touch only as a last resort.

This is the **contract half** of the per-harness spec: the obligations and posture decisions that change only when the product's behavior contract changes or an integration-posture re-run revises them. The structural facts that realize these obligations — harness file paths, function names, storage locations, JSON shapes — live in the sibling [`kilo-context-bonsai-bindings.md`](kilo-context-bonsai-bindings.md) and are referenced here by `binding key`; the bindings document is the derivation pipeline's rewritable layer (`derivation-pipeline-spec.md` §2.2) and may change without an edit here so long as each referenced obligation still holds.

## User Model

### User Gamut

- Kilo CLI users running long terminal sessions
- VS Code users relying on the bundled Kilo runtime through the extension
- maintainers minimizing divergence from upstream OpenCode
- operators who need bonsai behavior in the shared CLI engine, not in one UI shell only

### User-Needs Gamut

- full bonsai parity using existing native hooks where possible
- durable archive state aligned with Kilo session storage
- gauge visibility to the model without depending on UI-only status affordances
- minimal shared-core drift from upstream OpenCode

### Ambiguities From User Model

- Whether any Kilo-specific persistence or multi-session UX needs should diverge from upstream OpenCode behavior. This spec says no unless a concrete Kilo-only requirement forces it.

## Integration Posture

### Required architecture stance

- Kilo Context Bonsai MUST be plugin-first.
- Shared core modifications are allowed only when a required capability cannot be expressed through the native plugin hooks.
- Any shared-core change SHOULD be isolated, minimal, and Kilo-marked per repo policy.
- Bonsai-specific logic SHOULD live in plugin-side code unless a tiny capability-enabling core seam is unavoidable.

### Prune and retrieve contract

- The model-facing tools MUST remain `context-bonsai-prune` and `context-bonsai-retrieve`.
- Archive state SHOULD be implemented in the same style as the OpenCode reference unless Kilo session differences require a narrow adaptation.
- Per shared spec Pattern Matching Contract, the prune-wrapper filter on the ambiguity path MUST be implemented inside the plugin's pattern resolver (binding: `prune-wrapper-filter`), operating on the message-transform input the plugin already receives.
- Per shared spec Pattern Matching Contract, the side-repo text-extraction layer MUST include each tool part's name, input arguments, and completed output in the searchable text it produces for `MessageText` (binding: `searchable-text`). Skipping non-text parts is a spec violation. Tool-call messages MUST be reachable by pattern.

### Transcript mutation path

- Placeholder rendering and archived-range elision SHOULD be implemented entirely through the message-transform hook (binding: `message-transform-hook`).

### System guidance path

- Bonsai guidance SHOULD be injected through the system-transform hook (binding: `system-transform-hook`).

### Gauge path

- Gauge SHOULD reuse Kilo's token usage and model limit data and be injected in-band through transcript transformation.

## Fail-Closed Requirements

- If required plugin hooks are unavailable at runtime, the plugin must return explicit compatibility errors.
- If a Kilo-only patch would create unnecessary upstream drift, the implementation plan must justify it explicitly.

## Parity Gaps Against Shared Spec

- Host capability gaps are minimal.
- The real constraint is fork-maintenance cost and minimizing divergence from shared OpenCode files.

## Specified Implementation Direction

- Preferred: direct port of the OpenCode bonsai design through Kilo's plugin hooks.
- Acceptable: narrow shared-core change only where plugin hooks are insufficient.
- Not acceptable: broad Kilo-only divergence in shared OpenCode runtime code without a proven blocker.

## E2E Priorities

- OpenCode-parity prune/retrieve/gauge scenarios in the Kilo CLI runtime
- persistence across session reload and client surfaces that reuse the CLI engine
- regression checks that shared-core modifications remain minimal

## Key References

Structural references (source files, storage locations, seam sites) live in [`kilo-context-bonsai-bindings.md`](kilo-context-bonsai-bindings.md) §Key References.
