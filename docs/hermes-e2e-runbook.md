# Hermes Agent E2E Runbook: Concrete Command Bindings

This document supplies the concrete commands for the Hermes port's e2e procedure, `hermes_context_bonsai/docs/e2e-testing.md` (a combined installation+runtime document). Verdict rules, scenario semantics, evidence-channel rules, and credential discipline stay in the procedure doc and the shared templates — this document binds only the commands and Hermes facts they leave as slots.

Paths are relative to the parent repo root (`context-bonsai-agents/`) unless a block says otherwise. All EXECUTED citations ran 2026-07-07 against hermes-agent tag `v2026.7.1` (SHA `7c1a029553d87c43ecff8a3821336bc95872213b`) with the side repo at its Stage 5 head; evidence: `hermes_context_bonsai/docs/e2e-results-2026-07-07-live.md`.

## Command provenance

- **EXECUTED** — ran against a real build of the ported harness, with recorded results.
- **SOURCE-VERIFIED** — read from a cited site in the harness or side-repo source, not yet driven live here.
- **COMPOSED** — assembled from EXECUTED and SOURCE-VERIFIED primitives but not yet run end-to-end in that exact sequence.

Composed sequences first run at the next forward-port cycle's gates; a composed-command failure there is a finding against this runbook, not license to improvise.

## Shared bindings

- **Frozen harness clone** (COMPOSED for a fresh target; every downstream command EXECUTED against the derivation-time clone at this identity): the runtime under test is a source clone of the harness at the frozen tag, hydrated with `uv sync`, resolved by every drive through `HERMES_AGENT_ROOT`:

```bash
V=2026.7.1                          # frozen target version
ART=/tmp/hermes-bonsai-artifacts/hermes-agent/$V
git clone --branch "v$V" --depth 1 https://github.com/NousResearch/hermes-agent "$ART/clone"
git -C "$ART/clone" rev-parse HEAD   # must equal the frozen commit SHA (runtime target binding)
(cd "$ART/clone" && uv sync)
export HERMES_AGENT_ROOT="$ART/clone"
```

  Record the tag, the peeled SHA, the clone command, and the `uv sync` result in `$ART/manifest.json` (the §3.1 extraction-manifest realization for this shape). The drives default `HERMES_AGENT_ROOT` to the derivation-time path `/tmp/hermes-bonsai-derivation/hermes-agent`; a cycle always exports its own clone path instead.
- **Scratch root** (EXECUTED): all drive state (assembled `HERMES_HOME`, work dirs, logs, PTY transcripts) roots at `HERMES_BONSAI_SCRATCH_ROOT` (default `/tmp/hermes-bonsai-scratch`). Every drive wipes and reassembles its own slice; delete the whole root freely between runs, and remove it per forward-port-spec §1.19 once the run's results doc is committed. Nothing under it touches the operator's real `~/.hermes`.
- **Side-repo validation** (EXECUTED; from `hermes_context_bonsai/`): the pytest suite runs under the harness clone's interpreter (it imports the harness's `agent.context_engine` ABC):

```bash
HERMES_AGENT_ROOT="$ART/clone" uv run --project "$ART/clone" pytest tests -q   # 91 tests at v2026.7.1
uvx ruff@0.15.10 check .
```

- **Scenario matrix** (EXECUTED; from `hermes_context_bonsai/`): the whole automatable runtime matrix, 8 rows from clean state, per-row PASS/FAIL table, exit 0 only on 8/8:

```bash
HERMES_AGENT_ROOT="$ART/clone" bash scripts/run-scenarios.sh
```

  Rows and backing drives are tabulated in `hermes_context_bonsai/DEVELOPMENT.md`; every row is a real-entry-point `uv run hermes` drive against the stdlib stub provider (`tools/stub_provider.py`), asserting from the stub's **recorded provider requests** (the model-visible-context evidence channel — what the model sees IS the request payload) and the scratch session store. Individual drives run standalone the same way (`bash scripts/smoke.sh`, `bash scripts/drive-prune.sh`, …).
