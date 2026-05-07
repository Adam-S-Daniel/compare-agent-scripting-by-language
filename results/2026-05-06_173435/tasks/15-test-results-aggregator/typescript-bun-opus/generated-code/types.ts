export interface TestResult {
  name: string;
  suite: string;
  status: "passed" | "failed" | "skipped";
  duration: number;
  error?: string;
}

export interface TestRun {
  source: string;
  results: TestResult[];
}

export interface AggregatedTotals {
  totalTests: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
}

export interface FlakyTest {
  name: string;
  suite: string;
  passedIn: string[];
  failedIn: string[];
}

export interface AggregatedReport {
  totals: AggregatedTotals;
  flakyTests: FlakyTest[];
  runs: TestRun[];
}
