// Command-line interface for test results aggregation
import { parseJunitXml, parseJsonResults } from "./parser";
import {
  aggregateResults,
  identifyFlakyTests,
  type ParsedResult,
  type TestResult,
} from "./aggregator";
import { generateMarkdownSummary } from "./markdown";
import { readFileSync, writeFileSync } from "fs";
import { resolve } from "path";

export function processTestFiles(filePattern: string): {
  markdown: string;
  aggregated: any;
  flaky: any[];
} {
  // Get all matching files
  const glob = require("glob");
  const files = glob.sync(filePattern);

  if (files.length === 0) {
    throw new Error(`No test files found matching pattern: ${filePattern}`);
  }

  const results: ParsedResult[] = [];
  const allTestResults: TestResult[] = [];

  for (const file of files) {
    try {
      const content = readFileSync(file, "utf-8");
      let parsed;

      if (file.endsWith(".xml")) {
        parsed = parseJunitXml(content);
      } else if (file.endsWith(".json")) {
        const jsonData = JSON.parse(content);
        parsed = parseJsonResults(content);

        // Extract individual test results for flaky detection
        if (jsonData.tests && Array.isArray(jsonData.tests)) {
          for (const test of jsonData.tests) {
            allTestResults.push({
              source: file,
              testName: test.name || "unknown",
              status: test.status || "unknown",
            });
          }
        }
      } else {
        console.warn(`Skipping file with unknown format: ${file}`);
        continue;
      }

      results.push({
        source: file,
        ...parsed,
      });
    } catch (error) {
      console.error(`Error processing file ${file}:`, error);
      throw error;
    }
  }

  if (results.length === 0) {
    throw new Error("No valid test results were parsed");
  }

  const aggregated = aggregateResults(results);
  const flaky =
    allTestResults.length > 0 ? identifyFlakyTests(allTestResults) : [];

  const markdown = generateMarkdownSummary(aggregated, flaky);

  return { markdown, aggregated, flaky };
}

// Main CLI entry point
export async function main() {
  const args = Bun.argv.slice(2);

  if (args.length === 0) {
    console.error("Usage: aggregator.ts <file-pattern> [output-file]");
    console.error(
      "Example: aggregator.ts './results/**/*.xml' summary.md"
    );
    process.exit(1);
  }

  const filePattern = args[0];
  const outputFile = args[1];

  try {
    const { markdown, aggregated, flaky } = processTestFiles(filePattern);

    console.log(markdown);

    // Also write to GITHUB_STEP_SUMMARY if in CI
    const summaryFile = process.env.GITHUB_STEP_SUMMARY;
    if (summaryFile) {
      writeFileSync(summaryFile, markdown);
      console.log(`\n✅ Summary written to ${summaryFile}`);
    }

    // Write to output file if specified
    if (outputFile) {
      writeFileSync(outputFile, markdown);
      console.log(`✅ Summary written to ${outputFile}`);
    }

    // Exit with error code if there are failures
    if (aggregated.totalFailed > 0) {
      process.exit(1);
    }
  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

if (import.meta.main) {
  main();
}
