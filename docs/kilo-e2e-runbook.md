# Kilo E2E Runbook: Concrete Command Bindings

This document supplies the concrete commands for the Kilo port's e2e procedure, `kilo_context_bonsai/docs/e2e-testing.md` (a combined installation+runtime document). Verdict rules, scenario semantics, evidence-channel rules, and credential discipline stay in the procedure doc and the shared templates — this document binds only the commands and Kilo facts they leave as slots.

Paths are relative to the parent repo root (`context-bonsai-agents/`) unless a block says otherwise. All EXECUTED citations ran 2026-07-06 against fork commit `ab8ca53e9f` (branch `feat/context-bonsai-port`) with the side repo at zod 4.1.8; evidence: `kilo_context_bonsai/docs/e2e-results-2026-07-06-live.md`.

## Command provenance

- **EXECUTED** — ran against a real build of the ported harness, with recorded results.
- **SOURCE-VERIFIED** — read from a cited site in the harness or side-repo source, not yet driven live here.
- **COMPOSED** — assembled from EXECUTED and SOURCE-VERIFIED primitives but not yet run end-to-end in that exact sequence.

Composed sequences first run at the next forward-port cycle's gates; a composed-command failure there is a finding against this runbook, not license to improvise.

## Shared bindings

- **Runtime under test** (EXECUTED): the fork's CLI engine driven from source. Every drive runs **from `kilo/packages/opencode`** (bun must see that package's tsconfig; see procedure doc slot 1):

```bash
RUN_HOME=/tmp/kilo-bonsai-e2e/home
WORK_DIR=/tmp/kilo-bonsai-e2e/run-cwd
mkdir -p "$RUN_HOME" "$WORK_DIR" /tmp/kilo-bonsai-e2e/logs
git -C "$WORK_DIR" init -q     # EXECUTED trap: non-git dirs → worktree "/" → EACCES on archive write

cd kilo/packages/opencode
env KILO_TELEMETRY_LEVEL=off \
    XDG_DATA_HOME="$RUN_HOME/.local/share" KILO_TEST_HOME="$RUN_HOME" \
  timeout 570 bun run --conditions=browser src/index.ts run \
    --dir "$WORK_DIR" --model "<provider>/<model>" "<prompt>" \
    > /tmp/kilo-bonsai-e2e/logs/<scenario>.log 2>&1
```

  Follow-up turns add `--continue`; each is a fresh process (which is why any multi-turn scenario inherently exercises E2E-06). `KILO_TELEMETRY_LEVEL` set to anything other than `all` disables telemetry (SOURCE-VERIFIED, `packages/kilo-telemetry/src/telemetry.ts:44`); `XDG_DATA_HOME` isolates the sqlite/session state (`KILO_TEST_HOME` alone only moves `Path.home`, not the xdg data dir — EXECUTED trap: the first smoke leaked state into the real `~/.local/share/kilo`). Exit 124 records BLOCKED, not FAIL.
- **Prerequisite installs** (EXECUTED): `bun install` at the `kilo/` repo root (workspace deps; expect a floating `ghostty-web` lockfile pin change — do not commit it) and `bun install` in `kilo_context_bonsai/`.
- **Work-dir config** (EXECUTED; `$WORK_DIR/opencode.jsonc`): plugin absolute path + provider. The zero-credential reference rig:

```jsonc
{
  "plugin": ["/abs/path/to/kilo_context_bonsai/src/plugin.ts"],
  "compaction": { "auto": false },          // keep kilo's own compaction out of drills
  // Small-local-model rigs: disable every built-in tool so only the two bonsai
  // tools are offered (EXECUTED set; drop this block for capable providers):
  "tools": {
    "bash": false, "edit": false, "write": false, "read": false, "glob": false,
    "grep": false, "task": false, "todowrite": false, "todoread": false,
    "webfetch": false, "websearch": false, "codesearch": false, "skill": false,
    "lsp": false, "question": false, "suggest": false, "kilo_local_recall": false
  },
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://127.0.0.1:11434/v1", "timeout": false },
      "models": { "qwen25-6k": { "tool_call": true, "limit": { "context": 8192, "output": 8192 } } }
    }
  }
}
```

  EXECUTED traps behind those three settings: ollama's OpenAI endpoint silently truncates at its 4096 `num_ctx` default while kilo's assembled prompt is ~4.3k tokens — bake the context into a derived model (`printf 'FROM qwen2.5:7b-instruct\nPARAMETER num_ctx 6144\n' | ollama create qwen25-6k -f -`; ollama multiplies KV allocation by its parallelism, so 6144 was the largest loadable value on the 2026-07-06 rig); kilo aborts requests whose headers haven't arrived after 120s unless provider `options.timeout` is `false` (SOURCE-VERIFIED, `packages/opencode/src/kilocode/provider/provider.ts:248`), and CPU prompt-eval exceeds that; a declared `limit.context` near real usage triggers kilo auto-compaction mid-drill, which copies drill content into its own summary. The `"tools"` map above matters for small local models (EXECUTED: the full toolset overwhelmed a 7B; with only the two bonsai tools offered it drove them correctly).
- **Archive and session inspectors** (EXECUTED):

