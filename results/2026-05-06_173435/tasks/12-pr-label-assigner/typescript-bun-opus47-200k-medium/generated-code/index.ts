// CLI entrypoint: reads files and rules from JSON inputs, prints labels.
//
// Usage:
//   bun run index.ts --files <files.json|->
//                    --rules <rules.json>
//                    [--format json|lines]
//
// --files can be "-" to read from stdin. The files JSON should be an array
// of strings; the rules JSON should be an array of LabelRule objects.

import { assignLabels, type LabelRule } from "./labeler";

interface CliArgs {
  files: string;
  rules: string;
  format: "json" | "lines";
}

function parseArgs(argv: string[]): CliArgs {
  const args: Partial<CliArgs> = { format: "lines" };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--files") args.files = argv[++i];
    else if (a === "--rules") args.rules = argv[++i];
    else if (a === "--format") {
      const v = argv[++i];
      if (v !== "json" && v !== "lines") {
        throw new Error(`--format must be "json" or "lines" (got "${v}")`);
      }
      args.format = v;
    } else {
      throw new Error(`Unknown argument: ${a}`);
    }
  }
  if (!args.files) throw new Error("Missing required --files argument");
  if (!args.rules) throw new Error("Missing required --rules argument");
  return args as CliArgs;
}

async function readJson<T>(source: string): Promise<T> {
  const text =
    source === "-"
      ? await new Response(Bun.stdin.stream()).text()
      : await Bun.file(source).text();
  try {
    return JSON.parse(text) as T;
  } catch (e) {
    throw new Error(
      `Failed to parse JSON from ${source === "-" ? "stdin" : source}: ${(e as Error).message}`,
    );
  }
}

async function main(): Promise<void> {
  const args = parseArgs(Bun.argv.slice(2));
  const files = await readJson<string[]>(args.files);
  const rules = await readJson<LabelRule[]>(args.rules);

  if (!Array.isArray(files)) throw new Error("Files input must be a JSON array of strings");
  if (!Array.isArray(rules)) throw new Error("Rules input must be a JSON array of objects");

  const labels = assignLabels(files, rules);
  if (args.format === "json") {
    console.log(JSON.stringify({ labels }));
  } else {
    console.log("Labels:");
    for (const label of labels) console.log(`- ${label}`);
    console.log(`Total: ${labels.length}`);
  }
}

main().catch((err: Error) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
