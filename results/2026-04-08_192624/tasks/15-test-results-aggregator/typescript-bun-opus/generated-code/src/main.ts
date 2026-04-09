// Main entry point: reads test result files from a directory, aggregates, and outputs markdown summary

import { readdirSync, existsSync, writeFileSync, appendFileSync } from "fs";
import { join } from "path";
import { parseFile } from "./parser";
import { aggregateResults } from "./aggregator";
import { formatMarkdownSummary } from "./formatter";
import type { TestResult } from "./types";

// Read the fixtures directory from CLI arg or default to ./fixtures
const fixturesDir = process.argv[2] || "./fixtures";

if (!existsSync(fixturesDir)) {
  console.error(`ERROR: Fixtures directory not found: ${fixturesDir}`);
  process.exit(1);
}

// Find all supported test result files
const files = readdirSync(fixturesDir)
  .filter((f) => f.endsWith(".xml") || f.endsWith(".json"))
  .sort();

if (files.length === 0) {
  console.error(`ERROR: No .xml or .json test result files found in ${fixturesDir}`);
  process.exit(1);
}

console.log(`Processing ${files.length} test result file(s) from ${fixturesDir}`);

// Parse each file into a separate run (simulates matrix build)
const runs: TestResult[][] = [];
for (const file of files) {
  const filePath = join(fixturesDir, file);
  try {
    const results = parseFile(filePath);
    runs.push(results);
    console.log(`  Parsed ${file}: ${results.length} test(s)`);
  } catch (err) {
    console.error(`  ERROR parsing ${file}: ${(err as Error).message}`);
  }
}

// Aggregate all runs
const summary = aggregateResults(runs);

// Output structured key=value data for machine parsing
console.log("");
console.log("=== AGGREGATOR RESULTS ===");
console.log(`TOTAL_TESTS=${summary.totalTests}`);
console.log(`TOTAL_PASSED=${summary.totalPassed}`);
console.log(`TOTAL_FAILED=${summary.totalFailed}`);
console.log(`TOTAL_SKIPPED=${summary.totalSkipped}`);
console.log(`TOTAL_DURATION=${summary.totalDuration.toFixed(2)}`);
if (summary.flakyTests.length > 0) {
  const flakyNames = summary.flakyTests.map((f) => `${f.suite}::${f.name}`).join(",");
  console.log(`FLAKY_TESTS=${flakyNames}`);
} else {
  console.log("FLAKY_TESTS=none");
}
console.log("=== END RESULTS ===");

// Generate markdown summary
const markdown = formatMarkdownSummary(summary);

console.log("");
console.log("=== MARKDOWN SUMMARY ===");
console.log(markdown);
console.log("=== END MARKDOWN ===");

// Write to GITHUB_STEP_SUMMARY if available
const summaryFile = process.env.GITHUB_STEP_SUMMARY;
if (summaryFile) {
  try {
    appendFileSync(summaryFile, markdown + "\n");
    console.log(`\nMarkdown summary written to $GITHUB_STEP_SUMMARY`);
  } catch {
    console.log("Warning: Could not write to $GITHUB_STEP_SUMMARY");
  }
}
