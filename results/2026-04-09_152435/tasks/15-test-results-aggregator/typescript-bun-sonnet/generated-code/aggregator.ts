#!/usr/bin/env bun
// Main CLI entry point for the test results aggregator.
// Usage: bun run aggregator.ts <directory>
//
// Discovers all .xml and .json test result files under <directory>,
// parses them, aggregates totals, detects flaky tests, and prints
// a Markdown summary to stdout (suitable for $GITHUB_STEP_SUMMARY).

import { parseFile } from "./src/parser";
import { aggregate } from "./src/aggregator";
import { generateMarkdownSummary } from "./src/formatter";
import * as fs from "fs";
import * as path from "path";

function main(): void {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error("Usage: bun run aggregator.ts <directory>");
    console.error("Example: bun run aggregator.ts fixtures/");
    process.exit(1);
  }

  const dir = args[0];

  if (!fs.existsSync(dir)) {
    console.error(`Error: Directory not found: ${dir}`);
    process.exit(1);
  }

  // Recursively discover all test result files
  const files = findTestFiles(dir);

  if (files.length === 0) {
    console.error(`Error: No .xml or .json test result files found in: ${dir}`);
    process.exit(1);
  }

  console.log(`Found ${files.length} test result file(s):`);

  // Parse each file, collecting all suites
  const allSuites = [];
  for (const file of files) {
    try {
      const content = fs.readFileSync(file, "utf8");
      const suites = parseFile(content, file);
      allSuites.push(...suites);
      console.log(`  Parsed: ${file} (${suites.length} suite(s))`);
    } catch (err) {
      console.error(
        `  Error parsing ${file}: ${err instanceof Error ? err.message : String(err)}`
      );
    }
  }

  // Aggregate across all suites
  const results = aggregate(allSuites);

  // Print Markdown summary to stdout
  const summary = generateMarkdownSummary(results);
  console.log("");
  console.log(summary);
}

/** Recursively find all .xml and .json files under a directory, sorted. */
function findTestFiles(dir: string): string[] {
  const files: string[] = [];

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...findTestFiles(fullPath));
    } else if (entry.name.endsWith(".xml") || entry.name.endsWith(".json")) {
      files.push(fullPath);
    }
  }

  return files.sort();
}

main();
