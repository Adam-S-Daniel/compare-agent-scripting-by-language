// Aggregates results across multiple test runs and detects flaky tests

import type { AggregatedResults, AggregatedStats, FlakyTest, ParsedRun } from "./types";

export function aggregateRuns(runs: ParsedRun[]): AggregatedResults {
  const stats: AggregatedStats = { totalTests: 0, passed: 0, failed: 0, skipped: 0, duration: 0 };

  for (const run of runs) {
    for (const suite of run.suites) {
      for (const test of suite.tests) {
        stats.totalTests++;
        stats.duration += test.duration;
        if (test.status === "passed") stats.passed++;
        else if (test.status === "failed" || test.status === "error") stats.failed++;
        else if (test.status === "skipped") stats.skipped++;
      }
    }
  }

  const flakyTests = detectFlakyTests(runs);
  return { stats, runs, flakyTests };
}

export function detectFlakyTests(runs: ParsedRun[]): FlakyTest[] {
  // Track pass/fail status per test name across runs
  const testResults = new Map<string, { passedRuns: string[]; failedRuns: string[] }>();

  for (const run of runs) {
    for (const suite of run.suites) {
      for (const test of suite.tests) {
        if (test.status === "skipped") continue;

        const key = test.name;
        if (!testResults.has(key)) {
          testResults.set(key, { passedRuns: [], failedRuns: [] });
        }
        const entry = testResults.get(key)!;

        if (test.status === "passed") {
          entry.passedRuns.push(run.runId);
        } else if (test.status === "failed" || test.status === "error") {
          entry.failedRuns.push(run.runId);
        }
      }
    }
  }

  const flaky: FlakyTest[] = [];
  for (const [name, { passedRuns, failedRuns }] of testResults) {
    if (passedRuns.length > 0 && failedRuns.length > 0) {
      flaky.push({ name, passedInRuns: passedRuns, failedInRuns: failedRuns });
    }
  }

  return flaky.sort((a, b) => a.name.localeCompare(b.name));
}
