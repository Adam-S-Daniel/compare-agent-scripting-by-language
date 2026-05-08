import { describe, expect, test } from "bun:test";
import { parseJsonResults, parseJUnitXml } from "../src/parser.ts";

// First failing test: parse a minimal JUnit XML document and recognize all three statuses.
describe("parseJUnitXml", () => {
  test("parses a single suite with passed, failed, and skipped cases", () => {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="MathSuite" tests="3" failures="1" skipped="1">
    <testcase classname="MathSuite" name="adds" time="0.5"/>
    <testcase classname="MathSuite" name="subtracts" time="0.25">
      <failure message="expected 1 got 2">stack trace here</failure>
    </testcase>
    <testcase classname="MathSuite" name="divides" time="0">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>`;

    const run = parseJUnitXml(xml, "math.xml");
    expect(run.source).toBe("math.xml");
    expect(run.suites).toHaveLength(1);
    const suite = run.suites[0]!;
    expect(suite.name).toBe("MathSuite");
    expect(suite.cases).toHaveLength(3);

    expect(suite.cases[0]).toEqual({
      classname: "MathSuite",
      name: "adds",
      status: "passed",
      duration: 0.5,
    });
    expect(suite.cases[1]).toEqual({
      classname: "MathSuite",
      name: "subtracts",
      status: "failed",
      duration: 0.25,
      message: "expected 1 got 2",
    });
    expect(suite.cases[2]).toEqual({
      classname: "MathSuite",
      name: "divides",
      status: "skipped",
      duration: 0,
    });
  });

  test("parses multiple <testsuite> elements under <testsuites>", () => {
    const xml = `<testsuites>
      <testsuite name="A"><testcase classname="A" name="a1" time="0.1"/></testsuite>
      <testsuite name="B"><testcase classname="B" name="b1" time="0.2"/></testsuite>
    </testsuites>`;
    const run = parseJUnitXml(xml, "multi.xml");
    expect(run.suites.map((s) => s.name)).toEqual(["A", "B"]);
  });

  test("treats <error> the same as <failure>", () => {
    const xml = `<testsuite name="ErrSuite">
      <testcase classname="E" name="boom" time="0.1">
        <error message="kapow">trace</error>
      </testcase>
    </testsuite>`;
    const run = parseJUnitXml(xml, "err.xml");
    expect(run.suites[0]!.cases[0]!.status).toBe("failed");
    expect(run.suites[0]!.cases[0]!.message).toBe("kapow");
  });

  test("throws a clear error on empty input", () => {
    expect(() => parseJUnitXml("", "blank.xml")).toThrow(/empty XML/);
  });

  test("throws a clear error when no <testsuite> is present", () => {
    expect(() => parseJUnitXml("<root/>", "weird.xml")).toThrow(
      /no <testsuite>/,
    );
  });
});

describe("parseJsonResults", () => {
  test("parses a JSON results document with mixed statuses", () => {
    const json = JSON.stringify({
      suites: [
        {
          name: "ApiSuite",
          tests: [
            { classname: "Api", name: "list", status: "passed", duration: 1.2 },
            {
              classname: "Api",
              name: "create",
              status: "failed",
              duration: 0.4,
              message: "500 from server",
            },
            {
              classname: "Api",
              name: "delete",
              status: "skipped",
              duration: 0,
            },
          ],
        },
      ],
    });
    const run = parseJsonResults(json, "api.json");
    expect(run.source).toBe("api.json");
    expect(run.suites).toHaveLength(1);
    expect(run.suites[0]!.cases).toHaveLength(3);
    expect(run.suites[0]!.cases[1]).toEqual({
      classname: "Api",
      name: "create",
      status: "failed",
      duration: 0.4,
      message: "500 from server",
    });
  });

  test("rejects unknown statuses with a meaningful error", () => {
    const json = JSON.stringify({
      suites: [
        {
          name: "X",
          tests: [{ classname: "X", name: "y", status: "weird", duration: 0 }],
        },
      ],
    });
    expect(() => parseJsonResults(json, "bad.json")).toThrow(
      /unknown status "weird"/,
    );
  });

  test("rejects malformed JSON with a meaningful error", () => {
    expect(() => parseJsonResults("{ not json", "bad.json")).toThrow(
      /failed to parse JSON/,
    );
  });
});
