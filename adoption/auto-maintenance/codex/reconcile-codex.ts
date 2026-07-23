#!/usr/bin/env bun

import { spawnSync } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import {
  appendFileSync,
  chmodSync,
  copyFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readlinkSync,
  readdirSync,
  realpathSync,
  renameSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve } from "node:path";

const REPO_ROOT = resolve(import.meta.dir, "../../..");
const INITIAL_PATCH = join(REPO_ROOT, "adoption/codex/codex-0.144.5-bonsai.patch");
const INITIAL_PATCH_SHA256 = "37ee4993dee3d7c0252769186cc2ee11b9ee6e3206f4684dcacc19230df87855";
const SHARED_CORE = join(REPO_ROOT, "codex_context_bonsai");

const ALLOWED_PORT_FILES = [
  "codex-rs/core/Cargo.toml",
  "codex-rs/core/src/context_bonsai.rs",
  "codex-rs/core/src/hook_runtime.rs",
  "codex-rs/core/src/lib.rs",
  "codex-rs/core/src/session/mod.rs",
  "codex-rs/core/src/tools/handlers/bonsai.rs",
  "codex-rs/core/src/tools/handlers/mod.rs",
  "codex-rs/core/src/tools/spec_plan.rs",
  "codex-rs/core/src/tools/spec_plan_tests.rs",
  "codex-rs/core/tests/common/context_snapshot.rs",
] as const;

const REQUIRED_AUTONOMY_WIRING = [
  "codex_context_bonsai::BONSAI_GUIDANCE",
  "codex_context_bonsai::GAUGE_CADENCE_TURNS",
  "codex_context_bonsai::gauge_text_for_ratio",
  "bonsai_guidance_for_start_target",
  "bonsai_gauge_context_for_turn",
] as const;

export function missingAutonomyWiringTokens(hookRuntimeSource: string): string[] {
  return REQUIRED_AUTONOMY_WIRING.filter((token) => !hookRuntimeSource.includes(token));
}

export type FinalStatus =
  | "up-to-date"
  | "activated"
  | "benign-skip"
  | "needs-agent"
  | "certification-failed"
  | "rolled-back"
  | "invariant-failed";

export interface LinkSnapshot {
  linkPath: string;
  rawTarget: string;
  resolvedTarget: string;
  version: string;
}

export interface Candidate {
  binary: string;
  version: string;
  sha256: string;
  patchPath: string;
  patchSha256: string;
  sourceCommit: string;
  sharedCoreCommit: string;
  schemaHash: string;
}

export interface ActivationPaths {
  linkPath: string;
  stateRoot: string;
  runDir: string;
  runId: string;
}

export interface StableRelease {
  version: string;
  tag: string;
  publishedAt: string;
  assetName: string;
  assetUrl: string;
  assetSha256: string;
  assetBytes: number;
  fixtureBinary?: string;
}

interface ReleaseBaseline {
  binary: string;
  sha256: string;
}

export interface ReconcileConfig {
  releaseApiUrl: string;
  releaseJsonFixture?: string;
  stableBinaryFixture?: string;
  linkPath: string;
  stateRoot: string;
  artifactRoot: string;
  scratchRoot: string;
  upstreamUrl: string;
  sharedCore: string;
  runtimeManifest: string;
  sharedCoreTree: string;
  initialPatch: string;
  certifyExistingRun?: string;
}

export interface SharedCoreIdentity {
  commit: string;
  fingerprint: string;
  kind: "git" | "archive";
}

interface SharedCoreTreeEntry {
  mode: "100644" | "100755" | "120000";
  oid: string;
  path: string;
}

class ReconcileError extends Error {
  constructor(
    public readonly status: FinalStatus,
    public readonly exitCode: number,
    message: string,
    public summaryVersion?: string,
  ) {
    super(message);
  }
}

function nowId(): string {
  return `${new Date().toISOString().replace(/[-:.]/g, "").replace("Z", "Z")}-${process.pid}-${randomBytes(3).toString("hex")}`;
}

function mkdirFresh(path: string): void {
  mkdirSync(path, { recursive: false });
}

function writeExclusive(path: string, data: string): void {
  writeFileSync(path, data, { flag: "wx", mode: 0o600 });
}

function appendEvent(runDir: string, event: string, detail: Record<string, unknown> = {}): void {
  appendFileSync(
    join(runDir, "events.jsonl"),
    `${JSON.stringify({ at: new Date().toISOString(), event, ...detail })}\n`,
    { mode: 0o600 },
  );
}

function finish(runDir: string, status: FinalStatus, detail: Record<string, unknown>): void {
  writeExclusive(
    join(runDir, `FINAL-${status}.json`),
    `${JSON.stringify({ at: new Date().toISOString(), status, ...detail }, null, 2)}\n`,
  );
  appendEvent(runDir, "final", { status, ...detail });
}

function command(
  runDir: string,
  label: string,
  argv: string[],
  options: { cwd?: string; env?: NodeJS.ProcessEnv; allowFailure?: boolean } = {},
): { stdout: string; stderr: string; status: number } {
  appendEvent(runDir, "command-start", { label, argv, cwd: options.cwd });
  const result = spawnSync(argv[0], argv.slice(1), {
    cwd: options.cwd,
    env: { ...process.env, ...options.env },
    encoding: "utf8",
    maxBuffer: 128 * 1024 * 1024,
  });
  const status = result.status ?? 127;
  const stdout = result.stdout ?? "";
  const stderr = result.stderr ?? String(result.error ?? "");
  appendFileSync(
    join(runDir, "commands.log"),
    `\n=== ${label} ===\n$ ${argv.map(shellQuote).join(" ")}\n${stdout}${stderr}\n[exit ${status}]\n`,
  );
  appendEvent(runDir, "command-end", { label, status });
  if (status !== 0 && !options.allowFailure) {
    throw new ReconcileError("certification-failed", 21, `${label} failed with exit ${status}`);
  }
  return { stdout, stderr, status };
}

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'\\''`)}'`;
}

function parseVersion(output: string, label: string): string {
  const match = output.match(/\bcodex-cli\s+(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)/);
  if (!match) {
    throw new ReconcileError("invariant-failed", 23, `could not parse ${label} version from: ${output.trim()}`);
  }
  return match[1];
}

function versionOf(binary: string, runDir: string, label: string): string {
  const result = command(runDir, `${label}-version`, [binary, "--version"]);
  return parseVersion(`${result.stdout}\n${result.stderr}`, label);
}

function compareStableVersions(a: string, b: string): number {
  const parse = (value: string) => {
    if (!/^\d+\.\d+\.\d+$/.test(value)) {
      throw new ReconcileError("invariant-failed", 23, `automatic maintenance accepts stable versions only: ${value}`);
    }
    return value.split(".").map(Number);
  };
  const aa = parse(a);
  const bb = parse(b);
  for (let i = 0; i < 3; i += 1) {
    if (aa[i] !== bb[i]) return aa[i] < bb[i] ? -1 : 1;
  }
  return 0;
}

const STABLE_TAG = /^rust-v(\d+\.\d+\.\d+)$/;
const DARWIN_ARM64_ASSET = "codex-aarch64-apple-darwin.tar.gz";

export function parseStableReleasePayload(payload: unknown): StableRelease {
  if (payload === null || typeof payload !== "object") {
    throw new ReconcileError("invariant-failed", 23, "stable-release response is not a JSON object");
  }
  const release = payload as Record<string, unknown>;
  if (release.draft !== false || release.prerelease !== false) {
    throw new ReconcileError("invariant-failed", 23, "stable-release endpoint returned a draft or prerelease");
  }
  const tag = typeof release.tag_name === "string" ? release.tag_name : "";
  const match = tag.match(STABLE_TAG);
  if (!match) {
    throw new ReconcileError("invariant-failed", 23, `stable-release tag is not rust-vX.Y.Z: ${tag || "missing"}`);
  }
  const version = match[1];
  const publishedAt = typeof release.published_at === "string" ? release.published_at : "";
  if (!publishedAt || Number.isNaN(Date.parse(publishedAt))) {
    throw new ReconcileError("invariant-failed", 23, "stable-release published_at is missing or invalid");
  }
  if (!Array.isArray(release.assets)) {
    throw new ReconcileError("invariant-failed", 23, "stable-release assets are missing");
  }
  const matches = release.assets.filter(
    (value): value is Record<string, unknown> =>
      value !== null && typeof value === "object" && (value as Record<string, unknown>).name === DARWIN_ARM64_ASSET,
  );
  if (matches.length !== 1) {
    throw new ReconcileError(
      "invariant-failed",
      23,
      `stable release must contain exactly one ${DARWIN_ARM64_ASSET} asset`,
    );
  }
  const asset = matches[0];
  const assetUrl = typeof asset.browser_download_url === "string" ? asset.browser_download_url : "";
  const expectedPrefix = `https://github.com/openai/codex/releases/download/${tag}/`;
  if (assetUrl !== `${expectedPrefix}${DARWIN_ARM64_ASSET}`) {
    throw new ReconcileError("invariant-failed", 23, "stable-release asset URL is not the expected official download");
  }
  const digest = typeof asset.digest === "string" ? asset.digest : "";
  const digestMatch = digest.match(/^sha256:([0-9a-f]{64})$/);
  if (!digestMatch) {
    throw new ReconcileError("invariant-failed", 23, "stable-release asset lacks a valid SHA-256 digest");
  }
  const assetBytes = typeof asset.size === "number" ? asset.size : 0;
  if (!Number.isSafeInteger(assetBytes) || assetBytes <= 0) {
    throw new ReconcileError("invariant-failed", 23, "stable-release asset size is invalid");
  }
  return {
    version,
    tag,
    publishedAt,
    assetName: DARWIN_ARM64_ASSET,
    assetUrl,
    assetSha256: digestMatch[1],
    assetBytes,
  };
}

