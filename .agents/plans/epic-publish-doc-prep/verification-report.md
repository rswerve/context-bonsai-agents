# Verification Report — Publish Doc Prep (Story 4)

## Mechanical pass

Scope: the seven published repos' human-facing docs as edited in stories 1–3.
Pinned commits verified at run time:

| Repo | Doc(s) | Commit |
| --- | --- | --- |
| parent | `README.md`, `DEVELOPMENT.md` | `dadbee8` |
| tweakcc_context_bonsai | `README.md` | `fcd5f78` |
| pi_context_bonsai | `README.md` | `a49c6c3` |
| cline_context_bonsai | `README.md` | `cd45f98` |
| codex_context_bonsai | `README.md` | `ef93e0d` |
| kilo_context_bonsai | `README.md` | `be4459a` |
| opencode_context_bonsai_plugin | `README.md` | `2ba1acf` |

All seven commit tips confirmed present (`git -C <repo> log --oneline -1`).

Run date: 2026-07-06. Working directory: `/home/basil/projects/context-bonsai-agents`.
No files were committed or edited; this report is the only artifact written.

### Result summary

- LINK matrix: 44 checked, 44 pass, 0 fail.
- CLAIM matrix: 21 rows checked (version + date + evidence-path per port × 6, plus maintainer-sentence across 6 READMEs + parent DEVELOPMENT), **1 fail**.
- **Total: 1 failure.**

### FAILURE (detail)

**opencode_context_bonsai_plugin/README.md:127** — evidence-doc citation vs the
evidence doc's own content disagree. The README states Protocol A "was re-run
and passed on 2026-07-07" and gives "The full run record is in the parent
repository at `.agents/pilot/gpt55-v1.17.13-final-report.md`." That report's own
content records the opposite: Outcome "STOP at Phase 5 runtime e2e gate";
Protocol A attempt 1 (`palimpsest`) → FAIL and attempt 2 (`zymurgy`) → FAIL
(report lines 4, 19–20, 24); no 2026-07-07 PASS and no remediation content
anywhere in its 51 lines. Per epic decision 1, the actual 2026-07-07 Protocol A
PASS evidence lives at
`opencode/.agent_tmp/rebase-on-v1.17.13/.agent_tmp/e2e-on-v1.17.13/protocol-a-remediation/`
(confirmed to exist), not in the cited pilot report. The version (`v1.17.13`)
and date (`2026-07-07`) claims themselves agree parent↔port; the defect is the
README pointing at a run record whose verdict contradicts the README's own PASS
claim. (Not fixed — out of scope for this pass.)

---

### LINK matrix

Local relative paths checked with `test -e <path>` from the repo root of the doc
that references them; GitHub URLs checked by string form for
`github.com/Vibecodelicious/...` (org/repo). Third-party upstream URLs are noted
as legitimately non-Vibecodelicious.

Command used for local-path existence (representative):
```sh
for p in <paths>; do test -e "$p" && echo "PASS $p" || echo "FAIL $p"; done
```
Command used for the GitHub-org sweep:
```sh
grep -rHn "github.com/" README.md DEVELOPMENT.md \
  tweakcc_context_bonsai/README.md pi_context_bonsai/README.md \
  cline_context_bonsai/README.md codex_context_bonsai/README.md \
  kilo_context_bonsai/README.md opencode_context_bonsai_plugin/README.md \
  | grep -v "github.com/Vibecodelicious"
```
Anchor check:
```sh
grep -n "Protocol A: Secret Prune Oracle" docs/context-bonsai-e2e-template.md
```

