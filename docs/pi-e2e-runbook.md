# Pi E2E Runbook: Concrete Command Bindings

This runbook supplies the Pi-specific commands for the e2e scenarios that `pi_context_bonsai/docs/e2e-protocol.md` binds and `docs/agent-specs/forward-port-spec.md` §4.4 requires. The spec's §4.4 slot cites this document; routine cycle plans copy commands from here instead of inventing them. Verdict rules, scenario semantics, and credential discipline stay in the protocol doc and the templates it instantiates — this document binds only commands and Pi facts they leave as slots.

Paths are relative to the parent repo root (`context-bonsai-agents/`) unless a block states otherwise.

## Command provenance

Every command below carries one of three grounding marks:

- **EXECUTED** — ran against a real installed-Pi build with recorded results: the automated harness runs in the Test Runs table of `pi_context_bonsai/docs/e2e-testing.md` (2026-05-18 and 2026-07-05, both Protocol A PASS).
- **SOURCE-VERIFIED** — read from `pi_context_bonsai/test/e2e/run-e2e.sh`, the extension source (`src/schema.ts`, `src/retrieve.ts`), the side-repo README, or Pi's own source at a cited site.
- **COMPOSED** — assembled from EXECUTED and SOURCE-VERIFIED primitives but not yet run end-to-end in this exact sequence.

Composed sequences first run at a forward-port cycle's gates. If a composed command fails there, that is a finding against this runbook — fix it here, then re-run the gate — not license to improvise a substitute.

## Shared bindings

- **Provider and model**: every Pi launch takes `--provider "$BONSAI_E2E_PROVIDER" --model "$BONSAI_E2E_MODEL"`, provisioned out of band per §4.4's Credentials slot. Record the provider (only) in run records.
- **Timeouts**: `run-e2e.sh` does not wrap its own `pi` invocations in a timeout (recorded gap, protocol doc "Runtime e2e"); the operator wraps the whole script in one. Every manual `pi` drive below carries its own `timeout 120`. Exit 124, or a launch that dies before the model responds, is `BLOCKED` at that step, not `FAIL`.
- **Session file discovery** (SOURCE-VERIFIED, `run-e2e.sh` `pi_session_file`): the newest JSONL in the run's session dir — `ls -1t "$SESS_DIR"/*.jsonl | head -1`.
- **Evidence directory** (manual drives; per §4.4 Evidence paths): `/tmp/pi-bonsai-e2e/<version>/<scenario>/`. The automated harness manages its own throwaway work directory; preserve it with `BONSAI_E2E_KEEP_TMP=1`.

## Part 1: E2E-07 — Protocol A, automated

EXECUTED. From `pi_context_bonsai/`:

```bash
BONSAI_E2E_PROVIDER=<provider> BONSAI_E2E_MODEL=<model> \
  timeout 900 bash test/e2e/run-e2e.sh
```

Exit 0 is PASS; the script prints the `Protocol A transcript evidence` block (turn-3 prune tool call, turn-4 recall reply), which the run record cites. Non-zero with a preserved work directory is triaged per the protocol doc's Failure patterns. During a cycle, `PI_PKG` inside the script has already been bumped to the frozen target by the replay, so this run is the target-version runtime binding. Append the run's row to the Test Runs table in `pi_context_bonsai/docs/e2e-testing.md`.

The same PASS certifies E2E-01's prune-success/atomicity half (protocol doc, coverage table).

## Part 2: Manual-drive environment

COMPOSED from the harness's own EXECUTED staging steps (`run-e2e.sh` steps 1–2) — the manual drives below need an installed pinned Pi and a staged extension, which the automated harness sets up and tears down internally. Precondition (SOURCE-VERIFIED): `~/.pi/agent/extensions/context-bonsai` must not already exist; do not clobber it.

```bash
WORK=$(mktemp -d /tmp/pi-bonsai-e2e-manual-XXXXXX)
mkdir -p "$WORK/pi-install" "$WORK/run-cwd" "$WORK/session"
( cd "$WORK/pi-install" && npm init -y >/dev/null && \
  npm install --no-audit --no-fund @mariozechner/pi-coding-agent@<version> )
PI="$WORK/pi-install/node_modules/.bin/pi"

mkdir -p ~/.pi/agent/extensions/context-bonsai
cp -R pi_context_bonsai/src ~/.pi/agent/extensions/context-bonsai/src
cp pi_context_bonsai/package.json pi_context_bonsai/tsconfig.json \
   ~/.pi/agent/extensions/context-bonsai/
( cd ~/.pi/agent/extensions/context-bonsai && npm install --no-audit --no-fund --omit=dev )
```

Every drive launches from `$WORK/run-cwd` (cwd-independent discovery), with the shape (SOURCE-VERIFIED, `run-e2e.sh` `pi_turn`):

