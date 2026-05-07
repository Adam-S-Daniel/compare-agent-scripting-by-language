// Core types for test result aggregation

export type TestStatus = "passed" | "failed" | "skipped" | "error";

export interface TestCase {
  name: string;
  classname?: string;
  duration: number; // seconds
  status: TestStatus;
  failureMessage?: string;
}

export interface TestSuite {
  name: string;
  runId: string; // identifies which matrix run this came from
  tests: TestCase[];
}

export interface ParsedRun {
  runId: string;
  suites: TestSuite[];
}

export interface AggregatedStats {
  totalTests: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number; // total seconds across all runs
}

export interface FlakyTest {
  name: string;
  passedInRuns: string[];
  failedInRuns: string[];
}

export interface AggregatedResults {
  stats: AggregatedStats;
  runs: ParsedRun[];
  flakyTests: FlakyTest[];
}
