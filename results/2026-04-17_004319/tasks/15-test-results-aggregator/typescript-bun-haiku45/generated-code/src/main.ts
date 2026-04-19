// Main entry point for test results aggregator
import { parseJunitXml, parseJsonResults } from "./parser";
import {
  aggregateResults,
  identifyFlakyTests,
  type ParsedResult,
  type TestResult,
} from "./aggregator";
import { generateMarkdownSummary } from "./markdown";
import { readFileSync, writeFileSync, readdirSync } from "fs";
import { extname, join } from "path";

export function findTestFiles(
  directory: string,
  extensions: string[] = [".xml", ".json"]
): string[] {
  const files: string[] = [];

  try {
    const entries = readdirSync(directory, { recursive: true });

    for (const entry of entries) {
      const fullPath = typeof entry === "string" ? entry : entry.toString();

      if (
        extensions.some((ext) => fullPath.endsWith(ext)) &&
        !fullPath.includes("node_modules")
      ) {
        files.push(join(directory, fullPath));
      }
    }
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      // Directory doesn't exist, that's okay
      return files;
    }
    throw error;
  }

  return files;
}

export function processTestFiles(
  fileOrDir: string
): {
  markdown: string;
  aggregated: any;
  flaky: any[];
} {
  let files: string[] = [];

  // Check if it's a file or directory
  try {
    const stat = require("fs").statSync(fileOrDir);
    if (stat.isDirectory()) {
      files = findTestFiles(fileOrDir);
    } else {
      files = [fileOrDir];
    }
  } catch {
    // Treat as file path
    files = [fileOrDir];
  }

  files = files.filter((f) => {
    try {
      require("fs").statSync(f);
      return true;
    } catch {
      return false;
    }
  });

  if (files.length === 0) {
    throw new Error(`No test files found in: ${fileOrDir}`);
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
        // Skip unknown file types
        continue;
      }

      results.push({
        source: file,
        ...parsed,
      });
    } catch (error) {
      console.error(
        `Error processing file ${file}:`,
        error instanceof Error ? error.message : error
      );
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
    console.error("Usage: bun run src/main.ts <test-dir> [output-file]");
    console.error(
      "Example: bun run src/main.ts ./test-results summary.md"
    );
    process.exit(1);
  }

  const testDir = args[0];
  const outputFile = args[1];

  try {
    const { markdown, aggregated, flaky } = processTestFiles(testDir);

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
