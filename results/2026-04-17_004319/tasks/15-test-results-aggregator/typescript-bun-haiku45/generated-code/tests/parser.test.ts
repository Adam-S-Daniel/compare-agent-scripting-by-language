import { describe, it, expect, beforeEach } from "bun:test";
import { parseJunitXml, parseJsonResults } from "../src/parser";

describe("JUnit XML Parser", () => {
  // First failing test: parse a simple JUnit XML file
  it("should parse a simple JUnit XML file with passed tests", () => {
    const xmlContent = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suite1" tests="2" failures="0" skipped="0" time="1.5">
    <testcase name="test1" classname="MyTest" time="0.5"/>
    <testcase name="test2" classname="MyTest" time="1.0"/>
  </testsuite>
</testsuites>`;

    const result = parseJunitXml(xmlContent);

    expect(result.tests).toBe(2);
    expect(result.passed).toBe(2);
    expect(result.failed).toBe(0);
    expect(result.skipped).toBe(0);
    expect(result.duration).toBe(1.5);
  });

  it("should parse JUnit XML with failed tests", () => {
    const xmlContent = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suite1" tests="3" failures="1" skipped="0" time="2.0">
    <testcase name="test1" classname="MyTest" time="0.5"/>
    <testcase name="test2" classname="MyTest" time="1.0">
      <failure message="assertion failed">Expected 5 but got 3</failure>
    </testcase>
    <testcase name="test3" classname="MyTest" time="0.5"/>
  </testsuite>
</testsuites>`;

    const result = parseJunitXml(xmlContent);

    expect(result.tests).toBe(3);
    expect(result.passed).toBe(2);
    expect(result.failed).toBe(1);
    expect(result.skipped).toBe(0);
  });

  it("should parse JUnit XML with skipped tests", () => {
    const xmlContent = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suite1" tests="3" failures="0" skipped="1" time="1.5">
    <testcase name="test1" classname="MyTest" time="0.5"/>
    <testcase name="test2" classname="MyTest" time="0.0">
      <skipped/>
    </testcase>
    <testcase name="test3" classname="MyTest" time="1.0"/>
  </testsuite>
</testsuites>`;

    const result = parseJunitXml(xmlContent);

    expect(result.tests).toBe(3);
    expect(result.passed).toBe(2);
    expect(result.failed).toBe(0);
    expect(result.skipped).toBe(1);
  });

  it("should handle multiple test suites", () => {
    const xmlContent = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suite1" tests="2" failures="0" skipped="0" time="1.0">
    <testcase name="test1" classname="MyTest1" time="0.5"/>
    <testcase name="test2" classname="MyTest1" time="0.5"/>
  </testsuite>
  <testsuite name="suite2" tests="2" failures="1" skipped="0" time="1.5">
    <testcase name="test3" classname="MyTest2" time="0.8"/>
    <testcase name="test4" classname="MyTest2" time="0.7">
      <failure/>
    </testcase>
  </testsuite>
</testsuites>`;

    const result = parseJunitXml(xmlContent);

    expect(result.tests).toBe(4);
    expect(result.passed).toBe(3);
    expect(result.failed).toBe(1);
    expect(result.skipped).toBe(0);
    expect(result.duration).toBe(2.5);
  });
});

describe("JSON Results Parser", () => {
  it("should parse a simple JSON results file", () => {
    const jsonContent = JSON.stringify({
      name: "sample-test",
      tests: [
        { name: "test1", status: "passed", duration: 100 },
        { name: "test2", status: "passed", duration: 200 }
      ]
    });

    const result = parseJsonResults(jsonContent);

    expect(result.tests).toBe(2);
    expect(result.passed).toBe(2);
    expect(result.failed).toBe(0);
    expect(result.skipped).toBe(0);
    expect(result.duration).toBe(0.3); // 300ms converted to seconds
  });

  it("should parse JSON with mixed test statuses", () => {
    const jsonContent = JSON.stringify({
      name: "mixed-tests",
      tests: [
        { name: "test1", status: "passed", duration: 100 },
        { name: "test2", status: "failed", duration: 150 },
        { name: "test3", status: "skipped", duration: 0 },
        { name: "test4", status: "passed", duration: 200 }
      ]
    });

    const result = parseJsonResults(jsonContent);

    expect(result.tests).toBe(4);
    expect(result.passed).toBe(2);
    expect(result.failed).toBe(1);
    expect(result.skipped).toBe(1);
    expect(result.duration).toBeCloseTo(0.45, 2);
  });
});
