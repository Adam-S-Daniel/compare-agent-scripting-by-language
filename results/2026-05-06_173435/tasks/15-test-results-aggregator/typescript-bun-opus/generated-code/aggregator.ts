import type {
  AggregatedReport,
  AggregatedTotals,
  FlakyTest,
  TestRun,
} from "./types";

export function aggregate(runs: TestRun[]): AggregatedReport {
  const totals: AggregatedTotals = {
    totalTests: 0,
    passed: 0,
    failed: 0,
    skipped: 0,
    duration: 0,
  };

  // Track which runs each test passed/failed in (keyed by "suite::name")
  const passMap = new Map<string, string[]>();
  const failMap = new Map<string, string[]>();
  const suiteMap = new Map<string, string>();

  for (const run of runs) {
    for (const result of run.results) {
      totals.totalTests++;
      totals.duration += result.duration;

      if (result.status === "passed") {
        totals.passed++;
      } else if (result.status === "failed") {
        totals.failed++;
      } else {
        totals.skipped++;
      }

      const key = `${result.suite}::${result.name}`;
      suiteMap.set(key, result.suite);

      if (result.status === "passed") {
        const arr = passMap.get(key) || [];
        arr.push(run.source);
        passMap.set(key, arr);
      } else if (result.status === "failed") {
        const arr = failMap.get(key) || [];
        arr.push(run.source);
        failMap.set(key, arr);
      }
    }
  }

  // A test is flaky if it passed in some runs and failed in others
  const flakyTests: FlakyTest[] = [];
  for (const [key, passedIn] of passMap) {
    const failedIn = failMap.get(key);
    if (failedIn && failedIn.length > 0) {
      const [suite, ...nameParts] = key.split("::");
      flakyTests.push({
        name: nameParts.join("::"),
        suite,
        passedIn,
        failedIn,
      });
    }
  }

  return { totals, flakyTests, runs };
}
