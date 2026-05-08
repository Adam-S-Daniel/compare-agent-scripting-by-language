import { describe, expect, test } from "bun:test";
import { aggregate } from "../src/aggregator.ts";
import { generateMarkdown } from "../src/markdown.ts";
import type { TestRun } from "../src/types.ts";

function mkRun(source: string, ...cases: Array<[string, string, "passed" | "failed" | "skipped", number]>): TestRun {
  return {
    source,
    suites: [
      {
        name: "Suite",
        cases: cases.map(([classname, name, status, duration]) => ({
          classname,
          name,
          status,
          duration,
        })),
      },
    ],
  };
}

describe("generateMarkdown", () => {
  test("renders a top-level header and totals table", () => {
    const agg = aggregate([
      mkRun("a.xml", ["S", "ok", "passed", 1.0], ["S", "bad", "failed", 0.5]),
    ]);
    const md = generateMarkdown(agg);
    expect(md).toContain("# Test Results Summary");
    expect(md).toMatch(/\| Total \| 2 \|/);
    expect(md).toMatch(/\| Passed \| 1 \|/);
    expect(md).toMatch(/\| Failed \| 1 \|/);
    expect(md).toMatch(/\| Skipped \| 0 \|/);
    // Duration printed in seconds with 2 decimals
    expect(md).toContain("1.50s");
  });

  test("declares overall status FAILED when there are failing tests", () => {
    const agg = aggregate([mkRun("a.xml", ["S", "x", "failed", 0])]);
    const md = generateMarkdown(agg);
    expect(md).toContain("**Status:** FAILED");
  });

  test("declares overall status PASSED when nothing failed", () => {
    const agg = aggregate([mkRun("a.xml", ["S", "x", "passed", 0])]);
    const md = generateMarkdown(agg);
    expect(md).toContain("**Status:** PASSED");
  });

  test("includes a Flaky Tests section listing each flaky test with its pass/fail counts", () => {
    const agg = aggregate([
      mkRun("a.xml", ["S", "flaky", "passed", 0.1]),
      mkRun("b.xml", ["S", "flaky", "failed", 0.1]),
      mkRun("c.xml", ["S", "flaky", "passed", 0.1]),
    ]);
    const md = generateMarkdown(agg);
    expect(md).toContain("## Flaky Tests");
    expect(md).toMatch(/S\.flaky/);
    expect(md).toMatch(/\| 2 \| 1 \| 3 \|/);
  });

  test("omits the Flaky Tests section when none are flaky", () => {
    const agg = aggregate([mkRun("a.xml", ["S", "ok", "passed", 0])]);
    const md = generateMarkdown(agg);
    expect(md).not.toContain("## Flaky Tests");
  });

  test("includes per-run breakdown listing each source file", () => {
    const agg = aggregate([
      mkRun("a.xml", ["S", "ok", "passed", 0.1]),
      mkRun("b.json", ["S", "ok2", "failed", 0.2]),
    ]);
    const md = generateMarkdown(agg);
    expect(md).toContain("## Per-Run Breakdown");
    expect(md).toContain("a.xml");
    expect(md).toContain("b.json");
  });
});
