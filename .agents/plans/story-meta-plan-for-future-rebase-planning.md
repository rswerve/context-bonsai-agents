# Superseded: see `docs/agent-specs/forward-port-spec.md`

This meta-plan was restructured into the layered forward-port specification at
[`docs/agent-specs/forward-port-spec.md`](../../docs/agent-specs/forward-port-spec.md)
(shape-agnostic core + git-fork and closed-npm-artifact shape bindings + per-harness
binding slots), per the direction statement in `docs/meta-loop-direction.md`.

Supersession took effect 2026-07-02, after the regeneration acceptance test passed:
the two most recent executed cycle plans (`story-rebase-cycle-4d88b953…` for OpenCode
v1.15.7, `story-rebase-cycle-95c24228…` for Claude Code 2.1.156) were regenerated
clean-room from the new spec and independently audited equivalent on seal/blocking
gates, bucket taxonomy and precedence, validation command set with working
directories, and immutable e2e scope.

Do not generate new cycle plans from this document. The full historical text is in
git history (last complete revision: the parent of the commit that introduced this
note). Existing cycle plans that cite this meta-plan's immutability gate remain
valid for their own historical cycles; new cycles check `forward-port-spec.md`
immutability instead.
