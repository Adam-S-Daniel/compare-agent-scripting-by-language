// Type definitions for test results aggregation

export interface TestCase {
  name: string;
  className: string;
  status: 'passed' | 'failed' | 'skipped';
  duration: number; // in milliseconds
  message?: string;
  runId?: string;
}

export interface TestSuite {
  name: string;
  tests: number;
  failures: number;
  skipped: number;
  time: number; // in seconds
  cases: TestCase[];
}

export interface AggregatedResults {
  totalTests: number;
  totalPassed: number;
  totalFailed: number;
  totalSkipped: number;
  totalDuration: number; // in milliseconds
  suites: TestSuite[];
  flakyTests: FlakyTest[];
}

export interface FlakyTest {
  name: string;
  className: string;
  failureCount: number;
  passageCount: number;
  runIds: string[];
}

export interface ParsedResults {
  format: 'junit' | 'json';
  runId: string;
  results: TestSuite[];
}
