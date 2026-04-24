// Core domain types for the test results aggregator

export interface TestCase {
  name: string;
  suiteName: string;
  status: "passed" | "failed" | "skipped";
  duration: number;
  error?: string;
}

export interface TestSuite {
  name: string;
  tests: TestCase[];
  duration: number;
}

export interface ParsedResult {
  runId: string;
  format: "junit" | "json";
  suites: TestSuite[];
}

export interface FlakyTest {
  name: string;
  suiteName: string;
  passedRuns: number;
  failedRuns: number;
}

export interface FailedTestDetail {
  name: string;
  suiteName: string;
  runId: string;
  error?: string;
}

export interface AggregatedResults {
  totalTests: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
  flakyTests: FlakyTest[];
  failedTests: FailedTestDetail[];
  fileCount: number;
}
