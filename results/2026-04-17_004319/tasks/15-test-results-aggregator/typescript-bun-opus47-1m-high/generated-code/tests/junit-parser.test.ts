// TDD: tests for the JUnit XML parser.
// A JUnit XML file may contain a <testsuites> wrapper or a single <testsuite>.
// Each <testcase> has name/classname/time attributes plus optional <failure>,
// <error>, or <skipped> child elements.
import { describe, test, expect } from "bun:test";
import { parseJUnitXml } from "../src/junit-parser";

describe("parseJUnitXml", () => {
  test("parses a minimal passing testsuite", () => {
    const xml = `<?xml version="1.0"?>
<testsuite name="unit" tests="1" failures="0" errors="0" skipped="0" time="0.123">
  <testcase classname="Calc" name="adds" time="0.01"/>
</testsuite>`;
    const res = parseJUnitXml(xml);
    expect(res.suites).toHaveLength(1);
    expect(res.suites[0].name).toBe("unit");
    expect(res.suites[0].tests).toHaveLength(1);
    expect(res.suites[0].tests[0].name).toBe("adds");
    expect(res.suites[0].tests[0].classname).toBe("Calc");
    expect(res.suites[0].tests[0].status).toBe("passed");
    expect(res.suites[0].tests[0].duration).toBeCloseTo(0.01, 5);
  });

  test("parses failures, errors, and skipped cases", () => {
    const xml = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="s1" tests="3" failures="1" errors="1" skipped="1" time="1.5">
    <testcase classname="A" name="t_fail" time="0.1">
      <failure message="expected 2">boom</failure>
    </testcase>
    <testcase classname="A" name="t_err" time="0.2">
      <error message="NPE">stack</error>
    </testcase>
    <testcase classname="A" name="t_skip" time="0">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>`;
    const res = parseJUnitXml(xml);
    const statuses = res.suites[0].tests.map((t) => t.status);
    expect(statuses).toEqual(["failed", "failed", "skipped"]);
    expect(res.suites[0].tests[0].failureMessage).toBe("expected 2");
  });

  test("throws a helpful error on malformed XML", () => {
    expect(() => parseJUnitXml("not xml at all")).toThrow(/JUnit/);
  });

  test("handles multiple testsuites in a testsuites wrapper", () => {
    const xml = `<testsuites>
      <testsuite name="a" tests="1" failures="0" errors="0" skipped="0" time="0">
        <testcase classname="X" name="one" time="0"/>
      </testsuite>
      <testsuite name="b" tests="1" failures="0" errors="0" skipped="0" time="0">
        <testcase classname="Y" name="two" time="0"/>
      </testsuite>
    </testsuites>`;
    const res = parseJUnitXml(xml);
    expect(res.suites).toHaveLength(2);
    expect(res.suites.map((s) => s.name)).toEqual(["a", "b"]);
  });
});
