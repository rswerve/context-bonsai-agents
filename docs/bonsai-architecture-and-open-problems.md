# Context Bonsai on Claude Code + Codex — Architecture, Failure Modes, and the Case for a Deeper Fix

**Audience:** a fresh, capable model (Fable) asked to look for a *fundamentally cleaner* way to make Bonsai work, or to make the current approach structurally robust.
**Status as of 2026-07-23:** the current patch/fork approach is **live and works** — but it is a workaround with real structural fragility. This doc exists so you can either find a better door or harden the one we're using. **Challenge the assumptions marked ⚠️ LOAD-BEARING — several of our design choices are downstream of rulings that may be outdated or wrong.**

---

## 0. TL;DR

- **Goal:** autonomous, in-session, *recoverable* context management. The model itself calls `prune`/`retrieve`; pruned message ranges are hidden from the context assembled for the model each turn, but archived and byte-exactly restorable.
- **The hard part is ENFORCEMENT** — actually removing pruned messages from what the host sends to the model. Archiving is trivial; enforcement must happen *inside the host*.
- **Neither host offers a supported hook for context rewriting.** Combined with "subscription auth only" and "must not break AgentBridge," this forces us to **patch Claude Code's bundle** and **fork Codex**. There is no clean drop-in — the *official* Bonsai also patches Claude Code.
- **Everything fragile about this setup is downstream of that one fact.** The most recent bug (prune succeeding but reclaiming nothing in a running process) is a textbook example: the tool and the enforcer live on opposite sides of a seam the host won't help them share.

---

## 1. What Bonsai is, and the property that makes it hard

Bonsai lets a long session stay coherent by having the model prune completed, low-value stretches of its own transcript. A prune must satisfy three properties:

1. **Recorded** — an archive of the exact range is written, restorable later (`retrieve`).
2. **Enforced** — the pruned range is *removed from the context assembled and sent to the model on subsequent turns*, so the window actually shrinks.
3. **Recoverable & non-destructive** — nothing is lost; `retrieve` restores the range byte-for-byte.

(1) and (3) are easy — they're just file I/O in an MCP server. **(2) is the whole problem.** The host (Claude Code / Codex) owns the transcript and builds the provider request from it each turn. An external tool has no authority over that assembly. So enforcement must run *inside the host, at the point of context assembly.*

Ground truth for "did enforcement happen" is **the provider request's input token count** — not any on-screen gauge (see §5.7). A prune that archives but doesn't shrink the next provider request has failed, even if the UI says "Prune complete."

---

## 2. The hard constraints (the box we must stay inside)

| Constraint | Detail |
|---|---|
| **Two harnesses** | Claude Code (macOS, **Claude Max subscription**, ships as a **Bun-compiled Mach-O**) and Codex (**ChatGPT subscription**, Rust, Homebrew). Both must run Bonsai. |
| **AgentBridge** | A Claude↔Codex bridge (`~/.claude/plugins/…/agentbridge`, source `~/dev/agent-bridge`). It is **version-coupled to Codex's app-server wire schema**. Any Codex change that alters that schema breaks the bridge. |
| **herdr** | Multi-agent orchestrator the user relies on; must keep working. |
| **Subscriptions only — no API keys** | ⚠️ LOAD-BEARING. This is the single most consequential constraint; it kills the "clean" enforcement paths (see §3). |
| **Always-latest** | The user updates Claude/Codex to the newest release constantly, so the whole thing must **self-maintain** (auto re-cert / forward-port). |
| **macOS/arm64** | Session discovery, binary format, and build all target Darwin arm64. |

---

## 3. Why enforcement forces patching (the crux — and where to attack)

Enforcement must be inside the host. The candidate injection points, and why each is closed:

