/**
 * CLI entry point for the PR label assigner.
 *
 * Usage:
 *   bun run src/cli.ts --rules <rules.json> --files <files.txt>
 *   bun run src/cli.ts --rules <rules.json>     # files from stdin
 *
 * Where:
 *   - <rules.json> is a JSON array of LabelRule objects
 *   - <files.txt>  is a newline-delimited list of changed file paths
 *
 * Output: prints one label per line to stdout. Exits 0 on success, 1 on error.
 *
 * The CLI is a thin shell over `assignLabels` so the core logic stays a pure
 * function (and stays unit-testable without process plumbing).
 */
import { assignLabels, type LabelRule } from "./labeler.ts";

interface CliArgs {
  rulesPath: string;
  filesPath?: string;
}

function parseArgs(argv: string[]): CliArgs {
  let rulesPath: string | undefined;
  let filesPath: string | undefined;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--rules") rulesPath = argv[++i];
    else if (a === "--files") filesPath = argv[++i];
    else if (a === "--help" || a === "-h") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${a}`);
    }
  }
  if (!rulesPath) throw new Error("--rules <rules.json> is required");
  return { rulesPath, filesPath };
}

function printHelp(): void {
  console.log(
    "Usage: bun run src/cli.ts --rules <rules.json> [--files <files.txt>]\n" +
      "  If --files is omitted, file paths are read from stdin (one per line).",
  );
}

async function readFiles(path: string | undefined): Promise<string[]> {
  const raw = path
    ? await Bun.file(path).text()
    : await new Response(Bun.stdin.stream()).text();
  return raw
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const rulesText = await Bun.file(args.rulesPath).text();
  let rules: LabelRule[];
  try {
    rules = JSON.parse(rulesText) as LabelRule[];
  } catch (e) {
    throw new Error(
      `Could not parse rules JSON at ${args.rulesPath}: ${(e as Error).message}`,
    );
  }
  if (!Array.isArray(rules)) {
    throw new Error(`Rules file must contain a JSON array; got ${typeof rules}`);
  }

  const files = await readFiles(args.filesPath);
  const labels = assignLabels(files, rules);
  // One label per line — easy to consume from shell pipelines / `act` output.
  for (const label of labels) console.log(label);
}

main().catch((err) => {
  console.error(`error: ${(err as Error).message}`);
  process.exit(1);
});
