#!/usr/bin/env bun
// CLI: reads rules JSON and a changed-files list, prints the assigned labels.
// Usage: bun run src/cli.ts --rules rules.json --files files.txt
// Or:    bun run src/cli.ts --rules rules.json --files-json '["a.ts","b.md"]'

import { assignLabels, type LabelRule } from "./labeler.ts";

interface Args {
  rules?: string;
  files?: string;
  filesJson?: string;
}

function parseArgs(argv: string[]): Args {
  const out: Args = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--rules") out.rules = argv[++i];
    else if (a === "--files") out.files = argv[++i];
    else if (a === "--files-json") out.filesJson = argv[++i];
  }
  return out;
}

async function main(): Promise<void> {
  const args = parseArgs(Bun.argv.slice(2));
  if (!args.rules) {
    console.error("Error: --rules <path> is required");
    process.exit(2);
  }
  const rulesText = await Bun.file(args.rules).text();
  const rules = JSON.parse(rulesText) as LabelRule[];

  let files: string[];
  if (args.filesJson) {
    files = JSON.parse(args.filesJson);
  } else if (args.files) {
    const text = await Bun.file(args.files).text();
    files = text.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  } else {
    console.error("Error: provide --files <path> or --files-json <json>");
    process.exit(2);
    return;
  }

  const labels = assignLabels(files, rules);
  console.log("LABELS=" + JSON.stringify(labels));
}

main().catch((err) => {
  console.error("Error:", err instanceof Error ? err.message : String(err));
  process.exit(1);
});
