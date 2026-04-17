// TDD: markdown summary tests.
//
// The summary lands on the GitHub Actions "Job Summary" tab so it needs to
// be fully rendered markdown — H2/H3 headings, a totals table, and a
// section that calls out flaky tests if any were found.
import { describe, expect, test } from "bun:test";
import { renderMarkdown } from "../../src/summary.ts";
import type { AggregatedReport } from "../../src/types.ts";

const baseReport = (): AggregatedReport => ({
  runs: [
    { source: "a.xml", tests: [] },
    { source: "b.json", tests: [] },
  ],
  totals: { total: 10, passed: 7, failed: 2, skipped: 1, durationMs: 12345 },
  flaky: [],
  consistentlyFailing: [],
});

describe("renderMarkdown", () => {
  test("includes an overall summary heading", () => {
    const md = renderMarkdown(baseReport());
    expect(md).toMatch(/^# Test Results Summary/m);
  });

  test("renders a totals table with passed/failed/skipped counts and duration", () => {
    const md = renderMarkdown(baseReport());
    expect(md).toContain("| Passed | Failed | Skipped | Total | Duration |");
    expect(md).toContain("| 7 | 2 | 1 | 10 | 12.35s |");
  });

  test("lists every run source", () => {
    const md = renderMarkdown(baseReport());
    expect(md).toContain("a.xml");
    expect(md).toContain("b.json");
  });

  test("omits flaky section when there are no flaky tests", () => {
    const md = renderMarkdown(baseReport());
    expect(md).not.toContain("Flaky Tests");
  });

  test("emits a flaky section when flaky tests exist", () => {
    const report = baseReport();
    report.flaky = [
      { name: "login.retries", passCount: 2, failCount: 1, failedIn: ["a.xml"] },
      { name: "cache.miss", passCount: 1, failCount: 2, failedIn: ["a.xml", "b.json"] },
    ];
    const md = renderMarkdown(report);
    expect(md).toContain("## Flaky Tests");
    expect(md).toContain("login.retries");
    expect(md).toContain("cache.miss");
    // Table header.
    expect(md).toContain("| Test | Passes | Failures | Failed In |");
  });

  test("emits a consistently-failing section when present", () => {
    const report = baseReport();
    report.consistentlyFailing = ["dead.code.path"];
    const md = renderMarkdown(report);
    expect(md).toContain("## Consistently Failing");
    expect(md).toContain("dead.code.path");
  });

  test("includes overall pass-rate percentage", () => {
    const md = renderMarkdown(baseReport());
    // 7 passed / (7 + 2) executed (skips excluded) = 77.8%
    expect(md).toContain("77.8%");
  });

  test("gracefully handles zero tests (no divide-by-zero)", () => {
    const report: AggregatedReport = {
      runs: [],
      totals: { total: 0, passed: 0, failed: 0, skipped: 0, durationMs: 0 },
      flaky: [],
      consistentlyFailing: [],
    };
    expect(() => renderMarkdown(report)).not.toThrow();
  });
});
