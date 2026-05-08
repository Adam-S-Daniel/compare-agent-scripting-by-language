// Red/green TDD: parser tests written first, then minimum impl in src/parsers.ts.
import { describe, expect, test } from "bun:test";
import { parseJUnitXml, parseJsonResults } from "../src/parsers.ts";

describe("parseJUnitXml", () => {
  test("parses a passing test case with duration", () => {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="suite-a" tests="1" failures="0" skipped="0" time="0.123">
  <testcase name="adds 1+1" classname="MathSpec" time="0.123"/>
</testsuite>`;
    const suites = parseJUnitXml(xml, "junit-a.xml");
    expect(suites).toHaveLength(1);
    expect(suites[0].name).toBe("suite-a");
    expect(suites[0].cases).toHaveLength(1);
    expect(suites[0].cases[0]).toEqual({
      name: "adds 1+1",
      classname: "MathSpec",
      status: "passed",
      duration: 0.123,
    });
  });

  test("identifies failed and skipped cases", () => {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="mixed" tests="3" failures="1" skipped="1" time="1.5">
  <testcase name="ok" time="0.5"/>
  <testcase name="bad" time="0.5">
    <failure message="boom" type="AssertionError">expected 1 got 2</failure>
  </testcase>
  <testcase name="todo" time="0.5">
    <skipped/>
  </testcase>
</testsuite>`;
    const [suite] = parseJUnitXml(xml, "mixed.xml");
    const byName = Object.fromEntries(suite.cases.map((c) => [c.name, c]));
    expect(byName.ok.status).toBe("passed");
    expect(byName.bad.status).toBe("failed");
    expect(byName.bad.failureMessage).toContain("boom");
    expect(byName.todo.status).toBe("skipped");
  });

  test("supports a top-level <testsuites> wrapper with multiple suites", () => {
    const xml = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="s1" tests="1" failures="0" time="0.1">
    <testcase name="a" time="0.1"/>
  </testsuite>
  <testsuite name="s2" tests="1" failures="1" time="0.2">
    <testcase name="b" time="0.2">
      <failure message="x">trace</failure>
    </testcase>
  </testsuite>
</testsuites>`;
    const suites = parseJUnitXml(xml, "multi.xml");
    expect(suites.map((s) => s.name)).toEqual(["s1", "s2"]);
  });

  test("treats <error> the same as <failure>", () => {
    const xml = `<testsuite name="err" tests="1" errors="1" time="0.1">
  <testcase name="explodes" time="0.1">
    <error message="ENOENT" type="Error">stack...</error>
  </testcase>
</testsuite>`;
    const [suite] = parseJUnitXml(xml, "err.xml");
    expect(suite.cases[0].status).toBe("failed");
    expect(suite.cases[0].failureMessage).toContain("ENOENT");
  });

  test("rejects malformed XML with a meaningful error", () => {
    expect(() => parseJUnitXml("not xml at all", "bad.xml")).toThrow(
      /bad.xml/,
    );
  });
});

describe("parseJsonResults", () => {
  test("parses the documented JSON shape", () => {
    const json = JSON.stringify({
      suite: "json-suite",
      tests: [
        { name: "passes", status: "passed", duration: 0.05 },
        {
          name: "fails",
          status: "failed",
          duration: 0.1,
          message: "expected true",
        },
        { name: "todo", status: "skipped", duration: 0 },
      ],
    });
    const [suite] = parseJsonResults(json, "results.json");
    expect(suite.name).toBe("json-suite");
    expect(suite.cases).toHaveLength(3);
    expect(suite.cases[1]).toEqual({
      name: "fails",
      classname: undefined,
      status: "failed",
      duration: 0.1,
      failureMessage: "expected true",
    });
  });

  test("accepts an array of suites", () => {
    const json = JSON.stringify([
      {
        suite: "a",
        tests: [{ name: "t1", status: "passed", duration: 0.1 }],
      },
      {
        suite: "b",
        tests: [{ name: "t2", status: "passed", duration: 0.2 }],
      },
    ]);
    const suites = parseJsonResults(json, "arr.json");
    expect(suites.map((s) => s.name)).toEqual(["a", "b"]);
  });

  test("rejects unknown status values", () => {
    const json = JSON.stringify({
      suite: "x",
      tests: [{ name: "t", status: "weird", duration: 0 }],
    });
    expect(() => parseJsonResults(json, "x.json")).toThrow(/status/);
  });

  test("rejects malformed JSON", () => {
    expect(() => parseJsonResults("{not json", "bad.json")).toThrow(
      /bad.json/,
    );
  });
});
