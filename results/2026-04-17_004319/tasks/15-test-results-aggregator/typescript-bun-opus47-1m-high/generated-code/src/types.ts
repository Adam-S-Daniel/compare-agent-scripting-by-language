// Shared domain types for test result parsing and aggregation.

export type TestStatus = "passed" | "failed" | "skipped";

export interface TestCase {
  // Class/file the test belongs to. Used as part of the unique test identity.
  classname: string;
  name: string;
  status: TestStatus;
  duration: number;
  failureMessage?: string;
}

export interface TestSuite {
  name: string;
  tests: TestCase[];
}

export interface ParsedReport {
  // A single source file may contribute multiple suites.
  suites: TestSuite[];
  // Originating file path, when parsed from disk.
  source?: string;
}

export interface AggregateTotals {
  total: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
  fileCount: number;
}

export interface FlakyTest {
  // Stable cross-run identity: `${classname} :: ${name}`.
  id: string;
  classname: string;
  name: string;
  passedRuns: number;
  failedRuns: number;
  totalRuns: number;
}

export interface AggregateResult {
  totals: AggregateTotals;
  flaky: FlakyTest[];
  failures: Array<{ id: string; message: string }>;
}