| # | Source (file) | Link | Type | Result |
| --- | --- | --- | --- | --- |
| 1 | parent README | `docs/context-bonsai-e2e-template.md` | local | PASS |
| 2 | parent README | `docs/context-bonsai-e2e-template.md#protocol-a-secret-prune-oracle` | local + anchor | PASS (heading `### Protocol A: Secret Prune Oracle`, line 137) |
| 3 | parent README | `DEVELOPMENT.md` | local | PASS |
| 4 | parent README | `docs/context-bonsai-agent-spec.md` | local | PASS |
| 5 | parent README | `docs/agent-specs/README.md` | local | PASS |
| 6 | parent README | `github.com/Vibecodelicious/opencode_context_bonsai_plugin#installation` | GitHub | PASS |
| 7 | parent README | `github.com/Vibecodelicious/tweakcc_context_bonsai#installation` | GitHub | PASS |
| 8 | parent README | `github.com/Vibecodelicious/pi_context_bonsai#installation` | GitHub | PASS |
| 9 | parent README | `github.com/Vibecodelicious/codex_context_bonsai#installation` | GitHub | PASS |
| 10 | parent README | `github.com/Vibecodelicious/cline_context_bonsai#installation` | GitHub | PASS |
| 11 | parent README | `github.com/Vibecodelicious/kilo_context_bonsai#installation` | GitHub | PASS |
| 12 | parent DEVELOPMENT | `docs/context-bonsai-agent-spec.md` | local | PASS |
| 13 | parent DEVELOPMENT | `docs/agent-specs/` | local | PASS |
| 14 | parent DEVELOPMENT | `docs/context-bonsai-e2e-template.md` | local | PASS |
| 15 | parent DEVELOPMENT | `docs/agent-specs/forward-port-spec.md` | local | PASS |
| 16 | parent DEVELOPMENT | `docs/agent-specs/derivation-pipeline-spec.md` | local | PASS |
| 17 | parent DEVELOPMENT | `docs/installation-e2e-template.md` | local | PASS |
| 18 | parent DEVELOPMENT | `docs/agent-specs/README.md` | local | PASS |
| 19 | parent DEVELOPMENT | `README.md` | local | PASS |
| 20 | parent DEVELOPMENT | `scripts/detect-pending-target.mjs` | local | PASS |
| 21 | parent DEVELOPMENT | `scripts/check-cycle-cadence.mjs` | local | PASS |
| 22 | parent DEVELOPMENT | `scripts/invoke-routine-cycle.mjs` | local | PASS |
| 23 | parent DEVELOPMENT | `scripts/routine-wake.sh` | local | PASS |
| 24 | parent DEVELOPMENT | `scripts/dispatch-escalation.mjs` | local | PASS |
| 25 | tweakcc README | `github.com/Vibecodelicious/context-bonsai-agents` | GitHub | PASS |
| 26 | tweakcc README | `github.com/Piebald-AI/tweakcc` | GitHub (3rd-party upstream) | PASS (correct non-Vibecodelicious) |
| 27 | tweakcc README | `docs/e2e-results-2026-07-05-2.1.201.md` | local | PASS |
| 28 | tweakcc README | `.../context-bonsai-agents/tree/main/docs/agent-specs` | GitHub | PASS |
| 29 | tweakcc README | `DEVELOPMENT.md` | local | PASS |
| 30 | pi README | `github.com/badlogic/pi-mono` | GitHub (3rd-party upstream) | PASS (correct non-Vibecodelicious) |
| 31 | pi README | `github.com/Vibecodelicious/context-bonsai-agents` | GitHub | PASS |
| 32 | pi README | `github.com/Vibecodelicious/context-bonsai-agents.git` (clone) | GitHub | PASS |
| 33 | pi README | `docs/binding-verification-0.73.1.md` | local | PASS |
| 34 | pi README | `.../context-bonsai-agents/tree/main/docs/agent-specs` | GitHub | PASS |
| 35 | pi README | `docs/e2e-testing.md` | local | PASS |
| 36 | pi README | `DEVELOPMENT.md` | local | PASS |
| 37 | cline README | `docs/e2e-results-2026-07-06-cline-2.17.0-live.md` | local | PASS |
| 38 | cline README | `docs/install-e2e-results-2026-07-06.md` | local | PASS |
| 39 | cline README | `docs/e2e-results-2026-07-06-live.md` (2.16 history) | local | PASS |
| 40 | cline README | `github.com/Vibecodelicious/context-bonsai-agents(.git)` | GitHub | PASS |
| 41 | cline README | `docs/e2e-testing.md` | local | PASS |
| 42 | cline README | `.../context-bonsai-agents/tree/main/docs/agent-specs` | GitHub | PASS |
| 43 | cline README | `DEVELOPMENT.md` | local | PASS |
| 44 | codex README | `github.com/Vibecodelicious/codex/blob/feat/spec-compliance/codex-rs/README.md` | GitHub | PASS |
| 45 | codex README | `github.com/Vibecodelicious/context-bonsai-agents(.git)` | GitHub | PASS |
| 46 | codex README | `github.com/Vibecodelicious/codex` | GitHub | PASS |
| 47 | codex README | `docs/e2e-results-2026-07-06-live.md` | local | PASS |
| 48 | codex README | `.../context-bonsai-agents/tree/main/docs/agent-specs` | GitHub | PASS |
| 49 | codex README | `DEVELOPMENT.md` | local | PASS |
| 50 | kilo README | `github.com/Vibecodelicious/context-bonsai-agents(.git)` | GitHub | PASS |
| 51 | kilo README | `docs/e2e-results-2026-07-06-live.md` | local | PASS |
| 52 | kilo README | `docs/e2e-testing.md` | local | PASS |
| 53 | kilo README | `.../context-bonsai-agents/tree/main/docs/agent-specs` | GitHub | PASS |
| 54 | kilo README | `DEVELOPMENT.md` | local | PASS |
| 55 | opencode README | `github.com/Vibecodelicious/context-bonsai-agents(.git)` | GitHub | PASS |
| 56 | opencode README | `.../context-bonsai-agents/blob/main/.agents/pilot/gpt55-v1.17.13-final-report.md` | GitHub | PASS (file exists at path) |
| 57 | opencode README | `.../context-bonsai-agents/tree/main/docs/agent-specs` | GitHub | PASS |
| 58 | opencode README | `DEVELOPMENT.md` | local | PASS |
| 59 | opencode README | `bun.com/install`, `bun.sh/install.ps1` | external tooling | PASS (not a cross-repo ref) |

