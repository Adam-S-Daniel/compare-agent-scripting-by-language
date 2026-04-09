// Result aggregator
// Combines multiple TestSuite results (from a matrix build) into a single AggregatedResults.

import type { TestSuite, AggregatedResults } from "./types";

/**
 * Aggregate multiple test suites into a single summary.
 * All counts are summed; duration is summed across suites.
 */
export function aggregateResults(suites: TestSuite[]): AggregatedResults {
  let totalPassed = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  let totalDuration = 0;

  for (const suite of suites) {
    // Count test statuses from the actual test cases for accuracy
    for (const tc of suite.testCases) {
      if (tc.status === "passed") totalPassed++;
      else if (tc.status === "failed") totalFailed++;
      else if (tc.status === "skipped") totalSkipped++;
    }
    totalDuration += suite.duration;
  }

  return {
    totalPassed,
    totalFailed,
    totalSkipped,
    totalDuration,
    suites,
  };
}
