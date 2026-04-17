// TDD: Parser tests written first, before any parser implementation exists.
// Covers JUnit XML and JSON input formats for test-result files.
import { describe, expect, test } from "bun:test";
import { parseJUnitXml, parseJson, parseFile } from "../../src/parser.ts";

describe("parseJUnitXml", () => {
  test("parses a simple JUnit XML with passed, failed, and skipped cases", () => {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="unit" tests="3" failures="1" skipped="1" time="1.25">
    <testcase name="adds numbers" classname="math" time="0.01"/>
    <testcase name="divides numbers" classname="math" time="0.50">
      <failure message="division by zero">stack</failure>
    </testcase>
    <testcase name="subtracts numbers" classname="math" time="0.00">
      <skipped message="not implemented"/>
    </testcase>
  </testsuite>
</testsuites>`;
    const report = parseJUnitXml(xml, "run-1.xml");
    expect(report.source).toBe("run-1.xml");
    expect(report.tests).toHaveLength(3);

    const byName = Object.fromEntries(report.tests.map((t) => [t.name, t]));
    expect(byName["math.adds numbers"].status).toBe("passed");
    expect(byName["math.divides numbers"].status).toBe("failed");
    expect(byName["math.divides numbers"].failureMessage).toBe("division by zero");
    expect(byName["math.subtracts numbers"].status).toBe("skipped");
    // Duration is in milliseconds; 0.5s -> 500ms.
    expect(byName["math.divides numbers"].durationMs).toBe(500);
  });

  test("handles nested testsuites (suite within suites)", () => {
    const xml = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="outer">
    <testsuite name="inner">
      <testcase name="case_a" classname="inner" time="0.1"/>
    </testsuite>
  </testsuite>
</testsuites>`;
    const report = parseJUnitXml(xml, "nested.xml");
    expect(report.tests).toHaveLength(1);
    expect(report.tests[0].name).toBe("inner.case_a");
    expect(report.tests[0].status).toBe("passed");
  });

  test("throws a meaningful error for malformed XML", () => {
    expect(() => parseJUnitXml("<not-xml", "bad.xml")).toThrow(/bad\.xml/);
  });
});

describe("parseJson", () => {
  test("parses native JSON test-result format", () => {
    const json = JSON.stringify({
      tests: [
        { name: "login works", status: "passed", durationMs: 120 },
        { name: "logout works", status: "failed", durationMs: 80, failureMessage: "token expired" },
        { name: "reset password", status: "skipped", durationMs: 0 },
      ],
    });
    const report = parseJson(json, "run-2.json");
    expect(report.source).toBe("run-2.json");
    expect(report.tests).toHaveLength(3);
    expect(report.tests[1].failureMessage).toBe("token expired");
  });

  test("rejects JSON missing a tests array", () => {
    expect(() => parseJson("{}", "broken.json")).toThrow(/tests/);
  });
});

describe("parseFile", () => {
  test("dispatches by extension", async () => {
    const xmlReport = await parseFile("fixtures/run-1.xml");
    expect(xmlReport.tests.length).toBeGreaterThan(0);

    const jsonReport = await parseFile("fixtures/run-2.json");
    expect(jsonReport.tests.length).toBeGreaterThan(0);
  });

  test("rejects unsupported extensions", async () => {
    await expect(parseFile("fixtures/unknown.txt")).rejects.toThrow(/unsupported/i);
  });
});