export function releaseAction(currentVersion: string, releaseVersion: string): "current" | "forward-port" | "downgrade" {
  const direction = compareStableVersions(currentVersion, releaseVersion);
  if (direction === 0) return "current";
  return direction < 0 ? "forward-port" : "downgrade";
}

function fixtureRelease(binary: string, runDir: string): StableRelease {
  if (!existsSync(binary)) {
    throw new ReconcileError("invariant-failed", 23, `stable-binary fixture is missing: ${binary}`);
  }
  const version = versionOf(binary, runDir, "stable-fixture");
  compareStableVersions(version, version);
  return {
    version,
    tag: `rust-v${version}`,
    publishedAt: new Date(0).toISOString(),
    assetName: basename(binary),
    assetUrl: `fixture://${resolve(binary)}`,
    assetSha256: sha256File(binary),
    assetBytes: statSync(binary).size,
    fixtureBinary: realpathSync(binary),
  };
}

function detectLatestStable(config: ReconcileConfig, runDir: string): StableRelease {
  if (config.stableBinaryFixture) return fixtureRelease(config.stableBinaryFixture, runDir);
  let raw: string;
  if (config.releaseJsonFixture) {
    if (!existsSync(config.releaseJsonFixture)) {
      throw new ReconcileError("invariant-failed", 23, `stable-release fixture is missing: ${config.releaseJsonFixture}`);
    }
    raw = readFileSync(config.releaseJsonFixture, "utf8");
  } else {
    const response = command(
      runDir,
      "latest-stable-release",
      [
        "curl",
        "-fsSL",
        "--connect-timeout",
        process.env.CB_CODEX_RELEASE_CONNECT_TIMEOUT ?? "10",
        "--max-time",
        process.env.CB_CODEX_RELEASE_MAX_TIME ?? "30",
        "--retry",
        "1",
        "-H",
        "Accept: application/vnd.github+json",
        "-H",
        "X-GitHub-Api-Version: 2022-11-28",
        "-H",
        "User-Agent: context-bonsai-auto-maintenance",
        config.releaseApiUrl,
      ],
      { allowFailure: true },
    );
    if (response.status !== 0) {
      throw new ReconcileError(
        "benign-skip",
        20,
        `stable-release check unavailable (curl exit ${response.status}); current fork remains selected`,
      );
    }
    raw = response.stdout;
  }
  let payload: unknown;
  try {
    payload = JSON.parse(raw);
  } catch {
    throw new ReconcileError("invariant-failed", 23, "stable-release response is not valid JSON");
  }
  return parseStableReleasePayload(payload);
}

function sha256File(path: string): string {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function gitBlobOid(content: Buffer): string {
  return createHash("sha1")
    .update(Buffer.from(`blob ${content.length}\0`))
    .update(content)
    .digest("hex");
}

function parseSharedCoreTree(path: string): SharedCoreTreeEntry[] {
  if (!existsSync(path)) {
    throw new ReconcileError("certification-failed", 21, `shared-core tree manifest is missing: ${path}`);
  }
  const entries: SharedCoreTreeEntry[] = [];
  const seen = new Set<string>();
  for (const line of readFileSync(path, "utf8").split("\n").filter(Boolean)) {
    const match = /^(100644|100755|120000) blob ([0-9a-f]{40})\t(.+)$/.exec(line);
    if (!match) {
      throw new ReconcileError("certification-failed", 21, "shared-core tree manifest contains an invalid entry");
    }
    const entry = { mode: match[1], oid: match[2], path: match[3] } as SharedCoreTreeEntry;
    const parts = entry.path.split("/");
    if (
      isAbsolute(entry.path) ||
      parts.some((part) => part === "" || part === "." || part === "..") ||
      entry.path.includes("\t") ||
      entry.path.includes("\0") ||
      seen.has(entry.path)
    ) {
      throw new ReconcileError("certification-failed", 21, `unsafe or duplicate shared-core path: ${entry.path}`);
    }
    seen.add(entry.path);
    entries.push(entry);
  }
  if (entries.length === 0) {
    throw new ReconcileError("certification-failed", 21, "shared-core tree manifest is empty");
  }
  return entries.sort((a, b) => a.path.localeCompare(b.path));
}

function walkSharedCore(root: string, dir = root): string[] {
  const paths: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const absolute = join(dir, entry.name);
    if (entry.isDirectory()) {
      paths.push(...walkSharedCore(root, absolute));
    } else if (entry.isFile() || entry.isSymbolicLink()) {
      paths.push(relative(root, absolute));
    } else {
      throw new ReconcileError("certification-failed", 21, `unsupported shared-core filesystem entry: ${absolute}`);
    }
  }
  return paths.sort((a, b) => a.localeCompare(b));
}

