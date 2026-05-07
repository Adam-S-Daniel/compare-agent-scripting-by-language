import { describe, test, expect } from "bun:test";
import { aggregate } from "./aggregator";
import type { TestRun } from "./types";

// Two runs where "flaky test" passes in run1 but fails in run2
const run1: TestRun = {
  source: "run1",
  results: [
    { name: "always passes", suite: "Suite", status: "passed", duration: 1.0 },
    { name: "flaky test", suite: "Suite", status: "passed", duration: 2.0 },
    { name: "always skipped", suite: "Suite", status: "skipped", duration: 0 },
  ],
};

const run2: TestRun = {
  source: "run2",
  results: [
    { name: "always passes", suite: "Suite", status: "passed", duration: 1.5 },
    {
      name: "flaky test",
      suite: "Suite",
      status: "failed",
      duration: 2.5,
      error: "Timeout",
    },
    { name: "always skipped", suite: "Suite", status: "skipped", duration: 0 },
  ],
};

describe("aggregate", () => {
  test("computes correct totals across runs", () => {
    const report = aggregate([run1, run2]);

    // 3 tests per run x 2 runs = 6 total test executions
    expect(report.totals.totalTests).toBe(6);
    expect(report.totals.passed).toBe(3);
    expect(report.totals.failed).toBe(1);
    expect(report.totals.skipped).toBe(2);
  });

  test("computes total duration", () => {
    const report = aggregate([run1, run2]);

    // run1: 1.0+2.0+0 = 3.0, run2: 1.5+2.5+0 = 4.0, total = 7.0
    expect(report.totals.duration).toBeCloseTo(7.0, 1);
  });

  test("identifies flaky tests", () => {
    const report = aggregate([run1, run2]);

    expect(report.flakyTests).toHaveLength(1);
    expect(report.flakyTests[0].name).toBe("flaky test");
    expect(report.flakyTests[0].suite).toBe("Suite");
    expect(report.flakyTests[0].passedIn).toEqual(["run1"]);
    expect(report.flakyTests[0].failedIn).toEqual(["run2"]);
  });

  test("does not flag consistently passing tests as flaky", () => {
    const report = aggregate([run1, run2]);

    const flakyNames = report.flakyTests.map((f) => f.name);
    expect(flakyNames).not.toContain("always passes");
  });

  test("does not flag consistently skipped tests as flaky", () => {
    const report = aggregate([run1, run2]);

    const flakyNames = report.flakyTests.map((f) => f.name);
    expect(flakyNames).not.toContain("always skipped");
  });

  test("preserves all runs in report", () => {
    const report = aggregate([run1, run2]);

    expect(report.runs).toHaveLength(2);
    expect(report.runs[0].source).toBe("run1");
    expect(report.runs[1].source).toBe("run2");
  });

  test("handles single run with no flaky tests", () => {
    const report = aggregate([run1]);

    expect(report.totals.totalTests).toBe(3);
    expect(report.flakyTests).toHaveLength(0);
  });

  test("handles empty input", () => {
    const report = aggregate([]);

    expect(report.totals.totalTests).toBe(0);
    expect(report.totals.passed).toBe(0);
    expect(report.totals.failed).toBe(0);
    expect(report.totals.skipped).toBe(0);
    expect(report.totals.duration).toBe(0);
    expect(report.flakyTests).toHaveLength(0);
  });
});
