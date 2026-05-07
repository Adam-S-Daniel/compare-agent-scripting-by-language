// Shared types for the aggregator. Kept narrow on purpose — a `status` union
// of three strings is easier to switch over than a free-form string.

export type TestStatus = "passed" | "failed" | "skipped";

export interface TestCase {
  name: string;
  classname: string | undefined;
  status: TestStatus;
  duration: number; // seconds
  failureMessage?: string;
}

export interface TestSuite {
  name: string;
  source: string; // file the suite was parsed from
  cases: TestCase[];
}

export interface FlakyTest {
  name: string;
  classname: string | undefined;
  passCount: number;
  failCount: number;
  totalRuns: number; // pass + fail (skipped runs don't count toward flake decision)
}

export interface AggregatedResults {
  totalTests: number; // sum across all runs (matrix totals, not de-duped)
  passed: number;
  failed: number;
  skipped: number;
  totalDuration: number; // seconds
  fileCount: number;
  flaky: FlakyTest[];
  suites: TestSuite[];
}