export function validateSharedCoreSnapshot(
  sharedCore: string,
  runtimeManifest: string,
  treeManifest: string,
): SharedCoreIdentity {
  if (!existsSync(sharedCore) || !statSync(sharedCore).isDirectory()) {
    throw new ReconcileError("certification-failed", 21, `shared-core snapshot is missing: ${sharedCore}`);
  }
  if (!existsSync(runtimeManifest)) {
    throw new ReconcileError("certification-failed", 21, `runtime manifest is missing: ${runtimeManifest}`);
  }
  const metadata = JSON.parse(readFileSync(runtimeManifest, "utf8")) as Record<string, unknown>;
  const commit = typeof metadata.sharedCoreCommit === "string" ? metadata.sharedCoreCommit : "";
  const expectedTreeSha =
    typeof metadata.sharedCoreTreeSha256 === "string" ? metadata.sharedCoreTreeSha256 : "";
  if (!/^[0-9a-f]{40}$/.test(commit) || !/^[0-9a-f]{64}$/.test(expectedTreeSha)) {
    throw new ReconcileError("certification-failed", 21, "runtime manifest lacks valid shared-core integrity metadata");
  }
  const actualTreeSha = sha256File(treeManifest);
  if (actualTreeSha !== expectedTreeSha) {
    throw new ReconcileError("certification-failed", 21, "shared-core tree manifest checksum mismatch");
  }
  const entries = parseSharedCoreTree(treeManifest);
  const expectedPaths = entries.map((entry) => entry.path);
  const actualPaths = walkSharedCore(sharedCore);
  if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
    throw new ReconcileError("certification-failed", 21, "shared-core archive file set drifted");
  }
  for (const entry of entries) {
    const absolute = join(sharedCore, entry.path);
    const info = lstatSync(absolute);
    let mode: SharedCoreTreeEntry["mode"];
    let content: Buffer;
    if (info.isSymbolicLink()) {
      mode = "120000";
      content = Buffer.from(readlinkSync(absolute));
    } else if (info.isFile()) {
      mode = (info.mode & 0o111) === 0 ? "100644" : "100755";
      content = readFileSync(absolute);
    } else {
      throw new ReconcileError("certification-failed", 21, `unsupported shared-core entry: ${entry.path}`);
    }
    if (mode !== entry.mode) {
      throw new ReconcileError("certification-failed", 21, `shared-core mode mismatch: ${entry.path}`);
    }
    if (gitBlobOid(content) !== entry.oid) {
      throw new ReconcileError("certification-failed", 21, `shared-core blob mismatch: ${entry.path}`);
    }
  }
  return { commit, fingerprint: `${commit}:${actualTreeSha}`, kind: "archive" };
}

function resolveSharedCoreIdentity(config: ReconcileConfig, runDir: string, label: string): SharedCoreIdentity {
  if (existsSync(join(config.sharedCore, ".git"))) {
    const dirty = command(runDir, `${label}-shared-core-clean`, [
      "git",
      "-C",
      config.sharedCore,
      "status",
      "--porcelain",
    ]).stdout.trim();
    if (dirty) throw new ReconcileError("certification-failed", 21, "shared Context Bonsai core is dirty");
    const commit = command(runDir, `${label}-shared-core-commit`, [
      "git",
      "-C",
      config.sharedCore,
      "rev-parse",
      "HEAD",
    ]).stdout.trim();
    if (!/^[0-9a-f]{40}$/.test(commit)) {
      throw new ReconcileError("certification-failed", 21, "could not pin shared Context Bonsai core commit");
    }
    return { commit, fingerprint: commit, kind: "git" };
  }
  const identity = validateSharedCoreSnapshot(config.sharedCore, config.runtimeManifest, config.sharedCoreTree);
  appendEvent(runDir, `${label}-shared-core-archive-verified`, { ...identity });
  return identity;
}

function snapshotManagedLink(linkPath: string, runDir: string): LinkSnapshot {
  if (!existsSync(linkPath) && !safeLstat(linkPath)) {
    throw new ReconcileError(
      "invariant-failed",
      23,
      `${linkPath} is absent; daily reconciliation requires the one-time adoption switch first`,
    );
  }
  const stat = lstatSync(linkPath);
  if (!stat.isSymbolicLink()) {
    throw new ReconcileError("invariant-failed", 23, `${linkPath} is not a symlink; refusing unattended replacement`);
  }
  const rawTarget = readlinkSync(linkPath);
  const resolvedTarget = isAbsolute(rawTarget) ? rawTarget : resolve(dirname(linkPath), rawTarget);
  if (!existsSync(resolvedTarget) || !statSync(resolvedTarget).isFile()) {
    throw new ReconcileError("invariant-failed", 23, `current Codex target is missing: ${resolvedTarget}`);
  }
  return {
    linkPath,
    rawTarget,
    resolvedTarget: realpathSync(resolvedTarget),
    version: versionOf(resolvedTarget, runDir, "current-fork"),
  };
}

function safeLstat(path: string): boolean {
  try {
    lstatSync(path);
    return true;
  } catch {
    return false;
  }
}

function assertTools(binary: string, runDir: string, label: string): void {
  for (const marker of [
    "context-bonsai-prune",
    "context-bonsai-retrieve",
    "CONTEXT BONSAI ENFORCED",
    "excluded_messages=",
  ]) {
    command(runDir, `${label}-${marker.replaceAll(/[^a-zA-Z0-9_-]/g, "-")}`, ["rg", "-a", "-q", marker, binary]);
  }
}

function assertManagedArtifactChecksum(binary: string): void {
  const actual = sha256File(binary);
  const adoptionChecksum = join(dirname(binary), "codex.sha256");
  if (existsSync(adoptionChecksum)) {
    const expected = readFileSync(adoptionChecksum, "utf8").trim().split(/\s+/)[0];
    if (expected !== actual) {
      throw new ReconcileError("invariant-failed", 23, `current Codex checksum mismatch: ${binary}`);
    }
    return;
  }
  const manifest = join(dirname(dirname(binary)), "manifest.json");
  if (existsSync(manifest)) {
    const expected = JSON.parse(readFileSync(manifest, "utf8")).sha256;
    if (expected !== actual) {
      throw new ReconcileError("invariant-failed", 23, `current Codex manifest checksum mismatch: ${binary}`);
    }
    return;
  }
  throw new ReconcileError(
    "invariant-failed",
    23,
    `current Codex target lacks a recognized adoption checksum or maintenance manifest: ${binary}`,
  );
}

function assertCurrentLinkUnchanged(snapshot: LinkSnapshot): void {
  if (!safeLstat(snapshot.linkPath) || !lstatSync(snapshot.linkPath).isSymbolicLink()) {
    throw new ReconcileError("invariant-failed", 23, "Codex link changed or disappeared during isolated build");
  }
  const current = readlinkSync(snapshot.linkPath);
  if (current !== snapshot.rawTarget) {
    throw new ReconcileError(
      "invariant-failed",
      23,
      `Codex link changed concurrently (expected ${snapshot.rawTarget}, found ${current})`,
    );
  }
}

function acquireLock(stateRoot: string, runId: string): string {
  mkdirSync(join(stateRoot, "lock-history"), { recursive: true });
  const lock = join(stateRoot, "running.lock");
  if (safeLstat(lock)) {
    let pid = 0;
    try {
      pid = Number(readFileSync(join(lock, "pid"), "utf8").trim());
    } catch {
      pid = 0;
    }
    let alive = false;
    if (pid > 0) {
      try {
        process.kill(pid, 0);
        alive = true;
      } catch {
        alive = false;
      }
    }
    if (alive) {
      throw new ReconcileError("invariant-failed", 23, `another Codex reconciliation is running (pid ${pid})`);
    }
    renameSync(lock, join(stateRoot, "lock-history", `stale-${runId}`));
  }
  mkdirFresh(lock);
  writeExclusive(join(lock, "pid"), `${process.pid}\n`);
  writeExclusive(join(lock, "run-id"), `${runId}\n`);
  return lock;
}

