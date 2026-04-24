#!/usr/bin/env bun
// CLI entry point: recurse an input directory, parse every .xml / .json file,
// aggregate, and write a markdown summary. Designed for use in GitHub Actions,
// where it will also append to $GITHUB_STEP_SUMMARY when that env var is set.
import { readdirSync, readFileSync, writeFileSync, statSync, existsSync, appendFileSync } from "node:fs";
import { join, extname } from "node:path";
import { parseJUnitXml } from "./junit-parser";
import { parseJsonReport } from "./json-parser";
import { aggregate } from "./aggregator";
import { renderMarkdown } from "./renderer";
import type { ParsedReport } from "./types";

interface Args {
  input: string;
  output: string;
  failOnFailures: boolean;
}

function parseArgs(argv: string[]): Args {
  const out: Args = { input: "", output: "", failOnFailures: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--input" || a === "-i") out.input = argv[++i] ?? "";
    else if (a === "--output" || a === "-o") out.output = argv[++i] ?? "";
    else if (a === "--fail-on-failures") out.failOnFailures = true;
    else if (a === "--help" || a === "-h") {
      console.log(
        "Usage: bun run src/cli.ts --input <dir> --output <file> [--fail-on-failures]",
      );
      process.exit(0);
    }
  }
  if (!out.input || !out.output) {
    throw new Error("Usage: --input <dir> --output <file>");
  }
  return out;
}

// Recursively collect every .xml and .json file under `dir`.
function collectFiles(dir: string): string[] {
  if (!existsSync(dir)) {
    throw new Error(`Input directory not found: ${dir}`);
  }
  if (!statSync(dir).isDirectory()) {
    throw new Error(`Input is not a directory: ${dir}`);
  }
  const found: string[] = [];
  const walk = (d: string): void => {
    for (const entry of readdirSync(d, { withFileTypes: true })) {
      const full = join(d, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile()) {
        const ext = extname(entry.name).toLowerCase();
        if (ext === ".xml" || ext === ".json") found.push(full);
      }
    }
  };
  walk(dir);
  found.sort();
  return found;
}

function parseFile(path: string): ParsedReport {
  const raw = readFileSync(path, "utf8");
  const ext = extname(path).toLowerCase();
  try {
    const report = ext === ".xml" ? parseJUnitXml(raw) : parseJsonReport(raw);
    report.source = path;
    return report;
  } catch (e) {
    throw new Error(`Failed to parse ${path}: ${(e as Error).message}`);
  }
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const files = collectFiles(args.input);

  if (files.length === 0) {
    throw new Error(`No .xml or .json test result files found in ${args.input}`);
  }

  console.log(`Parsing ${files.length} test result file(s)...`);
  const reports = files.map(parseFile);
  const result = aggregate(reports);
  const markdown = renderMarkdown(result);

  writeFileSync(args.output, markdown, "utf8");
  console.log(`Wrote summary to ${args.output}`);

  // In GitHub Actions, also append to the job summary file when present.
  const stepSummary = process.env.GITHUB_STEP_SUMMARY;
  if (stepSummary) {
    appendFileSync(stepSummary, markdown + "\n", "utf8");
    console.log(`Appended summary to $GITHUB_STEP_SUMMARY`);
  }

  // Print a one-line status for CI logs.
  const { totals, flaky } = result;
  console.log(
    `Totals: total=${totals.total} passed=${totals.passed} failed=${totals.failed} skipped=${totals.skipped} flaky=${flaky.length}`,
  );

  if (args.failOnFailures && totals.failed > 0) {
    console.error(`Failing: ${totals.failed} test(s) failed`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(`Error: ${(err as Error).message}`);
  process.exit(2);
});
