// CLI entry point.
//
// Usage:
//   bun run src/main.ts <input-dir> [--out <markdown-path>]
//
// Reads every *.xml and *.json file in <input-dir>, parses each as JUnit XML
// or a JSON results document, aggregates them, prints a markdown summary to
// stdout, and (when --out is supplied) writes the same markdown to a file.
// Exits non-zero only when the script itself fails — failing tests are still
// surfaced via the FAILED status line and a non-zero --fail-on-failure flag.
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { extname, join } from "node:path";
import { aggregate } from "./aggregator.ts";
import { generateMarkdown } from "./markdown.ts";
import { parseJsonResults, parseJUnitXml } from "./parser.ts";
import type { TestRun } from "./types.ts";

interface CliArgs {
  inputDir: string;
  outPath?: string;
  failOnFailure: boolean;
}

function parseArgs(argv: string[]): CliArgs {
  // argv is process.argv after Bun has stripped runtime args, so the user-
  // supplied tokens start at index 0 here. We pop --out / --fail-on-failure
  // out, leaving the input directory as the lone positional arg.
  const args = [...argv];
  let outPath: string | undefined;
  let failOnFailure = false;
  const positionals: string[] = [];
  while (args.length > 0) {
    const token = args.shift()!;
    if (token === "--out") {
      outPath = args.shift();
      if (!outPath) throw new Error("--out requires a path argument");
    } else if (token === "--fail-on-failure") {
      failOnFailure = true;
    } else if (token.startsWith("--")) {
      throw new Error(`Unknown flag: ${token}`);
    } else {
      positionals.push(token);
    }
  }
  if (positionals.length !== 1) {
    throw new Error(
      "usage: bun run src/main.ts <input-dir> [--out <markdown-path>] [--fail-on-failure]",
    );
  }
  const result: CliArgs = { inputDir: positionals[0]!, failOnFailure };
  if (outPath !== undefined) result.outPath = outPath;
  return result;
}

function loadRuns(inputDir: string): TestRun[] {
  let entries: string[];
  try {
    entries = readdirSync(inputDir).sort();
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err);
    throw new Error(`Could not read input directory "${inputDir}": ${detail}`);
  }
  const runs: TestRun[] = [];
  for (const name of entries) {
    const ext = extname(name).toLowerCase();
    if (ext !== ".xml" && ext !== ".json") continue;
    const full = join(inputDir, name);
    const text = readFileSync(full, "utf8");
    if (ext === ".xml") {
      runs.push(parseJUnitXml(text, name));
    } else {
      runs.push(parseJsonResults(text, name));
    }
  }
  if (runs.length === 0) {
    throw new Error(
      `No .xml or .json test result files found in "${inputDir}"`,
    );
  }
  return runs;
}

export function runCli(argv: string[]): { markdown: string; exitCode: number } {
  const args = parseArgs(argv);
  const runs = loadRuns(args.inputDir);
  const agg = aggregate(runs);
  const md = generateMarkdown(agg);
  if (args.outPath) writeFileSync(args.outPath, md);
  const exitCode = args.failOnFailure && agg.totalFailed > 0 ? 1 : 0;
  return { markdown: md, exitCode };
}

// Bun executes top-level code in modules; only run when invoked directly.
if (import.meta.main) {
  try {
    const { markdown, exitCode } = runCli(Bun.argv.slice(2));
    process.stdout.write(markdown);
    if (!markdown.endsWith("\n")) process.stdout.write("\n");
    process.exit(exitCode);
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err);
    process.stderr.write(`error: ${detail}\n`);
    process.exit(2);
  }
}