function releaseLock(lock: string, stateRoot: string, runId: string): void {
  if (safeLstat(lock)) {
    renameSync(lock, join(stateRoot, "lock-history", `completed-${runId}`));
  }
}

function getCurrentArtifactPatch(currentBinary: string, fallback: string): string {
  const artifactDir = dirname(dirname(currentBinary));
  const manifestPath = join(artifactDir, "manifest.json");
  if (!existsSync(manifestPath)) return fallback;
  try {
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    const patchPath = join(artifactDir, "bonsai.patch");
    if (typeof manifest.patchSha256 !== "string" || !existsSync(patchPath)) {
      throw new Error("artifact manifest lacks its patch/checksum");
    }
    if (sha256File(patchPath) !== manifest.patchSha256) throw new Error("artifact patch checksum mismatch");
    return patchPath;
  } catch (error) {
    throw new ReconcileError("invariant-failed", 23, `could not trust current artifact patch lineage: ${String(error)}`);
  }
}

function checkoutTarget(config: ReconcileConfig, runDir: string, version: string): { source: string; commit: string } {
  const source = join(runDir, "source");
  const tag = `rust-v${version}`;
  const clone = command(runDir, "clone-upstream", [
    "git",
    "clone",
    "--filter=blob:none",
    "--depth=1",
    "--branch",
    tag,
    "--single-branch",
    config.upstreamUrl,
    source,
  ], { allowFailure: true });
  if (clone.status !== 0) {
    throw new ReconcileError(
      "benign-skip",
      20,
      `stable source checkout unavailable (git exit ${clone.status}); current fork remains selected`,
    );
  }
  const commit = command(runDir, "target-commit", ["git", "-C", source, "rev-parse", "HEAD"]).stdout.trim();
  const exactTag = command(runDir, "target-tag-commit", ["git", "-C", source, "rev-list", "-n", "1", tag]).stdout.trim();
  if (!/^[0-9a-f]{40}$/.test(commit) || commit !== exactTag) {
    throw new ReconcileError("invariant-failed", 23, `target checkout is not exact ${tag}`);
  }
  return { source, commit };
}

function extractedFiles(root: string, dir = root): string[] {
  const files: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    const stat = lstatSync(path);
    if (stat.isSymbolicLink()) {
      throw new ReconcileError("invariant-failed", 23, `stable-release archive extracted a symlink: ${relative(root, path)}`);
    }
    if (stat.isDirectory()) files.push(...extractedFiles(root, path));
    else if (stat.isFile()) files.push(path);
    else throw new ReconcileError("invariant-failed", 23, `stable-release archive contains a special file: ${relative(root, path)}`);
  }
  return files;
}

