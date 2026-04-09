// TDD: Tests for flaky test detection
// RED phase: these tests fail until the flaky detector is implemented

import { describe, it, expect } from "bun:test";
import { detectFlakyTests } from "../src/flaky";
import type { TestSuite } from "../src/types";

// Helper to create a test suite
function makeSuite(
  name: string,
  matrixKey: string,
  testCases: Array<{ name: string; className?: string; status: "passed" | "failed" | "skipped" }>
): TestSuite {
  const cases = testCases.map((tc) => ({
    name: tc.name,
    className: tc.className ?? name,
    duration: 1.0,
    status: tc.status,
  }));
  return {
    name,
    tests: cases.length,
    failures: cases.filter((c) => c.status === "failed").length,
    errors: 0,
    skipped: cases.filter((c) => c.status === "skipped").length,
    duration: cases.length,
    testCases: cases,
    matrixKey,
  };
}

describe("Flaky Test Detection", () => {
  describe("detectFlakyTests", () => {
    it("returns empty array when all tests consistently pass", () => {
      const suites = [
        makeSuite("Suite", "ubuntu", [{ name: "testA", status: "passed" }]),
        makeSuite("Suite", "windows", [{ name: "testA", status: "passed" }]),
      ];

      const flaky = detectFlakyTests(suites);
      expect(flaky).toHaveLength(0);
    });

    it("returns empty array when all tests consistently fail", () => {
      const suites = [
        makeSuite("Suite", "ubuntu", [{ name: "testA", status: "failed" }]),
        makeSuite("Suite", "windows", [{ name: "testA", status: "failed" }]),
      ];

      const flaky = detectFlakyTests(suites);
      expect(flaky).toHaveLength(0);
    });

    it("detects a test as flaky when it passes in one run and fails in another", () => {
      const suites = [
        makeSuite("Suite", "ubuntu", [{ name: "flakyTest", status: "failed" }]),
        makeSuite("Suite", "windows", [{ name: "flakyTest", status: "passed" }]),
      ];

      const flaky = detectFlakyTests(suites);
      expect(flaky).toHaveLength(1);
      expect(flaky[0].name).toBe("flakyTest");
    });

    it("identifies which matrix keys the test passed and failed in", () => {
      const suites = [
        makeSuite("Suite", "ubuntu", [{ name: "flakyTest", status: "failed" }]),
        makeSuite("Suite", "windows", [{ name: "flakyTest", status: "passed" }]),
        makeSuite("Suite", "macos", [{ name: "flakyTest", status: "passed" }]),
      ];

      const flaky = detectFlakyTests(suites);
      expect(flaky).toHaveLength(1);
      expect(flaky[0].failedIn).toContain("ubuntu");
      expect(flaky[0].passedIn).toContain("windows");
      expect(flaky[0].passedIn).toContain("macos");
    });

    it("identifies multiple flaky tests", () => {
      const suites = [
        makeSuite("Suite", "ubuntu", [
          { name: "flaky1", status: "failed" },
          { name: "flaky2", status: "passed" },
          { name: "stable", status: "passed" },
        ]),
        makeSuite("Suite", "windows", [
          { name: "flaky1", status: "passed" },
          { name: "flaky2", status: "failed" },
          { name: "stable", status: "passed" },
        ]),
      ];

      const flaky = detectFlakyTests(suites);
      expect(flaky).toHaveLength(2);
      const names = flaky.map((f) => f.name).sort();
      expect(names).toEqual(["flaky1", "flaky2"]);
    });

    it("does not flag skipped tests as flaky even if mixed with passed/failed", () => {
      // Skipped tests are not flaky - they're intentionally skipped
      const suites = [
        makeSuite("Suite", "ubuntu", [{ name: "skippedTest", status: "skipped" }]),
        makeSuite("Suite", "windows", [{ name: "skippedTest", status: "passed" }]),
      ];

      // A test that goes from skipped to passed is not flaky - it was never executed before
      // Flakiness requires both a pass and a fail
      const flaky = detectFlakyTests(suites);
      expect(flaky).toHaveLength(0);
    });

    it("uses className+name as the unique test identifier", () => {
      // Two different classes can have tests with the same name
      const suites = [
        makeSuite("SuiteA", "ubuntu", [
          { name: "testX", className: "com.example.SuiteA", status: "failed" },
          { name: "testX", className: "com.example.SuiteB", status: "passed" },
        ]),
        makeSuite("SuiteA", "windows", [
          { name: "testX", className: "com.example.SuiteA", status: "passed" },
          { name: "testX", className: "com.example.SuiteB", status: "failed" },
        ]),
      ];

      // Both tests with same name but different classes should be detected separately
      const flaky = detectFlakyTests(suites);
      expect(flaky).toHaveLength(2);
    });

    it("detects the testLoginInvalidPassword as flaky across ubuntu and windows fixtures", () => {
      // This mirrors the fixture data: fails on ubuntu, passes on windows
      const suites = [
        makeSuite("com.example.AuthServiceTest", "ubuntu-latest", [
          { name: "testLogin", status: "passed" },
          { name: "testLoginInvalidPassword", status: "failed" },
          { name: "testLogout", status: "passed" },
        ]),
        makeSuite("com.example.AuthServiceTest", "windows-latest", [
          { name: "testLogin", status: "passed" },
          { name: "testLoginInvalidPassword", status: "passed" },
          { name: "testLogout", status: "passed" },
        ]),
      ];

      const flaky = detectFlakyTests(suites);
      expect(flaky).toHaveLength(1);
      expect(flaky[0].name).toBe("testLoginInvalidPassword");
      expect(flaky[0].failedIn).toContain("ubuntu-latest");
      expect(flaky[0].passedIn).toContain("windows-latest");
    });
  });
});
