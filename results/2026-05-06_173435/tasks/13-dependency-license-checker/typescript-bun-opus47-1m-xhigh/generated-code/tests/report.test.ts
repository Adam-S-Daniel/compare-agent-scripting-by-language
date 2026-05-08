// TDD tests for the compliance-report formatter.
import { describe, expect, test } from "bun:test";
import { renderReport, summarize, type Format } from "../src/report.ts";
import type { CheckResult } from "../src/checker.ts";

const sample: CheckResult[] = [
  {
    name: "evil-pkg",
    version: "1.0.0",
    source: "package.json",
    license: "GPL-3.0",
    status: "denied",
    reason: "license GPL-3.0 is on the deny-list",
  },
  {
    name: "lodash",
    version: "^4.17.21",
    source: "package.json",
    license: "MIT",
    status: "approved",
    reason: "license MIT is on the allow-list",
  },
  {
    name: "obscure",
    version: "0.1.0",
    source: "package.json",
    license: null,
    status: "unknown",
    reason: "license could not be determined",
  },
];

describe("summarize", () => {
  test("counts dependencies by status", () => {
    expect(summarize(sample)).toEqual({
      total: 3,
      approved: 1,
      denied: 1,
      unknown: 1,
    });
  });
});

describe("renderReport", () => {
  test("text format includes header, per-dep lines, and summary", () => {
    const text = renderReport(sample, "text" satisfies Format);
    expect(text).toContain("Dependency License Compliance Report");
    expect(text).toContain("[DENIED]    evil-pkg@1.0.0  GPL-3.0  license GPL-3.0 is on the deny-list");
    expect(text).toContain("[APPROVED]  lodash@^4.17.21  MIT  license MIT is on the allow-list");
    expect(text).toContain("[UNKNOWN]   obscure@0.1.0  -  license could not be determined");
    expect(text).toContain("Summary: total=3 approved=1 denied=1 unknown=1");
  });

  test("json format produces a parseable object with results and summary", () => {
    const json = renderReport(sample, "json");
    const parsed = JSON.parse(json) as {
      summary: { total: number; approved: number; denied: number; unknown: number };
      results: CheckResult[];
    };
    expect(parsed.summary).toEqual({ total: 3, approved: 1, denied: 1, unknown: 1 });
    expect(parsed.results).toHaveLength(3);
    expect(parsed.results[0]?.name).toBe("evil-pkg");
  });

  test("text format reports 'No dependencies found' for an empty result set", () => {
    const text = renderReport([], "text");
    expect(text).toContain("No dependencies found");
    expect(text).toContain("Summary: total=0 approved=0 denied=0 unknown=0");
  });
});
