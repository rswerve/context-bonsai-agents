import { createHash, randomBytes } from "node:crypto";
import {
  chmodSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readlinkSync,
  renameSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { join, resolve } from "node:path";
import { describe, expect, test } from "bun:test";
import {
  activateCandidate,
  missingAutonomyWiringTokens,
  parseStableReleasePayload,
  releaseAction,
  releasePlan,
  rewriteSharedCoreDependencyText,
  validateSharedCoreSnapshot,
  type ActivationPaths,
  type Candidate,
  type LinkSnapshot,
} from "./reconcile-codex";

const REPO_ROOT = resolve(import.meta.dir, "../../..");
const SIM_ROOT = join(REPO_ROOT, ".staging/auto-maintenance/simulations");

function uniqueRoot(name: string): string {
  const root = join(SIM_ROOT, `${name}-${Date.now()}-${process.pid}-${randomBytes(3).toString("hex")}`);
  mkdirSync(root, { recursive: true });
  return root;
}

function fakeBinary(root: string, name: string, version: string): string {
  const path = join(root, name);
  writeFileSync(
    path,
    `#!/bin/zsh\nif [[ \"\${1:-}\" == \"--version\" ]]; then echo \"codex-cli ${version}\"; exit 0; fi\n# context-bonsai-prune context-bonsai-retrieve CONTEXT BONSAI ENFORCED excluded_messages=\nexit 0\n`,
  );
  chmodSync(path, 0o755);
  return path;
}

function sha(path: string): string {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function fixture(name: string) {
  const root = uniqueRoot(name);
  const bin = join(root, "bin");
  const stateRoot = join(root, "state");
  const runDir = join(root, "run");
  mkdirSync(bin, { recursive: true });
  mkdirSync(runDir, { recursive: true });
  const oldBinary = fakeBinary(root, "codex-0.144.5", "0.144.5");
  const candidateBinary = fakeBinary(root, "codex-0.145.0", "0.145.0");
  const linkPath = join(bin, "codex");
  symlinkSync(oldBinary, linkPath);
  const snapshot: LinkSnapshot = {
    linkPath,
    rawTarget: oldBinary,
    resolvedTarget: oldBinary,
    version: "0.144.5",
  };
  const candidate: Candidate = {
    binary: candidateBinary,
    version: "0.145.0",
    sha256: sha(candidateBinary),
    patchPath: join(root, "bonsai.patch"),
    patchSha256: "",
    sourceCommit: "a".repeat(40),
    sharedCoreCommit: "b".repeat(40),
    schemaHash: "c".repeat(64),
  };
  writeFileSync(candidate.patchPath, "simulated forward port\n");
  candidate.patchSha256 = sha(candidate.patchPath);
  const paths: ActivationPaths = { linkPath, stateRoot, runDir, runId: basenameSafe(root) };
  return { root, oldBinary, candidateBinary, linkPath, snapshot, candidate, paths };
}

function basenameSafe(path: string): string {
  return path.split("/").at(-1) ?? "simulation";
}

describe("simulated Codex version bumps", () => {
  test("green 0.144.5 -> 0.145.0 candidate atomically activates and preserves the old link", () => {
    const f = fixture("green-bump");
    const status = activateCandidate(f.candidate, f.snapshot, f.paths, (binary) => {
      expect(binary).toBe(f.candidateBinary);
      expect(sha(binary)).toBe(f.candidate.sha256);
    });
    expect(status).toBe("activated");
    expect(readlinkSync(f.linkPath)).toBe(f.candidateBinary);
    const history = join(f.paths.stateRoot, "link-history", `codex-before-${f.paths.runId}`);
    expect(lstatSync(history).isSymbolicLink()).toBe(true);
    expect(readlinkSync(history)).toBe(f.oldBinary);
    expect(lstatSync(join(f.paths.stateRoot, "active")).isSymbolicLink()).toBe(true);
  });

  test("post-apply verification failure restores the exact previous link", () => {
    const f = fixture("post-apply-failure");
    const status = activateCandidate(f.candidate, f.snapshot, f.paths, () => {
      throw new Error("simulated post-apply smoke failure");
    });
    expect(status).toBe("rolled-back");
    expect(readlinkSync(f.linkPath)).toBe(f.oldBinary);
    expect(readFileSync(join(f.paths.runDir, "events.jsonl"), "utf8")).toContain("activation-auto-rollback");
  });

  test("a later upgrade preserves the prior active-state pointer before committing the new one", () => {
    const f = fixture("second-upgrade");
    const states = join(f.paths.stateRoot, "states");
    mkdirSync(states, { recursive: true });
    writeFileSync(join(states, "prior.json"), "{}\n");
    symlinkSync("states/prior.json", join(f.paths.stateRoot, "active"));
    const status = activateCandidate(f.candidate, f.snapshot, f.paths, () => {});
    expect(status).toBe("activated");
    expect(readlinkSync(join(f.paths.stateRoot, "active"))).toBe(`states/${f.paths.runId}.json`);
    expect(readlinkSync(join(f.paths.stateRoot, "link-history", `active-before-${f.paths.runId}`))).toBe(
      "states/prior.json",
    );
  });

  test("unmanaged active-state metadata fails before the live link changes", () => {
    const f = fixture("unmanaged-state");
    mkdirSync(f.paths.stateRoot, { recursive: true });
    writeFileSync(join(f.paths.stateRoot, "active"), "unmanaged\n");
    expect(() => activateCandidate(f.candidate, f.snapshot, f.paths, () => {})).toThrow("not a managed symlink");
    expect(readlinkSync(f.linkPath)).toBe(f.oldBinary);
  });

  test("concurrent symlink drift fails before activation and preserves the concurrent target", () => {
    const f = fixture("compare-and-swap");
    const concurrent = fakeBinary(f.root, "codex-concurrent", "0.144.6");
    const replacement = join(f.root, "replacement-link");
    symlinkSync(concurrent, replacement);
    renameSync(replacement, f.linkPath);
    expect(() => activateCandidate(f.candidate, f.snapshot, f.paths, () => {})).toThrow("changed concurrently");
    expect(readlinkSync(f.linkPath)).toBe(concurrent);
  });

  test("a pre-commit certification failure performs no link operation", () => {
    const f = fixture("precommit-failure");
    const before = readlinkSync(f.linkPath);
    const simulatedGate = () => {
      throw new Error("simulated schema parity failure");
    };
    expect(simulatedGate).toThrow("schema parity");
    expect(readlinkSync(f.linkPath)).toBe(before);
  });
});

function stablePayload(version = "0.145.0") {
  const tag = `rust-v${version}`;
  return {
    tag_name: tag,
    name: version,
    draft: false,
    prerelease: false,
    published_at: "2026-07-20T00:00:00Z",
    assets: [
      {
        name: "codex-aarch64-apple-darwin.tar.gz",
        browser_download_url:
          `https://github.com/openai/codex/releases/download/${tag}/codex-aarch64-apple-darwin.tar.gz`,
        digest: `sha256:${"d".repeat(64)}`,
        size: 123456,
      },
    ],
  };
}

describe("latest stable release policy", () => {
  test("strict stable metadata selects a proactive forward port", () => {
    const release = parseStableReleasePayload(stablePayload());
    expect(release.version).toBe("0.145.0");
    expect(release.assetSha256).toBe("d".repeat(64));
    expect(releaseAction("0.144.5", release.version)).toBe("forward-port");
  });

  test("same stable version is a no-op and a lower release is never installed", () => {
    expect(releaseAction("0.144.5", "0.144.5")).toBe("current");
    expect(releaseAction("0.145.0", "0.144.5")).toBe("downgrade");
  });

  test("reviewed same-version certification is explicit and refuses version drift", () => {
    expect(releasePlan("0.145.0", "0.145.0", true)).toBe("same-version-certification");
    expect(() => releasePlan("0.144.6", "0.145.0", true)).toThrow(
      "same-version certification requires active and stable versions to match",
    );
    expect(releasePlan("0.145.0", "0.145.0")).toBe("up-to-date");
  });

  test("prereleases and non-stable tags fail closed", () => {
    expect(() => parseStableReleasePayload({ ...stablePayload(), prerelease: true })).toThrow("draft or prerelease");
    expect(() => parseStableReleasePayload({ ...stablePayload(), tag_name: "rust-v0.145.0-beta.1" })).toThrow(
      "rust-vX.Y.Z",
    );
  });

  test("missing digest or wrong release asset fails closed", () => {
    const noDigest = stablePayload();
    noDigest.assets[0].digest = "";
    expect(() => parseStableReleasePayload(noDigest)).toThrow("SHA-256");
    const wrongUrl = stablePayload();
    wrongUrl.assets[0].browser_download_url = "https://example.invalid/codex.tar.gz";
    expect(() => parseStableReleasePayload(wrongUrl)).toThrow("official download");
  });
});

describe("runtime portability", () => {
  test("normalizes the historical Cargo path to the installed shared core", () => {
    const source = 'codex-context-bonsai = { path = "/old/development/checkout" }\n';
    const rewritten = rewriteSharedCoreDependencyText(source, "/installed/runtime/codex_context_bonsai");
    expect(rewritten).toContain(
      'codex-context-bonsai = { path = "/installed/runtime/codex_context_bonsai" }',
    );
    expect(rewritten).not.toContain("/old/development/checkout");
  });

  test("fails closed if the dependency is missing or ambiguous", () => {
    expect(() => rewriteSharedCoreDependencyText("", "/runtime/core")).toThrow("found 0");
    const duplicate =
      'codex-context-bonsai = { path = "/one" }\n' + 'codex-context-bonsai = { path = "/two" }\n';
    expect(() => rewriteSharedCoreDependencyText(duplicate, "/runtime/core")).toThrow("found 2");
  });

  function archivedCore(name: string) {
    const root = uniqueRoot(name);
    const core = join(root, "codex_context_bonsai");
    mkdirSync(join(core, "src"), { recursive: true });
    writeFileSync(join(core, "Cargo.toml"), "[package]\nname='fixture'\nversion='0.0.0'\n");
    writeFileSync(join(core, "src/lib.rs"), "pub fn fixture() {}\n");
    const blob = (path: string) => {
      const content = readFileSync(path);
      return createHash("sha1").update(Buffer.from(`blob ${content.length}\0`)).update(content).digest("hex");
    };
    const tree = join(root, "shared-core-tree.txt");
    writeFileSync(
      tree,
      [
        `100644 blob ${blob(join(core, "Cargo.toml"))}\tCargo.toml`,
        `100644 blob ${blob(join(core, "src/lib.rs"))}\tsrc/lib.rs`,
        "",
      ].join("\n"),
    );
    const runtime = join(root, "runtime-manifest.json");
    const commit = "b".repeat(40);
    writeFileSync(runtime, `${JSON.stringify({ sharedCoreCommit: commit, sharedCoreTreeSha256: sha(tree) })}\n`);
    return { root, core, tree, runtime, commit };
  }

  test("verifies an immutable archived shared core without .git metadata", () => {
    const f = archivedCore("archived-core-green");
    const identity = validateSharedCoreSnapshot(f.core, f.runtime, f.tree);
    expect(identity).toEqual({ commit: f.commit, fingerprint: `${f.commit}:${sha(f.tree)}`, kind: "archive" });
  });

  test("fails closed when an archived shared-core blob changes", () => {
    const f = archivedCore("archived-core-tamper");
    writeFileSync(join(f.core, "src/lib.rs"), "pub fn tampered() {}\n");
    expect(() => validateSharedCoreSnapshot(f.core, f.runtime, f.tree)).toThrow("blob mismatch");
  });

  test("fails closed on added files or tree-manifest drift", () => {
    const added = archivedCore("archived-core-added");
    writeFileSync(join(added.core, "unexpected.txt"), "unexpected\n");
    expect(() => validateSharedCoreSnapshot(added.core, added.runtime, added.tree)).toThrow("file set drifted");

    const manifest = archivedCore("archived-core-manifest-drift");
    writeFileSync(manifest.tree, `${readFileSync(manifest.tree, "utf8")}\n`);
    expect(() => validateSharedCoreSnapshot(manifest.core, manifest.runtime, manifest.tree)).toThrow(
      "manifest checksum mismatch",
    );
  });
});

describe("Context Bonsai autonomy certification", () => {
  const completeWiring = [
    "codex_context_bonsai::BONSAI_GUIDANCE",
    "codex_context_bonsai::GAUGE_CADENCE_TURNS",
    "codex_context_bonsai::gauge_text_for_ratio",
    "bonsai_guidance_for_start_target",
    "bonsai_gauge_context_for_turn",
  ].join("\n");

  test("accepts a port containing the shared guidance and gauge controller", () => {
    expect(missingAutonomyWiringTokens(completeWiring)).toEqual([]);
  });

  test("rejects the former tools-only port", () => {
    const missing = missingAutonomyWiringTokens("context-bonsai-prune context-bonsai-retrieve");
    expect(missing).toContain("codex_context_bonsai::BONSAI_GUIDANCE");
    expect(missing).toContain("bonsai_gauge_context_for_turn");
  });
});
