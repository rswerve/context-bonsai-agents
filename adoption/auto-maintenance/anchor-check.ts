// Read-only diagnostic: reports which Context Bonsai patch anchors match a given Claude bundle.
// Never writes. Usage: bun run anchor-check.ts <bundle-path>
//   exit 0 = all registered patches match; 1 = one or more drifted; 2 = could not extract JS.
import { tweakccApi } from "../../tweakcc_context_bonsai/apply/tweakcc-api.ts";
import { bonsaiPatches } from "../../tweakcc_context_bonsai/patches/registry.ts";

const target = process.argv[2];
if (!target) { console.log("usage: bun run anchor-check.ts <bundle-path>"); process.exit(2); }

let content: string;
try {
  content = await tweakccApi.readContent({ path: target, kind: "native", version: "unknown" } as any);
} catch (e: any) {
  console.log("EXTRACT-FAIL:", e?.message ?? String(e));
  process.exit(2);
}

let allOk = true;
let candidate = content;
for (const p of bonsaiPatches) {
  try {
    candidate = p.apply(candidate, {
      installation: { path: target, kind: "native", version: "unknown" } as any,
      originalContent: content,
      patchIndex: bonsaiPatches.indexOf(p),
    });
    console.log("OK  ", p.name);
  }
  catch (e: any) { allOk = false; console.log("DRIFT", p.name, "|", e?.message ?? String(e)); }
}
process.exit(allOk ? 0 : 1);
