// Aggregates test results from multiple sources (matrix builds)
export interface ParsedResult {
  source: string;
  tests: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
}

export interface AggregatedResults {
  totalTests: number;
  totalPassed: number;
  totalFailed: number;
  totalSkipped: number;
  totalDuration: number;
  runCount: number;
  avgPassRate: number;
  avgFailRate: number;
  avgDuration: number;
}

export interface TestResult {
  source: string;
  testName: string;
  status: "passed" | "failed" | "skipped";
}

export interface FlakyTest {
  testName: string;
  passCount: number;
  failCount: number;
  totalRuns: number;
  flakyRate: number;
}

// Aggregate results across multiple runs
export function aggregateResults(
  results: ParsedResult[]
): AggregatedResults {
  const totalTests = results.reduce((sum, r) => sum + r.tests, 0);
  const totalPassed = results.reduce((sum, r) => sum + r.passed, 0);
  const totalFailed = results.reduce((sum, r) => sum + r.failed, 0);
  const totalSkipped = results.reduce((sum, r) => sum + r.skipped, 0);
  const totalDuration = results.reduce((sum, r) => sum + r.duration, 0);
  const runCount = results.length;

  const totalTestsRun = runCount > 0 ? totalPassed + totalFailed : 0;
  const avgPassRate =
    totalTestsRun > 0 ? (totalPassed / totalTestsRun) * 100 : 0;
  const avgFailRate =
    totalTestsRun > 0 ? (totalFailed / totalTestsRun) * 100 : 0;
  const avgDuration = runCount > 0 ? totalDuration / runCount : 0;

  return {
    totalTests,
    totalPassed,
    totalFailed,
    totalSkipped,
    totalDuration,
    runCount,
    avgPassRate,
    avgFailRate,
    avgDuration,
  };
}

// Identify tests that pass in some runs but fail in others
export function identifyFlakyTests(
  testResults: TestResult[]
): FlakyTest[] {
  const testMap = new Map<string, { pass: number; fail: number }>();

  for (const result of testResults) {
    if (!testMap.has(result.testName)) {
      testMap.set(result.testName, { pass: 0, fail: 0 });
    }

    const entry = testMap.get(result.testName)!;
    if (result.status === "passed") {
      entry.pass++;
    } else if (result.status === "failed") {
      entry.fail++;
    }
  }

  const flakyTests: FlakyTest[] = [];

  for (const [testName, counts] of testMap.entries()) {
    // A test is flaky if it has both passes and failures across runs
    if (counts.pass > 0 && counts.fail > 0) {
      const totalRuns = counts.pass + counts.fail;
      flakyTests.push({
        testName,
        passCount: counts.pass,
        failCount: counts.fail,
        totalRuns,
        flakyRate: (counts.fail / totalRuns) * 100,
      });
    }
  }

  // Sort by flaky rate descending
  return flakyTests.sort((a, b) => b.flakyRate - a.flakyRate);
}