```bash
cat "$WORK_DIR/.opencode/context-bonsai/<session-id>.json"        # metadata records; [] after retrieve
grep -c "<secret>" "$WORK_DIR/.opencode/context-bonsai/"*.json     # 0 always (metadata-only archive)
D="$RUN_HOME/.local/share/kilo"
SID=$(sqlite3 $D/kilo.db "SELECT session_id FROM message ORDER BY time_created DESC LIMIT 1;")
sqlite3 $D/kilo.db "SELECT json_extract(p.data,'\$.state.status'),
  substr(coalesce(json_extract(p.data,'\$.state.output'),json_extract(p.data,'\$.state.error'),''),1,200)
  FROM part p WHERE p.session_id='$SID' AND json_extract(p.data,'\$.type')='tool';"
```

- **Model-visible-context capture** (EXECUTED — the strongest evidence channel for E2E-01/07): point the provider `baseURL` at a one-shot local HTTP recorder for a single probe turn, then restore it. The recorder answers `GET /models` with the model id and dumps any `POST` body to disk before returning 500; the probe turn fails (harmless) but the captured JSON is the exact assembled request. Assert `raw.count(secret) == 0` and the placeholder `[PRUNED: <anchor> to <end>]` present with ids matching the archive file. Placeholder shape: SOURCE-VERIFIED, `kilo_context_bonsai/src/placeholder.ts:22`.

## Part 1: Runtime E2E

### Registration probe and live check

EXECUTED. Offline: the fork seam test, from `kilo/packages/opencode`: `bun test test/kilocode/context-bonsai.test.ts` (7 tests: production-loader path resolution, default-export shape, both tools + both transform hooks, `overflow.telemetry` math). Live: any driven turn logs `service=tool.registry status=completed` for both tool ids (grep the kilo log dir under `$D/log/`); PASS requires a live model call to a bonsai tool succeeding in-session. The seam test passing while the live check fails is FAIL (`tools-not-registered`).

### E2E-01 / E2E-07 — prune and Protocol A

EXECUTED as one session (`ses_0c9419a01ffeJENya3NQCNPnkB`): seed turn (secret + uppercase codeword; assistant answers a dictated uppercase word), prune turn in a new process, host-state checks, capture-probe turn, recall turn with tools forbidden. Pattern-dictation discipline is the procedure doc's; the EXECUTED indirection that converged: "the animal name zebrafish written in capital letters" for `from_pattern`, fragment-join ("join APPRO and VED") for `to_pattern`, plus "if the tool returns an error, fix the arguments and retry, up to 5 attempts".

### E2E-02 — boundary rejection

EXECUTED (as rejected attempts en route to the successful prune, plus dedicated failures): ambiguous pattern (`pattern ambiguous: … matched N messages`), unknown pattern (`pattern not found: …`), empty `to_pattern` (`to_pattern must be a non-empty string`). PASS: deterministic tool-result rejection and no archive file created.

### E2E-03 — retrieve by anchor

EXECUTED: follow-up turn instructing `context-bonsai-retrieve` with the exact anchor id from the prune result (the id is not a match pattern, so quoting it verbatim in the instruction is safe). PASS: archive file `[]`, model reproduces the previously unrecallable content.

### E2E-04 — gauge

NOT EXECUTED. Cadence is 5 transform calls counted per process (SOURCE-VERIFIED, `kilo_context_bonsai/src/gauge.ts:15` `CADENCE = 5`, `factory.ts` `bump()`), so cross-process `--continue` drives can never fire it — results-doc defect 3. COMPOSED single-process drive for a future run: one turn forcing ≥5 sequential model requests (a 4-call tool loop plus the answer), then a quote probe for the `<system-reminder>Context usage N%…` line (text: SOURCE-VERIFIED, `gauge.ts:43-67`). The 2026-07-06 rig's 7B model would not sustain the tool loop; run this against a stronger provider or after the defect fix.

### E2E-05 / E2E-06

E2E-05 non-live per the procedure doc (side-repo `bun test` carries fail-closed coverage). E2E-06 needs no dedicated drive: EXECUTED implicitly by the one-process-per-turn drive form (archive rehydrated from disk in processes that never saw the prune).

## Part 2: Installation E2E

COMPOSED (no fresh-machine run yet; commands assembled from the EXECUTED host-side sequence and the side-repo README). In a clean container from a pinned `oven/bun` image, bundle-sourced pre-publish per the shared sourcing discipline:

```bash
git clone <parent>.git context-bonsai-agents && cd context-bonsai-agents
git submodule update --init kilo kilo_context_bonsai
cd kilo_context_bonsai && bun install && bun test && bun run typecheck && cd ..
cd kilo && bun install && cd packages/opencode
bun test test/kilocode/context-bonsai.test.ts
```

then the live registration check and an E2E-01 + E2E-03 smoke via the shared drive form. The sprite-based post-publish variant the procedure doc's slot 7 names is **not yet bound here** — bind it (sprite create/exec/destroy plus this same command sequence) before the first post-publish Kilo install gate; until then only the pre-publish container path is bound. Provider for container smokes: any opencode-supported provider provisioned out of band; the zero-credential ollama rig requires the container to reach a local ollama (`--network host` or a mounted socket) — bind the choice in the run record. Teardown: destroy the container; on the host `rm -rf /tmp/kilo-bonsai-e2e` after the results doc is committed (forward-port-spec §1.19). Never touch `~/.local/share/kilo` beyond deleting state a run itself leaked there.
