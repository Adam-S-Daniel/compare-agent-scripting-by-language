import { describe, expect, test } from "bun:test";
import { parseJUnitXml, parseJsonResults, parseFile } from "../src/parser";

describe("parseJUnitXml", () => {
  test("parses suite, cases, durations, statuses", () => {
    const xml = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="MathSuite" tests="3" failures="1" skipped="1" time="0.45">
    <testcase classname="MathSuite" name="adds" time="0.10"/>
    <testcase classname="MathSuite" name="divides" time="0.30">
      <failure message="expected 2 got 3">stack...</failure>
    </testcase>
    <testcase classname="MathSuite" name="todo" time="0.05">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>`;
    const cases = parseJUnitXml(xml);
    expect(cases).toHaveLength(3);
    expect(cases[0]).toEqual({ suite: "MathSuite", name: "adds", status: "passed", durationMs: 100 });
    expect(cases[1].status).toBe("failed");
    expect(cases[1].message).toBe("expected 2 got 3");
    expect(cases[2].status).toBe("skipped");
  });

  test("handles single testsuite root (no testsuites wrapper)", () => {
    const xml = `<testsuite name="S" tests="1" time="0.01"><testcase classname="S" name="t" time="0.01"/></testsuite>`;
    const cases = parseJUnitXml(xml);
    expect(cases).toHaveLength(1);
    expect(cases[0].suite).toBe("S");
  });

  test("throws on malformed XML", () => {
    expect(() => parseJUnitXml("not xml at all <<>>")).toThrow();
  });
});

describe("parseJsonResults", () => {
  test("parses standard JSON test report", () => {
    const json = JSON.stringify({
      suite: "ApiSuite",
      tests: [
        { name: "GET /x", status: "passed", durationMs: 12 },
        { name: "GET /y", status: "failed", durationMs: 20, message: "500" },
        { name: "GET /z", status: "skipped", durationMs: 0 },
      ],
    });
    const cases = parseJsonResults(json);
    expect(cases).toHaveLength(3);
    expect(cases[0]).toEqual({ suite: "ApiSuite", name: "GET /x", status: "passed", durationMs: 12 });
    expect(cases[1].message).toBe("500");
  });

  test("throws with helpful error on bad JSON", () => {
    expect(() => parseJsonResults("{not json")).toThrow(/JSON/i);
  });

  test("throws on missing tests array", () => {
    expect(() => parseJsonResults(JSON.stringify({ suite: "x" }))).toThrow(/tests/);
  });
});

describe("parseFile", () => {
  test("dispatches by .xml extension", () => {
    const xml = `<testsuite name="S" tests="1" time="0"><testcase classname="S" name="t" time="0"/></testsuite>`;
    expect(parseFile("any/path/results.xml", xml)).toHaveLength(1);
  });

  test("dispatches by .json extension", () => {
    const json = `{"suite":"S","tests":[{"name":"t","status":"passed","durationMs":1}]}`;
    expect(parseFile("any/path/results.json", json)).toHaveLength(1);
  });

  test("rejects unsupported extension", () => {
    expect(() => parseFile("foo.txt", "")).toThrow(/Unsupported/);
  });
});