function prepareReleaseBaseline(release: StableRelease, runDir: string): ReleaseBaseline {
  if (release.fixtureBinary) {
    const version = versionOf(release.fixtureBinary, runDir, "stable-baseline-fixture");
    if (version !== release.version) {
      throw new ReconcileError("invariant-failed", 23, `stable fixture version ${version} != ${release.version}`);
    }
    if (sha256File(release.fixtureBinary) !== release.assetSha256) {
      throw new ReconcileError("invariant-failed", 23, "stable fixture changed after release detection");
    }
    return { binary: release.fixtureBinary, sha256: release.assetSha256 };
  }

  const baselineRoot = join(runDir, "stable-baseline");
  const extracted = join(baselineRoot, "extracted");
  mkdirSync(extracted, { recursive: true });
  const archive = join(baselineRoot, release.assetName);
  const download = command(runDir, "download-stable-baseline", [
    "curl",
    "-fL",
    "--connect-timeout",
    process.env.CB_CODEX_RELEASE_CONNECT_TIMEOUT ?? "10",
    "--max-time",
    process.env.CB_CODEX_DOWNLOAD_MAX_TIME ?? "600",
    "--retry",
    "2",
    "--output",
    archive,
    release.assetUrl,
  ], { allowFailure: true });
  if (download.status !== 0) {
    throw new ReconcileError(
      "benign-skip",
      20,
      `stable binary download unavailable (curl exit ${download.status}); current fork remains selected`,
    );
  }
  if (statSync(archive).size !== release.assetBytes) {
    throw new ReconcileError("certification-failed", 21, "stable-release archive byte count differs from release metadata");
  }
  if (sha256File(archive) !== release.assetSha256) {
    throw new ReconcileError("certification-failed", 21, "stable-release archive checksum differs from release metadata");
  }
  const entries = command(runDir, "inspect-stable-baseline-archive", ["tar", "-tzf", archive])
    .stdout.split("\n")
    .filter(Boolean);
  if (entries.length === 0) {
    throw new ReconcileError("certification-failed", 21, "stable-release archive is empty");
  }
  for (const entry of entries) {
    const normalized = entry.replace(/^\.\//, "");
    if (isAbsolute(normalized) || normalized.split("/").includes("..")) {
      throw new ReconcileError("invariant-failed", 23, `unsafe path in stable-release archive: ${entry}`);
    }
  }
  command(runDir, "extract-stable-baseline", ["tar", "-xzf", archive, "-C", extracted]);
  const expectedNames = new Set([DARWIN_ARM64_ASSET.replace(/\.tar\.gz$/, ""), "codex"]);
  const candidates = extractedFiles(extracted).filter((path) => expectedNames.has(basename(path)));
  if (candidates.length !== 1) {
    throw new ReconcileError(
      "certification-failed",
      21,
      `stable-release archive yielded ${candidates.length} Codex binary candidates`,
    );
  }
  const binary = candidates[0];
  chmodSync(binary, 0o755);
  const version = versionOf(binary, runDir, "stable-baseline");
  if (version !== release.version) {
    throw new ReconcileError("certification-failed", 21, `stable baseline version ${version} != ${release.version}`);
  }
  const architecture = command(runDir, "stable-baseline-architecture", ["file", "-b", binary]).stdout;
  if (!architecture.includes("arm64")) {
    throw new ReconcileError("certification-failed", 21, "stable baseline is not arm64");
  }
  return { binary, sha256: sha256File(binary) };
}

function prepareMechanicalPort(
  config: ReconcileConfig,
  runDir: string,
  source: string,
  patchPath: string,
  release: StableRelease,
  commit: string,
): void {
  const inputDir = join(runDir, "input");
  mkdirSync(inputDir, { recursive: true });
  const copiedPatch = join(inputDir, "bonsai-input.patch");
  copyFileSync(patchPath, copiedPatch);
  const check = command(runDir, "mechanical-patch-check", ["git", "-C", source, "apply", "--index", "--check", copiedPatch], {
    allowFailure: true,
  });
  if (check.status !== 0) {
    writeExclusive(
      join(runDir, "NEEDS_AGENT.json"),
      `${JSON.stringify(
        {
          reason: "mechanical-rebase-conflict",
          targetVersion: release.version,
          stableRelease: release,
          targetCommit: commit,
          source,
          inputPatch: copiedPatch,
          allowedFiles: ALLOWED_PORT_FILES,
          next: `Run ${join(import.meta.dir, "run-agentic-rebase.sh")} ${runDir}`,
        },
        null,
        2,
      )}\n`,
    );
    throw new ReconcileError("needs-agent", 10, "mechanical patch did not apply; isolated agentic bundle emitted");
  }
  command(runDir, "mechanical-patch-apply", ["git", "-C", source, "apply", "--index", copiedPatch]);
  normalizeSharedCoreDependency(config, runDir, source);
}

export function rewriteSharedCoreDependencyText(before: string, sharedCore: string): string {
  const pattern = /codex-context-bonsai = \{ path = "[^"]+" \}/g;
  const matches = before.match(pattern) ?? [];
  if (matches.length !== 1) {
    throw new ReconcileError(
      "certification-failed",
      21,
      `expected exactly one codex-context-bonsai path dependency, found ${matches.length}`,
    );
  }
  const escaped = resolve(sharedCore).replaceAll("\\", "\\\\").replaceAll('"', '\\"');
  return before.replace(pattern, `codex-context-bonsai = { path = "${escaped}" }`);
}

function normalizeSharedCoreDependency(config: ReconcileConfig, runDir: string, source: string): void {
  const manifest = join(source, "codex-rs/core/Cargo.toml");
  const before = readFileSync(manifest, "utf8");
  writeFileSync(manifest, rewriteSharedCoreDependencyText(before, config.sharedCore));
  command(runDir, "stage-runtime-shared-core-path", [
    "git",
    "-C",
    source,
    "add",
    "--",
    "codex-rs/core/Cargo.toml",
  ]);
}

function stageAgenticChanges(runDir: string, source: string): void {
  const status = command(runDir, "agentic-status", ["git", "-C", source, "status", "--porcelain"]).stdout;
  const paths = status
    .split("\n")
    .filter(Boolean)
    .map((line) => line.slice(3).replace(/^.* -> /, ""));
  const unexpected = paths.filter((path) => !ALLOWED_PORT_FILES.includes(path as (typeof ALLOWED_PORT_FILES)[number]));
  if (unexpected.length > 0) {
    throw new ReconcileError("certification-failed", 21, `agent changed files outside the allowlist: ${unexpected.join(", ")}`);
  }
  command(runDir, "stage-agentic-port", ["git", "-C", source, "add", "--", ...ALLOWED_PORT_FILES]);
}

function validatePortSource(
  config: ReconcileConfig,
  runDir: string,
  source: string,
  expectedCommit: string,
): { sharedCoreIdentity: SharedCoreIdentity; patchText: string } {
  const head = command(runDir, "source-head-invariant", ["git", "-C", source, "rev-parse", "HEAD"]).stdout.trim();
  if (head !== expectedCommit) {
    throw new ReconcileError("certification-failed", 21, "candidate changed upstream HEAD");
  }
  const coreManifest = readFileSync(join(source, "codex-rs/core/Cargo.toml"), "utf8");
  const expectedDependency = `codex-context-bonsai = { path = "${resolve(config.sharedCore)}" }`;
  if (!coreManifest.includes(expectedDependency)) {
    throw new ReconcileError("certification-failed", 21, "candidate does not use the pinned runtime shared core");
  }
  const hookRuntime = readFileSync(join(source, "codex-rs/core/src/hook_runtime.rs"), "utf8");
  const missingAutonomy = missingAutonomyWiringTokens(hookRuntime);
  if (missingAutonomy.length > 0) {
    throw new ReconcileError(
      "certification-failed",
      21,
      `candidate is missing Context Bonsai autonomy wiring: ${missingAutonomy.join(", ")}`,
    );
  }
  command(runDir, "port-diff-check", ["git", "-C", source, "diff", "--cached", "--check"]);
  const changed = command(runDir, "port-file-list", ["git", "-C", source, "diff", "--cached", "--name-only"])
    .stdout.trim()
    .split("\n")
    .filter(Boolean)
    .sort();
  const expected = [...ALLOWED_PORT_FILES].sort();
  if (JSON.stringify(changed) !== JSON.stringify(expected)) {
    throw new ReconcileError(
      "certification-failed",
      21,
      `port file set drifted; expected ${expected.join(", ")}; found ${changed.join(", ")}`,
    );
  }
  const summary = command(runDir, "port-mode-summary", ["git", "-C", source, "diff", "--cached", "--summary"]).stdout;
  if (/mode 120000|mode 100755/.test(summary)) {
    throw new ReconcileError("certification-failed", 21, "candidate introduced a symlink or executable source file");
  }
  const sharedCoreIdentity = resolveSharedCoreIdentity(config, runDir, "pre-certification");
  const patchText = command(runDir, "render-port-patch", [
    "git",
    "-C",
    source,
    "diff",
    "--cached",
    "--binary",
    "--full-index",
  ]).stdout;
  if (
    !patchText.includes("context-bonsai-prune") ||
    !patchText.includes("context-bonsai-retrieve") ||
    missingAutonomyWiringTokens(patchText).length > 0
  ) {
    throw new ReconcileError(
      "certification-failed",
      21,
      "candidate patch does not contain both tools plus autonomous guidance/gauge wiring",
    );
  }
  return { sharedCoreIdentity, patchText };
}

function walkJson(root: string, dir = root): string[] {
  const files: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) files.push(...walkJson(root, path));
    else if (entry.isFile() && entry.name.endsWith(".json")) files.push(relative(root, path));
  }
  return files.sort();
}

function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, child]) => [key, canonical(child)]),
    );
  }
  return value;
}

function schemaFingerprint(root: string): { count: number; hash: string } {
  const files = walkJson(root);
  const hash = createHash("sha256");
  for (const file of files) {
    hash.update(file);
    hash.update("\0");
    hash.update(JSON.stringify(canonical(JSON.parse(readFileSync(join(root, file), "utf8")))));
    hash.update("\0");
  }
  return { count: files.length, hash: hash.digest("hex") };
}

function assertOnlyGeneratedLockChanged(runDir: string, source: string, label: string): void {
  command(runDir, `${label}-generated-lock-diff-check`, [
    "git",
    "-C",
    source,
    "diff",
    "--check",
    "--",
    "codex-rs/Cargo.lock",
  ]);
  const unstaged = command(runDir, `${label}-unstaged-file-list`, [
    "git",
    "-C",
    source,
    "diff",
    "--name-only",
  ])
    .stdout.trim()
    .split("\n")
    .filter(Boolean);
  if (unstaged.length > 1 || (unstaged.length === 1 && unstaged[0] !== "codex-rs/Cargo.lock")) {
    throw new ReconcileError(
      "certification-failed",
      21,
      `build mutated source outside generated Cargo.lock: ${unstaged.join(", ")}`,
    );
  }
  const untracked = command(runDir, `${label}-untracked-file-list`, [
    "git",
    "-C",
    source,
    "ls-files",
    "--others",
    "--exclude-standard",
  ])
    .stdout.trim()
    .split("\n")
    .filter(Boolean);
  if (untracked.length > 0) {
    throw new ReconcileError("certification-failed", 21, `build created untracked source files: ${untracked.join(", ")}`);
  }
}

