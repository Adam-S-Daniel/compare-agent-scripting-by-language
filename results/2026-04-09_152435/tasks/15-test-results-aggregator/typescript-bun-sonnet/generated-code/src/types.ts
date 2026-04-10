// TypeScript types for the test results aggregator.
// These interfaces model parsed test data from JUnit XML and JSON formats.

export type TestStatus = "passed" | "failed" | "skipped";

export interface TestCase {
  name: string;
  classname: string;
  status: TestStatus;
  duration: number; // seconds
  errorMessage?: string;
}

export interface TestSuite {
  name: string;
  file: string; // source file path
  tests: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number; // seconds
  testCases: TestCase[];
}

export interface FlakyTest {
  name: string;
  passCount: number;
  failCount: number;
}

export interface AggregatedResults {
  totalTests: number;
  totalPassed: number;
  totalFailed: number;
  totalSkipped: number;
  totalDuration: number; // seconds
  suites: TestSuite[];
  flakyTests: FlakyTest[];
}
