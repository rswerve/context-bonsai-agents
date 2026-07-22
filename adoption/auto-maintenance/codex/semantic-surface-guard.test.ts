import { randomBytes } from "node:crypto";
import { execFileSync } from "node:child_process";
import { chmodSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { describe, expect, test } from "bun:test";
import {
  CONTEXT_BONSAI,
  EXACT_REGISTRATIONS,
  PORT_FILES,
  captureBaseline,
  verifyCandidate,
} from "./semantic-surface-guard";

const REPO_ROOT = resolve(import.meta.dir, "../../..");
const TEST_ROOT = process.env.CB_SEMANTIC_GUARD_TEST_ROOT
  ? resolve(process.env.CB_SEMANTIC_GUARD_TEST_ROOT)
  : join(REPO_ROOT, ".staging/auto-maintenance/semantic-guard");

type Fixture = { root: string; repo: string; state: string };

function uniqueRoot(name: string): string {
  const root = join(TEST_ROOT, `${name}-${Date.now()}-${process.pid}-${randomBytes(3).toString("hex")}`);
  mkdirSync(root, { recursive: true });
  return root;
}

function git(repo: string, ...args: string[]): string {
  return execFileSync("git", ["-C", repo, ...args], { encoding: "utf8" });
}

function write(path: string, content: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
}

function contextSource(): string {
  return `const BONSAI_ARCHIVE_FORMAT: &str = "context-bonsai-v1";
const BONSAI_STORE_VERSION: u32 = 1;
const BONSAI_STORAGE_PATH: &str = "$CODEX_HOME/context-bonsai";

struct ArchiveRecord { version: u32, payload: Vec<u8> }

fn persist_archive(record: &ArchiveRecord) { let _ = record; }
fn select_range(start: usize, end: usize) -> bool { start <= end }
fn reject_malformed_range(start: usize, end: usize) -> bool { start > end }
fn excludes_current_turn(index: usize, current: usize) -> bool { index < current }
fn mutate_session_history() {}

fn extract_text(item: &ResponseItem) -> String {
    // context-bonsai:auto-adapter-begin response-item-text-v1
    match item {
        ResponseItem::Message { content, .. } => content
            .iter()
            .find_map(|c| match c {
                ContentItem::InputText { text } | ContentItem::OutputText { text } => Some(text.clone()),
                ContentItem::InputImage { .. } => None,
            })
            .unwrap_or_default(),
        ResponseItem::Other => String::new(),
    }
    // context-bonsai:auto-adapter-end response-item-text-v1
}

fn explicit_item_id(item: &ResponseItem) -> Option<String> {
    // context-bonsai:auto-adapter-begin response-item-id-v1
    match item {
        ResponseItem::LocalShellCall { id: Some(id), .. } => Some(id.clone()),
        ResponseItem::FunctionCall { id: Some(id), .. } => Some(id.clone()),
        ResponseItem::ToolSearchCall { id: Some(id), .. } => Some(id.clone()),
        ResponseItem::CustomToolCall { id: Some(id), .. } => Some(id.clone()),
        _ => None,
    }
    // context-bonsai:auto-adapter-end response-item-id-v1
}
`;
}

function registrations(path: string, complete: boolean): string {
  const base: Record<string, string> = {
    "codex-rs/core/src/lib.rs": "pub mod config;",
    "codex-rs/core/src/tools/handlers/mod.rs": "pub mod apply_patch;",
    "codex-rs/core/src/tools/spec_plan.rs": "fn configure_native_tools() {}",
  };
  const lines = [base[path], ...(complete ? EXACT_REGISTRATIONS[path] ?? [] : [])];
  return lines.join("\n");
}

function createFixture(name: string, completeRegistrations = true): Fixture {
  const root = uniqueRoot(name);
  const repo = join(root, "source");
  const state = join(root, "immutable-baseline.json");
  mkdirSync(repo, { recursive: true });
  const files: Record<string, string> = {
    "codex-rs/core/Cargo.toml": "[package]\nname = \"codex-core\"\n",
    [CONTEXT_BONSAI]: contextSource(),
    "codex-rs/core/src/hook_runtime.rs":
      'const BONSAI_GUIDANCE: &str = "Model chooses prune/retrieve";\nconst GAUGE_CADENCE_TURNS: usize = 5;\n',
    "codex-rs/core/src/lib.rs": registrations("codex-rs/core/src/lib.rs", completeRegistrations),
    "codex-rs/core/src/session/mod.rs": "fn replace_compacted_history() {}\n",
    "codex-rs/core/src/tools/handlers/bonsai.rs":
      'const PRUNE_TOOL: &str = "context-bonsai-prune";\nconst RETRIEVE_TOOL: &str = "context-bonsai-retrieve";\nfn schema() {}\nfn handle() {}\n',
    "codex-rs/core/src/tools/handlers/mod.rs": registrations(
      "codex-rs/core/src/tools/handlers/mod.rs",
      completeRegistrations,
    ),
    "codex-rs/core/src/tools/spec_plan.rs": registrations(
      "codex-rs/core/src/tools/spec_plan.rs",
      completeRegistrations,
    ),
    "codex-rs/core/src/tools/spec_plan_tests.rs": "fn registration_test() {}\n",
    "codex-rs/core/tests/common/context_snapshot.rs": "fn normalize_snapshot() {}\n",
    "codex-rs/app-server-protocol/schema/json/codex_app_server_protocol.schemas.json":
      '{"wire":"stock"}\n',
  };
  for (const path of PORT_FILES) write(join(repo, path), files[path]);
  write(
    join(repo, "codex-rs/app-server-protocol/schema/json/codex_app_server_protocol.schemas.json"),
    files["codex-rs/app-server-protocol/schema/json/codex_app_server_protocol.schemas.json"],
  );
  git(repo, "init", "-q");
  git(repo, "config", "user.email", "semantic-guard-fixture@example.invalid");
  git(repo, "config", "user.name", "Semantic Guard Fixture");
  git(repo, "add", ".");
  git(repo, "commit", "-qm", "immutable baseline");
  captureBaseline(repo, state);
  return { root, repo, state };
}

function mutate(fixture: Fixture, path: string, from: string, to: string): void {
  const target = join(fixture.repo, path);
  const source = readFileSync(target, "utf8");
  expect(source).toContain(from);
  write(target, source.replace(from, to));
}

function appendRegistrations(fixture: Fixture): void {
  for (const [path, declarations] of Object.entries(EXACT_REGISTRATIONS)) {
    const target = join(fixture.repo, path);
    const source = readFileSync(target, "utf8");
    write(target, [source, ...declarations].join("\n"));
  }
}

function applyTodayAdapterFix(fixture: Fixture): void {
  mutate(
    fixture,
    CONTEXT_BONSAI,
    "                ContentItem::InputImage { .. } => None,",
    "                ContentItem::InputImage { .. } | ContentItem::InputAudio { .. } => None,",
  );
  const target = join(fixture.repo, CONTEXT_BONSAI);
  write(target, readFileSync(target, "utf8").replaceAll("Some(id.clone())", "Some(id.to_string())"));
}

function reject(fixture: Fixture, pattern: RegExp): void {
  expect(() => verifyCandidate(fixture.repo, fixture.state)).toThrow(pattern);
}

describe("semantic-surface guard allows only registered host-adapter categories", () => {
  test("accepts no-op complete candidate", () => {
    const f = createFixture("no-op");
    expect(() => verifyCandidate(f.repo, f.state)).not.toThrow();
  });

  test("accepts today's InputAudio, typed-ID, and exact-registration repair", () => {
    const f = createFixture("today-adapter", false);
    applyTodayAdapterFix(f);
    appendRegistrations(f);
    expect(() => verifyCandidate(f.repo, f.state)).not.toThrow();
  });

  test("accepts a future pure non-text content variant as the same category", () => {
    const f = createFixture("future-content-variant");
    mutate(
      f,
      CONTEXT_BONSAI,
      "                ContentItem::InputImage { .. } => None,",
      "                ContentItem::InputImage { .. } | ContentItem::InputVideo { .. } => None,",
    );
    expect(() => verifyCandidate(f.repo, f.state)).not.toThrow();
  });
});

describe("protected Bonsai semantics reject independently of agent claims", () => {
  const contextCases: Array<[string, string, string]> = [
    ["archive format", '"context-bonsai-v1"', '"context-bonsai-v2"'],
    ["archive version", "BONSAI_STORE_VERSION: u32 = 1", "BONSAI_STORE_VERSION: u32 = 2"],
    ["archive persistence", "let _ = record", "drop(record.payload.clone())"],
    ["range selection", "start <= end", "start < end"],
    ["malformed-range guard", "start > end", "start >= end"],
    ["current-turn exclusion", "index < current", "index <= current"],
    ["sidecar storage path", "$CODEX_HOME/context-bonsai", "$HOME/.bonsai"],
    ["session mutation helper", "fn mutate_session_history() {}", "fn mutate_session_history() { panic!() }"],
  ];
  for (const [name, from, to] of contextCases) {
    test(`rejects ${name}`, () => {
      const f = createFixture(`protected-${name.replaceAll(" ", "-")}`);
      mutate(f, CONTEXT_BONSAI, from, to);
      reject(f, /protected content changed/);
    });
  }

  const protectedFileCases: Array<[string, string, string, string]> = [
    ["tool name", "codex-rs/core/src/tools/handlers/bonsai.rs", "context-bonsai-prune", "bonsai-prune"],
    ["tool schema", "codex-rs/core/src/tools/handlers/bonsai.rs", "fn schema() {}", "fn schema() { unsafe {} }"],
    ["tool handler", "codex-rs/core/src/tools/handlers/bonsai.rs", "fn handle() {}", "fn handle() { panic!() }"],
    ["startup guidance", "codex-rs/core/src/hook_runtime.rs", "Model chooses prune/retrieve", "Harness chooses prune"],
    ["pressure cadence", "codex-rs/core/src/hook_runtime.rs", "GAUGE_CADENCE_TURNS: usize = 5", "GAUGE_CADENCE_TURNS: usize = 1"],
    ["host session mutation", "codex-rs/core/src/session/mod.rs", "replace_compacted_history", "replace_history"],
    [
      "app-server wire schema",
      "codex-rs/app-server-protocol/schema/json/codex_app_server_protocol.schemas.json",
      '"stock"',
      '"bonsai-extension"',
    ],
  ];
  for (const [name, path, from, to] of protectedFileCases) {
    test(`rejects ${name}`, () => {
      const f = createFixture(`protected-file-${name.replaceAll(" ", "-")}`);
      mutate(f, path, from, to);
      reject(f, /protected or unexpected files/);
    });
  }

  test("ignores a dishonest adapter-only report and rejects the actual diff", () => {
    const f = createFixture("dishonest-report");
    write(join(f.root, "agent-report.md"), "I changed only the adapter exhaustiveness arm.\n");
    mutate(f, CONTEXT_BONSAI, "start <= end", "true");
    reject(f, /protected content changed/);
  });
});

describe("repository and marker tampering fail closed", () => {
  test("rejects a deleted marker", () => {
    const f = createFixture("deleted-marker");
    mutate(f, CONTEXT_BONSAI, "    // context-bonsai:auto-adapter-end response-item-text-v1\n", "");
    reject(f, /must occur exactly once/);
  });

  test("rejects a forged duplicate marker", () => {
    const f = createFixture("forged-marker");
    mutate(
      f,
      CONTEXT_BONSAI,
      "    // context-bonsai:auto-adapter-begin response-item-text-v1\n",
      "    // context-bonsai:auto-adapter-begin response-item-text-v1\n    // context-bonsai:auto-adapter-begin response-item-text-v1\n",
    );
    reject(f, /must occur exactly once/);
  });

  test("rejects an altered guarded signature", () => {
    const f = createFixture("altered-signature");
    mutate(
      f,
      CONTEXT_BONSAI,
      "fn extract_text(item: &ResponseItem) -> String {",
      "fn extract_text(item: ResponseItem) -> String {",
    );
    reject(f, /adapter signature/);
  });

  test("rejects an untracked source file", () => {
    const f = createFixture("untracked-source");
    write(join(f.repo, "codex-rs/core/src/agent_smuggle.rs"), "pub fn smuggle() {}\n");
    reject(f, /untracked files/);
  });

  test("rejects a file-mode change", () => {
    const f = createFixture("file-mode");
    chmodSync(join(f.repo, CONTEXT_BONSAI), 0o755);
    reject(f, /file type, mode, or path/);
  });

  test("rejects a staged edit", () => {
    const f = createFixture("staged-edit");
    mutate(f, CONTEXT_BONSAI, "start <= end", "true");
    git(f.repo, "add", CONTEXT_BONSAI);
    reject(f, /Git index changed/);
  });

  test("rejects a commit", () => {
    const f = createFixture("committed-edit");
    mutate(f, CONTEXT_BONSAI, "start <= end", "true");
    git(f.repo, "add", CONTEXT_BONSAI);
    git(f.repo, "commit", "-qm", "agent attempted commit");
    reject(f, /HEAD changed/);
  });

  test("rejects a non-exact registration rewrite", () => {
    const f = createFixture("registration-rewrite");
    mutate(f, "codex-rs/core/src/lib.rs", "mod context_bonsai;", "pub mod context_bonsai;");
    reject(f, /exact registration must occur once/);
  });

  test("rejects category-shaped executable smuggling inside the adapter block", () => {
    const f = createFixture("adapter-smuggle");
    mutate(
      f,
      CONTEXT_BONSAI,
      "                ContentItem::InputImage { .. } => None,",
      "                ContentItem::InputImage { .. } | ContentItem::InputVideo { .. } => { let _ = BONSAI_STORE_VERSION; None },",
    );
    reject(f, /pure addition to the non-text ContentItem/);
  });

  test("rejects an unexpected second adapter edit accompanying an allowed variant", () => {
    const f = createFixture("adapter-double-edit");
    mutate(
      f,
      CONTEXT_BONSAI,
      "                ContentItem::InputImage { .. } => None,",
      "                ContentItem::InputImage { .. } | ContentItem::InputVideo { .. } => None,",
    );
    mutate(f, CONTEXT_BONSAI, "ResponseItem::Other => String::new()", "ResponseItem::Other => panic!()");
    reject(f, /pure addition to the non-text ContentItem/);
  });
});
