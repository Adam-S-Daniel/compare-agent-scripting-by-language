// TDD test suite for the aggregator. Each describe block mirrors the
// red→green evolution of one piece of functionality.
import { describe, expect, test } from "bun:test";
import {
  parseJUnitXml,
  parseJsonReport,
  parseFile,
  computeTotals,
  findFlaky,
  aggregate,
  renderMarkdown,
} from "../src/aggregator.ts";

const SAMPLE_XML = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="s1" tests="2" failures="1" time="0.5">
    <testcase name="a" classname="s1" time="0.1"/>
    <testcase name="b" classname="s1" time="0.4">
      <failure message="boom">trace</failure>
    </testcase>
  </testsuite>
</testsuites>`;

const SAMPLE_JSON = JSON.stringify({
  suites: [
    {
      name: "s1",
      tests: [
        { name: "a", classname: "s1", status: "passed", time: 0.2 },
        { name: "c", classname: "s1", status: "skipped", time: 0 },
      ],
    },
  ],
});

describe("parseJUnitXml", () => {
  test("extracts test cases with statuses", () => {
    const run = parseJUnitXml(SAMPLE_XML, "sample");
    expect(run.cases).toHaveLength(2);
    expect(run.cases[0]).toMatchObject({ name: "a", status: "passed" });
    expect(run.cases[1]).toMatchObject({
      name: "b",
      status: "failed",
      message: "boom",
    });
  });
  test("handles skipped tests", () => {
    const xml = `<testsuites><testsuite name="s"><testcase name="x" classname="s"><skipped/></testcase></testsuite></testsuites>`;
    const run = parseJUnitXml(xml);
    expect(run.cases[0].status).toBe("skipped");
  });
  test("throws on invalid XML", () => {
    expect(() => parseJUnitXml("not xml")).toThrow(/Invalid JUnit/);
  });
});

describe("parseJsonReport", () => {
  test("parses status and time fields", () => {
    const run = parseJsonReport(SAMPLE_JSON);
    expect(run.cases).toHaveLength(2);
    expect(run.cases[0].status).toBe("passed");
    expect(run.cases[1].status).toBe("skipped");
  });
  test("throws on malformed JSON", () => {
    expect(() => parseJsonReport("{bad")).toThrow(/Invalid JSON/);
  });
  test("throws on unknown status", () => {
    const bad = JSON.stringify({
      suites: [{ name: "s", tests: [{ name: "x", status: "weird" }] }],
    });
    expect(() => parseJsonReport(bad)).toThrow(/Invalid status/);
  });
});

describe("parseFile", () => {
  test("auto-detects format by extension", async () => {
    const xmlRun = await parseFile("fixtures/run1.xml");
    const jsonRun = await parseFile("fixtures/run2.json");
    expect(xmlRun.cases.length).toBeGreaterThan(0);
    expect(jsonRun.cases.length).toBeGreaterThan(0);
  });
  test("throws for missing file", async () => {
    await expect(parseFile("fixtures/nope.xml")).rejects.toThrow(/not found/);
  });
});

describe("computeTotals", () => {
  test("sums passed/failed/skipped and duration", () => {
    const run = parseJUnitXml(SAMPLE_XML);
    const t = computeTotals([run]);
    expect(t).toEqual({
      total: 2,
      passed: 1,
      failed: 1,
      skipped: 0,
      duration: 0.5,
    });
  });
  test("aggregates across runs", () => {
    const a = parseJUnitXml(SAMPLE_XML);
    const b = parseJsonReport(SAMPLE_JSON);
    const t = computeTotals([a, b]);
    expect(t.total).toBe(4);
    expect(t.passed).toBe(2);
    expect(t.failed).toBe(1);
    expect(t.skipped).toBe(1);
  });
});

describe("findFlaky", () => {
  test("identifies tests that both passed and failed", () => {
    const a = parseJUnitXml(SAMPLE_XML); // s1.a=pass, s1.b=fail
    const b = parseJsonReport(
      JSON.stringify({
        suites: [
          {
            name: "s1",
            tests: [
              { name: "a", classname: "s1", status: "failed" },
              { name: "b", classname: "s1", status: "failed" },
            ],
          },
        ],
      }),
    );
    const flaky = findFlaky([a, b]);
    expect(flaky).toHaveLength(1);
    expect(flaky[0].id).toBe("s1.a");
  });
  test("returns empty when nothing is flaky", () => {
    const run = parseJUnitXml(SAMPLE_XML);
    expect(findFlaky([run])).toEqual([]);
  });
});

describe("renderMarkdown", () => {
  test("renders totals and flaky sections", async () => {
    const runs = [
      await parseFile("fixtures/run1.xml"),
      await parseFile("fixtures/run2.json"),
      await parseFile("fixtures/run3.xml"),
    ];
    const md = renderMarkdown(aggregate(runs));
    expect(md).toContain("# Test Results");
    expect(md).toContain("## Totals");
    expect(md).toContain("| Total | 15 |");
    expect(md).toContain("| Passed | 10 |");
    expect(md).toContain("| Failed | 2 |");
    expect(md).toContain("| Skipped | 3 |");
    expect(md).toContain("## Flaky Tests");
    expect(md).toContain("auth.login_failure");
    expect(md).toContain("api.get_users");
  });
  test("shows pass banner when no failures", () => {
    const md = renderMarkdown({
      runs: [],
      totals: { total: 1, passed: 1, failed: 0, skipped: 0, duration: 0.1 },
      flaky: [],
    });
    expect(md).toContain("✅ PASS");
    expect(md).toContain("_No flaky tests detected._");
  });
});
