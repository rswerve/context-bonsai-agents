# Story: Remove Legacy ccsnap CLI

## Goal

Remove obsolete `ccsnap` functionality from the Claude Code/tweakcc Context Bonsai side repo so the package exposes only the current MCP server, tweakcc patch apply/restore flow, and shared library code needed by those paths.

## User Model

### User Gamut

- Examples only: Claude Code users installing Context Bonsai from public docs, maintainers forward-porting tweakcc patches, reviewers checking whether the integration can call models unexpectedly, operators auditing local session-file mutations, contributors reading side-repo source for the first time, package consumers inspecting `package.json` binaries.

### User-Needs Gamut

- Examples only: a clear install surface with no obsolete CLI, confidence that prune/retrieve go through MCP and not a legacy shell-out path, no accidental `claude -p` model calls from leftover CLI code, smaller maintenance surface, docs/specs that describe current architecture, tests that cover only supported behavior, preserved historical records where they are explicitly historical.

### Ambiguities From User Model

- Historical `.agents/plans/**` references should remain as audit history, not be rewritten to pretend old stories never mentioned `ccsnap`.
- Active docs in `tweakcc_context_bonsai` and `docs/agent-specs/claude-code-context-bonsai-spec.md` should be updated or deleted because they are current reader-facing source of truth.
- `CC_BONSAI.md` is stale strategic documentation in the side repo, not immutable history. Remove it unless implementation discovers a current non-`ccsnap` purpose worth preserving in a rewritten document.

## Context References

- `tweakcc_context_bonsai/package.json:5` - Package description still advertises `ccsnap CLI`.
- `tweakcc_context_bonsai/package.json:6` - `bin.ccsnap` exposes the obsolete executable.
- `tweakcc_context_bonsai/package.json:11` - `start` runs the obsolete CLI entrypoint.
- `tweakcc_context_bonsai/src/index.ts:1` - Obsolete `ccsnap` executable entrypoint.
- `tweakcc_context_bonsai/src/commands/*.ts` - Obsolete CLI command handlers for snapshot/process/compact/retrieve operations.
- `tweakcc_context_bonsai/src/lib/snapshot.ts:1` - Snapshot support used only by obsolete CLI commands.
- `tweakcc_context_bonsai/src/lib/config.ts:1` - Snapshot index support used only by obsolete snapshot support.
- `tweakcc_context_bonsai/src/lib/process.ts:1` - Process listing/killing support used only by obsolete CLI commands.
- `tweakcc_context_bonsai/src/lib/session.ts:183` - Snapshot-only session-id transform/copy helpers.
- `tweakcc_context_bonsai/src/types.ts:4` - Snapshot-only types live beside MCP/shared session types.
- `tweakcc_context_bonsai/src/lib/compact.ts:337` - Comment still describes a `ccsnap compact` operation.
- `tweakcc_context_bonsai/README.md:5` - User-facing docs still say the repo provides `ccsnap`.
- `tweakcc_context_bonsai/DEVELOPMENT.md:13` - Maintainer docs still identify `src/index.ts` as the `ccsnap` entrypoint.
- `tweakcc_context_bonsai/STANDARDS.md:5` - Standards still define the repo as `ccsnap` plus MCP.
- `tweakcc_context_bonsai/CC_BONSAI.md:1` - Stale strategic document centers `ccsnap`.
- `tweakcc_context_bonsai/docs/e2e-protocol.md:103` - Active validation doc points at `CC_BONSAI.md`, so deleting `CC_BONSAI.md` requires updating this reference.
- `docs/agent-specs/claude-code-context-bonsai-spec.md:5` - Parent spec still says the side repo contains `ccsnap`.

## Acceptance Criteria

- [ ] `tweakcc_context_bonsai` no longer exposes a `ccsnap` binary, `start` script, CLI entrypoint, CLI command handlers, or snapshot/process helpers that existed only to support `ccsnap`.
- [ ] MCP prune/retrieve behavior remains available through `context-bonsai` and continues to use shared library code directly, without shelling out.
- [ ] Snapshot-only code and tests are removed, while session/compact code still needed by MCP remains and is typechecked.
- [ ] Active docs and package metadata describe the current MCP-plus-tweakcc-patch architecture without presenting `ccsnap` as available or supported, including any active docs that currently point at `CC_BONSAI.md`.
- [ ] Parent Claude Code agent spec no longer describes the side repo as containing `ccsnap`.
- [ ] Historical `.agents/plans/**`, ignored `.agent_tmp/**`, and git internals are not edited solely to remove old mentions.
- [ ] A case-insensitive source search finds no `ccsnap` references in active tracked source/docs outside historical plans or git/temporary artifacts.
- [ ] Side repo validation passes, then side repo changes are committed, parent submodule pin is advanced, and parent validation passes.

## Implementation Tasks

