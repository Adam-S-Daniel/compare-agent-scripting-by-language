// TDD: Tests for JSON test result parser
// RED phase: these tests fail until the parser is implemented

import { describe, it, expect } from "bun:test";
import { parseJsonResult } from "../src/parsers/json";
import { readFileSync } from "fs";
import { join } from "path";

const fixturesDir = join(import.meta.dir, "../fixtures");

describe("JSON Test Result Parser", () => {
  describe("parseJsonResult", () => {
    it("parses a simple JSON result object into a TestSuite", () => {
      const input = {
        suiteName: "com.example.SimpleTest",
        results: [
          { name: "testA", className: "com.example.SimpleTest", status: "passed" as const, duration: 1.0 },
          { name: "testB", className: "com.example.SimpleTest", status: "failed" as const, duration: 0.5,
            error: { type: "AssertionError", message: "Expected 1 but got 2" } },
          { name: "testC", className: "com.example.SimpleTest", status: "skipped" as const, duration: 0.0 },
        ],
      };

      const suite = parseJsonResult(input);
      expect(suite.name).toBe("com.example.SimpleTest");
      expect(suite.testCases).toHaveLength(3);
    });

    it("correctly counts tests, failures, and skipped", () => {
      const input = {
        suiteName: "SomeTest",
        results: [
          { name: "t1", className: "SomeTest", status: "passed" as const, duration: 1.0 },
          { name: "t2", className: "SomeTest", status: "failed" as const, duration: 0.5,
            error: { type: "Error", message: "oops" } },
          { name: "t3", className: "SomeTest", status: "skipped" as const, duration: 0.0 },
        ],
      };

      const suite = parseJsonResult(input);
      expect(suite.tests).toBe(3);
      expect(suite.failures).toBe(1);
      expect(suite.skipped).toBe(1);
      expect(suite.errors).toBe(0);
    });

    it("computes total duration from sum of individual test durations", () => {
      const input = {
        suiteName: "DurationTest",
        results: [
          { name: "t1", className: "DurationTest", status: "passed" as const, duration: 1.5 },
          { name: "t2", className: "DurationTest", status: "passed" as const, duration: 2.5 },
        ],
      };

      const suite = parseJsonResult(input);
      expect(suite.duration).toBeCloseTo(4.0, 2);
    });

    it("maps failed test error info to TestCase fields", () => {
      const input = {
        suiteName: "ErrorTest",
        results: [
          { name: "failTest", className: "ErrorTest", status: "failed" as const, duration: 1.0,
            error: { type: "NullPointerException", message: "null reference at line 42" } },
        ],
      };

      const suite = parseJsonResult(input);
      const tc = suite.testCases[0];
      expect(tc.status).toBe("failed");
      expect(tc.errorType).toBe("NullPointerException");
      expect(tc.errorMessage).toBe("null reference at line 42");
    });

    it("preserves matrixKey from input", () => {
      const input = {
        suiteName: "MatrixTest",
        matrixKey: "node-18",
        results: [
          { name: "t1", className: "MatrixTest", status: "passed" as const, duration: 0.5 },
        ],
      };

      const suite = parseJsonResult(input);
      expect(suite.matrixKey).toBe("node-18");
    });

    it("parses the macos fixture file correctly", () => {
      const raw = readFileSync(join(fixturesDir, "results-macos.json"), "utf-8");
      const input = JSON.parse(raw);
      const suite = parseJsonResult(input);

      expect(suite.name).toBe("com.example.PaymentServiceTest");
      expect(suite.matrixKey).toBe("macos-latest");
      expect(suite.testCases).toHaveLength(4);

      const failed = suite.testCases.filter((t) => t.status === "failed");
      expect(failed).toHaveLength(1);
      expect(failed[0].name).toBe("testPaymentTimeout");
      expect(failed[0].errorType).toBe("TimeoutException");

      const skipped = suite.testCases.filter((t) => t.status === "skipped");
      expect(skipped).toHaveLength(1);
    });

    it("throws a meaningful error for invalid JSON structure", () => {
      expect(() => parseJsonResult(null as any)).toThrow(/Invalid JSON test result/);
    });

    it("throws if suiteName is missing", () => {
      expect(() => parseJsonResult({ results: [] } as any)).toThrow(/suiteName/);
    });
  });
});
