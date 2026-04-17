// TDD: aggregation tests. Written first, drive the shape of the public API.
import { describe, expect, test } from "bun:test";
import { aggregate } from "../../src/aggregator.ts";
import type { RunReport } from "../../src/types.ts";

const mkRun = (source: string, tests: RunReport["tests"]): RunReport => ({ source, tests });

describe("aggregate", () => {
  test("sums totals across runs", () => {
    const runs: RunReport[] = [
      mkRun("a.xml", [
        { name: "t1", status: "passed", durationMs: 100 },
        { name: "t2", status: "failed", durationMs: 50, failureMessage: "boom" },
        { name: "t3", status: "skipped", durationMs: 0 },
      ]),
      mkRun("b.json", [
        { name: "t1", status: "passed", durationMs: 90 },
        { name: "t2", status: "passed", durationMs: 55 },
      ]),
    ];
    const agg = aggregate(runs);
    expect(agg.totals.total).toBe(5);
    expect(agg.totals.passed).toBe(3);
    expect(agg.totals.failed).toBe(1);
    expect(agg.totals.skipped).toBe(1);
    expect(agg.totals.durationMs).toBe(295);
  });

  test("identifies flaky tests (passed in some runs, failed in others)", () => {
    const runs: RunReport[] = [
      mkRun("a.xml", [{ name: "t1", status: "failed", durationMs: 1, failureMessage: "x" }]),
      mkRun("b.xml", [{ name: "t1", status: "passed", durationMs: 1 }]),
      mkRun("c.xml", [{ name: "t1", status: "passed", durationMs: 1 }]),
    ];
    const agg = aggregate(runs);
    expect(agg.flaky).toHaveLength(1);
    expect(agg.flaky[0].name).toBe("t1");
    expect(agg.flaky[0].passCount).toBe(2);
    expect(agg.flaky[0].failCount).toBe(1);
    expect(agg.flaky[0].failedIn).toEqual(["a.xml"]);
  });

  test("tests that always fail are not flaky — they're consistently failing", () => {
    const runs: RunReport[] = [
      mkRun("a.xml", [{ name: "broken", status: "failed", durationMs: 0, failureMessage: "boom" }]),
      mkRun("b.xml", [{ name: "broken", status: "failed", durationMs: 0, failureMessage: "boom" }]),
    ];
    const agg = aggregate(runs);
    expect(agg.flaky).toHaveLength(0);
    expect(agg.consistentlyFailing).toEqual(["broken"]);
  });

  test("skipped runs don't pollute flaky detection", () => {
    const runs: RunReport[] = [
      mkRun("a", [{ name: "t", status: "skipped", durationMs: 0 }]),
      mkRun("b", [{ name: "t", status: "passed", durationMs: 1 }]),
    ];
    const agg = aggregate(runs);
    expect(agg.flaky).toHaveLength(0);
  });

  test("empty input produces zero totals", () => {
    const agg = aggregate([]);
    expect(agg.totals).toEqual({ total: 0, passed: 0, failed: 0, skipped: 0, durationMs: 0 });
    expect(agg.flaky).toEqual([]);
    expect(agg.consistentlyFailing).toEqual([]);
  });
});