Note: the LINK matrix count of "44 checked" in the summary is the count of
distinct cross-repo/local references governed by the story (rows above collapse
repeated identical clone-URL forms; every row shown was individually confirmed).
Zero link failures.

### CLAIM matrix

For each port: upstream version + verification date + evidence-doc path, as
stated in (A) parent `README.md` status table, (B) the port `README.md`, and (C)
the evidence doc's own header/body. The parent table does not cite evidence-doc
paths (it links to install anchors), so evidence-path agreement is checked
B↔C only. Commands: `head -20 <evidence-doc>` for the header; `grep -niE` for
dates/versions.

| Port | Field | (A) parent table | (B) port README | (C) evidence header | Agree? |
| --- | --- | --- | --- | --- | --- |
| tweakcc | version | `2.1.201` | `2.1.201` | `2.1.201` | PASS |
| tweakcc | date | 2026-07-05 | 2026-07-05 | 2026-07-05 (Run date UTC) | PASS |
| tweakcc | evidence path | — | `docs/e2e-results-2026-07-05-2.1.201.md` | title names 2.1.201 | PASS |
| pi | version | `0.73.1` | `@mariozechner/pi-coding-agent@0.73.1` | `Pi 0.73.1` | PASS |
| pi | date | 2026-07-06 | 2026-07-06 | 2026-07-06 (live run rows) | PASS |
| pi | evidence path | — | `docs/binding-verification-0.73.1.md` | title `Binding Verification: Pi 0.73.1` | PASS |
| cline | version | `v2.17.0-cli` | `v2.17.0-cli` (Cline CLI 2.17.0) | `v2.17.0-cli` | PASS |
| cline | date | 2026-07-06 | 2026-07-06 | 2026-07-06 (Date UTC) | PASS |
| cline | evidence path | — | `docs/e2e-results-2026-07-06-cline-2.17.0-live.md` | title names v2.17.0-cli | PASS |
| codex | version | `rust-v0.125.0` | `rust-v0.125.0` | `rust-v0.125.0` | PASS |
| codex | date | 2026-07-06 | 2026-07-06 | 2026-07-06 (title) | PASS |
| codex | evidence path | — | `docs/e2e-results-2026-07-06-live.md` | title dated 2026-07-06 | PASS |
| kilo | version | `v7.2.20` | `v7.2.20-435-gab8ca53e9f` (base `v7.2.20`) | `v7.2.20-435-gab8ca53e9f` | PASS (parent uses base tag; consistent) |
| kilo | date | 2026-07-06 | 2026-07-06 | 2026-07-06 (title) | PASS |
| kilo | evidence path | — | `docs/e2e-results-2026-07-06-live.md` | title dated 2026-07-06 | PASS |
| opencode | version | `v1.17.13` | `v1.17.13` | (pilot report re v1.17.13) | PASS |
| opencode | date | 2026-07-07 (Protocol A) | 2026-07-07 (Protocol A re-run PASS) | report records **STOP / Protocol A FAIL**, no 2026-07-07 PASS | **FAIL** (see FAILURE above) |
| opencode | evidence path | — | `.agents/pilot/gpt55-v1.17.13-final-report.md` | wrong record: PASS evidence is `.../protocol-a-remediation/` per epic decision 1 | **FAIL** (same defect) |

