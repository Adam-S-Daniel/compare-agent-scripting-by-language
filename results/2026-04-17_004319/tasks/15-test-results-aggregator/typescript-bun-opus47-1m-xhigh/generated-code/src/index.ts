#!/usr/bin/env bun
// CLI entry point: `bun run src/index.ts <file...> [--exit-on-failure]`
//
// When run inside a GitHub Actions job, $GITHUB_STEP_SUMMARY points to a
// file that GitHub turns into a nicely-rendered job summary. We always
// print the markdown to stdout so the workflow logs show it, and
// additionally append to $GITHUB_STEP_SUMMARY when set.

import { aggregate } from "./aggregator.ts";
import { parseFile } from "./parser.ts";
import { renderMarkdown } from "./summary.ts";
import { appendFile, writeFile } from "node:fs/promises";
import type { RunReport } from "./types.ts";

interface CliOptions {
  files: string[];
  exitOnFailure: boolean;
  output?: string;
}

function parseArgs(argv: string[]): CliOptions {
  const files: string[] = [];
  let exitOnFailure = false;
  let output: string | undefined;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--exit-on-failure") {
      exitOnFailure = true;
    } else if (a === "--output" || a === "-o") {
      output = argv[++i];
      if (!output) throw new Error("--output requires a path argument");
    } else if (a === "--help" || a === "-h") {
      printUsage(process.stdout);
      process.exit(0);
    } else if (a.startsWith("--")) {
      throw new Error(`Unknown option: ${a}`);
    } else {
      files.push(a);
    }
  }
  return { files, exitOnFailure, output };
}

function printUsage(stream: NodeJS.WriteStream): void {
  stream.write(
    [
      "Usage: bun run src/index.ts <file...> [--exit-on-failure] [--output PATH]",
      "",
      "Parses one or more JUnit XML or JSON test-result files, aggregates",
      "results, identifies flaky tests, and prints a markdown summary.",
      "",
      "If $GITHUB_STEP_SUMMARY is set, the summary is also appended there.",
      "",
      "Options:",
      "  --exit-on-failure   Exit 1 when any test failed (default: always exit 0)",
      "  --output PATH       Write markdown to PATH in addition to stdout",
      "  -h, --help          Show this help",
      "",
    ].join("\n"),
  );
}

async function main(argv: string[]): Promise<number> {
  let opts: CliOptions;
  try {
    opts = parseArgs(argv);
  } catch (e) {
    process.stderr.write(`error: ${(e as Error).message}\n`);
    printUsage(process.stderr);
    return 2;
  }

  if (opts.files.length === 0) {
    process.stderr.write("error: at least one test result file is required\n");
    printUsage(process.stderr);
    return 2;
  }

  // Parse every input file. We report individual parse errors but continue
  // so that one bad file doesn't hide a wall of good results.
  const runs: RunReport[] = [];
  let parseErrors = 0;
  for (const file of opts.files) {
    try {
      runs.push(await parseFile(file));
    } catch (e) {
      parseErrors += 1;
      process.stderr.write(`warning: failed to parse ${file}: ${(e as Error).message}\n`);
    }
  }

  const agg = aggregate(runs);
  const md = renderMarkdown(agg);

  // stdout: always.
  process.stdout.write(md + "\n");

  // $GITHUB_STEP_SUMMARY: append so consecutive steps can all contribute.
  const stepSummary = process.env.GITHUB_STEP_SUMMARY;
  if (stepSummary) {
    await appendFile(stepSummary, md + "\n", "utf8");
  }

  // --output: overwrite target path.
  if (opts.output) {
    await writeFile(opts.output, md + "\n", "utf8");
  }

  if (parseErrors > 0 && runs.length === 0) return 2;
  if (opts.exitOnFailure && agg.totals.failed > 0) return 1;
  return 0;
}

// Execute under Bun; skip when imported for tests.
if (import.meta.main) {
  const code = await main(Bun.argv.slice(2));
  process.exit(code);
}

export { main };
