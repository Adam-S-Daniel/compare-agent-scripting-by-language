#!/usr/bin/env bun
// Test Results Aggregator
//
// Usage:
//   bun run index.ts [file1] [file2] ...
//   bun run index.ts --dir <directory>
//
// Parses JUnit XML (.xml) and JSON (.json) test result files,
// aggregates them across a matrix build, detects flaky tests,
// and outputs a markdown summary to stdout (or GITHUB_STEP_SUMMARY).

import { readFileSync, readdirSync, existsSync } from "fs";
import { join, extname, basename } from "path";
import { parseJUnitXml } from "./src/parsers/junit";
import { parseJsonResult } from "./src/parsers/json";
import { aggregateResults } from "./src/aggregator";
import { detectFlakyTests } from "./src/flaky";
import { generateMarkdownReport } from "./src/reporter";
import type { TestSuite, JsonTestResult } from "./src/types";

/** Parse command-line arguments to get list of files to process */
function getInputFiles(): string[] {
  const args = process.argv.slice(2);

  // --dir mode: scan a directory for test result files
  const dirIndex = args.indexOf("--dir");
  if (dirIndex !== -1) {
    const dir = args[dirIndex + 1];
    if (!dir) {
      console.error("Error: --dir requires a directory path");
      process.exit(1);
    }
    if (!existsSync(dir)) {
      console.error(`Error: directory not found: ${dir}`);
      process.exit(1);
    }
    return readdirSync(dir)
      .filter((f) => f.endsWith(".xml") || f.endsWith(".json"))
      .map((f) => join(dir, f));
  }

  // Explicit file list mode
  if (args.length > 0) {
    return args;
  }

  // Default: look in current directory
  try {
    return readdirSync(".")
      .filter((f) => f.endsWith(".xml") || f.endsWith(".json"))
      .map((f) => join(".", f));
  } catch {
    return [];
  }
}

/** Derive a matrix key from a filename (e.g., "junit-ubuntu-latest.xml" → "ubuntu-latest") */
function deriveMatrixKey(filePath: string): string {
  const name = basename(filePath).replace(/\.(xml|json)$/, "");
  // Strip common prefixes like "junit-", "results-", "test-"
  return name.replace(/^(junit|results|test|report)-?/i, "") || name;
}

/** Parse a single test result file and return suites */
function parseFile(filePath: string): TestSuite[] {
  if (!existsSync(filePath)) {
    console.error(`Warning: file not found: ${filePath}`);
    return [];
  }

  const content = readFileSync(filePath, "utf-8").trim();
  const ext = extname(filePath).toLowerCase();
  const matrixKey = deriveMatrixKey(filePath);

  try {
    if (ext === ".xml") {
      return parseJUnitXml(content, matrixKey);
    } else if (ext === ".json") {
      const jsonData: JsonTestResult = JSON.parse(content);
      // Use the matrixKey from JSON data if provided, otherwise derive from filename
      if (!jsonData.matrixKey) {
        jsonData.matrixKey = matrixKey;
      }
      return [parseJsonResult(jsonData)];
    } else {
      console.error(`Warning: unsupported file type: ${filePath}`);
      return [];
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Error parsing ${filePath}: ${msg}`);
    return [];
  }
}

/** Main entry point */
async function main(): Promise<void> {
  const files = getInputFiles();

  if (files.length === 0) {
    console.error("No test result files found. Pass file paths as arguments or use --dir <directory>.");
    process.exit(1);
  }

  console.error(`Processing ${files.length} file(s)...`);

  // Parse all files and collect suites
  const allSuites: TestSuite[] = [];
  for (const file of files) {
    console.error(`  Parsing: ${file}`);
    const suites = parseFile(file);
    allSuites.push(...suites);
  }

  if (allSuites.length === 0) {
    console.error("No test suites found in any input files.");
    process.exit(1);
  }

  // Aggregate results
  const aggregated = aggregateResults(allSuites);

  // Detect flaky tests
  const flakyTests = detectFlakyTests(allSuites);

  // Generate markdown report
  const report = generateMarkdownReport({ aggregated, flakyTests });

  // Always print the summary line for machine parsing
  console.log(`SUMMARY: passed=${aggregated.totalPassed} failed=${aggregated.totalFailed} skipped=${aggregated.totalSkipped} duration=${aggregated.totalDuration.toFixed(2)} flaky=${flakyTests.length} suites=${allSuites.length}`);

  // Write the full markdown report
  console.log("\n" + report);

  // If running in GitHub Actions, also write to GITHUB_STEP_SUMMARY
  const stepSummary = process.env.GITHUB_STEP_SUMMARY;
  if (stepSummary) {
    await Bun.write(stepSummary, report);
    console.error(`Markdown summary written to ${stepSummary}`);
  }

  // Exit with non-zero code if there are hard failures
  // (flaky tests that passed elsewhere are not hard failures)
  const flakyFailedTests = new Set(
    flakyTests.map((f) => `${f.className}::${f.name}`)
  );
  let hardFailureCount = 0;
  for (const suite of allSuites) {
    for (const tc of suite.testCases) {
      if (tc.status === "failed" && !flakyFailedTests.has(`${tc.className}::${tc.name}`)) {
        hardFailureCount++;
      }
    }
  }

  if (hardFailureCount > 0) {
    console.error(`\n${hardFailureCount} hard failure(s) detected (non-flaky). Exiting with code 1.`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
