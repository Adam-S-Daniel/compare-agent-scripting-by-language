// Core type definitions shared across parser, aggregator and summary.
//
// A single "run" is what one test-result file represents. Running the same
// suite in a matrix build produces N such runs, each with its own set of test
// results. We intentionally keep per-test data small: name, status, duration,
// and a failure message when applicable.

export type TestStatus = "passed" | "failed" | "skipped";

export interface TestResult {
  /** Fully-qualified test name. For JUnit we compose `classname.name`. */
  name: string;
  status: TestStatus;
  /** Duration in milliseconds. */
  durationMs: number;
  /** Failure message if `status === "failed"`. */
  failureMessage?: string;
}

export interface RunReport {
  /** Origin file or label — used in the markdown summary and for debugging. */
  source: string;
  tests: TestResult[];
}

export interface AggregatedTotals {
  total: number;
  passed: number;
  failed: number;
  skipped: number;
  /** Sum of all test durations, in milliseconds. */
  durationMs: number;
}

export interface FlakyTest {
  name: string;
  passCount: number;
  failCount: number;
  /** Sources (file names) where this test failed. */
  failedIn: string[];
}

export interface AggregatedReport {
  runs: RunReport[];
  totals: AggregatedTotals;
  flaky: FlakyTest[];
  /** Tests that failed in every run they appeared in — truly broken. */
  consistentlyFailing: string[];
}
