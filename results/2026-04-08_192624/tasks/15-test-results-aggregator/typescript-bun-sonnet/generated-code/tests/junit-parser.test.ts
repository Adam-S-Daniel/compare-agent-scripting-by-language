// TDD: Tests for JUnit XML parser
// RED phase: these tests fail until the parser is implemented

import { describe, it, expect } from "bun:test";
import { parseJUnitXml } from "../src/parsers/junit";
import type { TestSuite } from "../src/types";
import { readFileSync } from "fs";
import { join } from "path";

const fixturesDir = join(import.meta.dir, "../fixtures");

describe("JUnit XML Parser", () => {
  describe("parseJUnitXml", () => {
    it("parses a valid JUnit XML string and returns TestSuite array", () => {
      const xml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="com.example.SomeTest" tests="2" failures="0" errors="0" skipped="0" time="1.0">
    <testcase name="testFoo" classname="com.example.SomeTest" time="0.5"/>
    <testcase name="testBar" classname="com.example.SomeTest" time="0.5"/>
  </testsuite>
</testsuites>`;

      const suites = parseJUnitXml(xml);
      expect(suites).toHaveLength(1);
      expect(suites[0].name).toBe("com.example.SomeTest");
      expect(suites[0].testCases).toHaveLength(2);
    });

    it("correctly marks passing tests", () => {
      const xml = `<testsuites>
  <testsuite name="Suite" tests="1" failures="0" errors="0" skipped="0" time="1.0">
    <testcase name="passingTest" classname="Suite" time="1.0"/>
  </testsuite>
</testsuites>`;

      const suites = parseJUnitXml(xml);
      expect(suites[0].testCases[0].status).toBe("passed");
    });

    it("correctly marks failing tests with failure element", () => {
      const xml = `<testsuites>
  <testsuite name="Suite" tests="1" failures="1" errors="0" skipped="0" time="1.0">
    <testcase name="failingTest" classname="Suite" time="1.0">
      <failure type="AssertionError" message="Expected true but got false">stack trace</failure>
    </testcase>
  </testsuite>
</testsuites>`;

      const suites = parseJUnitXml(xml);
      const tc = suites[0].testCases[0];
      expect(tc.status).toBe("failed");
      expect(tc.errorMessage).toBe("Expected true but got false");
      expect(tc.errorType).toBe("AssertionError");
    });

    it("correctly marks skipped tests", () => {
      const xml = `<testsuites>
  <testsuite name="Suite" tests="1" failures="0" errors="0" skipped="1" time="0.5">
    <testcase name="skippedTest" classname="Suite" time="0.0">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>`;

      const suites = parseJUnitXml(xml);
      expect(suites[0].testCases[0].status).toBe("skipped");
    });

    it("handles error elements like failures", () => {
      const xml = `<testsuites>
  <testsuite name="Suite" tests="1" failures="0" errors="1" skipped="0" time="1.0">
    <testcase name="errorTest" classname="Suite" time="1.0">
      <error type="RuntimeException" message="Unexpected null pointer">trace</error>
    </testcase>
  </testsuite>
</testsuites>`;

      const suites = parseJUnitXml(xml);
      const tc = suites[0].testCases[0];
      expect(tc.status).toBe("failed");
      expect(tc.errorType).toBe("RuntimeException");
    });

    it("parses duration correctly from time attribute", () => {
      const xml = `<testsuites>
  <testsuite name="Suite" tests="1" failures="0" errors="0" skipped="0" time="2.345">
    <testcase name="test1" classname="Suite" time="2.345"/>
  </testsuite>
</testsuites>`;

      const suites = parseJUnitXml(xml);
      expect(suites[0].duration).toBeCloseTo(2.345, 3);
      expect(suites[0].testCases[0].duration).toBeCloseTo(2.345, 3);
    });

    it("parses multiple suites from testsuites element", () => {
      const xml = `<testsuites>
  <testsuite name="SuiteA" tests="1" failures="0" errors="0" skipped="0" time="1.0">
    <testcase name="testA" classname="SuiteA" time="1.0"/>
  </testsuite>
  <testsuite name="SuiteB" tests="1" failures="0" errors="0" skipped="0" time="2.0">
    <testcase name="testB" classname="SuiteB" time="2.0"/>
  </testsuite>
</testsuites>`;

      const suites = parseJUnitXml(xml);
      expect(suites).toHaveLength(2);
      expect(suites[0].name).toBe("SuiteA");
      expect(suites[1].name).toBe("SuiteB");
    });

    it("attaches matrixKey when provided", () => {
      const xml = `<testsuites>
  <testsuite name="Suite" tests="1" failures="0" errors="0" skipped="0" time="1.0">
    <testcase name="test1" classname="Suite" time="1.0"/>
  </testsuite>
</testsuites>`;

      const suites = parseJUnitXml(xml, "ubuntu-latest");
      expect(suites[0].matrixKey).toBe("ubuntu-latest");
    });

    it("parses the ubuntu fixture file correctly", () => {
      const xml = readFileSync(join(fixturesDir, "junit-ubuntu.xml"), "utf-8");
      const suites = parseJUnitXml(xml, "ubuntu-latest");

      // Two suites
      expect(suites).toHaveLength(2);

      // Auth suite: 4 tests, 1 failure, 1 skipped
      const authSuite = suites[0];
      expect(authSuite.name).toBe("com.example.AuthServiceTest");
      expect(authSuite.testCases).toHaveLength(4);

      const failedTests = authSuite.testCases.filter((t) => t.status === "failed");
      expect(failedTests).toHaveLength(1);
      expect(failedTests[0].name).toBe("testLoginInvalidPassword");

      const skippedTests = authSuite.testCases.filter((t) => t.status === "skipped");
      expect(skippedTests).toHaveLength(1);
      expect(skippedTests[0].name).toBe("testRefreshToken");
    });

    it("throws a meaningful error for invalid XML", () => {
      expect(() => parseJUnitXml("this is not xml at all!!!")).toThrow();
    });
  });
});
