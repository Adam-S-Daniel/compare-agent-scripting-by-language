// Flaky test detection
// A test is "flaky" if it passed in at least one matrix run AND failed in at least one other.
// Skipped tests are never considered flaky (they didn't actually run).

import type { TestSuite, FlakyTest } from "./types";

/**
 * Detect flaky tests across multiple test suites (matrix runs).
 * Groups tests by their unique identity (className + name) and checks
 * if the same test has both passed and failed across different runs.
 */
export function detectFlakyTests(suites: TestSuite[]): FlakyTest[] {
  // Map from unique test ID → { passedIn: string[], failedIn: string[] }
  const testResults = new Map<string, { passedIn: string[]; failedIn: string[]; name: string; className: string }>();

  for (const suite of suites) {
    const matrixKey = suite.matrixKey ?? suite.name;

    for (const tc of suite.testCases) {
      // Skip tests that were skipped — they didn't run, not flaky
      if (tc.status === "skipped") continue;

      const id = `${tc.className}::${tc.name}`;

      if (!testResults.has(id)) {
        testResults.set(id, {
          passedIn: [],
          failedIn: [],
          name: tc.name,
          className: tc.className,
        });
      }

      const entry = testResults.get(id)!;
      if (tc.status === "passed") {
        entry.passedIn.push(matrixKey);
      } else if (tc.status === "failed") {
        entry.failedIn.push(matrixKey);
      }
    }
  }

  // A test is flaky if it has BOTH passed and failed runs
  const flakyTests: FlakyTest[] = [];
  for (const [, entry] of testResults) {
    if (entry.passedIn.length > 0 && entry.failedIn.length > 0) {
      flakyTests.push({
        name: entry.name,
        className: entry.className,
        passedIn: entry.passedIn,
        failedIn: entry.failedIn,
      });
    }
  }

  return flakyTests;
}
