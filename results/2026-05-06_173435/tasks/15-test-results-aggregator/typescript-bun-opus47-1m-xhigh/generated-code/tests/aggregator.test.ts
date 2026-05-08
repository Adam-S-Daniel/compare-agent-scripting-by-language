import { describe, expect, test } from "bun:test";
import { aggregate } from "../src/aggregator.ts";
import type { TestRun } from "../src/types.ts";

// Helper to build runs for tests cleanly.
function run(source: string, ...cases: Array<[string, string, "passed" | "failed" | "skipped", number]>): TestRun {
  return {
    source,
    suites: [
      {
        name: "Suite",
        cases: cases.map(([classname, name, status, duration]) => ({
          classname,
          name,
          status,
          duration,
        })),
      },
    ],
  };
}

describe("aggregate", () => {
  test("computes totals across multiple runs", () => {
    const runs: TestRun[] = [
      run("a.xml", ["S", "t1", "passed", 1.0], ["S", "t2", "failed", 2.0]),
      run("b.xml", ["S", "t1", "passed", 1.5], ["S", "t3", "skipped", 0]),
    ];
    const agg = aggregate(runs);
    expect(agg.runCount).toBe(2);
    expect(agg.totalTests).toBe(4);
    expect(agg.totalPassed).toBe(2);
    expect(agg.totalFailed).toBe(1);
    expect(agg.totalSkipped).toBe(1);
    expect(agg.totalDuration).toBeCloseTo(4.5, 5);
  });

  test("identifies a test as flaky when it both passes and fails across runs", () => {
    const runs: TestRun[] = [
      run("a.xml", ["S", "flake", "passed", 0.1]),
      run("b.xml", ["S", "flake", "failed", 0.1]),
      run("c.xml", ["S", "flake", "passed", 0.1]),
    ];
    const agg = aggregate(runs);
    expect(agg.flakyTests).toHaveLength(1);
    const flaky = agg.flakyTests[0]!;
    expect(flaky.id).toBe("S.flake");
    expect(flaky.passed).toBe(2);
    expect(flaky.failed).toBe(1);
    expect(flaky.total).toBe(3);
  });

  test("does not report consistently-passing tests as flaky", () => {
    const runs: TestRun[] = [
      run("a.xml", ["S", "stable", "passed", 0.1]),
      run("b.xml", ["S", "stable", "passed", 0.1]),
    ];
    const agg = aggregate(runs);
    expect(agg.flakyTests).toHaveLength(0);
  });

  test("does not report consistently-failing tests as flaky", () => {
    const runs: TestRun[] = [
      run("a.xml", ["S", "broken", "failed", 0.1]),
      run("b.xml", ["S", "broken", "failed", 0.1]),
    ];
    const agg = aggregate(runs);
    expect(agg.flakyTests).toHaveLength(0);
    expect(agg.failingTests).toHaveLength(1);
    expect(agg.failingTests[0]!.id).toBe("S.broken");
  });

  test("treats skipped runs as neither pass nor fail when classifying flakiness", () => {
    // A test that is skipped in one run and passed in another is NOT flaky —
    // flakiness requires at least one pass AND at least one fail.
    const runs: TestRun[] = [
      run("a.xml", ["S", "maybe", "skipped", 0]),
      run("b.xml", ["S", "maybe", "passed", 0.1]),
    ];
    const agg = aggregate(runs);
    expect(agg.flakyTests).toHaveLength(0);
  });
});