### Claude Code
- **MCP tools** — a separate process exposing tools. **Cannot** remove host-owned messages from the assembled context. Fine for record/retrieve, useless for enforcement. ⚠️ LOAD-BEARING: *is there any MCP/protocol capability (now or emerging) that lets a server influence context assembly?* We believe no; verify.
- **Official hooks** — forward-only (observe/block/inject). ⚠️ LOAD-BEARING: **as of 2.1.205–2.1.218 there is no hook that rewrites/removes outgoing context.** If a newer Claude Code added a "context transform" or "pre-request" hook, that would obviate the entire bundle patch. **Re-check current docs — this is the highest-value thing to falsify.**
- **Agent SDK** — full context control, but ⚠️ LOAD-BEARING **API-key only**; the Max *subscription* OAuth can't drive it. If that changed (subscription-auth SDK, or a supported subscription bridge), it could replace patching wholesale.
- **Local proxy** (strip messages between client and API) — the subscription OAuth is bound to Anthropic's endpoint, and there was a **ToS/legal block on Max-in-third-party clients (Apr 2026)**. So a proxy can't preserve subscription auth. ⚠️ verify current ToS posture.
- **∴ Bundle patch** — the *only* subscription-compatible enforcement point left. Claude Code is a **Bun single-file executable**: the JS is embedded in the Mach-O (`__BUN`/`$bunfs`) and *executed* by the embedded Bun runtime, so patching the embedded JS changes runtime behavior. This is what `tweakcc` does, and it's how the *official* Bonsai works too.

### Codex
- Codex is more open: a **local Responses provider with `requires_openai_auth=true` preserves ChatGPT-sub auth**, so a no-fork proxy path is *theoretically* possible. But enforcement still has to live at Codex's history/compaction seam, and the only way that keeps **AgentBridge** intact was a **minimal fork that changes no wire schema.** Hence fork, not proxy.

**Meta-point for a deeper fix:** every constraint above is a *ruling*, and rulings expire. The cleanest possible "deeper fix" is discovering that one of the ⚠️ LOAD-BEARING closures is no longer true (a new hook, a subscription-auth SDK, an MCP context capability). The second-cleanest is making the Codex-style *in-process* approach available to Claude via a more stable seam than bundle-patching.

---

## 4. The current architecture (what's live and how it fits together)

