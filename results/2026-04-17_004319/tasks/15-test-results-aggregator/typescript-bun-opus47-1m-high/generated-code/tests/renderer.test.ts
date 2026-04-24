// TDD: tests for the markdown renderer that produces a GitHub Actions job summary.
import { describe, test, expect } from "bun:test";
import { renderMarkdown } from "../src/renderer";
import type { AggregateResult } from "../src/types";

describe("renderMarkdown", () => {
  const base: AggregateResult = {
    totals: { total: 10, passed: 7, failed: 2, skipped: 1, duration: 12.345, fileCount: 3 },
    flaky: [
      { id: "A :: flip", classname: "A", name: "flip", passedRuns: 2, failedRuns: 1, totalRuns: 3 },
    ],
    failures: [{ id: "A :: broken", message: "expected 1 got 2" }],
  };

  test("renders headline totals", () => {
    const md = renderMarkdown(base);
    expect(md).toContain("# Test Results Summary");
    expect(md).toContain("| Total | Passed | Failed | Skipped | Duration | Files |");
    expect(md).toContain("| 10 | 7 | 2 | 1 | 12.35s | 3 |");
  });

  test("renders flaky tests section when present", () => {
    const md = renderMarkdown(base);
    expect(md).toContain("## Flaky Tests");
    expect(md).toContain("A :: flip");
    expect(md).toContain("2/3");
  });

  test("renders failures section when present", () => {
    const md = renderMarkdown(base);
    expect(md).toContain("## Failures");
    expect(md).toContain("A :: broken");
    expect(md).toContain("expected 1 got 2");
  });

  test("shows an all-green badge when no failures and no flakes", () => {
    const md = renderMarkdown({
      totals: { total: 5, passed: 5, failed: 0, skipped: 0, duration: 1, fileCount: 1 },
      flaky: [],
      failures: [],
    });
    expect(md).toContain("All tests passed");
    expect(md).not.toContain("## Failures");
    expect(md).not.toContain("## Flaky Tests");
  });
});
