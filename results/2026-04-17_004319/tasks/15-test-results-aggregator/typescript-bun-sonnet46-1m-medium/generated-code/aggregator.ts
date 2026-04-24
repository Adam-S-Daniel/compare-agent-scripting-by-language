// Aggregates multiple TestSuites into a single AggregatedResults.
// Flaky test detection: a test is flaky if it appears in multiple suites with
// the same (suiteName, testName) key and has both passed and failed runs.

import type { TestSuite, AggregatedResults, FlakyTest } from './types';

export function aggregateResults(suites: TestSuite[]): AggregatedResults {
  let passed = 0;
  let failed = 0;
  let skipped = 0;
  let duration = 0;

  // Track per (suiteName + testName) outcome counts for flaky detection
  const outcomeMap = new Map<string, { passCount: number; failCount: number; suiteName: string; testName: string }>();

  for (const suite of suites) {
    duration += suite.duration;

    for (const result of suite.results) {
      if (result.status === 'passed') passed++;
      else if (result.status === 'failed') failed++;
      else if (result.status === 'skipped') skipped++;

      const key = `${result.suiteName}::${result.testName}`;
      const existing = outcomeMap.get(key) ?? {
        passCount: 0,
        failCount: 0,
        suiteName: result.suiteName,
        testName: result.testName,
      };

      if (result.status === 'passed') existing.passCount++;
      else if (result.status === 'failed') existing.failCount++;

      outcomeMap.set(key, existing);
    }
  }

  // A test is flaky when it has both passes and failures across runs
  const flakyTests: FlakyTest[] = [];
  for (const entry of outcomeMap.values()) {
    if (entry.passCount > 0 && entry.failCount > 0) {
      flakyTests.push({
        suiteName: entry.suiteName,
        testName: entry.testName,
        passCount: entry.passCount,
        failCount: entry.failCount,
      });
    }
  }

  return {
    totalSuites: suites.length,
    totalTests: passed + failed + skipped,
    passed,
    failed,
    skipped,
    duration: Math.round(duration * 1000) / 1000, // round to 3 decimal places
    flakyTests,
    suites,
  };
}
