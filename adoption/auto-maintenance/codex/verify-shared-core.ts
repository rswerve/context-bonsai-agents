#!/usr/bin/env bun
import { resolve } from "node:path";
import { validateSharedCoreSnapshot } from "./reconcile-codex";

const root = resolve(process.argv[2] ?? "");
if (!process.argv[2]) throw new Error("usage: verify-shared-core.ts RUNTIME_ROOT");
const identity = validateSharedCoreSnapshot(
  resolve(root, "codex_context_bonsai"),
  resolve(root, "runtime-manifest.json"),
  resolve(root, "shared-core-tree.txt"),
);
process.stdout.write(`shared core verified: ${identity.commit}\n`);
