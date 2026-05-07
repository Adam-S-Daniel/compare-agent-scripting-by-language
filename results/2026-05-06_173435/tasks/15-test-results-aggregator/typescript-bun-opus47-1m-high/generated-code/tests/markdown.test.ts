// Markdown summary tests. The output is shown verbatim in the GitHub Actions
// job summary panel, so we assert on exact strings.
import { describe, expect, test } from "bun:test";
import { renderMarkdown } from "../src/markdown.ts";
import type { AggregatedResults } from "../src/types.ts";

const baseResult: AggregatedResults = {
  totalTests: 0,
  passed: 0,
  failed: 0,
  skipped: 0,
  totalDuration: 0,
  fileCount: 0,
  flaky: [],
  suites: [],
};

describe("renderMarkdown", () => {
  test("includes a summary table with totals and a duration in seconds", () => {
    const md = renderMarkdown({
      ...baseResult,
      totalTests: 10,
      passed: 7,
      failed: 2,
      skipped: 1,
      totalDuration: 12.5,
      fileCount: 3,
    });
    expect(md).toContain("# Test Results");
    expect(md).toContain("| Total | Passed | Failed | Skipped | Duration | Files |");
    expect(md).toContain("| 10 | 7 | 2 | 1 | 12.50s | 3 |");
  });

  test("uses an all-green status line when nothing failed", () => {
    const md = renderMarkdown({
      ...baseResult,
      totalTests: 4,
      passed: 4,
      totalDuration: 1.2,
      fileCount: 1,
    });
    expect(md).toContain("Status: all tests passed");
    expect(md).not.toContain("FAILED");
  });

  test("calls out failures explicitly", () => {
    const md = renderMarkdown({
      ...baseResult,
      totalTests: 2,
      passed: 1,
      failed: 1,
      totalDuration: 0.3,
      fileCount: 1,
      suites: [
        {
          name: "Suite",
          source: "r1.xml",
          cases: [
            { name: "ok", classname: "Suite", status: "passed", duration: 0.1 },
            {
              name: "bad",
              classname: "Suite",
              status: "failed",
              duration: 0.2,
              failureMessage: "expected 1 got 2",
            },
          ],
        },
      ],
    });
    expect(md).toMatch(/Status:.*FAILED/);
    expect(md).toContain("## Failures");
    expect(md).toContain("`Suite::bad`");
    expect(md).toContain("expected 1 got 2");
  });

  test("renders a flaky-tests section sorted by failCount", () => {
    const md = renderMarkdown({
      ...baseResult,
      totalTests: 6,
      passed: 4,
      failed: 2,
      totalDuration: 1.0,
      fileCount: 3,
      flaky: [
        { name: "shaky", classname: "S", passCount: 1, failCount: 2, totalRuns: 3 },
        { name: "wobbly", classname: "S", passCount: 2, failCount: 1, totalRuns: 3 },
      ],
    });
    expect(md).toContain("## Flaky Tests");
    expect(md).toContain("| `S::shaky` | 1 | 2 | 3 |");
    expect(md).toContain("| `S::wobbly` | 2 | 1 | 3 |");
    // Header lists Pass / Fail / Total Runs.
    expect(md).toContain("| Test | Pass | Fail | Total Runs |");
  });

  test("omits flaky section when no flaky tests are present", () => {
    const md = renderMarkdown({
      ...baseResult,
      totalTests: 1,
      passed: 1,
      totalDuration: 0.1,
      fileCount: 1,
    });
    expect(md).not.toContain("Flaky Tests");
  });

  test("escapes pipe characters in failure messages so the table doesn't break", () => {
    const md = renderMarkdown({
      ...baseResult,
      totalTests: 1,
      failed: 1,
      totalDuration: 0.1,
      fileCount: 1,
      suites: [
        {
          name: "S",
          source: "x.xml",
          cases: [
            {
              name: "t",
              classname: "S",
              status: "failed",
              duration: 0.1,
              failureMessage: "got | a | b",
            },
          ],
        },
      ],
    });
    // The pipe must be escaped so it doesn't terminate a markdown table cell.
    expect(md).toContain("got \\| a \\| b");
  });
});