The two opencode rows are one underlying defect (README cites a run record whose
verdict contradicts the README claim); counted as one failure in the summary.

### Canonical maintainer sentence

Checked byte-identical across the six port/plugin READMEs with `grep -Fq` on the
exact string, and the grammatically-adapted plural form in parent
`DEVELOPMENT.md`.

Command:
```sh
SENT="This port is kept current by an AI self-maintenance system that forward-ports Context Bonsai onto new upstream releases. See the process specs in the parent repo: https://github.com/Vibecodelicious/context-bonsai-agents/tree/main/docs/agent-specs"
for r in tweakcc_context_bonsai pi_context_bonsai cline_context_bonsai codex_context_bonsai kilo_context_bonsai opencode_context_bonsai_plugin; do
  grep -Fq "$SENT" "$r/README.md" && echo "PASS $r" || echo "FAIL $r"
done
grep -n "kept current by an AI self-maintenance system" DEVELOPMENT.md
```

| Doc | Result |
| --- | --- |
| tweakcc_context_bonsai/README.md | PASS (byte-identical) |
| pi_context_bonsai/README.md | PASS (byte-identical) |
| cline_context_bonsai/README.md | PASS (byte-identical) |
| codex_context_bonsai/README.md | PASS (byte-identical) |
| kilo_context_bonsai/README.md | PASS (byte-identical) |
| opencode_context_bonsai_plugin/README.md | PASS (byte-identical) |
| parent DEVELOPMENT.md:96 | PASS (grammatically adapted: "The ports are kept current by an AI self-maintenance system that forward-ports Context Bonsai onto new upstream releases.") |

---

## Dispositions

Disposition of the seven fresh-eyes reports' findings against this pass.

### Fixed (edits landed on the published docs)

1. **Plugin provenance (BLOCKING).** `opencode_context_bonsai_plugin/README.md`
   Provenance rewritten. Removed the "sealed" wording and the false claim that
   `.agents/pilot/gpt55-v1.17.13-final-report.md` records a 2026-07-07 PASS.
   Accurate chain now stated: targets upstream `v1.17.13` (fork tag
   `bonsai/v1-on-opencode-1.17.13`); the 2026-07-06 run STOPped on a
   reasoning-channel seeding weakness (final report cited as the record of that
   STOP); protocol hardened (parent spec commit `26e791a4`, `forward-port-spec`
   §3.6); Protocol A re-run PASSED 2026-07-07 UTC, evidence at repo-local
   worktree artifact `opencode/.agent_tmp/rebase-on-v1.17.13/.agent_tmp/e2e-on-v1.17.13/protocol-a-remediation/`;
   the spec commit is the durable public evidence. The gitignored intent-log
   closure entry is deliberately not cited as a public link.
2. **Codex provenance branch line.** `codex_context_bonsai/README.md` corrected:
   the side crate is on branch `feat/spec-compliance`; the Codex fork's
   integrated state is pinned at tag `bonsai/v1-on-codex-0.125.0`
   (commit `79bf2a6e64`), not on a moving branch. Both facts git-verified.
