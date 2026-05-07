// Entry point: parse test result files from CLI args and output a markdown summary

import { readFileSync, appendFileSync } from "fs";
import { extname, basename } from "path";
import { parseJUnitXml, parseJsonResults } from "./src/parsers";
import { aggregateRuns } from "./src/aggregator";
import { generateMarkdownSummary } from "./src/markdown";
import type { ParsedRun } from "./src/types";

function parseFile(filePath: string): ParsedRun {
  const ext = extname(filePath).toLowerCase();
  const runId = basename(filePath, ext);
  let content: string;

  try {
    content = readFileSync(filePath, "utf-8");
  } catch (err) {
    throw new Error(`Cannot read file "${filePath}": ${String(err)}`);
  }

  if (ext === ".xml") {
    return parseJUnitXml(content, runId);
  } else if (ext === ".json") {
    return parseJsonResults(content, runId);
  } else {
    throw new Error(`Unsupported file format "${ext}" for "${filePath}". Expected .xml or .json`);
  }
}

function main(): void {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error("Usage: bun run main.ts <file1.xml> [file2.xml] [file3.json] ...");
    console.error("  Supported formats: JUnit XML (.xml), JSON (.json)");
    process.exit(1);
  }

  const runs: ParsedRun[] = [];
  for (const filePath of args) {
    try {
      const run = parseFile(filePath);
      runs.push(run);
    } catch (err) {
      console.error(`Error parsing "${filePath}": ${String(err)}`);
      process.exit(1);
    }
  }

  const results = aggregateRuns(runs);
  const summary = generateMarkdownSummary(results);

  // Append to GITHUB_STEP_SUMMARY if running inside GitHub Actions
  const stepSummaryPath = process.env.GITHUB_STEP_SUMMARY;
  if (stepSummaryPath) {
    try {
      appendFileSync(stepSummaryPath, summary);
    } catch (_err) {
      // Non-fatal: continue to stdout
    }
  }

  // Always print to stdout so it's visible in workflow logs
  console.log(summary);
}

main();
