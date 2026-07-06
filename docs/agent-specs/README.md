# Per-Agent Context Bonsai Specs

These documents specialize the shared Context Bonsai contract for each agent repo currently present in this workspace. Each harness has a document pair: the **contract half** (`*-spec.md` — obligations and posture decisions, stable across harness releases) and the **bindings half** (`*-bindings.md` — the exploration-derived structural facts realizing those obligations; the derivation pipeline's rewritable layer, referenced from the contract half by binding key).

- [claude-code-context-bonsai-spec.md](claude-code-context-bonsai-spec.md) · [bindings](claude-code-context-bonsai-bindings.md)
- [cline-context-bonsai-spec.md](cline-context-bonsai-spec.md) · [bindings](cline-context-bonsai-bindings.md)
- [codex-context-bonsai-spec.md](codex-context-bonsai-spec.md) · [bindings](codex-context-bonsai-bindings.md)
- [gemini-cli-context-bonsai-spec.md](gemini-cli-context-bonsai-spec.md) · [bindings](gemini-cli-context-bonsai-bindings.md)
- [kilo-context-bonsai-spec.md](kilo-context-bonsai-spec.md) · [bindings](kilo-context-bonsai-bindings.md)
- [pi-context-bonsai-spec.md](pi-context-bonsai-spec.md) · [bindings](pi-context-bonsai-bindings.md)

All of them derive from the shared contract in [context-bonsai-agent-spec.md](../context-bonsai-agent-spec.md). The procedure for deriving one — and for re-deriving a harness's forward-port bindings after a structural break — is [derivation-pipeline-spec.md](derivation-pipeline-spec.md).

The intent here is not to produce implementation plans yet. These are host-specific specifications that define the acceptable integration shape, the likely extension path, the known parity gaps, and the evidence-backed constraints that future implementation plans must respect.
