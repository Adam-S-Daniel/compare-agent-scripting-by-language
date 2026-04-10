// Aggregator module: combines multiple TestSuites into a single result set
// and detects flaky tests (tests with inconsistent outcomes across runs).

import type { TestSuite, AggregatedResults, FlakyTest } from "./types";

/**
 * Aggregate results across all provided test suites.
 * Computes totals and detects flaky tests in a single pass.
 */
export function aggregate(suites: TestSuite[]): AggregatedResults {
  let totalTests = 0;
  let totalPassed = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  let totalDuration = 0;

  for (const suite of suites) {
    totalTests += suite.tests;
    totalPassed += suite.passed;
    totalFailed += suite.failed;
    totalSkipped += suite.skipped;
    totalDuration += suite.duration;
  }

  return {
    totalTests,
    totalPassed,
    totalFailed,
    totalSkipped,
    totalDuration,
    suites,
    flakyTests: findFlakyTests(suites),
  };
}

/**
 * Identify tests that have inconsistent outcomes (passed in some runs, failed in others).
 * Skipped status is ignored — only pass/fail transitions count as flaky.
 *
 * Returns flaky tests sorted alphabetically by name.
 */
export function findFlakyTests(suites: TestSuite[]): FlakyTest[] {
  // Accumulate per-test pass/fail counts across all suites
  const counts = new Map<string, { passCount: number; failCount: number }>();

  for (const suite of suites) {
    for (const tc of suite.testCases) {
      const entry = counts.get(tc.name) ?? { passCount: 0, failCount: 0 };
      if (tc.status === "passed") {
        entry.passCount++;
      } else if (tc.status === "failed") {
        entry.failCount++;
      }
      // skipped status is not counted
      counts.set(tc.name, entry);
    }
  }

  // A test is flaky if it has at least one pass AND at least one fail
  const flaky: FlakyTest[] = [];
  for (const [name, { passCount, failCount }] of counts) {
    if (passCount > 0 && failCount > 0) {
      flaky.push({ name, passCount, failCount });
    }
  }

  return flaky.sort((a, b) => a.name.localeCompare(b.name));
}
