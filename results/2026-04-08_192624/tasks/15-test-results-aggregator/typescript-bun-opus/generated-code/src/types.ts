// Shared type definitions for the test results aggregator

/** Status of an individual test case */
export type TestStatus = "passed" | "failed" | "skipped";

/** A single test case result from any format */
export interface TestResult {
  name: string;
  suite: string;
  status: TestStatus;
  duration: number; // seconds
  message?: string; // failure/error message
}

/** Aggregated summary across all test files */
export interface AggregatedSummary {
  totalTests: number;
  totalPassed: number;
  totalFailed: number;
  totalSkipped: number;
  totalDuration: number; // seconds
  flakyTests: FlakyTest[];
  suites: SuiteSummary[];
}

/** A test identified as flaky (different outcomes across runs) */
export interface FlakyTest {
  name: string;
  suite: string;
  passCount: number;
  failCount: number;
}

/** Per-suite summary */
export interface SuiteSummary {
  name: string;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
}

/** JSON test result input format */
export interface JsonTestFile {
  testSuites: JsonTestSuite[];
}

export interface JsonTestSuite {
  name: string;
  tests: JsonTestCase[];
}

export interface JsonTestCase {
  name: string;
  status: TestStatus;
  duration: number;
  message?: string;
}
