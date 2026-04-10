// TDD Step 1: Parser tests written FIRST (failing until src/parser.ts is implemented).
// Tests cover JUnit XML and JSON formats.

import { describe, it, expect } from "bun:test";
import { parseJUnit, parseJSON, parseFile } from "../src/parser";

describe("JUnit XML Parser", () => {
  it("parses testsuite with all passing tests", () => {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="MathOperations" tests="2" failures="0" skipped="0" time="1.000">
    <testcase classname="math.add" name="test-add" time="0.500"/>
    <testcase classname="math.subtract" name="test-subtract" time="0.500"/>
  </testsuite>
</testsuites>`;

    const suites = parseJUnit(xml, "test.xml");

    expect(suites).toHaveLength(1);
    expect(suites[0].name).toBe("MathOperations");
    expect(suites[0].tests).toBe(2);
    expect(suites[0].passed).toBe(2);
    expect(suites[0].failed).toBe(0);
    expect(suites[0].skipped).toBe(0);
    expect(suites[0].duration).toBeCloseTo(1.0);
    expect(suites[0].testCases).toHaveLength(2);
    expect(suites[0].testCases[0].name).toBe("test-add");
    expect(suites[0].testCases[0].status).toBe("passed");
    expect(suites[0].testCases[0].duration).toBeCloseTo(0.5);
  });

  it("parses testcase with failure element", () => {
    const xml = `<testsuites>
  <testsuite name="Suite" tests="1" failures="1" skipped="0" time="0.600">
    <testcase classname="Suite" name="test-fail" time="0.600">
      <failure message="Expected 4 but got 5">AssertionError</failure>
    </testcase>
  </testsuite>
</testsuites>`;

    const suites = parseJUnit(xml);
    expect(suites[0].testCases[0].status).toBe("failed");
    expect(suites[0].testCases[0].errorMessage).toBe("Expected 4 but got 5");
    expect(suites[0].failed).toBe(1);
    expect(suites[0].passed).toBe(0);
  });

  it("parses testcase with skipped element", () => {
    const xml = `<testsuites>
  <testsuite name="Suite" tests="1" failures="0" skipped="1" time="0.000">
    <testcase classname="Suite" name="test-skip" time="0.000">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>`;

    const suites = parseJUnit(xml);
    expect(suites[0].testCases[0].status).toBe("skipped");
    expect(suites[0].skipped).toBe(1);
    expect(suites[0].passed).toBe(0);
  });

  it("parses multiple testsuites", () => {
    const xml = `<testsuites>
  <testsuite name="Suite1" tests="1" failures="0" skipped="0" time="0.500">
    <testcase classname="S1" name="test-a" time="0.500"/>
  </testsuite>
  <testsuite name="Suite2" tests="1" failures="0" skipped="0" time="0.300">
    <testcase classname="S2" name="test-b" time="0.300"/>
  </testsuite>
</testsuites>`;

    const suites = parseJUnit(xml);
    expect(suites).toHaveLength(2);
    expect(suites[0].name).toBe("Suite1");
    expect(suites[1].name).toBe("Suite2");
  });

  it("stores the source file path", () => {
    const xml = `<testsuites><testsuite name="S" tests="0" failures="0" skipped="0" time="0"></testsuite></testsuites>`;
    const suites = parseJUnit(xml, "fixtures/run1/results.xml");
    expect(suites[0].file).toBe("fixtures/run1/results.xml");
  });
});

describe("JSON Parser", () => {
  it("parses a JSON suite with all passing tests", () => {
    const json = JSON.stringify({
      name: "StringOperations",
      duration: 0.8,
      tests: [
        { name: "test-concat", status: "passed", duration: 0.4 },
        { name: "test-split", status: "passed", duration: 0.4 },
      ],
    });

    const suites = parseJSON(json, "test.json");

    expect(suites).toHaveLength(1);
    expect(suites[0].name).toBe("StringOperations");
    expect(suites[0].tests).toBe(2);
    expect(suites[0].passed).toBe(2);
    expect(suites[0].failed).toBe(0);
    expect(suites[0].duration).toBeCloseTo(0.8);
    expect(suites[0].testCases[0].name).toBe("test-concat");
    expect(suites[0].testCases[0].status).toBe("passed");
  });

  it("parses JSON with failed and skipped tests", () => {
    const json = JSON.stringify({
      name: "MixedSuite",
      duration: 1.0,
      tests: [
        { name: "test-pass", status: "passed", duration: 0.3 },
        {
          name: "test-fail",
          status: "failed",
          duration: 0.4,
          errorMessage: "Assertion failed",
        },
        { name: "test-skip", status: "skipped", duration: 0.0 },
      ],
    });

    const suites = parseJSON(json);
    expect(suites[0].passed).toBe(1);
    expect(suites[0].failed).toBe(1);
    expect(suites[0].skipped).toBe(1);
    expect(suites[0].testCases[1].errorMessage).toBe("Assertion failed");
  });

  it("parses an array of JSON suites", () => {
    const json = JSON.stringify([
      { name: "Suite1", duration: 0.5, tests: [{ name: "t1", status: "passed", duration: 0.5 }] },
      { name: "Suite2", duration: 0.3, tests: [{ name: "t2", status: "passed", duration: 0.3 }] },
    ]);

    const suites = parseJSON(json);
    expect(suites).toHaveLength(2);
    expect(suites[0].name).toBe("Suite1");
    expect(suites[1].name).toBe("Suite2");
  });
});

describe("parseFile dispatch", () => {
  it("dispatches to JUnit parser for .xml files", () => {
    const xml = `<testsuites><testsuite name="S" tests="0" failures="0" skipped="0" time="0"></testsuite></testsuites>`;
    const suites = parseFile(xml, "results.xml");
    expect(suites).toHaveLength(1);
  });

  it("dispatches to JSON parser for .json files", () => {
    const json = JSON.stringify({ name: "S", duration: 0, tests: [] });
    const suites = parseFile(json, "results.json");
    expect(suites).toHaveLength(1);
  });

  it("throws an error for unsupported file formats", () => {
    expect(() => parseFile("data", "results.csv")).toThrow("Unsupported file format");
  });
});
