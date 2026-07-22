#!/usr/bin/env bun
/**
 * Deterministic post-agent guard for an isolated Codex forward-port.
 *
 * This tool is intentionally not wired into unattended maintenance. It captures
 * an immutable staged baseline, then treats the model's worktree delta as
 * hostile input. The model's prose report is neither accepted nor read.
 */
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { isAbsolute, relative, resolve } from "node:path";

export const GUARD_VERSION = 1;
export const CONTEXT_BONSAI = "codex-rs/core/src/context_bonsai.rs";

export const PORT_FILES = [
  "codex-rs/core/Cargo.toml",
  CONTEXT_BONSAI,
  "codex-rs/core/src/hook_runtime.rs",
  "codex-rs/core/src/lib.rs",
  "codex-rs/core/src/session/mod.rs",
  "codex-rs/core/src/tools/handlers/bonsai.rs",
  "codex-rs/core/src/tools/handlers/mod.rs",
  "codex-rs/core/src/tools/spec_plan.rs",
  "codex-rs/core/src/tools/spec_plan_tests.rs",
  "codex-rs/core/tests/common/context_snapshot.rs",
] as const;

type PortFile = (typeof PORT_FILES)[number];

type AdapterBlock = {
  id: "response-item-text-v1" | "response-item-id-v1";
  signature: string;
  begin: string;
  end: string;
};

export const ADAPTER_BLOCKS: readonly AdapterBlock[] = [
  {
    id: "response-item-text-v1",
    signature: "fn extract_text(item: &ResponseItem) -> String {",
    begin: "    // context-bonsai:auto-adapter-begin response-item-text-v1",
    end: "    // context-bonsai:auto-adapter-end response-item-text-v1",
  },
  {
    id: "response-item-id-v1",
    signature: "fn explicit_item_id(item: &ResponseItem) -> Option<String> {",
    begin: "    // context-bonsai:auto-adapter-begin response-item-id-v1",
    end: "    // context-bonsai:auto-adapter-end response-item-id-v1",
  },
] as const;

/** Exact declarations may be added by an agent, but never rewritten. */
export const EXACT_REGISTRATIONS: Readonly<Record<string, readonly string[]>> = {
  "codex-rs/core/src/lib.rs": ["mod context_bonsai;"],
  "codex-rs/core/src/tools/handlers/mod.rs": [
    "mod bonsai;",
    "pub use bonsai::ContextBonsaiPruneHandler;",
    "pub use bonsai::ContextBonsaiRetrieveHandler;",
  ],
  "codex-rs/core/src/tools/spec_plan.rs": [
    "use crate::tools::handlers::ContextBonsaiPruneHandler;",
    "use crate::tools::handlers::ContextBonsaiRetrieveHandler;",
    "    planned_tools.add(ContextBonsaiPruneHandler);",
    "    planned_tools.add(ContextBonsaiRetrieveHandler);",
  ],
};

const MUTABLE_FILES = new Set<string>([CONTEXT_BONSAI, ...Object.keys(EXACT_REGISTRATIONS)]);

const ID_OLD = "Some(id.clone())";
const ID_NEW = "Some(id.to_string())";
const NON_TEXT_VARIANT_LINE =
  /^(\s*)((?:ContentItem::[A-Z][A-Za-z0-9_]* \{ \.\. \})(?: \| ContentItem::[A-Z][A-Za-z0-9_]* \{ \.\. \})*) => None,$/;

export type GuardState = {
  version: number;
  repository: string;
  head: string;
  indexTree: string;
  protectedDigest: string;
  portFiles: readonly string[];
  adapterBodyDigests: Record<string, string>;
  registrationCounts: Record<string, Record<string, number>>;
};

export class SemanticGuardError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SemanticGuardError";
  }
}

function sha256(text: string): string {
  return createHash("sha256").update(text).digest("hex");
}

function git(repo: string, args: string[], allowFailure = false): string {
  const result = spawnSync("git", ["-C", repo, ...args], { encoding: "utf8" });
  if (result.status !== 0 && !allowFailure) {
    throw new SemanticGuardError(
      `git ${args.join(" ")} failed: ${(result.stderr || result.stdout || "unknown error").trim()}`,
    );
  }
  return result.stdout ?? "";
}

function exactlyOnce(text: string, needle: string, label: string): number {
  const first = text.indexOf(needle);
  const last = text.lastIndexOf(needle);
  if (first < 0 || first !== last) {
    const count = first < 0 ? 0 : text.split(needle).length - 1;
    throw new SemanticGuardError(`${label} must occur exactly once (found ${count})`);
  }
  return first;
}

