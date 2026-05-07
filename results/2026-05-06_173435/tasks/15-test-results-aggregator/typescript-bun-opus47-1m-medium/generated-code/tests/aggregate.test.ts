import { describe, expect, test } from "bun:test";
import { aggregate } from "../src/aggregate";
import type { RunResult } from "../src/types";

const runs: RunResult[] = [
  {
    runId: "run-1",
    cases: [
      { suite: "S", name: "a", status: "passed", durationMs: 10 },
      { suite: "S", name: "flaky", status: "passed", durationMs: 5 },
      { suite: "S", name: "fail", status: "failed", durationMs: 8, message: "boom" },
      { suite: "S", name: "skip", status: "skipped", durationMs: 0 },
    ],
  },
  {
    runId: "run-2",
    cases: [
      { suite: "S", name: "a", status: "passed", durationMs: 11 },
      { suite: "S", name: "flaky", status: "failed", durationMs: 6, message: "race" },
      { suite: "S", name: "fail", status: "failed", durationMs: 9, message: "boom" },
    ],
  },
];

describe("aggregate", () => {
  test("computes totals across all runs", () => {
    const r = aggregate(runs);
    expect(r.totals.passed).toBe(3);
    expect(r.totals.failed).toBe(3);
    expect(r.totals.skipped).toBe(1);
    expect(r.totals.total).toBe(7);
    expect(r.totals.durationMs).toBe(49);
  });

  test("flags flaky tests (pass and fail across runs)", () => {
    const r = aggregate(runs);
    expect(r.flaky).toHaveLength(1);
    expect(r.flaky[0]).toEqual({ suite: "S", name: "flaky", passes: 1, failures: 1 });
  });

  test("does not flag consistently-failing tests as flaky", () => {
    const r = aggregate(runs);
    expect(r.flaky.find((f) => f.name === "fail")).toBeUndefined();
  });

  test("collects all failures", () => {
    const r = aggregate(runs);
    expect(r.failures).toHaveLength(3);
  });
});