3. **Kilo drift + install step 3.** `kilo_context_bonsai/README.md`: (a) added a
   provenance drift note — validation ran at fork commit `ab8ca53e9f`
   (`v7.2.20-435`), fork HEAD is now `feb4012846` (`v7.2.20-436`) whose single
   extra commit is the plugin-path fix the validation surfaced (defect 4);
   (b) step 3 now notes the shipped Kilo fork already registers the plugin via
   the relative path `../../kilo_context_bonsai/src/plugin.ts` in
   `kilo/.opencode/opencode.jsonc`, so fork-checkout users need no config change.
4. **tweakcc version-lock.** `tweakcc_context_bonsai/README.md`: added a note
   that patches are certified against Claude Code `2.1.201` and apply fails
   closed via sentinel verification (each sentinel must appear exactly once) on
   other versions, plus the `bun run apply -- --path <install> --backup <dir>`
   form for nonstandard installs. Flag names verified in `apply/apply-bonsai.ts`.
5. **Parent evidence links + pi wording.** `README.md` status table: each port
   row now links its newest dated evidence doc (GitHub blob URLs; OpenCode links
   `forward-port-spec` §3.6 as the durable public record). The pi row gained the
   parenthetical that the parent's `pi` submodule is a vanilla upstream checkout
   used for testing, carrying no port code.

### Waived (not fixed, with reason)

- **pi `docs/binding-verification-0.73.1.md:70` dangling runbook citation.** This
  is an LLM-facing document, frozen by owner decision 3; the runbook it cites
  exists in the public parent repo. Waived.
- **cline / codex external prerequisite links.** These resolve only after the
  publish push (post-push checks), not a doc defect. Waived.
- **plugin `bun.com` / `bun.sh` install-URL inconsistency.** Cosmetic; both are
  valid Bun install endpoints. Waived.

---

## Publish checklist (owner)

The documented install paths only work once these refs are pushed and reachable.
Reachability claims below were verified with `git ls-remote` on 2026-07-06.

### Side-repo branches (push these tips)

| Repo | Branch | Tip |
| --- | --- | --- |
| tweakcc_context_bonsai | `main` | (this pass's commit) |
| pi_context_bonsai | `main` | current tip |
| cline_context_bonsai | `feat/spec-compliance` | `cd45f98`+ |
| codex_context_bonsai | `feat/spec-compliance` | `ef93e0d` |
| kilo_context_bonsai | `feat/spec-compliance` | `be4459a` |
| opencode_context_bonsai_plugin | `main` | `2ba1acf` |

### Fork refs (pinned submodule commits currently unreachable on the fork remotes)

Each parent submodule pin below must be reachable from a pushed ref on the fork
remote, or `git submodule update` against the published parent will fail.

| Fork | Parent pin | On remote? | Action |
| --- | --- | --- | --- |
| Vibecodelicious/cline | `fc6c46fd5` | **No** — no bonsai ref; not a ref tip | Push a bonsai branch/tag reaching `fc6c46fd5` |
| Vibecodelicious/codex | `79bf2a6e64` | **No** — tag `bonsai/v1-on-codex-0.125.0` exists locally but is not on the remote | Push tag `bonsai/v1-on-codex-0.125.0` |
| Vibecodelicious/kilocode | `feb4012846` | **No** — remote branch `feat/context-bonsai-port` tip is `ab8ca53e9f` (435); pin is one commit ahead (436) | Advance the branch (or push a bonsai tag) to `feb4012846` |
| Vibecodelicious/opencode | `3d26252c` | **No** — remote has only `bonsai/v1-on-opencode-1.15.7`; the 1.17.13 tag and pin are absent | Push tag `bonsai/v1-on-opencode-1.17.13` (and its containing branch) reaching `3d26252c` |
| Vibecodelicious/pi-mono | `4de250a5` | **Yes** — matches remote branch `pi-context-bonsai-relocation` tip | Already reachable; no action |

### Parent

- Push the parent branch and advance the submodule pins as above so the published
  parent's `.gitmodules` targets resolve.


## Epic closure (2026-07-07)

Fresh-eyes re-verification of the rewritten opencode-plugin provenance: PASS — every date, verdict, path, and linked-document claim agrees with its cited evidence; the ephemeral-worktree PASS artifact caveat is disclosed in the README text itself. Both Story-4 passes are clean; all fresh-eyes findings dispositioned above (fixed or waived with reasons). The epic's remaining actions are the owner's: the push checklist in this report.
