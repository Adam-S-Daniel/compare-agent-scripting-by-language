// Core types for the test results aggregator

export type TestStatus = 'passed' | 'failed' | 'skipped';

export interface TestResult {
  suiteName: string;
  testName: string;
  status: TestStatus;
  duration: number; // seconds
  errorMessage?: string;
  source: string; // originating filename
}

export interface TestSuite {
  name: string;
  source: string;
  duration: number; // total suite duration in seconds
  results: TestResult[];
}

export interface FlakyTest {
  suiteName: string;
  testName: string;
  passCount: number;
  failCount: number;
}

export interface AggregatedResults {
  totalSuites: number;
  totalTests: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number; // total across all suites
  flakyTests: FlakyTest[];
  suites: TestSuite[];
}

// JSON fixture format for the JSON parser
export interface JsonTestFixture {
  suiteName: string;
  duration: number;
  tests: Array<{
    name: string;
    status: TestStatus;
    duration: number;
    errorMessage?: string;
  }>;
}
