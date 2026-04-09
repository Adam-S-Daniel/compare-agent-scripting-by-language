// TDD: Tests for markdown reporter
// RED phase: these tests fail until the reporter is implemented

import { describe, it, expect } from "bun:test";
import { generateMarkdownReport } from "../src/reporter";
import type { TestReport, AggregatedResults, FlakyTest } from "../src/types";

function makeReport(overrides?: Partial<TestReport>): TestReport {
  const defaultAggregated: AggregatedResults = {
    totalPassed: 10,
    totalFailed: 2,
    totalSkipped: 1,
    totalDuration: 15.5,
    suites: [
      {
        name: "com.example.AuthServiceTest",
        tests: 4,
        failures: 1,
        errors: 0,
        skipped: 1,
        duration: 2.345,
        matrixKey: "ubuntu-latest",
        testCases: [
          { name: "testLogin", className: "com.example.AuthServiceTest", duration: 0.5, status: "passed" },
          { name: "testLogout", className: "com.example.AuthServiceTest", duration: 0.3, status: "passed" },
          { name: "testLoginInvalidPassword", className: "com.example.AuthServiceTest", duration: 1.2,
            status: "failed", errorMessage: "Expected 401 but got 200", errorType: "AssertionError" },
          { name: "testRefreshToken", className: "com.example.AuthServiceTest", duration: 0.345, status: "skipped" },
        ],
      },
    ],
  };

  return {
    aggregated: defaultAggregated,
    flakyTests: [],
    ...overrides,
  };
}

describe("Markdown Reporter", () => {
  describe("generateMarkdownReport", () => {
    it("returns a non-empty string", () => {
      const report = generateMarkdownReport(makeReport());
      expect(typeof report).toBe("string");
      expect(report.length).toBeGreaterThan(0);
    });

    it("includes a heading with 'Test Results'", () => {
      const report = generateMarkdownReport(makeReport());
      expect(report).toContain("Test Results");
    });

    it("includes total passed count", () => {
      const report = generateMarkdownReport(makeReport());
      expect(report).toContain("10"); // totalPassed
    });

    it("includes total failed count", () => {
      const report = generateMarkdownReport(makeReport());
      expect(report).toContain("2"); // totalFailed
    });

    it("includes total skipped count", () => {
      const report = generateMarkdownReport(makeReport());
      expect(report).toContain("1"); // totalSkipped
    });

    it("includes duration in seconds", () => {
      const report = generateMarkdownReport(makeReport());
      expect(report).toContain("15.5");
    });

    it("lists suite names", () => {
      const report = generateMarkdownReport(makeReport());
      expect(report).toContain("com.example.AuthServiceTest");
    });

    it("shows no flaky tests section when none detected", () => {
      const report = generateMarkdownReport(makeReport({ flakyTests: [] }));
      // Should either omit the flaky section or show "No flaky tests"
      expect(report).toMatch(/no flaky|0 flaky/i);
    });

    it("shows flaky tests section when flaky tests exist", () => {
      const flakyTests: FlakyTest[] = [
        {
          name: "testLoginInvalidPassword",
          className: "com.example.AuthServiceTest",
          passedIn: ["windows-latest"],
          failedIn: ["ubuntu-latest"],
        },
      ];
      const report = generateMarkdownReport(makeReport({ flakyTests }));
      expect(report).toContain("testLoginInvalidPassword");
      expect(report).toContain("Flaky");
    });

    it("shows passed/failed matrix context for flaky tests", () => {
      const flakyTests: FlakyTest[] = [
        {
          name: "flakyTest",
          className: "com.example.Suite",
          passedIn: ["windows-latest", "macos-latest"],
          failedIn: ["ubuntu-latest"],
        },
      ];
      const report = generateMarkdownReport(makeReport({ flakyTests }));
      expect(report).toContain("windows-latest");
      expect(report).toContain("ubuntu-latest");
    });

    it("marks all-passing report with a success indicator", () => {
      const allPass = makeReport({
        aggregated: {
          totalPassed: 5,
          totalFailed: 0,
          totalSkipped: 0,
          totalDuration: 5.0,
          suites: [],
        },
        flakyTests: [],
      });
      const report = generateMarkdownReport(allPass);
      // Should contain a green/pass/success indicator
      expect(report).toMatch(/✅|:white_check_mark:|passed|success/i);
    });

    it("marks failing report with a failure indicator", () => {
      const hasFail = makeReport({
        aggregated: {
          totalPassed: 3,
          totalFailed: 2,
          totalSkipped: 0,
          totalDuration: 5.0,
          suites: [],
        },
        flakyTests: [],
      });
      const report = generateMarkdownReport(hasFail);
      // Should contain a red/fail indicator
      expect(report).toMatch(/❌|:x:|failed|failure/i);
    });

    it("includes failed test details with error messages", () => {
      const report = generateMarkdownReport(makeReport());
      // The fixture has a failed test with a known error message
      expect(report).toContain("Expected 401 but got 200");
    });
  });
});
