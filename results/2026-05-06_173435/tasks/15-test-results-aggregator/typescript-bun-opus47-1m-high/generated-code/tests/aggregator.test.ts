// Aggregator tests: totals across runs and flaky-test detection.
import { describe, expect, test } from "bun:test";
import { aggregate } from "../src/aggregator.ts";
import type { TestSuite } from "../src/types.ts";

function suite(
  name: string,
  source: string,
  cases: Array<[string, "passed" | "failed" | "skipped", number]>,
): TestSuite {
  return {
    name,
    source,
    cases: cases.map(([n, status, duration]) => ({
      name: n,
      classname: name,
      status,
      duration,
    })),
  };
}

describe("aggregate", () => {
  test("counts passed/failed/skipped and sums duration", () => {
    const suites: TestSuite[] = [
      suite("S", "run1.xml", [
        ["a", "passed", 1.0],
        ["b", "failed", 0.5],
        ["c", "skipped", 0],
      ]),
      suite("S", "run2.xml", [
        ["a", "passed", 1.1],
        ["b", "passed", 0.4],
      ]),
    ];
    const r = aggregate(suites);
    expect(r.totalTests).toBe(5);
    expect(r.passed).toBe(3);
    expect(r.failed).toBe(1);
    expect(r.skipped).toBe(1);
    expect(r.totalDuration).toBeCloseTo(3.0, 5);
    expect(r.fileCount).toBe(2);
  });

  test("flags a test that passed in one run and failed in another", () => {
    const suites: TestSuite[] = [
      suite("S", "r1.xml", [["b", "passed", 0.5]]),
      suite("S", "r2.xml", [["b", "failed", 0.5]]),
      suite("S", "r3.xml", [["b", "passed", 0.5]]),
    ];
    const r = aggregate(suites);
    expect(r.flaky).toHaveLength(1);
    expect(r.flaky[0]).toEqual({
      name: "b",
      classname: "S",
      passCount: 2,
      failCount: 1,
      totalRuns: 3,
    });
  });

  test("does not flag tests that always pass or always fail", () => {
    const suites: TestSuite[] = [
      suite("S", "r1.xml", [
        ["always-green", "passed", 0.1],
        ["always-red", "failed", 0.1],
      ]),
      suite("S", "r2.xml", [
        ["always-green", "passed", 0.1],
        ["always-red", "failed", 0.1],
      ]),
    ];
    expect(aggregate(suites).flaky).toEqual([]);
  });

  test("ignores skipped runs when deciding flake status", () => {
    // A test skipped in one run and passed in another is NOT flaky
    // (skipped means the test didn't run, not that it changed result).
    const suites: TestSuite[] = [
      suite("S", "r1.xml", [["t", "skipped", 0]]),
      suite("S", "r2.xml", [["t", "passed", 0.5]]),
    ];
    expect(aggregate(suites).flaky).toEqual([]);
  });

  test("disambiguates same-named tests in different classes", () => {
    const suites: TestSuite[] = [
      suite("S", "r1.xml", [
        ["t", "passed", 0.1],
      ]),
      suite("Other", "r1.xml", [
        ["t", "failed", 0.1],
      ]),
      suite("S", "r2.xml", [
        ["t", "passed", 0.1],
      ]),
      suite("Other", "r2.xml", [
        ["t", "failed", 0.1],
      ]),
    ];
    // Neither is flaky — each (classname,name) is consistent.
    expect(aggregate(suites).flaky).toEqual([]);
  });

  test("returns flaky entries sorted by failCount desc then name", () => {
    const suites: TestSuite[] = [
      suite("S", "r1.xml", [
        ["alpha", "passed", 0.1],
        ["bravo", "failed", 0.1],
      ]),
      suite("S", "r2.xml", [
        ["alpha", "failed", 0.1],
        ["bravo", "passed", 0.1],
      ]),
      suite("S", "r3.xml", [
        ["alpha", "passed", 0.1],
        ["bravo", "failed", 0.1],
      ]),
    ];
    const flaky = aggregate(suites).flaky;
    expect(flaky.map((f) => f.name)).toEqual(["bravo", "alpha"]);
  });
});
