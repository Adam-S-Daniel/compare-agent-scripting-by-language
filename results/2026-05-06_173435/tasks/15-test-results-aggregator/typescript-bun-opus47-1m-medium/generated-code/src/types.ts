// Shared domain types for the test-results aggregator.

export type TestStatus = "passed" | "failed" | "skipped";

export interface TestCase {
  suite: string;
  name: string;
  status: TestStatus;
  durationMs: number;
  message?: string;
}

export interface RunResult {
  // Logical run identifier (e.g. "ubuntu-latest", "fixture-1.json"). Used for flaky detection.
  runId: string;
  cases: TestCase[];
}

export interface AggregatedResults {
  totals: {
    passed: number;
    failed: number;
    skipped: number;
    total: number;
    durationMs: number;
  };
  // A test (suite::name) is flaky if it both passed and failed across runs.
  flaky: { suite: string; name: string; passes: number; failures: number }[];
  failures: TestCase[];
  runs: RunResult[];
}