type LocatedBlock = AdapterBlock & { body: string; bodyStart: number; bodyEnd: number };

function locateBlock(text: string, block: AdapterBlock, label: string): LocatedBlock {
  const signatureAt = exactlyOnce(text, block.signature, `${label}: adapter signature ${block.signature}`);
  const beginAt = exactlyOnce(text, block.begin, `${label}: marker ${block.begin}`);
  const endAt = exactlyOnce(text, block.end, `${label}: marker ${block.end}`);
  const requiredPrefix = `${block.signature}\n${block.begin}\n`;
  if (text.slice(signatureAt, signatureAt + requiredPrefix.length) !== requiredPrefix) {
    throw new SemanticGuardError(`${label}: ${block.id} begin marker moved or signature altered`);
  }
  if (endAt <= beginAt || text.slice(endAt + block.end.length, endAt + block.end.length + 2) !== "\n}") {
    throw new SemanticGuardError(`${label}: ${block.id} end marker moved or function boundary altered`);
  }
  const bodyStart = beginAt + block.begin.length + 1;
  const bodyEnd = endAt - 1;
  if (bodyEnd < bodyStart) throw new SemanticGuardError(`${label}: ${block.id} has an invalid marker range`);
  return { ...block, body: text.slice(bodyStart, bodyEnd), bodyStart, bodyEnd };
}

function normalizedContext(text: string, label: string): { text: string; bodies: Record<string, string> } {
  const located = ADAPTER_BLOCKS.map((block) => locateBlock(text, block, label)).sort(
    (a, b) => b.bodyStart - a.bodyStart,
  );
  const bodies: Record<string, string> = {};
  let normalized = text;
  for (const block of located) {
    bodies[block.id] = block.body;
    normalized =
      normalized.slice(0, block.bodyStart) +
      `<context-bonsai:normalized-adapter:${block.id}>` +
      normalized.slice(block.bodyEnd);
  }
  return { text: normalized, bodies };
}

function lineCount(text: string, line: string): number {
  return text.split("\n").filter((candidate) => candidate === line).length;
}

function normalizedRegistrations(path: string, text: string): string {
  const declarations = EXACT_REGISTRATIONS[path] ?? [];
  if (declarations.length === 0) return text;
  const allowed = new Set(declarations);
  return text
    .split("\n")
    .filter((line) => !allowed.has(line))
    .join("\n");
}

function registrationCounts(path: string, text: string): Record<string, number> {
  return Object.fromEntries((EXACT_REGISTRATIONS[path] ?? []).map((line) => [line, lineCount(text, line)]));
}

function requireFinalRegistrations(path: string, text: string): void {
  for (const declaration of EXACT_REGISTRATIONS[path] ?? []) {
    const count = lineCount(text, declaration);
    if (count !== 1) {
      throw new SemanticGuardError(
        `${path}: exact registration must occur once: ${JSON.stringify(declaration)} (found ${count})`,
      );
    }
  }
}

function indexFile(repo: string, path: string): string {
  return git(repo, ["show", `:${path}`]);
}

function worktreeFile(repo: string, path: string): string {
  const absolute = resolve(repo, path);
  if (!existsSync(absolute)) throw new SemanticGuardError(`candidate removed protected file: ${path}`);
  return readFileSync(absolute, "utf8");
}

function protectedProjection(path: PortFile, text: string, label: string): { text: string; bodies: Record<string, string> } {
  let normalized = text;
  let bodies: Record<string, string> = {};
  if (path === CONTEXT_BONSAI) {
    const context = normalizedContext(text, label);
    normalized = context.text;
    bodies = context.bodies;
  }
  normalized = normalizedRegistrations(path, normalized);
  return { text: normalized, bodies };
}

function projectionDigest(files: ReadonlyMap<string, string>): string {
  const hash = createHash("sha256");
  for (const path of [...files.keys()].sort()) {
    hash.update(path).update("\0").update(files.get(path) ?? "").update("\0");
  }
  return hash.digest("hex");
}

function stateOutsideRepository(repo: string, statePath: string): void {
  const rel = relative(repo, resolve(statePath));
  const parentPrefix = `..${process.platform === "win32" ? "\\" : "/"}`;
  if (rel === "" || (rel !== ".." && !rel.startsWith(parentPrefix) && !isAbsolute(rel))) {
    throw new SemanticGuardError("guard state must live outside the agent-writable repository");
  }
}

function requireNoUnmerged(repo: string): void {
  if (git(repo, ["ls-files", "-u"]).trim() !== "") {
    throw new SemanticGuardError("repository has unresolved index conflicts");
  }
}

