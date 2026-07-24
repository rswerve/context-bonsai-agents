# Incident: Claude Code went native — bundle patches no longer attach, prune is a silent no-op

**Reported:** 2026-07-23, from a live Claude Code session on the Quill project.
**Severity:** High — `prune` appears to work but reclaims zero context.
**Affected component:** the Claude Code integration (JS-bundle patching).

## Symptom

During a long session, `context-bonsai-prune` was called several times. Each call
returned `Prune complete` with an `anchor_id`, i.e. the range archived server-side.
But the context gauge **never dropped** — it climbed straight through every
"successful" prune (roughly 9% → 68% across the session). Pruning freed no window
space at all.

## Root cause (confirmed)

Context-bonsai patches Claude Code's **JavaScript bundle** at three sentinels:
`context-bonsai-gauge`, `archived-filter`, `message-content-ids`.

Claude Code is no longer a JS bundle. The installed CLI is a **native compiled
binary**:

```
$ file ~/.local/share/claude/versions/2.1.218
… : Mach-O 64-bit executable arm64
$ claude --version
2.1.218 (Claude Code)
```

All three sentinels return **0 hits** when grepped against that binary — the
patches have nothing to attach to. (Prior local notes report the same for
2.1.208–2.1.218; 2.1.218 confirmed here.)

The load-bearing patch is **`archived-filter`**: it is what strips archived
ranges out of the context assembled for the model each turn. With the MCP
*server* still running as its own process, the `prune`/`retrieve` **tools**
respond normally and archive server-side — but with `archived-filter` absent,
the archived content is never filtered out of the actual window. Result: prune
archives, but does not shrink.

This is worse than not pruning: an operator sees "Prune complete," believes
headroom was reclaimed, and keeps working against a window that never actually
shrank.

## What's needed

The tweakcc-style bundle-patching approach cannot work against a native Mach-O
binary. Options to investigate:
- A runtime/integration that does not depend on patching the JS bundle (e.g. an
  official extension/hook point, an output-transform proxy, or driving context
  assembly from the MCP side if the protocol allows it).
- Detecting the native-binary case and **failing loudly** — the tool should
  refuse or warn ("archived-filter not applied; prune will not reclaim context")
  rather than returning a clean `Prune complete`, so operators aren't misled.

## Secondary, minor (tool robustness)

Separately, several `prune` calls failed hard with
`Error: prune requires from_pattern, to_pattern, summary, and index_terms`
even though all four were supplied. Cause was on the caller side: the `summary`
string contained angle-bracket / markup-like text (e.g. a literal `sessionid`
placeholder in angle brackets), which the tool-call parameter parser read as
tags and dropped the parameters. Worth hardening the tool (or documenting) so
markup inside a string param can't silently null out the whole call.
