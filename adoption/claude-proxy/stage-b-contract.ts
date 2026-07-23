#!/usr/bin/env bun
// Deterministic Stage-B gate: drive a real MCP prune against a transcript COPY,
// then prove its emitted boundary hashes select the same exact wire range.
import assert from "node:assert";
import { readFileSync, writeFileSync } from "node:fs";
import {
  routeContextBonsaiTool,
} from "../../tweakcc_context_bonsai/mcp-server/index";
import {
  applyFilter,
  canonicalHash,
} from "../../tweakcc_context_bonsai/proxy-prototype/correlate.mjs";

const [sessionPath, wirePath, fromPattern, toPattern, evidencePath] = process.argv.slice(2);
if (!sessionPath || !wirePath || !fromPattern || !toPattern || !evidencePath) {
  console.error("usage: stage-b-contract.ts <session-copy.jsonl> <wire-body.json> <from-pattern> <to-pattern> <evidence.json>");
  process.exit(2);
}

const internal = readFileSync(sessionPath, "utf8")
  .split("\n")
  .filter(Boolean)
  .map((line) => JSON.parse(line));
const wireBody = JSON.parse(readFileSync(wirePath, "utf8"));
assert(Array.isArray(wireBody.messages));

function text(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content.flatMap((block: any) => {
    if (typeof block === "string") return [block];
    if (block?.type === "text") return [block.text ?? ""];
    if (block?.type === "tool_result") return [text(block.content)];
    return [];
  }).join("\n");
}
function uniqueBoundary(pattern: string): any {
  const matches = internal.filter((entry) =>
    entry?.uuid && entry?.message?.role && text(entry.message.content).includes(pattern));
  assert.equal(matches.length, 1, `internal pattern must match exactly once: ${pattern}`);
  return matches[0];
}

const from = uniqueBoundary(fromPattern);
const to = uniqueBoundary(toPattern);
const expectedStart = canonicalHash(from.message);
const expectedEnd = canonicalHash(to.message);

const result = await routeContextBonsaiTool("context-bonsai-prune", {
  from_pattern: fromPattern,
  to_pattern: toPattern,
  summary: "Stage-B isolated marker/hash contract proof.",
  index_terms: ["stage-b", "wire-correlation"],
  reason: "isolated migration certification",
}, {
  discoverSessionPath: async () => sessionPath,
  assertArchivedFilterPatchPresent: async () => true,
});
assert.equal(result.isError, undefined, JSON.stringify(result));
const resultText = result.content.map((block) => block.text).join("\n");
const marker = resultText.match(
  /\[\[CB-PRUNE v1 archive=([^ ]+) start=([a-f0-9]{64}) end=([a-f0-9]{64})\]\]/,
);
assert(marker, "MCP result did not contain a well-formed prune marker");
const [, archive, start, end] = marker;
assert.equal(start, expectedStart, "MCP start hash diverges from the shared canonical hash");
assert.equal(end, expectedEnd, "MCP end hash diverges from the shared canonical hash");

const hashes = wireBody.messages.map(canonicalHash);
const starts = hashes.flatMap((hash: string, index: number) => hash === start ? [index] : []);
const ends = hashes.flatMap((hash: string, index: number) => hash === end ? [index] : []);
assert.equal(starts.length, 1, "start hash is not unique on the wire");
assert.equal(ends.length, 1, "end hash is not unique on the wire");
assert(starts[0] <= ends[0], "wire boundaries are inverted");

const pruneUseId = "toolu_cb_stage_b_prune";
const pruneMessages = [
  ...wireBody.messages,
  {
    role: "assistant",
    content: [{
      type: "tool_use",
      id: pruneUseId,
      name: "mcp__context-bonsai__context-bonsai-prune",
      input: {},
    }],
  },
  {
    role: "user",
    content: [{ type: "tool_result", tool_use_id: pruneUseId, content: resultText }],
  },
];
const pruned = applyFilter(pruneMessages);
const pruneReport = pruned.report.find((entry: any) => entry.archive === archive);
assert.equal(pruneReport?.status, "enforced", JSON.stringify(pruned.report));
assert.deepEqual(pruneReport.range, [starts[0], ends[0]]);
assert.equal(pruned.droppedCount, ends[0] - starts[0] + 1);

const retrieveUseId = "toolu_cb_stage_b_retrieve";
const withRetrieve = [
  ...pruneMessages,
  {
    role: "assistant",
    content: [{
      type: "tool_use",
      id: retrieveUseId,
      name: "mcp__context-bonsai__context-bonsai-retrieve",
      input: { anchor_id: archive },
    }],
  },
  {
    role: "user",
    content: [{
      type: "tool_result",
      tool_use_id: retrieveUseId,
      content: `[[CB-RETRIEVE v1 archive=${archive}]]`,
    }],
  },
];
const restored = applyFilter(withRetrieve);
assert.equal(restored.droppedCount, 0);
assert.deepEqual(restored.filtered.slice(0, wireBody.messages.length), wireBody.messages);

const evidence = {
  session_copy: sessionPath,
  wire_body: wirePath,
  archive,
  from_uuid: from.uuid,
  to_uuid: to.uuid,
  start_hash: start,
  end_hash: end,
  wire_range: [starts[0], ends[0]],
  dropped_messages: pruned.droppedCount,
  original_wire_messages: wireBody.messages.length,
  filtered_wire_messages: pruned.filtered.length,
  marker: marker[0],
  prune_enforced: true,
  retrieve_byte_exact: true,
};
writeFileSync(evidencePath, JSON.stringify(evidence, null, 2) + "\n");
console.log(JSON.stringify(evidence));