function certifyAndBuild(
  config: ReconcileConfig,
  runDir: string,
  source: string,
  baseline: ReleaseBaseline,
  stableRelease: StableRelease,
  version: string,
  sourceCommit: string,
  sharedCoreIdentity: SharedCoreIdentity,
  patchText: string,
): Candidate {
  if (stableRelease.version !== version) {
    throw new ReconcileError("invariant-failed", 23, "certification target differs from stable release metadata");
  }
  const targetDir = join(runDir, "cargo-target");
  const baseEnv = { CARGO_TARGET_DIR: targetDir, RUST_MIN_STACK: "8388608" };
  command(runDir, "resolve-candidate-lock", ["cargo", "metadata", "--format-version", "1"], {
    cwd: join(source, "codex-rs"),
    env: baseEnv,
  });
  assertOnlyGeneratedLockChanged(runDir, source, "post-lock-resolution");
  const sharedCoreTest = join(runDir, "shared-core-test");
  command(runDir, "stage-shared-core-tests", ["cp", "-R", config.sharedCore, sharedCoreTest]);
  command(runDir, "resolve-shared-core-lock-offline", [
    "cargo",
    "generate-lockfile",
    "--offline",
    "--manifest-path",
    join(sharedCoreTest, "Cargo.toml"),
  ], {
    cwd: sharedCoreTest,
  });
  command(runDir, "shared-core-tests", [
    "cargo",
    "test",
    "--locked",
    "--manifest-path",
    join(sharedCoreTest, "Cargo.toml"),
  ], {
    cwd: sharedCoreTest,
    env: { CARGO_TARGET_DIR: join(runDir, "shared-core-target") },
  });
  command(runDir, "focused-bonsai-tests", ["cargo", "test", "--locked", "-p", "codex-core", "context_bonsai", "--lib"], {
    cwd: join(source, "codex-rs"),
    env: baseEnv,
  });
  command(runDir, "full-codex-core-tests", ["cargo", "test", "--locked", "-p", "codex-core", "--lib"], {
    cwd: join(source, "codex-rs"),
    env: baseEnv,
  });
  command(runDir, "app-server-protocol-tests", ["cargo", "test", "--locked", "-p", "codex-app-server-protocol"], {
    cwd: join(source, "codex-rs"),
    env: baseEnv,
  });
  command(runDir, "codex-core-clippy", ["cargo", "clippy", "--locked", "-p", "codex-core", "--lib"], {
    cwd: join(source, "codex-rs"),
    env: baseEnv,
  });
  command(runDir, "release-build", ["cargo", "build", "--locked", "--release", "-p", "codex-cli", "--bin", "codex"], {
    cwd: join(source, "codex-rs"),
    env: baseEnv,
  });
  assertOnlyGeneratedLockChanged(runDir, source, "post-build");
  const sharedCoreAfter = resolveSharedCoreIdentity(config, runDir, "post-certification");
  if (sharedCoreAfter.fingerprint !== sharedCoreIdentity.fingerprint) {
    throw new ReconcileError("certification-failed", 21, "shared Context Bonsai core changed during certification");
  }
  const sourceCommitAfter = command(runDir, "source-head-after-build", ["git", "-C", source, "rev-parse", "HEAD"])
    .stdout.trim();
  if (sourceCommitAfter !== sourceCommit) {
    throw new ReconcileError("certification-failed", 21, "upstream source HEAD changed during certification");
  }
  const built = join(targetDir, "release", "codex");
  if (!existsSync(built)) throw new ReconcileError("certification-failed", 21, "release binary was not produced");
  const builtVersion = versionOf(built, runDir, "candidate");
  if (builtVersion !== version) {
    throw new ReconcileError("certification-failed", 21, `candidate version ${builtVersion} != target ${version}`);
  }
  const file = command(runDir, "candidate-architecture", ["file", "-b", built]).stdout;
  if (!file.includes("arm64")) throw new ReconcileError("certification-failed", 21, "candidate is not arm64");
  assertTools(built, runDir, "candidate");

  const baselineVersionBeforeSchema = versionOf(baseline.binary, runDir, "baseline-before-schema");
  if (baselineVersionBeforeSchema !== version) {
    throw new ReconcileError("invariant-failed", 23, "stable-release baseline changed during candidate build");
  }
  if (sha256File(baseline.binary) !== baseline.sha256) {
    throw new ReconcileError("invariant-failed", 23, "stable-release baseline checksum changed during candidate build");
  }

  const baselineSchema = join(runDir, "schema-stable-baseline");
  const candidateSchema = join(runDir, "schema-candidate");
  command(runDir, "stable-baseline-schema", [
    baseline.binary,
    "app-server",
    "generate-json-schema",
    "--out",
    baselineSchema,
    "--experimental",
  ]);
  command(runDir, "candidate-schema", [
    built,
    "app-server",
    "generate-json-schema",
    "--out",
    candidateSchema,
    "--experimental",
  ]);
  const baselineFingerprint = schemaFingerprint(baselineSchema);
  const candidateFingerprint = schemaFingerprint(candidateSchema);
  appendEvent(runDir, "schema-parity", { baselineFingerprint, candidateFingerprint });
  if (
    baselineFingerprint.count === 0 ||
    baselineFingerprint.count !== candidateFingerprint.count ||
    baselineFingerprint.hash !== candidateFingerprint.hash
  ) {
    throw new ReconcileError("certification-failed", 21, "candidate app-server schema differs from same-version stable release");
  }

  const sha256 = sha256File(built);
  const artifactDir = join(config.artifactRoot, version, `${sourceCommit.slice(0, 12)}-${sha256.slice(0, 12)}`);
  const binDir = join(artifactDir, "bin");
  mkdirSync(binDir, { recursive: true });
  const binary = join(binDir, "codex");
  if (existsSync(binary)) {
    if (sha256File(binary) !== sha256) {
      throw new ReconcileError("invariant-failed", 23, `immutable artifact collision at ${binary}`);
    }
  } else {
    const temporaryBinary = join(binDir, `.codex-${basename(runDir)}`);
    copyFileSync(built, temporaryBinary);
    chmodSync(temporaryBinary, 0o755);
    if (sha256File(temporaryBinary) !== sha256) {
      throw new ReconcileError("certification-failed", 21, "candidate checksum changed while staging the artifact");
    }
    renameSync(temporaryBinary, binary);
  }
  const patchPath = join(artifactDir, "bonsai.patch");
  const patchSha256 = createHash("sha256").update(patchText).digest("hex");
  if (existsSync(patchPath)) {
    if (readFileSync(patchPath, "utf8") !== patchText) {
      throw new ReconcileError("invariant-failed", 23, `immutable patch collision at ${patchPath}`);
    }
  } else {
    writeExclusive(patchPath, patchText);
  }
  if (sha256File(patchPath) !== patchSha256) {
    throw new ReconcileError("invariant-failed", 23, `staged patch checksum mismatch at ${patchPath}`);
  }
  const generatedLock = join(source, "codex-rs", "Cargo.lock");
  const lockPath = join(artifactDir, "Cargo.lock.certified");
  const lockSha256 = sha256File(generatedLock);
  if (existsSync(lockPath)) {
    if (sha256File(lockPath) !== lockSha256) {
      throw new ReconcileError("invariant-failed", 23, `immutable generated lock collision at ${lockPath}`);
    }
  } else {
    copyFileSync(generatedLock, lockPath);
  }
  const manifestPath = join(artifactDir, "manifest.json");
  if (!existsSync(manifestPath)) {
    writeExclusive(
      manifestPath,
      `${JSON.stringify(
        {
          version,
          sourceCommit,
          sharedCoreCommit: sharedCoreIdentity.commit,
          sha256,
          lockSha256,
          patchSha256,
          bytes: statSync(binary).size,
          stableRelease: {
            tag: stableRelease.tag,
            publishedAt: stableRelease.publishedAt,
            assetName: stableRelease.assetName,
            assetSha256: stableRelease.assetSha256,
            assetBytes: stableRelease.assetBytes,
            extractedBinarySha256: baseline.sha256,
          },
          schema: candidateFingerprint,
          greenGates: [
            "shared-core-tests",
            "isolated-lock-resolution-then-locked-build",
            "focused-bonsai-tests",
            "full-codex-core-tests",
            "app-server-protocol-tests",
            "codex-core-clippy",
            "release-build",
            "arm64-version-tools-live-enforcement-evidence",
            "same-version-stable-release-schema-parity",
          ],
        },
        null,
        2,
      )}\n`,
    );
  }
  return {
    binary,
    version,
    sha256,
    patchPath,
    patchSha256,
    sourceCommit,
    sharedCoreCommit: sharedCoreIdentity.commit,
    schemaHash: candidateFingerprint.hash,
  };
}

