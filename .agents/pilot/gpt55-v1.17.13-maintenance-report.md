# Routine Maintenance Report — OpenCode v1.17.13 Cycle

Outcome: maintenance completed after STOP at `forward-port-spec.md` §1.15. The cycle halted during plan generation validation, before plan approval, replay, seal, parent pin advancement, or publish.

## Part 4 Updates

- Updated `docs/agent-specs/forward-port-spec.md` §4.2 to clarify that `opencode_context_bonsai_plugin/` is not modified during an OpenCode cycle and that its publish-ladder action is a clean-status no-op when there are no cycle commits, including detached side-repo checkouts.
- Updated §4.2 to require parent pin advancement to use the replay tip by detached commit or tag checkout, because the replay branch is already occupied by the isolated worktree.
- Updated §4.2 evidence paths to require an explicit disposition for pre-publish install-gate run records under `.agents/pilot/`.

## Failure Attribution

- `EXECUTOR-FAIL`: release-gate order, concrete worktree checks, diff-scope checks, subject verification, and parent fast-forward commands were deterministic in Parts 1-2 but were not generated correctly within the three §1.15 iterations.
- `SPEC-GAP`: OpenCode §4.2 did not state how to handle the unchanged/detached plugin side repo during the publish ladder, how to advance the parent submodule pin without checking out a branch occupied by the replay worktree, or how to dispose of install-gate run-record artifacts.

No Parts 1-3 changes were made.
