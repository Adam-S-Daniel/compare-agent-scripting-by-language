// TDD tests for aggregation logic and flaky test detection
// Written FIRST (red phase) before implementations exist

import { test, expect, describe } from "bun:test";
import { aggregateRuns, detectFlakyTests } from "../src/aggregator";
import type { ParsedRun } from "../src/types";

// Shared fixture data matching the fixture files
const run1: ParsedRun = {
  runId: "run1",
  suites: [
    {
      name: "SuiteA",
      runId: "run1",
      tests: [
        { name: "TestAlpha", classname: "SuiteA", duration: 0.5, status: "passed" },
        { name: "TestBeta", classname: "SuiteA", duration: 0.3, status: "passed" },
        { name: "TestFlaky", classname: "SuiteA", duration: 0.1, status: "failed", failureMessage: "assertion failed" },
      ],
    },
    {
      name: "SuiteB",
      runId: "run1",
      tests: [
        { name: "TestGamma", classname: "SuiteB", duration: 0.2, status: "passed" },
        { name: "TestDelta", classname: "SuiteB", duration: 0.0, status: "skipped" },
      ],
    },
  ],
};

const run2: ParsedRun = {
  runId: "run2",
  suites: [
    {
      name: "SuiteA",
      runId: "run2",
      tests: [
        { name: "TestAlpha", classname: "SuiteA", duration: 0.4, status: "passed" },
        { name: "TestBeta", classname: "SuiteA", duration: 0.3, status: "passed" },
        { name: "TestFlaky", classname: "SuiteA", duration: 0.2, status: "passed" }, // was failed in run1
      ],
    },
    {
      name: "SuiteB",
      runId: "run2",
      tests: [
        { name: "TestGamma", classname: "SuiteB", duration: 0.1, status: "failed", failureMessage: "timeout" }, // was passed in run1
        { name: "TestDelta", classname: "SuiteB", duration: 0.15, status: "passed" },
      ],
    },
  ],
};

const run3: ParsedRun = {
  runId: "run3",
  suites: [
    {
      name: "SuiteC",
      runId: "run3",
      tests: [
        { name: "TestEpsilon", duration: 1.0, status: "passed" },
        { name: "TestZeta", duration: 0.5, status: "passed" },
      ],
    },
  ],
};

describe("aggregateRuns", () => {
  test("counts total tests across all runs", () => {
    const result = aggregateRuns([run1, run2, run3]);
    // run1: 5 tests, run2: 5 tests, run3: 2 tests = 12 total
    expect(result.stats.totalTests).toBe(12);
  });

  test("counts passed tests correctly", () => {
    const result = aggregateRuns([run1, run2, run3]);
    // run1: TestAlpha+TestBeta+TestGamma=3, run2: TestAlpha+TestBeta+TestFlaky+TestDelta=4, run3: TestEpsilon+TestZeta=2 -> 9
    expect(result.stats.passed).toBe(9);
  });

  test("counts failed tests correctly", () => {
    const result = aggregateRuns([run1, run2, run3]);
    // run1: TestFlaky=1, run2: TestGamma=1 -> 2
    expect(result.stats.failed).toBe(2);
  });

  test("counts skipped tests correctly", () => {
    const result = aggregateRuns([run1, run2, run3]);
    // run1: TestDelta=1 -> 1
    expect(result.stats.skipped).toBe(1);
  });

  test("sums duration across all tests", () => {
    const result = aggregateRuns([run1, run2, run3]);
    // run1: 0.5+0.3+0.1+0.2+0.0=1.1, run2: 0.4+0.3+0.2+0.1+0.15=1.15, run3: 1.0+0.5=1.5 -> 3.75
    expect(result.stats.duration).toBeCloseTo(3.75, 5);
  });

  test("includes all runs in result", () => {
    const result = aggregateRuns([run1, run2, run3]);
    expect(result.runs).toHaveLength(3);
  });

  test("handles empty runs array", () => {
    const result = aggregateRuns([]);
    expect(result.stats.totalTests).toBe(0);
    expect(result.stats.passed).toBe(0);
    expect(result.stats.failed).toBe(0);
    expect(result.stats.skipped).toBe(0);
    expect(result.stats.duration).toBe(0);
  });
});

describe("detectFlakyTests", () => {
  test("identifies tests that passed in some runs and failed in others", () => {
    const flaky = detectFlakyTests([run1, run2, run3]);
    const names = flaky.map((f) => f.name).sort();
    expect(names).toEqual(["TestFlaky", "TestGamma"]);
  });

  test("records which runs each flaky test passed and failed in", () => {
    const flaky = detectFlakyTests([run1, run2, run3]);
    const flakyTest = flaky.find((f) => f.name === "TestFlaky")!;
    expect(flakyTest.failedInRuns).toContain("run1");
    expect(flakyTest.passedInRuns).toContain("run2");
  });

  test("returns empty array when no flaky tests", () => {
    const stable: ParsedRun = {
      runId: "stable",
      suites: [
        {
          name: "S",
          runId: "stable",
          tests: [
            { name: "TestA", duration: 0.1, status: "passed" },
            { name: "TestB", duration: 0.1, status: "passed" },
          ],
        },
      ],
    };
    const flaky = detectFlakyTests([stable]);
    expect(flaky).toHaveLength(0);
  });

  test("does not flag consistently failing tests as flaky", () => {
    const always: ParsedRun = {
      runId: "r",
      suites: [
        {
          name: "S",
          runId: "r",
          tests: [{ name: "TestConsistent", duration: 0.1, status: "failed" }],
        },
      ],
    };
    const flaky = detectFlakyTests([always, always]);
    expect(flaky).toHaveLength(0);
  });
});