```bash
cd "$WORK/run-cwd"
timeout 120 "$PI" -p --mode json \
  --provider "$BONSAI_E2E_PROVIDER" --model "$BONSAI_E2E_MODEL" \
  --session-dir "$WORK/session" [--session "$SESS_FILE"] [--no-tools] \
  "<prompt>" > <turn>.jsonl 2> <turn>.err
SESS_FILE=$(ls -1t "$WORK/session"/*.jsonl | head -1)
```

Teardown: `rm -rf ~/.pi/agent/extensions/context-bonsai "$WORK"`.

## Part 3: E2E-01 placeholder half + E2E-03 retrieve roundtrip

COMPOSED. One session covers both: prune, verify the placeholder is model-visible, retrieve, verify restoration. The placeholder check is LLM-driven by necessity — the `--mode json` stream carries a turn's own events, never the assembled model-visible context (protocol doc, E2E-01 row).

```bash
# P1 — seed a uniquely bounded discussion (fresh session: omit --session)
"...pi_turn shape..." "Tell me three detailed facts about octopuses. At least a paragraph each."

# P2 — prune it
"...pi_turn shape... --session $SESS_FILE" \
  "Use context-bonsai-prune to archive the octopus discussion (my request and your answer). Choose from_pattern and to_pattern that each match exactly once."

# P3 — assert persistence and capture the anchor id (deterministic; never ask the model)
jq -r 'select(.customType=="context-bonsai:archive") | .data.anchorEntryId' "$SESS_FILE"
# Exactly one id must print; record it as <ANCHOR_ID>. Zero or multiple is a FAIL
# of the capture step. (Field: ArchiveRecord.anchorEntryId, SOURCE-VERIFIED
# pi_context_bonsai/src/schema.ts; retrieve takes it as anchor_id,
# SOURCE-VERIFIED src/retrieve.ts.)

# P4 — E2E-01 placeholder half: the model can only know this text from its visible context
"...pi_turn shape... --session $SESS_FILE --no-tools" \
  "Quote verbatim the text that now stands in place of the octopus discussion in your visible context. Do not use any tools."
# PASS: the reply reproduces the placeholder (summary + index terms present,
# octopus facts absent). FAIL: the original facts are quoted back.

# P5 — E2E-03 retrieve
"...pi_turn shape... --session $SESS_FILE" \
  "Use context-bonsai-retrieve with anchor_id <ANCHOR_ID> to restore the archived discussion."
jq -r 'select(.customType=="context-bonsai:archive-clear") | .data.anchorEntryId' "$SESS_FILE"
# Must print <ANCHOR_ID> (the tombstone persisted).

# P6 — restoration visible
"...pi_turn shape... --session $SESS_FILE --no-tools" \
  "Without using tools: what were the three octopus facts from earlier? Summarize each in one line."
# PASS: the facts are recounted from restored visible context.
```

Verdicts: **PASS** — P3 prints one id, P4 reproduces the placeholder, P5's tombstone persists, P6 recounts the restored content. **FAIL** — any assertion misses on a completed turn. **BLOCKED** — a launch/provider/timeout failure before the assertion could run.

## Part 4: On-demand drives (E2E-02, E2E-06)

Required only when a cycle's drift scan marks their binding rows `updated_anchor` (§4.4). COMPOSED:

- **E2E-02 ambiguity rejection**: seed the same marker text in two messages, then instruct — per §3.6's ambiguity-path driving discipline — "Invoke context-bonsai-prune with exactly these arguments and do not correct them: from_pattern: \"<marker>\", to_pattern: \"<marker>\" …; report the tool's verbatim output." Expect a deterministic plain-text error and `jq` count of archive entries = 0. A plain natural-language prune request does not reach this path (the model auto-refines the boundary).
- **E2E-06 persistence across resume**: after a prune, start a new Pi process with `--session "$SESS_FILE"` (the process exit between turns is inherent to `-p` mode — each `pi_turn` is already a fresh process; a stronger variant re-runs P4's placeholder check from a second `$WORK/run-cwd2` directory). Assert the archive entry survives on disk and the placeholder still renders per P4's method.

## Part 5: Installation e2e

The protocol doc's Installation section is already command-literal (README steps quoted verbatim, sprite phases, pre-publish bundle block); run it as written. Fresh-machine choice is machine-checkable as in the OpenCode runbook: if `sprite list` exits 0, use the sprite flow; otherwise the throwaway-directory variant above is **not** a substitute on the installation dimension (protocol doc, fresh-machine slot) — record the run as `BLOCKED (sprite-unavailable)` rather than downgrading the dimension. Results land in `pi_context_bonsai/docs/install-e2e-results-<DATE>.md`, committed in that side repo.
