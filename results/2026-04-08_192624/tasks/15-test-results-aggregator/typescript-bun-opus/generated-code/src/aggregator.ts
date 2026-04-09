// Aggregator module: combines test results from multiple files, computes totals, detects flaky tests

import type { TestResult, AggregatedSummary, FlakyTest, SuiteSummary } from "./types";

/**
 * Aggregate results from multiple test runs.
 * Computes totals and identifies flaky tests (same test has different outcomes across runs).
 */
export function aggregateResults(runs: TestResult[][]): AggregatedSummary {
  const allResults = runs.flat();

  // Compute overall totals
  const totalTests = allResults.length;
  const totalPassed = allResults.filter((r) => r.status === "passed").length;
  const totalFailed = allResults.filter((r) => r.status === "failed").length;
  const totalSkipped = allResults.filter((r) => r.status === "skipped").length;
  const totalDuration = allResults.reduce((sum, r) => sum + r.duration, 0);

  // Build per-suite summaries
  const suiteMap = new Map<string, SuiteSummary>();
  for (const result of allResults) {
    let suite = suiteMap.get(result.suite);
    if (!suite) {
      suite = { name: result.suite, passed: 0, failed: 0, skipped: 0, duration: 0 };
      suiteMap.set(result.suite, suite);
    }
    if (result.status === "passed") suite.passed++;
    else if (result.status === "failed") suite.failed++;
    else if (result.status === "skipped") suite.skipped++;
    suite.duration += result.duration;
  }

  // Detect flaky tests: a test that both passed and failed across different runs
  const flakyTests = detectFlakyTests(runs);

  return {
    totalTests,
    totalPassed,
    totalFailed,
    totalSkipped,
    totalDuration: Math.round(totalDuration * 100) / 100,
    flakyTests,
    suites: Array.from(suiteMap.values()).sort((a, b) => a.name.localeCompare(b.name)),
  };
}

/**
 * Detect flaky tests by comparing outcomes across runs.
 * A test is flaky if it passed in at least one run AND failed in at least one run.
 */
function detectFlakyTests(runs: TestResult[][]): FlakyTest[] {
  // Track pass/fail counts per unique test (keyed by suite::name)
  const testOutcomes = new Map<string, { suite: string; name: string; passCount: number; failCount: number }>();

  for (const run of runs) {
    for (const result of run) {
      const key = `${result.suite}::${result.name}`;
      let entry = testOutcomes.get(key);
      if (!entry) {
        entry = { suite: result.suite, name: result.name, passCount: 0, failCount: 0 };
        testOutcomes.set(key, entry);
      }
      if (result.status === "passed") entry.passCount++;
      else if (result.status === "failed") entry.failCount++;
    }
  }

  // A test is flaky if it has both passes and failures
  const flaky: FlakyTest[] = [];
  for (const entry of testOutcomes.values()) {
    if (entry.passCount > 0 && entry.failCount > 0) {
      flaky.push({
        name: entry.name,
        suite: entry.suite,
        passCount: entry.passCount,
        failCount: entry.failCount,
      });
    }
  }

  return flaky.sort((a, b) => `${a.suite}::${a.name}`.localeCompare(`${b.suite}::${b.name}`));
}