- **Session and archive inspectors** (EXECUTED; `$HERMES_HOME` = the drive's scratch home):

```bash
sqlite3 "$HERMES_HOME/state.db" \
  "SELECT role, substr(content,1,200) FROM messages WHERE session_id='<sid>' AND active=1 ORDER BY id;"
# a realized prune leaves originals soft-archived: active=0, compacted=1
cat "$HERMES_HOME/context_bonsai/session-<sid>.json"   # port archive: recoverable originals + anchor/lifecycle metadata
```

- **PTY driver** (EXECUTED): scenarios that need one long-lived process (gauge cadence) or a real restart+resume (persistence) drive the interactive REPL through `hermes_context_bonsai/tools/repl_driver.py`. Three flags matter on slow local rigs: `--wait-db`/`--turn-targets` end turns by polling `state.db` for newly persisted assistant rows (screen-quiet heuristics fail during silent CPU prompt-eval), and `--workdir` runs Hermes from a neutral empty directory — run from the harness clone and its ~11k-token `AGENTS.md` is folded into every request's system prompt, overflowing small-`num_ctx` local models. The oneshot path (`hermes -z`) never resumes a session; resume drives must use the REPL's `--resume <session_id>`.

## Part 1: Runtime E2E

### Engine liveness (registration probe)

EXECUTED — matrix row 1 (`scripts/smoke.sh`). Offline half: `uv run --project "$ART/clone" hermes plugins list --plain --no-bundled` must show `context-bonsai` … `enabled`. Trap (procedure doc slot 5): that proves plugin **discovery** only — on engine-selection failure Hermes falls back to its built-in compressor silently and `plugins list` still reads `enabled`. The discriminating half is the smoke's recorded-request assertion: `context-bonsai-prune` present in the provider request's tool catalog with `context.engine: bonsai`, and absent with the engine left at default.

### E2E-01 / E2E-02 / E2E-05 — prune, boundary rejection, compatibility gate

EXECUTED — matrix rows 2/3/5 (`scripts/drive-prune.sh`, three drives in one script). Realization-timing evidence is the recorded request following the prune turn (placeholder present, originals gone) plus the `state.db` soft-archive check; the ambiguity rejection and the `compression.in_place: false` compatibility error both assert a deterministic tool-result error with zero mutation (no archive file, no `state.db` change).

### E2E-03 — retrieve + same-step guard

EXECUTED — matrix row 4 (`scripts/drive-retrieve.sh`): restored originals present and placeholder gone in the post-retrieve recorded request; retrieving an anchor whose prune is still `pending` from the same turn returns a deterministic guard error and leaves the pending prune untouched.

### E2E-04 — gauge cadence and silence

EXECUTED — matrix row 6 (`scripts/drive-gauge.sh`, PTY driver): gauge text asserted in the recorded requests of a single persistent REPL process (cadence state is in-memory per process — invisible to per-process `-z` drives), plus the missing-usage silence case.

### E2E-06 — persistence across restart/resume

EXECUTED — matrix row 8 (`scripts/drive-persistence.sh`): real process exit, REPL restart with `--resume <session_id>` (the only entry point that rehydrates history), archive state and anchors intact from disk.

### E2E-07 / Protocol A — secret prune oracle

EXECUTED, both halves, split per the procedure doc: the **payload oracle** (matrix row 7, `scripts/drive-secret-oracle.sh`, stub rig) proves the secret leaves every recorded request while summary/index terms survive; the **behavioral oracle** runs against a real model:

```bash
HERMES_AGENT_ROOT="$ART/clone" bash hermes_context_bonsai/scripts/drive-protocol-a-live.sh
```

  Zero-credential reference rig (EXECUTED ×2): a local ollama model behind `tools/openai_surface_proxy.py`, which exposes only the OpenAI-compatible `/v1` surface — pointed directly at ollama, Hermes recognizes the vendor and enforces a 64,000-token runtime `num_ctx` floor for tool use, a KV-cache allocation no model size fits in this host's RAM. Model provisioning (EXECUTED; shared with the Kilo rig): `printf 'FROM qwen2.5:7b-instruct\nPARAMETER num_ctx 6144\n' | ollama create qwen25-6k -f -` — size `num_ctx` to free RAM; an oversized model is refused by ollama and Hermes retries the refusal **silently forever** (frozen spinner), so every drive turn is hard-capped by the driver. Overrides: `LIVE_MODEL`, `LIVE_BASE_URL`, `LIVE_PROXY_PORT`, `LIVE_CONTEXT_LENGTH` (declared `model.context_length` must be ≥ 64000 — Hermes hard-rejects less at config level). Pattern-dictation discipline (procedure doc): the drive dictates sentinel boundary patterns by fragments the model assembles — a verbatim-quoted pattern makes the instruction message itself a second match and trips the port's ambiguity guard.

## Part 2: Installation E2E

EXECUTED (local variant, 2026-07-07): the side-repo README's install commands run verbatim (copy form) against a clean isolated `$HERMES_HOME` — `mkdir -p` + `cp -r context-bonsai/` into `$HERMES_HOME/plugins/`, then the three config lines (`plugins.enabled: [context-bonsai]`, `context.engine: bonsai`, `compression.in_place: true`). Verification halves: `hermes plugins list --plain --no-bundled` shows the plugin enabled, and a stub-backed `hermes -z` run from the installed home records both bonsai tools in the provider request's tool catalog. The local variant shares the host toolchain (uv, Python, the hydrated clone) and does not catch toolchain blind spots; the **sprite-based post-publish variant the procedure doc's slot 7 names is not yet bound here** — bind it (sprite create/exec/destroy plus this same command sequence from a fresh clone) before the first post-publish Hermes install gate. Until then only the host-local pre-publish path is bound, and run records must say so.

Teardown: `rm -rf "$HERMES_BONSAI_SCRATCH_ROOT"` and the cycle's `$ART` clone after the results doc is committed (forward-port-spec §1.19). Never touch the operator's real `~/.hermes`.
