// TDD tests for JUnit XML and JSON parsers
// Written FIRST (red phase) before implementations exist

import { test, expect, describe } from "bun:test";
import { parseJUnitXml, parseJsonResults } from "../src/parsers";

// --- JUnit XML Parser Tests ---

describe("parseJUnitXml", () => {
  test("parses a single passing test", () => {
    const xml = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="SuiteA" tests="1">
    <testcase name="TestAlpha" classname="SuiteA" time="0.5"/>
  </testsuite>
</testsuites>`;
    const result = parseJUnitXml(xml, "run1");
    expect(result.runId).toBe("run1");
    expect(result.suites).toHaveLength(1);
    expect(result.suites[0].name).toBe("SuiteA");
    expect(result.suites[0].tests).toHaveLength(1);
    expect(result.suites[0].tests[0].name).toBe("TestAlpha");
    expect(result.suites[0].tests[0].status).toBe("passed");
    expect(result.suites[0].tests[0].duration).toBe(0.5);
  });

  test("parses a failed test with failure message", () => {
    const xml = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="SuiteA" tests="1" failures="1">
    <testcase name="TestFlaky" classname="SuiteA" time="0.1">
      <failure message="assertion failed">Expected true but got false</failure>
    </testcase>
  </testsuite>
</testsuites>`;
    const result = parseJUnitXml(xml, "run1");
    const tc = result.suites[0].tests[0];
    expect(tc.status).toBe("failed");
    expect(tc.failureMessage).toBe("assertion failed");
  });

  test("parses a skipped test", () => {
    const xml = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="SuiteB" tests="1" skipped="1">
    <testcase name="TestDelta" classname="SuiteB" time="0.0">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>`;
    const result = parseJUnitXml(xml, "run1");
    expect(result.suites[0].tests[0].status).toBe("skipped");
  });

  test("parses multiple suites with mixed results", () => {
    const xml = `<?xml version="1.0"?>
<testsuites name="Matrix Run 1" time="1.1" tests="5" failures="1" skipped="1">
  <testsuite name="SuiteA" tests="3" failures="1" time="0.9">
    <testcase name="TestAlpha" classname="SuiteA" time="0.5"/>
    <testcase name="TestBeta" classname="SuiteA" time="0.3"/>
    <testcase name="TestFlaky" classname="SuiteA" time="0.1">
      <failure message="assertion failed">Expected true but got false</failure>
    </testcase>
  </testsuite>
  <testsuite name="SuiteB" tests="2" skipped="1" time="0.2">
    <testcase name="TestGamma" classname="SuiteB" time="0.2"/>
    <testcase name="TestDelta" classname="SuiteB" time="0.0">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>`;
    const result = parseJUnitXml(xml, "run1");
    expect(result.suites).toHaveLength(2);
    expect(result.suites[0].tests).toHaveLength(3);
    expect(result.suites[1].tests).toHaveLength(2);
    const allTests = result.suites.flatMap((s) => s.tests);
    const passed = allTests.filter((t) => t.status === "passed");
    const failed = allTests.filter((t) => t.status === "failed");
    const skipped = allTests.filter((t) => t.status === "skipped");
    expect(passed).toHaveLength(3);
    expect(failed).toHaveLength(1);
    expect(skipped).toHaveLength(1);
  });

  test("attaches runId to all suites", () => {
    const xml = `<testsuites><testsuite name="S" tests="1"><testcase name="T" time="0.1"/></testsuite></testsuites>`;
    const result = parseJUnitXml(xml, "my-run-id");
    expect(result.suites[0].runId).toBe("my-run-id");
  });

  test("throws on invalid XML", () => {
    expect(() => parseJUnitXml("not xml", "run1")).toThrow();
  });
});

// --- JSON Parser Tests ---

describe("parseJsonResults", () => {
  test("parses JSON with passing tests", () => {
    const json = JSON.stringify({
      runId: "run3",
      testSuites: [
        {
          name: "SuiteC",
          tests: [
            { name: "TestEpsilon", status: "passed", duration: 1.0 },
            { name: "TestZeta", status: "passed", duration: 0.5 },
          ],
        },
      ],
    });
    const result = parseJsonResults(json, "run3");
    expect(result.runId).toBe("run3");
    expect(result.suites).toHaveLength(1);
    expect(result.suites[0].tests).toHaveLength(2);
    expect(result.suites[0].tests[0].name).toBe("TestEpsilon");
    expect(result.suites[0].tests[0].status).toBe("passed");
    expect(result.suites[0].tests[0].duration).toBe(1.0);
  });

  test("uses filename as runId when not in JSON", () => {
    const json = JSON.stringify({
      testSuites: [
        { name: "S", tests: [{ name: "T", status: "passed", duration: 0.1 }] },
      ],
    });
    const result = parseJsonResults(json, "fallback-run");
    expect(result.runId).toBe("fallback-run");
  });

  test("throws on invalid JSON", () => {
    expect(() => parseJsonResults("{bad json}", "run1")).toThrow();
  });

  test("throws when testSuites is missing", () => {
    expect(() => parseJsonResults('{"runId":"x"}', "run1")).toThrow();
  });
});
