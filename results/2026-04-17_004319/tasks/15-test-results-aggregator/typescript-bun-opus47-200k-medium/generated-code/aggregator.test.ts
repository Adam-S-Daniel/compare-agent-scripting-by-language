// Tests for the test-results aggregator.
// Follows red/green TDD: each describe block represents a thin feature slice.

import { describe, expect, test } from "bun:test";
import {
  aggregate,
  findFlaky,
  parseJSON,
  parseJUnit,
  parseResultFile,
  renderMarkdown,
  type TestCase,
  type TestRun,
} from "./aggregator";

const junitSample = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suite-a" tests="3" failures="1" skipped="1" time="1.5">
    <testcase classname="A" name="passes" time="0.2"/>
    <testcase classname="A" name="flaky" time="0.3">
      <failure message="boom">boom</failure>
    </testcase>
    <testcase classname="A" name="skipme" time="0.0">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>`;

const jsonSample = JSON.stringify({
  suite: "suite-a",
  duration: 1.2,
  tests: [
    { name: "A.passes", status: "passed", duration: 0.2 },
    { name: "A.flaky", status: "passed", duration: 0.4 },
    { name: "A.skipme", status: "skipped", duration: 0 },
  ],
});

describe("parseJUnit", () => {
  test("extracts test cases with status and duration", () => {
    const run = parseJUnit(junitSample, "junit.xml");
    expect(run.source).toBe("junit.xml");
    expect(run.tests).toHaveLength(3);
    const byName = Object.fromEntries(run.tests.map((t) => [t.name, t]));
    expect(byName["A.passes"].status).toBe("passed");
    expect(byName["A.flaky"].status).toBe("failed");
    expect(byName["A.skipme"].status).toBe("skipped");
    expect(byName["A.passes"].duration).toBeCloseTo(0.2);
  });

  test("throws with a useful message on invalid XML", () => {
    expect(() => parseJUnit("not xml at all", "bad.xml")).toThrow(/bad.xml/);
  });
});

describe("parseJSON", () => {
  test("extracts test cases from JSON payload", () => {
    const run = parseJSON(jsonSample, "run.json");
    expect(run.tests).toHaveLength(3);
    expect(run.tests[0].name).toBe("A.passes");
    expect(run.tests[1].status).toBe("passed");
  });

  test("errors on malformed JSON", () => {
    expect(() => parseJSON("{bad", "bad.json")).toThrow(/bad.json/);
  });
});

describe("parseResultFile", () => {
  test("dispatches by extension", async () => {
    const tmpDir = `/tmp/agg-test-${Date.now()}`;
    await Bun.write(`${tmpDir}/a.xml`, junitSample);
    await Bun.write(`${tmpDir}/b.json`, jsonSample);
    const a = await parseResultFile(`${tmpDir}/a.xml`);
    const b = await parseResultFile(`${tmpDir}/b.json`);
    expect(a.tests).toHaveLength(3);
    expect(b.tests).toHaveLength(3);
  });

  test("rejects unknown extensions", async () => {
    expect(parseResultFile("nope.txt")).rejects.toThrow(/unsupported/i);
  });
});

describe("aggregate", () => {
  test("sums counts and durations across runs", () => {
    const runs: TestRun[] = [
      {
        source: "r1",
        duration: 1.5,
        tests: [
          { name: "t1", status: "passed", duration: 1 },
          { name: "t2", status: "failed", duration: 0.5 },
        ],
      },
      {
        source: "r2",
        duration: 0.8,
        tests: [
          { name: "t1", status: "passed", duration: 0.3 },
          { name: "t3", status: "skipped", duration: 0 },
        ],
      },
    ];
    const agg = aggregate(runs);
    expect(agg.totals.passed).toBe(2);
    expect(agg.totals.failed).toBe(1);
    expect(agg.totals.skipped).toBe(1);
    expect(agg.totals.total).toBe(4);
    expect(agg.totals.duration).toBeCloseTo(2.3);
    expect(agg.runs).toHaveLength(2);
  });
});

describe("findFlaky", () => {
  test("flags tests that both pass and fail across runs", () => {
    const runs: TestRun[] = [
      {
        source: "r1",
        duration: 0,
        tests: [
          { name: "sometimes", status: "passed", duration: 0 },
          { name: "always-pass", status: "passed", duration: 0 },
        ],
      },
      {
        source: "r2",
        duration: 0,
        tests: [
          { name: "sometimes", status: "failed", duration: 0 },
          { name: "always-pass", status: "passed", duration: 0 },
        ],
      },
    ];
    const flaky = findFlaky(runs);
    expect(flaky.map((f) => f.name)).toEqual(["sometimes"]);
    expect(flaky[0].passCount).toBe(1);
    expect(flaky[0].failCount).toBe(1);
  });

  test("skipped-only runs do not count as flaky", () => {
    const cases: TestCase[][] = [
      [{ name: "x", status: "skipped", duration: 0 }],
      [{ name: "x", status: "passed", duration: 0 }],
    ];
    const runs: TestRun[] = cases.map((tests, i) => ({
      source: `r${i}`,
      duration: 0,
      tests,
    }));
    expect(findFlaky(runs)).toEqual([]);
  });
});

describe("renderMarkdown", () => {
  test("produces a GH Actions-friendly summary", () => {
    const md = renderMarkdown({
      totals: { passed: 2, failed: 1, skipped: 1, total: 4, duration: 2.3 },
      runs: [
        {
          source: "r1",
          duration: 1.5,
          tests: [
            { name: "t1", status: "passed", duration: 1 },
            { name: "t2", status: "failed", duration: 0.5 },
          ],
        },
      ],
      flaky: [{ name: "sometimes", passCount: 1, failCount: 1 }],
    });
    expect(md).toContain("# Test Results");
    expect(md).toContain("| Passed | 2 |");
    expect(md).toContain("| Failed | 1 |");
    expect(md).toContain("Flaky");
    expect(md).toContain("sometimes");
  });
});
