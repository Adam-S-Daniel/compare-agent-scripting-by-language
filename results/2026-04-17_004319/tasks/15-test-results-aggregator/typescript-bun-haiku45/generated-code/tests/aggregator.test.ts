import { describe, it, expect, beforeEach } from "bun:test";
import {
  aggregateResults,
  identifyFlakyTests,
  AggregatedResults,
} from "../src/aggregator";

describe("Results Aggregator", () => {
  it("should aggregate results from multiple sources", () => {
    const results = [
      {
        source: "run1",
        tests: 10,
        passed: 8,
        failed: 1,
        skipped: 1,
        duration: 5.5,
      },
      {
        source: "run2",
        tests: 10,
        passed: 9,
        failed: 1,
        skipped: 0,
        duration: 6.2,
      },
      {
        source: "run3",
        tests: 10,
        passed: 10,
        failed: 0,
        skipped: 0,
        duration: 4.8,
      },
    ];

    const aggregated = aggregateResults(results);

    expect(aggregated.totalTests).toBe(30);
    expect(aggregated.totalPassed).toBe(27);
    expect(aggregated.totalFailed).toBe(2);
    expect(aggregated.totalSkipped).toBe(1);
    expect(aggregated.totalDuration).toBe(16.5);
    expect(aggregated.runCount).toBe(3);
  });

  it("should calculate averages correctly", () => {
    const results = [
      {
        source: "run1",
        tests: 20,
        passed: 18,
        failed: 2,
        skipped: 0,
        duration: 10.0,
      },
      {
        source: "run2",
        tests: 20,
        passed: 19,
        failed: 1,
        skipped: 0,
        duration: 12.0,
      },
    ];

    const aggregated = aggregateResults(results);

    expect(aggregated.avgPassRate).toBeCloseTo(92.5, 1);
    expect(aggregated.avgFailRate).toBeCloseTo(7.5, 1);
    expect(aggregated.avgDuration).toBe(11.0);
  });

  it("should handle single result", () => {
    const results = [
      {
        source: "run1",
        tests: 5,
        passed: 4,
        failed: 1,
        skipped: 0,
        duration: 3.5,
      },
    ];

    const aggregated = aggregateResults(results);

    expect(aggregated.totalTests).toBe(5);
    expect(aggregated.runCount).toBe(1);
    expect(aggregated.avgPassRate).toBeCloseTo(80, 2);
  });
});

describe("Flaky Test Detection", () => {
  it("should identify flaky tests", () => {
    const testResults = [
      {
        source: "run1",
        testName: "test_login",
        status: "passed",
      },
      {
        source: "run2",
        testName: "test_login",
        status: "failed",
      },
      {
        source: "run3",
        testName: "test_login",
        status: "passed",
      },
      {
        source: "run1",
        testName: "test_checkout",
        status: "passed",
      },
      {
        source: "run2",
        testName: "test_checkout",
        status: "passed",
      },
      {
        source: "run3",
        testName: "test_checkout",
        status: "passed",
      },
    ];

    const flaky = identifyFlakyTests(testResults);

    expect(flaky.length).toBe(1);
    expect(flaky[0].testName).toBe("test_login");
    expect(flaky[0].passCount).toBe(2);
    expect(flaky[0].failCount).toBe(1);
    expect(flaky[0].totalRuns).toBe(3);
  });

  it("should not flag consistently passing tests as flaky", () => {
    const testResults = [
      {
        source: "run1",
        testName: "test_stable",
        status: "passed",
      },
      {
        source: "run2",
        testName: "test_stable",
        status: "passed",
      },
      {
        source: "run3",
        testName: "test_stable",
        status: "passed",
      },
    ];

    const flaky = identifyFlakyTests(testResults);

    expect(flaky.length).toBe(0);
  });

  it("should identify multiple flaky tests", () => {
    const testResults = [
      {
        source: "run1",
        testName: "test_api_call",
        status: "passed",
      },
      {
        source: "run2",
        testName: "test_api_call",
        status: "failed",
      },
      {
        source: "run1",
        testName: "test_db_connection",
        status: "failed",
      },
      {
        source: "run2",
        testName: "test_db_connection",
        status: "passed",
      },
    ];

    const flaky = identifyFlakyTests(testResults);

    expect(flaky.length).toBe(2);
    expect(flaky.map((t) => t.testName).sort()).toEqual([
      "test_api_call",
      "test_db_connection",
    ]);
  });
});