function changedPaths(repo: string): string[] {
  return git(repo, ["diff", "--name-only", "--no-ext-diff"])
    .split("\n")
    .filter(Boolean);
}

function structuralChanges(repo: string): string {
  return git(repo, ["diff", "--summary", "--no-ext-diff"]).trim();
}

function untrackedPaths(repo: string): string[] {
  return git(repo, ["ls-files", "--others", "--exclude-standard"])
    .split("\n")
    .filter(Boolean);
}

function assertAdapterTransition(id: AdapterBlock["id"], baseline: string, candidate: string): void {
  if (candidate === baseline) return;
  if (id === "response-item-text-v1") {
    const baselineLines = baseline.split("\n");
    const candidateLines = candidate.split("\n");
    if (baselineLines.length === candidateLines.length) {
      const changedIndexes = baselineLines.flatMap((line, index) =>
        line === candidateLines[index] ? [] : [index],
      );
      if (changedIndexes.length === 1) {
        const index = changedIndexes[0];
        const before = NON_TEXT_VARIANT_LINE.exec(baselineLines[index]);
        const after = NON_TEXT_VARIANT_LINE.exec(candidateLines[index]);
        if (before && after && before[1] === after[1]) {
          const variants = (match: RegExpExecArray): string[] =>
            match[2].split(" | ").map((part) => part.slice("ContentItem::".length, part.indexOf(" {")));
          const oldVariants = variants(before);
          const newVariants = variants(after);
          const oldSet = new Set(oldVariants);
          const newSet = new Set(newVariants);
          let cursor = 0;
          for (const variant of newVariants) {
            if (variant === oldVariants[cursor]) cursor += 1;
          }
          const isStrictSuperset =
            oldSet.size === oldVariants.length &&
            newSet.size === newVariants.length &&
            newSet.size > oldSet.size &&
            oldVariants.every((variant) => newSet.has(variant)) &&
            cursor === oldVariants.length &&
            oldSet.has("InputImage");
          if (isStrictSuperset) return;
        }
      }
    }
    throw new SemanticGuardError(
      `${id}: delta is not a pure addition to the non-text ContentItem exhaustiveness arm`,
    );
  }
  const baselineLines = baseline.split("\n");
  const candidateLines = candidate.split("\n");
  if (baselineLines.length === candidateLines.length) {
    let conversions = 0;
    const onlyTypedIdConversions = baselineLines.every((line, index) => {
      const candidateLine = candidateLines[index];
      if (line === candidateLine) return true;
      if (line.includes(ID_OLD) && line.replace(ID_OLD, ID_NEW) === candidateLine) {
        conversions += 1;
        return true;
      }
      return false;
    });
    if (onlyTypedIdConversions && conversions > 0) return;
  }
  throw new SemanticGuardError(
    `${id}: delta is not the registered ResponseItemId clone -> to_string adaptation`,
  );
}

export function captureBaseline(repoInput: string, stateInput: string): GuardState {
  const repo = realpathSync(repoInput);
  const statePath = resolve(stateInput);
  stateOutsideRepository(repo, statePath);
  if (existsSync(statePath)) throw new SemanticGuardError(`refusing to overwrite guard state: ${statePath}`);
  requireNoUnmerged(repo);
  const unstaged = changedPaths(repo);
  if (unstaged.length > 0) {
    throw new SemanticGuardError(`baseline has unstaged edits: ${unstaged.join(", ")}`);
  }
  const untracked = untrackedPaths(repo);
  if (untracked.length > 0) {
    throw new SemanticGuardError(`baseline has untracked files: ${untracked.join(", ")}`);
  }

  const protectedFiles = new Map<string, string>();
  const adapterBodyDigests: Record<string, string> = {};
  const counts: Record<string, Record<string, number>> = {};
  for (const path of PORT_FILES) {
    const source = indexFile(repo, path);
    const projection = protectedProjection(path, source, `baseline ${path}`);
    protectedFiles.set(path, projection.text);
    for (const [id, body] of Object.entries(projection.bodies)) adapterBodyDigests[id] = sha256(body);
    if (EXACT_REGISTRATIONS[path]) counts[path] = registrationCounts(path, source);
  }

  const state: GuardState = {
    version: GUARD_VERSION,
    repository: repo,
    head: git(repo, ["rev-parse", "HEAD"]).trim(),
    indexTree: git(repo, ["write-tree"]).trim(),
    protectedDigest: projectionDigest(protectedFiles),
    portFiles: PORT_FILES,
    adapterBodyDigests,
    registrationCounts: counts,
  };
  writeFileSync(statePath, `${JSON.stringify(state, null, 2)}\n`, { flag: "wx" });
  return state;
}