export function activateCandidate(
  candidate: Candidate,
  snapshot: LinkSnapshot,
  paths: ActivationPaths,
  verify: (binary: string) => void,
): "activated" | "rolled-back" {
  mkdirSync(join(paths.stateRoot, "states"), { recursive: true });
  mkdirSync(join(paths.stateRoot, "link-history"), { recursive: true });
  assertCurrentLinkUnchanged(snapshot);

  const oldLinkRecord = join(paths.stateRoot, "link-history", `codex-before-${paths.runId}`);
  symlinkSync(snapshot.rawTarget, oldLinkRecord);
  const stateRecord = join(paths.stateRoot, "states", `${paths.runId}.json`);
  writeExclusive(
    stateRecord,
    `${JSON.stringify(
      {
        preparedAt: new Date().toISOString(),
        version: candidate.version,
        binary: candidate.binary,
        sha256: candidate.sha256,
        patchPath: candidate.patchPath,
        patchSha256: candidate.patchSha256,
        sourceCommit: candidate.sourceCommit,
        sharedCoreCommit: candidate.sharedCoreCommit,
        schemaHash: candidate.schemaHash,
        previousLinkTarget: snapshot.rawTarget,
        previousResolvedTarget: snapshot.resolvedTarget,
      },
      null,
      2,
    )}\n`,
  );
  const active = join(paths.stateRoot, "active");
  if (safeLstat(active)) {
    if (!lstatSync(active).isSymbolicLink()) throw new Error(`${active} is not a managed symlink`);
    const priorActive = readlinkSync(active);
    symlinkSync(priorActive, join(paths.stateRoot, "link-history", `active-before-${paths.runId}`));
  }
  const tempActive = join(paths.stateRoot, `.active-${paths.runId}`);
  symlinkSync(relative(paths.stateRoot, stateRecord), tempActive);

  // Prepare both directions before changing the live link. After this point an
  // allocation or permissions failure cannot prevent restoration.
  const rollbackLink = join(dirname(paths.linkPath), `.codex-rollback-${paths.runId}`);
  symlinkSync(snapshot.rawTarget, rollbackLink);
  const tempLink = join(dirname(paths.linkPath), `.codex-bonsai-${paths.runId}`);
  symlinkSync(candidate.binary, tempLink);
  renameSync(tempLink, paths.linkPath);

  try {
    if (readlinkSync(paths.linkPath) !== candidate.binary) throw new Error("candidate symlink did not land");
    verify(candidate.binary);
    renameSync(tempActive, active);
    try {
      renameSync(rollbackLink, join(paths.stateRoot, "link-history", `rollback-ready-${paths.runId}`));
      appendEvent(paths.runDir, "activation-committed", { binary: candidate.binary });
    } catch {
      // The binary and active-state commits already landed atomically. Retain
      // any rollback symlink/logging residue for diagnosis; do not undo a
      // verified activation because optional evidence organization failed.
    }
    return "activated";
  } catch (error) {
    renameSync(rollbackLink, paths.linkPath);
    if (readlinkSync(paths.linkPath) !== snapshot.rawTarget) {
      throw new ReconcileError(
        "invariant-failed",
        23,
        `post-apply verification failed and automatic rollback could not restore ${snapshot.rawTarget}: ${String(error)}`,
      );
    }
    appendEvent(paths.runDir, "activation-auto-rollback", { error: String(error), restored: snapshot.rawTarget });
    return "rolled-back";
  }
}

function productionVerify(binary: string, runDir: string, expectedVersion: string, expectedSha: string): void {
  const actualVersion = versionOf(binary, runDir, "post-apply");
  if (actualVersion !== expectedVersion) throw new Error(`post-apply version ${actualVersion} != ${expectedVersion}`);
  if (sha256File(binary) !== expectedSha) throw new Error("post-apply checksum mismatch");
  assertTools(binary, runDir, "post-apply");
  command(runDir, "post-apply-app-server-help", [binary, "app-server", "--help"]);
}

function defaultConfig(certifyExistingRun?: string): ReconcileConfig {
  const sharedState = process.env.CB_STATE ? join(process.env.CB_STATE, "codex") : undefined;
  return {
    releaseApiUrl:
      process.env.CB_CODEX_RELEASE_API_URL ?? "https://api.github.com/repos/openai/codex/releases/latest",
    releaseJsonFixture: process.env.CB_CODEX_RELEASE_JSON,
    // Backward-compatible fixture seam. Production has no default stock binary:
    // the same-version baseline comes from the checksummed stable release asset.
    stableBinaryFixture: process.env.CB_CODEX_STABLE_BIN ?? process.env.CB_CODEX_STOCK_BIN,
    linkPath:
      process.env.CB_CODEX_LINK_PATH ??
      process.env.CB_CODEX_SYMLINK ??
      join(process.env.HOME ?? "", ".local/bin/codex"),
    stateRoot:
      process.env.CB_CODEX_MAINTENANCE_STATE ??
      sharedState ??
      join(process.env.HOME ?? "", ".local/state/context-bonsai/codex-maintenance"),
    artifactRoot:
      process.env.CB_CODEX_ARTIFACT_ROOT ??
      join(process.env.HOME ?? "", ".local/share/context-bonsai/artifacts/codex"),
    scratchRoot:
      process.env.CB_CODEX_SCRATCH_ROOT ??
      join(process.env.HOME ?? "", ".local/state/context-bonsai/codex-maintenance/runs"),
    upstreamUrl: process.env.CB_CODEX_UPSTREAM_URL ?? "https://github.com/openai/codex.git",
    sharedCore: process.env.CB_CODEX_SHARED_CORE ?? SHARED_CORE,
    runtimeManifest: process.env.CB_CODEX_RUNTIME_MANIFEST ?? join(REPO_ROOT, "runtime-manifest.json"),
    sharedCoreTree: process.env.CB_CODEX_SHARED_CORE_TREE ?? join(REPO_ROOT, "shared-core-tree.txt"),
    initialPatch: process.env.CB_CODEX_INITIAL_PATCH ?? INITIAL_PATCH,
    certifyExistingRun,
  };
}

