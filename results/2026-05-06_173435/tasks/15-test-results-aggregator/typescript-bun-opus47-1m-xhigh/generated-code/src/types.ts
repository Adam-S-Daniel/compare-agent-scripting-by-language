// Shared types for the test-results aggregator.
// A "run" is one test result file (e.g. one shard or matrix leg in CI).
// A "case" is a single test (identified by classname.name).
export type TestStatus = "passed" | "failed" | "skipped";

export interface TestCase {
  classname: string;
  name: string;
  status: TestStatus;
  duration: number; // seconds
  message?: string; // failure message, if any
}

export interface TestSuite {
  name: string;
  cases: TestCase[];
}

export interface TestRun {
  source: string; // file name / identifier of this run
  suites: TestSuite[];
}

export interface FlakyTest {
  id: string; // classname.name
  classname: string;
  name: string;
  passed: number;
  failed: number;
  total: number;
}

export interface AggregatedResults {
  totalPassed: number;
  totalFailed: number;
  totalSkipped: number;
  totalTests: number;
  totalDuration: number; // seconds
  runCount: number;
  flakyTests: FlakyTest[];
  failingTests: { id: string; classname: string; name: string; message?: string }[];
  runs: TestRun[];
}
