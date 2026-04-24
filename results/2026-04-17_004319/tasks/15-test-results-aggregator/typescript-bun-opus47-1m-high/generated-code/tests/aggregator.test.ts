// TDD: tests for aggregation logic — totals, duration, flaky detection.
// A flaky test is one that has both at least one "passed" and one "failed"
// outcome across the aggregated runs. Skipped-only tests are not flaky.
import { describe, test, expect } from "bun:test";
import { aggregate } from "../src/aggregator";
import type { ParsedReport } from "../src/types";

function mkReport(
  name: string,
  cases: Array<[string, string, "passed" | "failed" | "skipped", number?]>,
): ParsedReport {
  return {
    source: name,
    suites: [
      {
        name,
        tests: cases.map(([cls, n, status, dur]) => ({
          classname: cls,
          name: n,
          status,
          duration: dur ?? 0,
          failureMessage: status === "failed" ? `fail ${n}` : undefined,
        })),
      },
    ],
  };
}

describe("aggregate", () => {
  test("computes totals across multiple reports", () => {
    const r1 = mkReport("r1", [
      ["A", "t1", "passed", 0.5],
      ["A", "t2", "failed", 0.2],
      ["A", "t3", "skipped", 0],
    ]);
    const r2 = mkReport("r2", [
      ["A", "t1", "passed", 0.6],
      ["A", "t2", "passed", 0.3],
    ]);
    const res = aggregate([r1, r2]);
    expect(res.totals.total).toBe(5);
    expect(res.totals.passed).toBe(3);
    expect(res.totals.failed).toBe(1);
    expect(res.totals.skipped).toBe(1);
    expect(res.totals.duration).toBeCloseTo(1.6, 5);
    expect(res.totals.fileCount).toBe(2);
  });

  test("detects flaky tests (passed in one run, failed in another)", () => {
    const r1 = mkReport("r1", [["A", "flip", "passed"]]);
    const r2 = mkReport("r2", [["A", "flip", "failed"]]);
    const r3 = mkReport("r3", [["A", "flip", "passed"]]);
    const res = aggregate([r1, r2, r3]);
    expect(res.flaky).toHaveLength(1);
    expect(res.flaky[0].id).toBe("A :: flip");
    expect(res.flaky[0].passedRuns).toBe(2);
    expect(res.flaky[0].failedRuns).toBe(1);
    expect(res.flaky[0].totalRuns).toBe(3);
  });

  test("does not flag consistently-failing tests as flaky", () => {
    const r1 = mkReport("r1", [["A", "broken", "failed"]]);
    const r2 = mkReport("r2", [["A", "broken", "failed"]]);
    const res = aggregate([r1, r2]);
    expect(res.flaky).toHaveLength(0);
    expect(res.failures).toHaveLength(2);
  });

  test("captures failure messages in the failures list", () => {
    const r1 = mkReport("r1", [["A", "t", "failed"]]);
    const res = aggregate([r1]);
    expect(res.failures[0].id).toBe("A :: t");
    expect(res.failures[0].message).toBe("fail t");
  });
});
