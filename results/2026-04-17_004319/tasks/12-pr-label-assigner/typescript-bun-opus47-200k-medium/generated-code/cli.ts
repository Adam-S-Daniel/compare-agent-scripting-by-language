// CLI entrypoint for the PR label assigner.
//
// Usage:
//   bun run cli.ts --rules rules.json --files files.json
//   bun run cli.ts --rules rules.json --files-stdin    (newline-separated paths)
//
// Emits a JSON object { "labels": [...] } on stdout and also a human-readable
// "LABELS: a,b,c" line on stderr for easy grepping in CI logs.

import { assignLabels, type LabelRule } from "./labeler";

interface Args {
  rules?: string;
  files?: string;
  filesStdin: boolean;
}

function parseArgs(argv: string[]): Args {
  const args: Args = { filesStdin: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--rules") args.rules = argv[++i];
    else if (a === "--files") args.files = argv[++i];
    else if (a === "--files-stdin") args.filesStdin = true;
    else if (a === "--help" || a === "-h") {
      console.log("Usage: bun run cli.ts --rules rules.json (--files files.json | --files-stdin)");
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${a}`);
    }
  }
  return args;
}

async function readStdin(): Promise<string> {
  const chunks: Uint8Array[] = [];
  for await (const chunk of Bun.stdin.stream()) chunks.push(chunk);
  return new TextDecoder().decode(Buffer.concat(chunks));
}

async function main(): Promise<void> {
  const args = parseArgs(Bun.argv.slice(2));
  if (!args.rules) throw new Error("--rules is required");

  const rules = JSON.parse(await Bun.file(args.rules).text()) as LabelRule[];
  if (!Array.isArray(rules)) throw new Error("rules file must be a JSON array");

  let files: string[];
  if (args.filesStdin) {
    const text = await readStdin();
    files = text.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  } else if (args.files) {
    const parsed = JSON.parse(await Bun.file(args.files).text());
    if (!Array.isArray(parsed)) throw new Error("files file must be a JSON array");
    files = parsed as string[];
  } else {
    throw new Error("Either --files or --files-stdin must be provided");
  }

  const labels = assignLabels(files, rules);
  console.log(JSON.stringify({ labels }));
  console.error(`LABELS: ${labels.join(",")}`);
}

main().catch((err) => {
  console.error(`ERROR: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});
