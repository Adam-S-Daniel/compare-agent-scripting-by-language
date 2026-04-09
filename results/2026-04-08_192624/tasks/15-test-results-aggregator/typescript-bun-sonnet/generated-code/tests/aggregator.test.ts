// TDD: Tests for result aggregator
// RED phase: these tests fail until the aggregator is implemented

import { describe, it, expect } from "bun:test";
import { aggregateResults } from "../src/aggregator";
import type { TestSuite } from "../src/types";

// Helper to create a minimal TestSuite for testing
function makeSuite(
  name: string,
  matrixKey: string,
  testCases: Array<{ name: string; status: "passed" | "failed" | "skipped"; duration?: number }>
): TestSuite {
  const cases = testCases.map((tc) => ({
    name: tc.name,
    className: name,
    duration: tc.duration ?? 1.0,
    status: tc.status,
  }));

  return {
    name,
    tests: cases.length,
    failures: cases.filter((c) => c.status === "failed").length,
    errors: 0,
    skipped: cases.filter((c) => c.status === "skipped").length,
    duration: cases.reduce((s, c) => s + c.duration, 0),
    testCases: cases,
    matrixKey,
  };
}

describe("Result Aggregator", () => {
  describe("aggregateResults", () => {
    it("returns zero totals for an empty suite list", () => {
      const result = aggregateResults([]);
      expect(result.totalPassed).toBe(0);
      expect(result.totalFailed).toBe(0);
      expect(result.totalSkipped).toBe(0);
      expect(result.totalDuration).toBe(0);
      expect(result.suites).toHaveLength(0);
    });

    it("correctly counts passed tests across a single suite", () => {
      const suite = makeSuite("SuiteA", "ubuntu", [
        { name: "t1", status: "passed" },
        { name: "t2", status: "passed" },
        { name: "t3", status: "passed" },
      ]);

      const result = aggregateResults([suite]);
      expect(result.totalPassed).toBe(3);
      expect(result.totalFailed).toBe(0);
      expect(result.totalSkipped).toBe(0);
    });

    it("correctly counts mixed results across a single suite", () => {
      const suite = makeSuite("SuiteA", "ubuntu", [
        { name: "t1", status: "passed" },
        { name: "t2", status: "failed" },
        { name: "t3", status: "skipped" },
      ]);

      const result = aggregateResults([suite]);
      expect(result.totalPassed).toBe(1);
      expect(result.totalFailed).toBe(1);
      expect(result.totalSkipped).toBe(1);
    });

    it("aggregates results across multiple suites", () => {
      const suites = [
        makeSuite("SuiteA", "ubuntu", [
          { name: "t1", status: "passed" },
          { name: "t2", status: "failed" },
        ]),
        makeSuite("SuiteB", "windows", [
          { name: "t3", status: "passed" },
          { name: "t4", status: "skipped" },
        ]),
        makeSuite("SuiteC", "macos", [
          { name: "t5", status: "failed" },
          { name: "t6", status: "passed" },
        ]),
      ];

      const result = aggregateResults(suites);
      expect(result.totalPassed).toBe(3);
      expect(result.totalFailed).toBe(2);
      expect(result.totalSkipped).toBe(1);
    });

    it("sums duration correctly across suites", () => {
      const suites = [
        makeSuite("SuiteA", "ubuntu", [
          { name: "t1", status: "passed", duration: 1.5 },
          { name: "t2", status: "passed", duration: 2.5 },
        ]),
        makeSuite("SuiteB", "windows", [
          { name: "t3", status: "passed", duration: 3.0 },
        ]),
      ];

      const result = aggregateResults(suites);
      expect(result.totalDuration).toBeCloseTo(7.0, 2);
    });

    it("preserves all suites in the result", () => {
      const suites = [
        makeSuite("SuiteA", "ubuntu", [{ name: "t1", status: "passed" }]),
        makeSuite("SuiteB", "windows", [{ name: "t2", status: "passed" }]),
      ];

      const result = aggregateResults(suites);
      expect(result.suites).toHaveLength(2);
      expect(result.suites[0].name).toBe("SuiteA");
      expect(result.suites[1].name).toBe("SuiteB");
    });
  });
});
