#!/usr/bin/env bun
// Main CLI entry point: reads test result files, aggregates, and prints a markdown summary.
// Usage: bun run aggregate.ts [file1 file2 ...]
//   If no files are given, defaults to all files in ./fixtures/

import { readFileSync, readdirSync, existsSync, writeFileSync } from "fs";
import { join, extname, basename } from "path";
import {
  parseJUnitXml,
  parseJsonResults,
  aggregateResults,
  identifyFlakyTests,
  generateMarkdownSummary,
} from "./src/aggregator";
import type { TestRunResult } from "./src/aggregator";

function loadFile(filePath: string): TestRunResult {
  const content = readFileSync(filePath, "utf-8");
  const ext = extname(filePath).toLowerCase();
  const name = basename(filePath);
  if (ext === ".xml") {
    return parseJUnitXml(content, name);
  } else if (ext === ".json") {
    return parseJsonResults(content, name);
  } else {
    throw new Error(`Unsupported file extension "${ext}" for file: ${filePath}`);
  }
}

function main(): void {
  let filePaths: string[] = process.argv.slice(2);

  if (filePaths.length === 0) {
    const fixturesDir = join(import.meta.dir, "fixtures");
    if (!existsSync(fixturesDir)) {
      console.error("No files provided and ./fixtures/ directory not found.");
      process.exit(1);
    }
    filePaths = readdirSync(fixturesDir)
      .filter((f) => f.endsWith(".xml") || f.endsWith(".json"))
      .map((f) => join(fixturesDir, f));
  }

  if (filePaths.length === 0) {
    console.error("No test result files found to process.");
    process.exit(1);
  }

  const runs: TestRunResult[] = [];
  for (const fp of filePaths) {
    try {
      runs.push(loadFile(fp));
    } catch (e) {
      console.error(`Error parsing "${fp}": ${(e as Error).message}`);
      process.exit(1);
    }
  }

  const agg = aggregateResults(runs);
  const flaky = identifyFlakyTests(agg);
  const md = generateMarkdownSummary(agg, flaky);

  console.log(md);

  // Write to GITHUB_STEP_SUMMARY if available (GitHub Actions integration)
  const summaryPath = process.env["GITHUB_STEP_SUMMARY"];
  if (summaryPath) {
    writeFileSync(summaryPath, md, "utf-8");
  }
}

main();