export function verifyCandidate(repoInput: string, stateInput: string): void {
  const repo = realpathSync(repoInput);
  const statePath = resolve(stateInput);
  stateOutsideRepository(repo, statePath);
  const state = JSON.parse(readFileSync(statePath, "utf8")) as GuardState;
  if (state.version !== GUARD_VERSION) throw new SemanticGuardError(`unsupported guard state version: ${state.version}`);
  if (state.repository !== repo) throw new SemanticGuardError("guard state belongs to a different repository");
  if (JSON.stringify(state.portFiles) !== JSON.stringify(PORT_FILES)) {
    throw new SemanticGuardError("guard state protected-file allowlist differs from this guard version");
  }
  requireNoUnmerged(repo);

  const head = git(repo, ["rev-parse", "HEAD"]).trim();
  if (head !== state.head) throw new SemanticGuardError(`HEAD changed after baseline capture (${state.head} -> ${head})`);
  const indexTree = git(repo, ["write-tree"]).trim();
  if (indexTree !== state.indexTree) {
    throw new SemanticGuardError(`Git index changed after baseline capture (${state.indexTree} -> ${indexTree})`);
  }
  const untracked = untrackedPaths(repo);
  if (untracked.length > 0) throw new SemanticGuardError(`agent created untracked files: ${untracked.join(", ")}`);
  const structural = structuralChanges(repo);
  if (structural !== "") {
    throw new SemanticGuardError(`agent changed file type, mode, or path: ${structural}`);
  }

  const changed = changedPaths(repo);
  const unexpected = changed.filter((path) => !MUTABLE_FILES.has(path));
  if (unexpected.length > 0) {
    throw new SemanticGuardError(`agent changed protected or unexpected files: ${unexpected.join(", ")}`);
  }

  const baselineProtected = new Map<string, string>();
  const candidateProtected = new Map<string, string>();
  const protectedMismatches: string[] = [];
  for (const path of PORT_FILES) {
    const baseline = indexFile(repo, path);
    const candidate = worktreeFile(repo, path);
    const baselineProjection = protectedProjection(path, baseline, `baseline ${path}`);
    const candidateProjection = protectedProjection(path, candidate, `candidate ${path}`);
    baselineProtected.set(path, baselineProjection.text);
    candidateProtected.set(path, candidateProjection.text);
    if (baselineProjection.text !== candidateProjection.text) protectedMismatches.push(path);
    if (path === CONTEXT_BONSAI) {
      for (const block of ADAPTER_BLOCKS) {
        if (sha256(baselineProjection.bodies[block.id]) !== state.adapterBodyDigests[block.id]) {
          throw new SemanticGuardError(`${block.id}: immutable baseline adapter digest changed`);
        }
        assertAdapterTransition(
          block.id,
          baselineProjection.bodies[block.id],
          candidateProjection.bodies[block.id],
        );
      }
    }
    requireFinalRegistrations(path, candidate);
  }

  const baselineDigest = projectionDigest(baselineProtected);
  if (baselineDigest !== state.protectedDigest) {
    throw new SemanticGuardError("captured baseline protected-content digest no longer matches its immutable index");
  }
  if (protectedMismatches.length > 0) {
    throw new SemanticGuardError(
      `protected content changed outside registered adapter bodies/declarations: ${protectedMismatches.join(", ")}`,
    );
  }
  const candidateDigest = projectionDigest(candidateProtected);
  if (candidateDigest !== state.protectedDigest) {
    throw new SemanticGuardError("candidate protected-content digest differs from baseline");
  }
}

function usage(): never {
  throw new SemanticGuardError(
    "usage: semantic-surface-guard.ts capture|verify --repo REPOSITORY --state OUTSIDE_REPOSITORY.json",
  );
}

function parseCli(argv: string[]): { command: "capture" | "verify"; repo: string; state: string } {
  const command = argv[0];
  if (command !== "capture" && command !== "verify") usage();
  let repo = "";
  let state = "";
  for (let i = 1; i < argv.length; i += 2) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (!value) usage();
    if (flag === "--repo") repo = value;
    else if (flag === "--state") state = value;
    else usage();
  }
  if (!repo || !state) usage();
  return { command, repo, state };
}

if (import.meta.main) {
  try {
    const args = parseCli(process.argv.slice(2));
    if (args.command === "capture") {
      const state = captureBaseline(args.repo, args.state);
      process.stdout.write(`semantic baseline captured: ${state.protectedDigest}\n`);
    } else {
      verifyCandidate(args.repo, args.state);
      process.stdout.write("semantic surface verified: adapter-only delta\n");
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`semantic guard rejected candidate: ${message}\n`);
    process.exit(10);
  }
}
