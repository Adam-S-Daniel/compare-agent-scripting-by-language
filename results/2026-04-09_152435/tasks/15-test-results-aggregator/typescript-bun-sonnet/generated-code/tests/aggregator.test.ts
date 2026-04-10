// TDD Step 2: Aggregator tests written FIRST (failing until src/aggregator.ts is implemented).
// Tests cover totals computation and flaky test detection.

import { describe, it, expect } from "bun:test";
import { aggregate, findFlakyTests } from "../src/aggregator";
import type { TestSuite } from "../src/types";

// Helper: build a minimal TestSuite with given test outcomes
function makeSuite(
  name: string,
  testCases: Array<{ name: string; status: "passed" | "failed" | "skipped" }>,
  duration = 1.0
): TestSuite {
  const passed = testCases.filter((tc) => tc.status === "passed").length;
  const failed = testCases.filter((tc) => tc.status === "failed").length;
  const skipped = testCases.filter((tc) => tc.status === "skipped").length;
  return {
    name,
    file: `${name}.xml`,
    tests: testCases.length,
    passed,
    failed,
    skipped,
    duration,
    testCases: testCases.map((tc) => ({
      name: tc.name,
      classname: name,
      status: tc.status,
      duration: 0.1,
    })),
  };
}

describe("Aggregate totals", () => {
  it("computes correct totals across multiple suites", () => {
    const suites: TestSuite[] = [
      makeSuite("Suite1", [
        { name: "test-a", status: "passed" },
        { name: "test-b", status: "passed" },
      ], 1.5),
      makeSuite("Suite2", [
        { name: "test-c", status: "failed" },
        { name: "test-d", status: "skipped" },
      ], 2.0),
    ];

    const results = aggregate(suites);

    expect(results.totalTests).toBe(4);
    expect(results.totalPassed).toBe(2);
    expect(results.totalFailed).toBe(1);
    expect(results.totalSkipped).toBe(1);
    expect(results.totalDuration).toBeCloseTo(3.5);
    expect(results.suites).toHaveLength(2);
  });

  it("handles empty suites list", () => {
    const results = aggregate([]);
    expect(results.totalTests).toBe(0);
    expect(results.totalPassed).toBe(0);
    expect(results.totalFailed).toBe(0);
    expect(results.totalSkipped).toBe(0);
    expect(results.totalDuration).toBe(0);
    expect(results.flakyTests).toHaveLength(0);
  });

  it("handles a single suite with all statuses", () => {
    const suites = [
      makeSuite("Suite", [
        { name: "pass1", status: "passed" },
        { name: "pass2", status: "passed" },
        { name: "fail1", status: "failed" },
        { name: "skip1", status: "skipped" },
      ], 2.5),
    ];

    const results = aggregate(suites);
    expect(results.totalTests).toBe(4);
    expect(results.totalPassed).toBe(2);
    expect(results.totalFailed).toBe(1);
    expect(results.totalSkipped).toBe(1);
    expect(results.totalDuration).toBeCloseTo(2.5);
  });
});

describe("Flaky test detection", () => {
  it("identifies tests with inconsistent results across suites", () => {
    const suites: TestSuite[] = [
      makeSuite("Run1", [{ name: "flaky-test", status: "passed" }]),
      makeSuite("Run2", [{ name: "flaky-test", status: "failed" }]),
    ];

    const flaky = findFlakyTests(suites);

    expect(flaky).toHaveLength(1);
    expect(flaky[0].name).toBe("flaky-test");
    expect(flaky[0].passCount).toBe(1);
    expect(flaky[0].failCount).toBe(1);
  });

  it("does not mark consistently passing tests as flaky", () => {
    const suites: TestSuite[] = [
      makeSuite("Run1", [{ name: "stable-test", status: "passed" }]),
      makeSuite("Run2", [{ name: "stable-test", status: "passed" }]),
    ];

    const flaky = findFlakyTests(suites);
    expect(flaky).toHaveLength(0);
  });

  it("does not mark consistently failing tests as flaky", () => {
    const suites: TestSuite[] = [
      makeSuite("Run1", [{ name: "broken-test", status: "failed" }]),
      makeSuite("Run2", [{ name: "broken-test", status: "failed" }]),
    ];

    const flaky = findFlakyTests(suites);
    expect(flaky).toHaveLength(0);
  });

  it("ignores skipped status when determining flakiness", () => {
    // Skipped tests don't contribute to pass/fail count
    const suites: TestSuite[] = [
      makeSuite("Run1", [{ name: "maybe-flaky", status: "passed" }]),
      makeSuite("Run2", [{ name: "maybe-flaky", status: "skipped" }]),
    ];

    const flaky = findFlakyTests(suites);
    expect(flaky).toHaveLength(0); // skipped + passed is NOT flaky
  });

  it("returns multiple flaky tests sorted by name", () => {
    const suites: TestSuite[] = [
      makeSuite("Run1", [
        { name: "zeta-test", status: "passed" },
        { name: "alpha-test", status: "passed" },
      ]),
      makeSuite("Run2", [
        { name: "zeta-test", status: "failed" },
        { name: "alpha-test", status: "failed" },
      ]),
    ];

    const flaky = findFlakyTests(suites);
    expect(flaky).toHaveLength(2);
    expect(flaky[0].name).toBe("alpha-test");
    expect(flaky[1].name).toBe("zeta-test");
  });

  it("counts multiple passes and failures correctly", () => {
    const suites: TestSuite[] = [
      makeSuite("Run1", [{ name: "flaky", status: "passed" }]),
      makeSuite("Run2", [{ name: "flaky", status: "passed" }]),
      makeSuite("Run3", [{ name: "flaky", status: "failed" }]),
    ];

    const flaky = findFlakyTests(suites);
    expect(flaky[0].passCount).toBe(2);
    expect(flaky[0].failCount).toBe(1);
  });
});
