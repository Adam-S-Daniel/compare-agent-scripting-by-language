// Aggregator: reads test result files and computes summary statistics
import { existsSync, readFileSync } from "fs";
import { basename, extname } from "path";
import { parseJUnit } from "./parsers/junit";
import { parseJSON } from "./parsers/json-parser";
import type {
  ParsedResult,
  AggregatedResults,
  FlakyTest,
  FailedTestDetail,
} from "./types";

export function parseFile(filePath: string): ParsedResult {
  if (!existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }

  const content = readFileSync(filePath, "utf-8");
  const ext = extname(filePath).toLowerCase();
  const runId = basename(filePath, ext);

  if (ext === ".xml") {
    return parseJUnit(content, runId);
  } else if (ext === ".json") {
    return parseJSON(content, runId);
  } else {
    throw new Error(`Unsupported file format: ${ext}. Expected .xml or .json`);
  }
}

export function aggregateResults(files: string[]): AggregatedResults {
  if (files.length === 0) {
    throw new Error("No files provided for aggregation");
  }
  const results: ParsedResult[] = files.map(parseFile);
  return computeAggregation(results);
}

// Pure aggregation logic - separated for testability
export function computeAggregation(results: ParsedResult[]): AggregatedResults {
  // Track per-test outcomes by (suiteName::testName) key across all runs
  const testOutcomes = new Map<string, { passed: number; failed: number }>();
  const failedTests: FailedTestDetail[] = [];

  let totalTests = 0;
  let passed = 0;
  let failed = 0;
  let skipped = 0;
  let duration = 0;

  for (const result of results) {
    for (const suite of result.suites) {
      duration += suite.duration;

      for (const test of suite.tests) {
        totalTests++;
        const key = `${test.suiteName}::${test.name}`;

        if (test.status === "passed") {
          passed++;
          const entry = testOutcomes.get(key) ?? { passed: 0, failed: 0 };
          entry.passed++;
          testOutcomes.set(key, entry);
        } else if (test.status === "failed") {
          failed++;
          const entry = testOutcomes.get(key) ?? { passed: 0, failed: 0 };
          entry.failed++;
          testOutcomes.set(key, entry);
          failedTests.push({
            name: test.name,
            suiteName: test.suiteName,
            runId: result.runId,
            error: test.error,
          });
        } else {
          // skipped tests don't count toward pass/fail tracking
          skipped++;
        }
      }
    }
  }

  // Flaky = appeared as both passed and failed across different runs
  const flakyTests: FlakyTest[] = [];
  for (const [key, outcomes] of testOutcomes) {
    if (outcomes.passed > 0 && outcomes.failed > 0) {
      const sepIdx = key.indexOf("::");
      const suiteName = key.slice(0, sepIdx);
      const name = key.slice(sepIdx + 2);
      flakyTests.push({
        name,
        suiteName,
        passedRuns: outcomes.passed,
        failedRuns: outcomes.failed,
      });
    }
  }

  return {
    totalTests,
    passed,
    failed,
    skipped,
    duration,
    flakyTests,
    failedTests,
    fileCount: results.length,
  };
}
