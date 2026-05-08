// Tests for the test-results aggregator.
// Built with red/green TDD: every interface here was validated by a failing
// test before the implementation existed.
import { describe, expect, test } from "bun:test";
import {
  parseJUnitXml,
  parseJsonResults,
  aggregate,
  renderMarkdown,
  loadFile,
  type TestRun,
} from "./aggregator";
import { writeFileSync, mkdtempSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

describe("parseJUnitXml", () => {
  test("parses a basic JUnit XML report", () => {
    const xml = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="Suite A" tests="3" failures="1" skipped="1" time="2.5">
    <testcase classname="Suite A" name="passes" time="0.5"/>
    <testcase classname="Suite A" name="fails" time="1.0">
      <failure message="boom">stack</failure>
    </testcase>
    <testcase classname="Suite A" name="skipped_one" time="0.0">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>`;
    const run = parseJUnitXml(xml, "junit-1.xml");
    expect(run.source).toBe("junit-1.xml");
    expect(run.tests).toHaveLength(3);
    expect(run.tests.find((t) => t.name === "passes")?.status).toBe("passed");
    expect(run.tests.find((t) => t.name === "fails")?.status).toBe("failed");
    expect(run.tests.find((t) => t.name === "skipped_one")?.status).toBe(
      "skipped",
    );
    expect(run.tests[0].duration).toBeCloseTo(0.5);
  });

  test("throws a clear error on malformed XML", () => {
    expect(() => parseJUnitXml("not xml at all", "bad.xml")).toThrow(
      /JUnit/i,
    );
  });
});

describe("parseJsonResults", () => {
  test("parses our internal JSON shape", () => {
    const json = JSON.stringify({
      tests: [
        { suite: "S", name: "a", status: "passed", duration: 0.1 },
        { suite: "S", name: "b", status: "failed", duration: 0.2 },
      ],
    });
    const run = parseJsonResults(json, "results.json");
    expect(run.tests).toHaveLength(2);
    expect(run.tests[1].status).toBe("failed");
  });

  test("rejects missing tests array with a useful message", () => {
    expect(() => parseJsonResults("{}", "x.json")).toThrow(/tests/);
  });
});

describe("aggregate", () => {
  const runs: TestRun[] = [
    {
      source: "run-1",
      tests: [
        { suite: "S", name: "a", status: "passed", duration: 0.1 },
        { suite: "S", name: "b", status: "failed", duration: 0.2 },
        { suite: "S", name: "c", status: "skipped", duration: 0 },
      ],
    },
    {
      source: "run-2",
      tests: [
        { suite: "S", name: "a", status: "passed", duration: 0.15 },
        { suite: "S", name: "b", status: "passed", duration: 0.18 }, // flaky
        { suite: "S", name: "c", status: "skipped", duration: 0 },
      ],
    },
  ];

  test("computes totals across runs", () => {
    const agg = aggregate(runs);
    expect(agg.totals.passed).toBe(3);
    expect(agg.totals.failed).toBe(1);
    expect(agg.totals.skipped).toBe(2);
    expect(agg.totals.total).toBe(6);
    expect(agg.totals.duration).toBeCloseTo(0.63);
  });

  test("identifies flaky tests (passed in some, failed in others)", () => {
    const agg = aggregate(runs);
    expect(agg.flaky.map((f) => f.name)).toEqual(["b"]);
  });

  test("does not flag consistently-failing tests as flaky", () => {
    const agg = aggregate([
      { source: "x", tests: [{ suite: "S", name: "z", status: "failed", duration: 0 }] },
      { source: "y", tests: [{ suite: "S", name: "z", status: "failed", duration: 0 }] },
    ]);
    expect(agg.flaky).toHaveLength(0);
    expect(agg.totals.failed).toBe(2);
  });
});

describe("renderMarkdown", () => {
  test("includes totals, flaky list, and per-suite table", () => {
    const md = renderMarkdown(
      aggregate([
        {
          source: "a",
          tests: [
            { suite: "S1", name: "ok", status: "passed", duration: 0.1 },
            { suite: "S1", name: "bad", status: "failed", duration: 0.2 },
          ],
        },
        {
          source: "b",
          tests: [
            { suite: "S1", name: "bad", status: "passed", duration: 0.1 },
          ],
        },
      ]),
    );
    expect(md).toContain("# Test Results");
    expect(md).toContain("Passed");
    expect(md).toContain("Flaky");
    expect(md).toContain("bad");
    expect(md).toContain("S1");
  });

  test("renders a clean message when no failures and no flakies", () => {
    const md = renderMarkdown(
      aggregate([
        {
          source: "a",
          tests: [{ suite: "S", name: "ok", status: "passed", duration: 0.1 }],
        },
      ]),
    );
    expect(md).toMatch(/All .* passed/i);
  });
});

describe("loadFile (auto-detect format)", () => {
  test("dispatches to the right parser by extension and content", () => {
    const dir = mkdtempSync(join(tmpdir(), "agg-"));
    const xmlPath = join(dir, "a.xml");
    const jsonPath = join(dir, "b.json");
    writeFileSync(
      xmlPath,
      `<testsuites><testsuite name="S" tests="1" failures="0"><testcase classname="S" name="t" time="0.1"/></testsuite></testsuites>`,
    );
    writeFileSync(
      jsonPath,
      JSON.stringify({
        tests: [{ suite: "S", name: "t2", status: "passed", duration: 0.2 }],
      }),
    );
    const r1 = loadFile(xmlPath);
    const r2 = loadFile(jsonPath);
    expect(r1.tests[0].name).toBe("t");
    expect(r2.tests[0].name).toBe("t2");
  });
});