1. Delete the obsolete CLI entrypoint and command handlers: `src/index.ts`, `src/commands/`, and `src/commands/.gitkeep`.
2. Delete snapshot/process support that is only reachable from the removed CLI: `src/lib/snapshot.ts`, `src/lib/config.ts`, `src/lib/process.ts`, `src/lib/snapshot.test.ts`, and `src/lib/process.test.ts`.
3. Preserve MCP-local process discovery in `mcp-server/index.ts`; it is separate from `src/lib/process.ts` and remains required for active-session resolution.
4. Remove snapshot-only helpers and tests from `src/lib/session.ts` and `src/lib/session.test.ts`, especially `transformSessionId` and `copySessionWithNewId`. Preserve `findCurrentSession`, `findSessionPath`, `readSessionMessages`, and `getMessageRange`.
5. Remove snapshot-only types from `src/types.ts`: `SnapshotMetadata`, `SnapshotIndex`, and `ClaudeProcess`. Preserve Claude Code session message types, including `FileHistorySnapshot`, because compact/retrieve handles it as real Claude Code JSONL schema.
6. Remove only snapshot-specific path helpers from `src/lib/paths.ts`. Preserve `getHistoryPath`, `getProjectDir`, and `getSessionPath`.
7. Update `src/lib/compact.ts` comments and any remaining source comments so archive metadata is described as Context Bonsai/MCP state, not `ccsnap compact` state.
8. Update root `package.json` to remove `bin.ccsnap`, remove the root `start` script, and revise the package description. Do not remove `mcp-server/package.json`'s valid MCP `start` script.
9. Refresh root `bun.lock` after package metadata changes. Refresh `mcp-server/bun.lock` only if nested MCP package metadata or dependency resolution changes; otherwise validate it remains unchanged.
10. Update `README.md`, `DEVELOPMENT.md`, and `STANDARDS.md` to describe the supported MCP server and patch apply/restore flow only.
11. Delete `CC_BONSAI.md` as stale strategic documentation and update `docs/e2e-protocol.md` to reference current README/operator docs instead.
12. Update `docs/agent-specs/claude-code-context-bonsai-spec.md` in the parent repo to describe the side repo as MCP server plus patch/apply tooling and shared libraries.
13. Run validation commands in the side repo and parent repo.
14. Commit the side repo change, update the parent submodule pin plus parent spec/plan changes, commit the parent change, and push only if explicitly requested during orchestration.

## Testing Strategy

- Use typechecking to catch imports left behind by deleting CLI/snapshot/process modules.
- Use unit tests to ensure supported session/compact/MCP behavior still passes.
- Use source search to verify active source/docs no longer mention `ccsnap`.
- Do not require live Claude Code E2E for this cleanup unless implementation changes MCP/runtime patch behavior beyond deleting obsolete CLI code.

## Validation Commands

Every story plan MUST list the validation commands explicitly. These are the source of truth for the developer's Pre-Implementation Starting-State Check and Completion Rerun; no runtime substitution is permitted.

- `git status --short`
- `git -C tweakcc_context_bonsai status --short`
- `git -C tweakcc_context_bonsai grep -n -i ccsnap -- . ':!CC_BONSAI.md' || true`
- `git -C tweakcc_context_bonsai grep -n -i ccsnap -- . || true`
- `cd tweakcc_context_bonsai && bun install --lockfile-only`
- `cd tweakcc_context_bonsai/mcp-server && bun install --lockfile-only`
- `cd tweakcc_context_bonsai && bun test`
- `cd tweakcc_context_bonsai && bun run typecheck`
- `git grep -n -i ccsnap -- docs/agent-specs/claude-code-context-bonsai-spec.md || true`
- `git diff --check`
- `git -C tweakcc_context_bonsai diff --check`

## Worktree Artifact Check

- Checked At: `2026-05-21T12:30:29-07:00`
- Planned Target Files: `docs/agent-specs/claude-code-context-bonsai-spec.md`, `tweakcc_context_bonsai`, `tweakcc_context_bonsai/package.json`, `tweakcc_context_bonsai/bun.lock`, `tweakcc_context_bonsai/mcp-server/bun.lock`, `tweakcc_context_bonsai/README.md`, `tweakcc_context_bonsai/DEVELOPMENT.md`, `tweakcc_context_bonsai/STANDARDS.md`, `tweakcc_context_bonsai/CC_BONSAI.md`, `tweakcc_context_bonsai/docs/e2e-protocol.md`, `tweakcc_context_bonsai/src/index.ts`, `tweakcc_context_bonsai/src/commands/.gitkeep`, `tweakcc_context_bonsai/src/commands/create.ts`, `tweakcc_context_bonsai/src/commands/list.ts`, `tweakcc_context_bonsai/src/commands/switch.ts`, `tweakcc_context_bonsai/src/commands/ps.ts`, `tweakcc_context_bonsai/src/commands/truncate.ts`, `tweakcc_context_bonsai/src/commands/compact.ts`, `tweakcc_context_bonsai/src/commands/retrieve.ts`, `tweakcc_context_bonsai/src/lib/snapshot.ts`, `tweakcc_context_bonsai/src/lib/config.ts`, `tweakcc_context_bonsai/src/lib/process.ts`, `tweakcc_context_bonsai/src/lib/session.ts`, `tweakcc_context_bonsai/src/lib/paths.ts`, `tweakcc_context_bonsai/src/lib/compact.ts`, `tweakcc_context_bonsai/src/types.ts`, `tweakcc_context_bonsai/src/lib/snapshot.test.ts`, `tweakcc_context_bonsai/src/lib/process.test.ts`, `tweakcc_context_bonsai/src/lib/session.test.ts`
- Overlaps Found (path + class): `none`; parent and tweakcc side repo statuses were clean before planning. The plan document itself is a planning artifact, not an implementation target for this check.
- Escalation Status: `none`
- Decision Citation: `none`

## Plan Approval and Commit Status

- Approval Status: `pending`
- Approval Citation: `none`
- Plan Commit Hash: `none`
- Ready-for-Orchestration: `no`

## Validation Loop Results

- Missing details check: iteration 1 found nested MCP lockfile validation, `.gitkeep`, and supported helper clarity gaps; plan updated. Iteration 2 found no remaining blockers.
- Ambiguity check: iteration 1 found `CC_BONSAI.md` active-doc dependency, MCP process-discovery preservation, path/type pruning precision, and root `start` script ambiguity; plan updated. Iteration 2 found no remaining high-impact ambiguity.
- Plan-commit status check: pending approval and commit
- Iterations run: 2