### 4.1 Claude side — four host patches + an MCP server
Injected into the Bun-embedded JS via `tweakcc`, each stamped with a grep-able sentinel (`grep -a`, it's a binary):

| Patch | Sentinel | Job |
|---|---|---|
| `archived-filter` | `cb:archived-filter` | Removes archived ranges from the context assembled for the model each turn. **Load-bearing for enforcement.** |
| `message-content-ids` | `cb:message-content-ids` | Stable per-message addressing so ranges resolve. |
| `context-bonsai-gauge` | `cb:context-bonsai-gauge` | Injects a context-pressure gauge + autonomous-prune guidance (every 5 user turns). |
| **`cbim-v1`** (added 2026-07-23) | `cbim` | **In-memory** archive-range map, decoded from the prune result at the provider seam and applied *same-turn, same-process* (the fix for §5.3). Emits a real acknowledgement (pid/build/archive/excluded count). |

Plus: the **`context-bonsai` MCP server** (`tweakcc_context_bonsai/mcp-server/index.ts`) providing `prune`/`retrieve`, registered in `~/.claude.json`; and a **macOS `ProcReader`** for session discovery (Darwin `ps`/`KERN_PROCARGS2` via Bun FFI / `lsof`, not Linux `/proc`).

### 4.2 Codex side — a minimal sidecar fork
A fork of Codex (Rust) that, after writing a persistent sidecar archive, calls Codex's own **`replace_compacted_history()`** in the same process (so it reclaims in-session natively), plus the guidance/gauge wiring and the audit acknowledgement. **No wire-schema change → AgentBridge-safe** (verified: 347-file app-server schema fingerprint identical to stock). Runs via `~/.local/bin/codex` → a content-addressed artifact.

### 4.3 Auto-maintenance (keeps it alive across updates)
- **External runtime**: `~/.local/share/context-bonsai/runtime/current` → a committed fork snapshot (currently commit `380bb5f`), **decoupled from the dev git checkout** so branch/pull/rebase can't break the live install.
- **Three lanes**, daily + a Claude **WatchPaths** instant-react agent: (1) Bonsai source sync from upstream, (2) Claude re-cert/re-apply, (3) Codex proactive forward-port to the latest *stable* upstream release.
- **Fail-safe transactions**: build+certify a candidate in isolation → verify → atomic swap (isolate-verify-swap for Claude, CAS symlink for Codex) → auto-rollback → on drift/conflict, do nothing and notify. Never leaves the install broken.
- **Forks**: `rswerve/context-bonsai-agents` + `rswerve/tweakcc_context_bonsai`, both on `main`.

### 4.4 Current live hashes (for grounding)
- Claude 2.1.218, binary sha `7ad4488b…`, four sentinels present.
- Codex 0.145.0, CAS artifact `bf0c6ea8…`.
- Same-process reclaim proven on the *installed* builds: Claude 105,585→25,887 (75.5%), Codex 95,617→29,802 (68.8%), each cross-attested over the bridge.

---

## 5. What has failed / the fragility catalog (read this closely)

This is the section that motivates a deeper fix. Each item is a real failure we hit, not a hypothetical.

**5.1 The re-patch treadmill.** Every Claude Code auto-update ships a fresh unpatched binary; the patch is wiped until re-applied. The auto-maintenance re-patches within seconds (WatchPaths), but the *anchors* (regex code-shape patterns locating the injection points) can **drift** when the bundle changes shape, requiring re-derivation. We've re-derived anchors by hand more than once (e.g., 2.1.215).

**5.2 Codex version drift.** Each upstream Codex release needs a rebase + full ~20-min release rebuild, and real API changes break the patch: e.g. 0.145.0 introduced a typed `ResponseItemId` and an `InputAudio` content variant that the port had to adapt to. Mechanical conflicts (upstream deleting adjacent declarations) also occur.

**5.3 The in-memory enforcement bug (the deepest one; fixed 2026-07-23).** For a long time, `prune` **archived but did not reclaim in a running session.** Root cause: the MCP server wrote `archived` flags to the session JSONL, but a long-lived Claude process **never re-imported those flags into its already-loaded in-memory transcript**; the `archived-filter` only hid messages already flagged *in memory*. So pruning only took effect after restart/resume. **It looked like it worked** (the tool returned `Prune complete` with an anchor id) while the window never shrank — worse than not pruning. Fixed by the `cbim-v1` patch (decode the prune metadata at the provider seam and filter from an in-memory map immediately). *This is the seam-mismatch archetype: tool-writes-to-disk vs. enforcer-reads-from-memory, with no host mechanism to reconcile them within a turn.*

> ⚠️ A prior diagnosis (`docs/incident-claude-code-native-binary.md`) blamed this on "Claude Code is now a native binary, so bundle patching can't attach." **That root cause is wrong** — 2.1.218 is Bun-compiled with embedded *patchable, executed* JS; the sentinels are present (the incident's `grep` lacked `-a` on a binary). The *symptom* it reported was real; the *cause* was the in-memory reimport gap above. Don't re-derive the native-binary red herring.

**5.4 Coordination seams between self-healing systems.** Activation (a maintenance transaction) writes the Claude binary; the WatchPaths reconciler *also* writes it and is *triggered by* the first write. They churned (multiple re-applies) until it settled. A **latent lock-race** made it worse: `run-daily.sh` set the `EXIT` cleanup trap *before* acquiring the lock, so a queued run that failed to acquire still fired its trap and deleted the *holder's* lock — defeating single-instance serialization. Fixed (trap after acquire; release checks PID ownership), but the two-writers-one-file design is inherently touchy.

**5.5 Model anti-injection resistance.** Even *testing* enforcement is hard: current models treat synthetic exact-string test protocols as prompt injection and refuse to call the tool, so behavioral tests need naturally-worded "installed extension" framing to get a real prune call.

**5.6 The deep-verification gap.** Headless certification (unit tests, schema parity, token-drop tests) can't run the *full live behavioral* test with a real model + bridge. A fix can pass every automated gate and still be subtly wrong in real use. Mitigation is a "spot-check when convenient" nudge, not a guarantee.

**5.7 Observability is misleading by default.** The context gauge is a *display* and lags/rises as new content is added; it is **not** proof a prune reclaimed. Operators (and models — I did this twice) infer "prune freed nothing" from a rising gauge, which is wrong. The only trustworthy signal is provider-request input tokens, same-PID, before vs. after.

---

## 6. The structural diagnosis

Every failure in §5 traces to one root: **we are bolting a context-rewriter onto two hosts that expose no supported seam for it, while holding subscription auth and a version-coupled bridge fixed.** The patches are load-bearing but *unofficial*, so they drift with every update; the enforcement and the tool live in different processes/memory spaces the host won't reconcile; and two self-healing systems fight over one file. It works, and it's now well-tested — but it's a treadmill with sharp edges, and each new host version is a fresh chance for a subtle seam bug like §5.3.

---

## 7. The open question for Fable (where a deeper fix might live)

Ranked roughly by leverage. The first three are "find a better door"; the rest are "harden the current one."

1. **Falsify the ⚠️ LOAD-BEARING closures.** The biggest win is discovering one is outdated:
   - Has Claude Code added an **official hook or extension point that can rewrite/remove outgoing context** (a "pre-request"/"context transform" hook, a plugin surface)? If yes, the entire Claude bundle patch could be retired.
   - Is there a **subscription-auth-compatible Agent SDK** or supported embedding path now? That would give clean context control.
   - Can an **MCP server influence context assembly** through any current/emerging protocol capability (elicitation, sampling, resource injection with removal semantics)?
   - Has the **ToS posture on local proxies / third-party clients** changed such that a subscription-preserving proxy is viable?
2. **A stable Claude-side in-process seam.** Codex's fork reclaims cleanly because it calls `replace_compacted_history()` *in-process*. Is there a Claude-side analog — a single, stable, version-resilient injection point (rather than three drifting anchors) that does in-memory enforcement + record in one place, minimizing re-cert surface?
3. **Reframe "prune" to fit MCP's real powers.** Is there a definition of context management that achieves most of the value *without* host enforcement — e.g., leveraging the host's native compaction/summarization primitives (Codex exposes `replace_compacted_history`; does Claude Code expose anything callable?) so the tool *drives* a supported mechanism instead of bypassing it?
4. **Make the patch self-describing / version-adaptive** so anchor drift doesn't require human re-derivation — e.g., structural/semantic matching robust to minification changes, or a patch that discovers its own injection point at load time.
5. **Collapse the two-writers-one-file design** (activation vs. WatchPaths reconciler) into a single serialized authority to eliminate churn and lock races structurally, not by patching the trap order.
6. **Close the deep-verification gap** — a way to run the real behavioral proof (same-process reclaim with a live model) as a gate, cheaply and without triggering anti-injection refusals.

A blunt honest take to react to: **the current approach may be the *right* answer given the constraints, and the deeper fix may be "make the patch self-describing + unify the writers," not "find a new door."** But #1 is worth an hour of genuine falsification before accepting that — because if a supported context-rewrite hook exists now, everything else here is obsolete.

---

## 8. Pointers for digging in

- **Claude port:** `tweakcc_context_bonsai/` — `patches/` (anchors + the 4 patches incl. `cbim`), `mcp-server/index.ts` (prune/retrieve + the runtime guard), `apply/` (tweakcc driver), `docs/e2e-protocol.md`.
- **Codex fork:** `codex/` (Rust source + Bonsai handlers) and `adoption/codex/` (patch, build, enable/rollback).
- **Auto-maintenance:** `adoption/auto-maintenance/` — `run-daily.sh` (orchestrator), `reconcile-claude.sh`, `codex/reconcile-codex.sh`, `source/`, `semantic-surface-guard.ts` (dormant), `lib.sh` (shared helpers incl. the fixed lock).
- **The wrong diagnosis (don't re-derive):** `docs/incident-claude-code-native-binary.md`.
- **Live reclaim evidence:** `.staging/same-process-reclaim-20260723/` (candidate + live-build JSON, with provider token counts, PIDs, binary hashes, acknowledgements).
- **Live install (outside git):** `~/.local/share/context-bonsai/runtime/current` → commit `380bb5f`; Claude binary `~/.local/share/claude/versions/2.1.218` (sha `7ad4488b`); Codex `~/.local/bin/codex` → CAS `bf0c6ea8`.
- **Forks:** `rswerve/context-bonsai-agents`, `rswerve/tweakcc_context_bonsai`.
- **Verify anything before trusting it.** The two hardest-won lessons here: (a) ground truth is *provider input tokens same-PID*, never the gauge; (b) the model's report of what it did carries no authority — read the diff / the evidence.

---

## 9. Findings — Fable + Codex falsification pass (2026-07-23)

Worked §7.1 as a joint pass: Fable (Claude) ran the docs/ToS falsification and the live proxy experiments; Codex mapped the embedded 2.1.218 JS for callable native primitives. Each claim below is tagged **[verified]** (we ran it / read live docs), **[reported]** (secondary sources, not yet primary-confirmed), or **[open]**.

### 9.1 The four load-bearing closures, re-checked

| Closure (§3) | Verdict | Basis |
|---|---|---|
| **Hooks can't rewrite outgoing context** | **HOLDS** | Full v2.1.218 hook inventory (code.claude.com/docs/en/hooks.md) can inject / block / mutate tool I/O only. No hook mutates existing transcript; no programmatic compaction API. **[verified against live docs]** |
| **MCP can't touch host context assembly** | **HOLDS** | Current MCP spec + 2026-07-28 RC: server→host surface is tools/resources/prompts only; "intentionally limits server visibility into prompts." **[verified against live docs]** |
| **Agent SDK is API-key-only** | **PARTIALLY FALSE** | SDK ran here on Max OAuth, **no API key** (`apiKeySource=none`). Policy pendulum: hard ban Feb–Apr 2026 → reversed May/Jun; the blanket "OAuth in any other product incl. Agent SDK not permitted" sentence is **gone from the live legal page**; Help Center (Jun 16) currently lets Agent SDK / `claude -p` / third-party apps draw on normal sub limits (separate SDK-credit plan was *paused*). **[verified: it runs] / [reported: policy]** |
| **No subscription-preserving proxy (ToS block)** | **EXPIRED** | The Apr 4 2026 hard enforcement was reversed. Anthropic's own **llm-gateway docs** now document `ANTHROPIC_BASE_URL` routing *with a retained claude.ai subscription login* as a supported config. **[verified against live docs]** |

The two "find a better door" closures that mattered most — SDK auth and proxy ToS — are **no longer solidly closed.** Hooks and MCP remain closed.

### 9.2 The live proxy experiment (the headline result)

Ran against the live install (Claude 2.1.218, subscription auth, no `ANTHROPIC_API_KEY`):

- **Passthrough:** `claude -p` through a local `ANTHROPIC_BASE_URL` proxy → `POST /v1/messages?beta=true` → **200**. Subscription OAuth survives an intermediary. **[verified]**
- **Body modification:** the same, but the proxy **altered the request body in flight** (injected a system block) → **200, accepted**. No signature/integrity check rejected the change. **[verified]**

∴ The enforcement primitive Bonsai needs — dropping archived ranges from the outgoing `messages[]` — is **mechanically viable at the wire seam with zero binary patch.** A wire proxy: has **no minified anchors** (retires the §5.1 re-patch treadmill and the §5.4 two-writers churn on the Claude side), reads **provider input tokens directly** (§5.7 ground truth becomes native, not inferred), and lives inside a **documented, versioned** config.

### 9.3 Native in-process primitives (Codex's map of the 2.1.218 bundle)

The bundle *does* contain real context-mutating primitives whose call sites replace the live in-memory history (`L.length=0; L.push(...)`):
- **`uRo(...)`** — full compaction → `{boundaryMarker, summaryMessages, messagesToKeep}`; **destructive summarize** ⇒ fails Bonsai's byte-exact non-destructive contract.
- **`mId(..., direction)`** — partial compaction, `"from"`/`"up_to"` directional, driven from the message-selector UI. Closest in shape, but `messagesToKeep` semantics ≠ arbitrary contiguous recoverable range.
- **`vtd(...)`** microcompaction + `applyHintEdits` (`context_hint`) — only swap old tool-result bodies for placeholders.

Two strikes against the native path, both now **[verified]**: the identifiers are **private lexical bindings inside the Bun CJS wrapper** — nothing on `globalThis`, `exports`, or any module property exposes `uRo`/`mId`/`vtd`/`cze`/`Pid`, so reuse *still* requires source-patching + minified-name rediscovery (no better than today's anchors); and the semantics **summarize/clear rather than losslessly hide a range.** Verdict: **fallback, not presumptive replacement.** Its lasting value is the **stable-token map** (property names `boundaryMarker`/`messagesToKeep`, literals `"from"`/`"up_to"`/`context_hint`) that survives minification and feeds a self-describing patch (§7.4) if we ever must keep patching.

### 9.3b The native wire context-editing API (`context_management`) — a partial supported channel

The live `/v1/messages` body **already carries** Anthropic's native context-editing surface as a documented top-level field (seen in a real capture):

```json
"context_management": { "edits": [ { "type": "clear_thinking_20251015", "keep": "all" } ] }
```

Verified against docs (platform.claude.com/docs/.../context-editing) — **exactly two** edit types exist, both **type-based**, **[verified]**:
- **`clear_tool_uses_20250919`** — clears oldest tool results (optionally tool inputs); params `trigger`, `keep`, `clear_at_least`, `exclude_tools`, `clear_tool_inputs`.
- **`clear_thinking_20251015`** — clears thinking blocks; param `keep` (`thinking_turns` N | `"all"`).

There is **no `offset` / `range` / `start_index` parameter** — no way to clear an arbitrary contiguous message range or arbitrary user/assistant prose. So this channel **cannot express Bonsai's full contract**, but it *is* a **supported, versioned, ToS-clean** way to shed the token weight that's usually largest in agentic sessions (tool results + thinking). Also on the wire: no per-message id (`messages[]` entries are `{role, content}` only — correlation can't key on a native id), `output_config.effort`, `metadata.user_id`.

**Design consequence — a hybrid that shrinks the patch surface toward zero:** drive **`context_management.edits`** (a published request parameter, appended by a proxy — not a body rewrite) for tool-results + thinking, and fall back to `messages[]` filtering **only** for residual arbitrary prose ranges. If most of a typical prune's weight is tool-results/thinking, the proxy barely touches `messages[]`, minimizing both the ToS-gray surface and any need for a correlation id.

### 9.4 Where this leaves the ranking

The bake-off is no longer "three drifting anchors vs. one in-process seam." It's:

1. **Zero-patch wire proxy** (§9.2) — leading candidate. Open engineering question: **correlation** — the MCP server knows archived ranges by internal id (`cb:message-content-ids`); the proxy sees only the raw wire `messages[]`. Bridge it by (a) content-hashing wire messages against the archived originals the MCP server already persists, or (b) one tiny surviving id-tag patch (far smaller surface than today's three anchors). Open risks: prompt-cache breakpoint shifts when ranges drop (**cost/latency, not correctness**), and the "forwarding authorized / rewriting silent" **ToS gray area — Maz's call.**
2. **Native in-process primitive** (§9.3) — fallback; callability now **disproven** (private lexical bindings) and semantics are lossy, so it offers no anchor-stability edge over today's patch.
3. **Harden the current patch** (§7.4/§7.5) — always-available floor; the stable-token map makes anchors self-describing.

**Bottom line:** §7's premise ("#1 is worth an hour of genuine falsification") paid off. A supported context-rewrite *hook* still doesn't exist — but a **subscription-legal, patch-free wire seam does**, and it was closed in the doc only because of an April ToS ruling that has since been reversed. Recommended next step: prototype the correlation layer (§9.5) and measure the prompt-cache cost of dropping ranges before committing to migrate off the bundle patch.

### 9.5 Converged correlation design (Fable + Codex consensus)

The proxy's only hard problem is mapping archived ranges to the id-less wire `messages[]`. Converged recommendation:

- **Primary: (c) tool-call-slice + content-boundary matching.** The `prune` tool_result is authored by **our own MCP server** and rides the outgoing `messages[]` as a `tool_result` block — so the MCP server embeds the archived range's **boundary content-hashes in that tool_result text**, and the proxy reads them straight off the wire. **The archive→proxy channel is the tool_result itself: no shared file, no id injection, no patch.** On each subsequent request the proxy finds the boundary messages by content and drops the enclosed range. Correlation happens in the exact representation the proxy will edit.
- **Hashing rule:** hash at the **message level** (normalized concat of all text blocks), **not** per-block. A live model-selected prune disproved the earlier 1:1 assumption: Claude merged five consecutive JSONL `user` records into one wire message. Therefore, before recording an archive, the MCP asks the loopback proxy to prove that both whole-message boundary hashes are uniquely present and ordered in that session's latest effective wire request. Non-1:1, compacted, missing, or ambiguous boundaries are refused before mutation; interior messages need no hash match.
- **Fallback: (b) one tiny id-tag patch**, used *only* if a replay test shows boundary content isn't uniquely recoverable after Claude's JSONL→wire normalization. Far smaller surface than today's three anchors.
- **Compose with native edits (order fixed by the real request path):** the proxy filters `messages[]` **in transit, before** the request reaches Anthropic; Anthropic then applies `context_management` **server-side on the remaining history.** So proxy-filter is necessarily first — removed archived messages never reach the native editor, which then clears eligible blocks in what's left. Safe, no conflict. **Measure savings from final provider `usage` (input tokens), never by summing two estimated deltas** — a pruned message may also contain tool-results the native edit would have cleared, so adding the two double-counts the overlap.
- **Fail-closed invariant (both agents insist on this):** if the named boundary messages aren't *both* uniquely present in the outgoing body, **forward unchanged, record "not enforced," never guess.** This is the exact inverse of the §5.3 failure (which claimed success while reclaiming nothing). A missed prune just doesn't shrink *that* turn — correctness preserved.
- **Known cost (not correctness):** dropping messages shifts the `cache_control` breakpoint → cache-read miss on that turn. Measure in the replay test.

**Handoff state:** this was a read-only falsification + design pass. The concrete next step for a build phase is a proxy prototype exercising §9.5 against a replay corpus, measuring (1) boundary uniqueness after normalization — decides (c) vs. (b), and (2) prompt-cache cost. Two calls remain Maz's: the ToS comfort of appending `context_management` vs. rewriting `messages[]`, and the acceptable cache-cost ceiling.

### 9.6 Quantitative backing (Codex measurements, 2026-07-23)

**Native-edit coverage** — how much of a real archived range's weight the two native `context_management` edits can shed, across **5 real archived ranges** in the current Bonsai session. **JSON-byte upper bounds, not provider tokens:**

| Slice | Bytes | Share |
|---|---|---|
| Total serialized content | 477,721 | 100% |
| Thinking + tool-results (`clear_thinking` + `clear_tool_uses`) | 265,676 | **55.6%** |
| + tool-use inputs (`clear_tool_inputs`) | 282,981 | 59.2% |
| Residual ordinary prose (needs `messages[]` filtering) | — | **40.8%** |

Per-range spread: **43.7%–82.5%** native-addressable. **Interpretation:** the native channel sheds roughly half-to-60% of byte-weight cleanly and ToS-legally — materially useful — but the **~41% residual prose confirms the `messages[]` filter is load-bearing, not optional.** Bytes overstate token savings and overlap must not be summed; final numbers come from provider input tokens after both ops (§9.5).

**Anchor-drift root cause (refines §5.1 / §7.4).** The 2.1.215 break was **regex-*window* drift, not semantic drift**: the stable `api_system` provider branch grew to a 177-byte gap while the matcher allowed only 140 (fixed by commit `3346187`, window → 300). The structural seam is unchanged on 2.1.218 — only minified helper names/counts moved. **Implication:** a **build-time AST/semantic matcher** would prevent this whole failure class; **load-time self-discovery cannot** cleanly locate the private lexical functions (§9.3), so §7.4's "discovers its own injection point at load time" is not a general fix — the build-time-AST variant is. Ref: `tweakcc_context_bonsai/patches/anchors.ts`.

**Native-primitive evidence table** (stable tokens for a future self-describing patch — all confirmed private lexical bindings, uncallable from MCP):

| Primitive | Stable evidence tokens | Capability | Bonsai verdict |
|---|---|---|---|
| `uRo`+`cze` | `boundaryMarker`, `summaryMessages`, `messagesToKeep`, `Conversation compacted`, `L.length=0;L.push(...)` | Full-history summarize | Destructive; no range, no byte-exact retrieve |
| `mId`+`Pid` | `direction:"from"/"up_to"`, `Nothing to summarize…` | Prefix/suffix summarize | Directional + destructive |
| `vtd` | `[Old tool result content cleared]`, `<persisted-output>`, `keepRecent`, `tokensSaved` | Clears old tool-result bodies | Partial only |
| `applyHintEdits` | internal export + `context_hint` | Microcompaction | Tool-result-only |
| wire `context_management` | `clear_thinking_20251015`, `clear_tool_uses_20250919` | Server block-type clear | Partial; no range |

### 9.7 Does the patch surface disappear? (the D1 answer — build phase, 2026-07-23)

Per-patch retirement under the proxy. This is the concrete answer to "does the Claude-side binary-patch surface go to zero":

| Current patch (§4.1) | Replacement under the proxy | Retires? | Basis |
|---|---|---|---|
| `archived-filter` | The proxy's `messages[]` filter *is* enforcement | **Yes, by construction** | It's literally the proxy's job |
| `cbim-v1` | No in-memory/disk seam exists — the proxy reads a fresh outgoing body each turn | **Yes, moot** | §5.3's whole cause (disk-vs-memory) can't arise |
| `message-content-ids` | Content-hash correlation (`canonicalHash`) via the tool_result channel | **Yes** — uniqueness confirmed | **[verified]** — 612/612 boundary messages uniquely hashed (100%), 0 collision classes across a 12-body / 5-lineage / 717-message id-less corpus. Ambiguity stays a runtime fail-closed condition, not a patch |
| `context-bonsai-gauge` | `UserPromptSubmit` hook (cadence + gauge from transcript `usage`) + `PostToolUse` hook on prune (forced nudge) | **Yes** | **[verified feasible]** — read `context-bonsai-gauge.patch.ts`: every input is hook-available, output is `additionalContext` |

**All four retire on the evidence in hand — the patch surface reaches zero.** (The `message-content-ids` variable resolved favorably: 100% boundary uniqueness on a real id-less corpus, so content-hash correlation needs no id patch; ambiguity remains a runtime fail-closed condition.) When the patch surface reaches zero, the machinery that exists *only to maintain patches* retires with it: the §5.1 re-patch treadmill, anchor re-derivation, the WatchPaths reconciler, isolate-verify-swap, and the §5.4 two-writers race. **This is a replacement of the Claude patch stack, not an augmentation of it.** The `context_management` hybrid (§9.3b) is the *only* additive piece, and it is optional (a cache-cost optimization, severable).

**Prototype (`tweakcc_context_bonsai/proxy-prototype/`):** the correlation core (`correlate.mjs`) + fail-closed structural guard is built and unit-verified. See §9.8 for the build-phase results.

### 9.8 Prototype results (build phase, 2026-07-23)

The `proxy-prototype/` proves the design end-to-end against the live API. All five acceptance criteria met; the correlation core is security-hardened via an adversarial review.

**Live A/B — criteria 2 & 5 (same proxy PID, identical replay body):**

| Mode | `input` | `cache_read` | Effective input tokens |
|---|---|---|---|
| Passthrough (warm) | 179 | 121,026 | 121,205 |
| Enforced (warm) | 179 | 52,035 | 52,214 |

- **Reduction: 68,991 tokens = 56.9%** (146 → 45 wire messages, 101 dropped), four consecutive `200`s in each mode. Same-PID, so this is §5.7 ground truth, not the gauge.
- **Cache cost (criterion 5):** the first enforced shape pays a one-turn re-cache (`cache_write=48,706`, `cache_read=3,329`); every subsequent call reads the full 52,035 from cache. So dropping a range costs **one turn of re-caching, then amortizes immediately** — the quantified breakpoint churn.

**Correlation core — criteria 1, 3, 4 + security:** 13 unit checks green.
- Criterion 1 (uniqueness): 612/612, 100% (§9.7), **re-confirmed 612/612 with zero collisions under the post-review canonicalizer** (the empty-user `"(no content)"` normalization introduced no new collisions). D1 fully closed on measured evidence.
- Criterion 3 (byte-exact retrieve) — **proven live**: a retrieve replay went 148→148 messages, outbound body SHA matched the replay file exactly (`8b5a2017…`), and the restored 101-message slice matched byte-for-byte (`c450ccae…`), four provider `200`s. Nothing is lost; recovery is exact.
- Criterion 4 (fail-closed) — **proven live**: the hostile `system→user` case returns 400 unguarded; with the guard it forwards unchanged (`refused=1`) and gets four `200`s. Plus 13 unit checks.
- Alternation guard **confirmed unnecessary live**: consecutive user/user at the A/B cut was accepted by the provider (the API merges same-role turns, as the docs state).
- **Adversarial review (Codex) found and fixed two real holes pre-activation:**
  1. **Marker forgery via other tools** — a model can make Bash/Read *return* marker-shaped text into a trusted tool_result. Fixed: markers are honored only from tool_results **paired by `tool_use_id` to our Bonsai prune/retrieve tool** (host-assigned identities; another tool can't impersonate ours), and the marker kind must match the tool kind. (Earlier fix already blocked markers in model prose.) HMAC-signing noted as defense-in-depth.
  2. **`system → assistant` adjacency** — real transcripts interleave 100+ system messages; the live API returns 400 when a nonempty system message is followed by a non-assistant (dropping the intervening assistant leaves `system → user`). Encoded as a fail-closed check and reproduced against the live API: **a nonempty system message must be followed by an assistant or end the array.** (An earlier draft carved out an empty `content:[]` system carrying message-level `output_config`; live verification *rejected* that shape — `messages.N.output_config: Extra inputs are not permitted` — so the carve-out was removed. `output_config` is top-level only, matching the wire capture.)

**Core status: done.** Both open items resolved: (1) uniqueness re-confirmed 612/612 under the post-review canonicalizer; (2) the `output_config` exception was falsified against the live API and removed. Remaining work is not core: HMAC-signing the marker (defense-in-depth, optional), a live end-to-end run with the real MCP server emitting markers, and — only if migrating — the gauge `UserPromptSubmit` hook. The migrate/don't-migrate decision, the ToS posture on `messages[]` rewriting, and any use of the optional `context_management` hybrid remain the operator's calls.
