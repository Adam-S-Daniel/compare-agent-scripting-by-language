// Core types for test result aggregation

/** A single test case result */
export interface TestCase {
  name: string;
  className: string;
  duration: number; // seconds
  status: "passed" | "failed" | "skipped";
  errorMessage?: string;
  errorType?: string;
}

/** Results from a single test suite (file) */
export interface TestSuite {
  name: string;
  tests: number;
  failures: number;
  errors: number;
  skipped: number;
  duration: number; // seconds
  testCases: TestCase[];
  /** Which matrix dimension this came from (e.g. "ubuntu-latest", "node-18") */
  matrixKey?: string;
}

/** Aggregated results across all suites */
export interface AggregatedResults {
  totalPassed: number;
  totalFailed: number;
  totalSkipped: number;
  totalDuration: number; // seconds
  suites: TestSuite[];
}

/** A test identified as flaky (passed in some runs, failed in others) */
export interface FlakyTest {
  name: string;
  className: string;
  passedIn: string[]; // matrixKeys where it passed
  failedIn: string[]; // matrixKeys where it failed
}

/** Full report including aggregated results and flaky tests */
export interface TestReport {
  aggregated: AggregatedResults;
  flakyTests: FlakyTest[];
}

/** Input to the JSON parser format */
export interface JsonTestResult {
  suiteName: string;
  matrixKey?: string;
  results: Array<{
    name: string;
    className: string;
    status: "passed" | "failed" | "skipped";
    duration: number;
    error?: {
      message: string;
      type: string;
    };
  }>;
}