export async function reconcile(config: ReconcileConfig): Promise<{ status: FinalStatus; runDir: string }> {
  const runId = nowId();
  mkdirSync(config.stateRoot, { recursive: true });
  mkdirSync(config.scratchRoot, { recursive: true });
  const lock = acquireLock(config.stateRoot, runId);
  const runDir = config.certifyExistingRun ? resolve(config.certifyExistingRun) : join(config.scratchRoot, runId);
  let summaryVersion: string | undefined;
  try {
    if (!config.certifyExistingRun) mkdirFresh(runDir);
    else if (!existsSync(runDir)) {
      throw new ReconcileError("invariant-failed", 23, `agentic run does not exist: ${runDir}`);
    }
    appendEvent(runDir, "reconcile-start", { runId, mode: config.certifyExistingRun ? "certify-agentic" : "reconcile" });
    if (!existsSync(config.initialPatch)) throw new ReconcileError("invariant-failed", 23, `initial patch missing: ${config.initialPatch}`);
    if (config.initialPatch === INITIAL_PATCH && sha256File(config.initialPatch) !== INITIAL_PATCH_SHA256) {
      throw new ReconcileError("invariant-failed", 23, "initial Codex Bonsai patch checksum does not match its manifest");
    }
    const snapshot = snapshotManagedLink(config.linkPath, runDir);
    summaryVersion = snapshot.version;
    assertManagedArtifactChecksum(snapshot.resolvedTarget);
    assertTools(snapshot.resolvedTarget, runDir, "current-fork");
    const release = detectLatestStable(config, runDir);
    summaryVersion = release.version;
    appendEvent(runDir, "stable-release-detected", {
      version: release.version,
      tag: release.tag,
      publishedAt: release.publishedAt,
      assetName: release.assetName,
      assetSha256: release.assetSha256,
    });
    const action = releaseAction(snapshot.version, release.version);
    if (action === "current") {
      finish(runDir, "up-to-date", {
        version: release.version,
        stableTag: release.tag,
        currentTarget: snapshot.resolvedTarget,
      });
      return { status: "up-to-date", runDir };
    }
    if (action === "downgrade") {
      throw new ReconcileError(
        "invariant-failed",
        23,
        `refusing unattended downgrade: active ${snapshot.version}, latest stable ${release.version}`,
      );
    }

    let source: string;
    let sourceCommit: string;
    let targetVersion: string;
    if (config.certifyExistingRun) {
      const requestPath = join(runDir, "NEEDS_AGENT.json");
      if (!existsSync(requestPath)) throw new ReconcileError("invariant-failed", 23, "agentic run lacks NEEDS_AGENT.json");
      const request = JSON.parse(readFileSync(requestPath, "utf8"));
      source = request.source;
      sourceCommit = request.targetCommit;
      targetVersion = request.targetVersion;
      if (targetVersion !== release.version || request.stableRelease?.assetSha256 !== release.assetSha256) {
        throw new ReconcileError("invariant-failed", 23, "latest stable release changed during agentic resolution");
      }
      normalizeSharedCoreDependency(config, runDir, source);
      stageAgenticChanges(runDir, source);
    } else {
      targetVersion = release.version;
      const checkout = checkoutTarget(config, runDir, targetVersion);
      source = checkout.source;
      sourceCommit = checkout.commit;
      prepareMechanicalPort(
        config,
        runDir,
        source,
        getCurrentArtifactPatch(snapshot.resolvedTarget, config.initialPatch),
        release,
        sourceCommit,
      );
    }

    const { sharedCoreIdentity, patchText } = validatePortSource(config, runDir, source, sourceCommit);
    const baseline = prepareReleaseBaseline(release, runDir);
    const candidate = certifyAndBuild(
      config,
      runDir,
      source,
      baseline,
      release,
      targetVersion,
      sourceCommit,
      sharedCoreIdentity,
      patchText,
    );
    assertCurrentLinkUnchanged(snapshot);
    const activation = activateCandidate(
      candidate,
      snapshot,
      { linkPath: config.linkPath, stateRoot: config.stateRoot, runDir, runId },
      (binary) => productionVerify(binary, runDir, targetVersion, candidate.sha256),
    );
    if (activation === "rolled-back") {
      finish(runDir, "rolled-back", {
        candidate: candidate.binary,
        candidateVersion: candidate.version,
        restoredTarget: snapshot.resolvedTarget,
      });
      return { status: "rolled-back", runDir };
    }
    finish(runDir, "activated", {
      fromVersion: snapshot.version,
      toVersion: targetVersion,
      stableTag: release.tag,
      stablePublishedAt: release.publishedAt,
      binary: candidate.binary,
      sha256: candidate.sha256,
    });
    return { status: "activated", runDir };
  } catch (error) {
    const failure = error instanceof ReconcileError ? error : new ReconcileError("invariant-failed", 23, String(error));
    failure.summaryVersion ??= summaryVersion;
    if (existsSync(runDir) && !existsSync(join(runDir, `FINAL-${failure.status}.json`))) {
      finish(runDir, failure.status, { error: failure.message });
    }
    throw failure;
  } finally {
    releaseLock(lock, config.stateRoot, runId);
  }
}

function parseArgs(argv: string[]): { command: "reconcile" | "certify-agentic"; run?: string } {
  if (argv.length === 0 || argv[0] === "reconcile") return { command: "reconcile" };
  if (argv[0] === "certify-agentic" && argv.length === 2) return { command: "certify-agentic", run: argv[1] };
  throw new Error("usage: reconcile-codex.ts [reconcile | certify-agentic RUN_DIR]");
}

if (import.meta.main) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const result = await reconcile(defaultConfig(args.command === "certify-agentic" ? args.run : undefined));
    const finalPath = `FINAL-${result.status}.json`;
    const final = finalPath ? JSON.parse(readFileSync(join(result.runDir, finalPath), "utf8")) : {};
    if (result.status === "up-to-date") {
      process.stdout.write(`codex ${final.version ?? "unknown"}: Bonsai already current\n`);
    } else if (result.status === "activated") {
      process.stdout.write(`codex ${final.toVersion ?? "unknown"}: forward-ported + verified\n`);
    } else if (result.status === "rolled-back") {
      process.stdout.write(
        `codex ${final.candidateVersion ?? "candidate"}: post-apply verification failed — previous target auto-restored (attention)\n`,
      );
      process.exit(10);
    }
  } catch (error) {
    const failure = error instanceof ReconcileError ? error : new ReconcileError("invariant-failed", 23, String(error));
    const version = (() => {
      if (failure.summaryVersion) return failure.summaryVersion;
      try {
        const link =
          process.env.CB_CODEX_LINK_PATH ??
          process.env.CB_CODEX_SYMLINK ??
          join(process.env.HOME ?? "", ".local/bin/codex");
        return parseVersion(spawnSync(link, ["--version"], { encoding: "utf8" }).stdout ?? "", "current fork");
      } catch {
        return "unknown";
      }
    })();
    if (failure.status === "benign-skip") {
      process.stdout.write(`codex ${version}: stable upstream unavailable — current fork unchanged\n`);
      process.stderr.write(`${JSON.stringify({ status: failure.status, error: failure.message })}\n`);
      process.exit(20);
    }
    const phrase =
      failure.status === "needs-agent"
        ? "rebase conflict — candidate isolated, install untouched (escalate)"
        : failure.status === "certification-failed"
          ? "candidate failed certification — install untouched (attention)"
          : "maintenance invariant failed — install untouched (attention)";
    process.stdout.write(`codex ${version}: ${phrase}\n`);
    process.stderr.write(`${JSON.stringify({ status: failure.status, error: failure.message })}\n`);
    process.exit(10);
  }
}
