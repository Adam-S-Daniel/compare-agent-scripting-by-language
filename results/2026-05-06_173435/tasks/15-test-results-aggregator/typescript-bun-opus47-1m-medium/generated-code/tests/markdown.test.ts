import { describe, expect, test } from "bun:test";
import { renderMarkdown } from "../src/markdown";
import type { AggregatedResults } from "../src/types";

const sample: AggregatedResults = {
  totals: { passed: 3, failed: 2, skipped: 1, total: 6, durationMs: 1234 },
  flaky: [{ suite: "S", name: "flaky", passes: 1, failures: 1 }],
  failures: [
    { suite: "S", name: "broken", status: "failed", durationMs: 12, message: "boom" },
  ],
  runs: [
    { runId: "run-1", cases: [] },
    { runId: "run-2", cases: [] },
  ],
};

describe("renderMarkdown", () => {
  test("includes a heading and totals", () => {
    const md = renderMarkdown(sample);
    expect(md).toContain("# Test Results");
    expect(md).toContain("3 passed");
    expect(md).toContain("2 failed");
    expect(md).toContain("1 skipped");
  });

  test("shows duration in seconds", () => {
    const md = renderMarkdown(sample);
    expect(md).toContain("1.23s");
  });

  test("lists flaky tests in their own section", () => {
    const md = renderMarkdown(sample);
    expect(md).toMatch(/## Flaky tests[\s\S]*S::flaky/);
  });

  test("lists failures with messages", () => {
    const md = renderMarkdown(sample);
    expect(md).toMatch(/## Failures[\s\S]*S::broken[\s\S]*boom/);
  });

  test("status icon at top reflects failure state", () => {
    expect(renderMarkdown(sample)).toContain("FAILED");
    const passing: AggregatedResults = {
      ...sample,
      totals: { passed: 3, failed: 0, skipped: 0, total: 3, durationMs: 100 },
      failures: [],
      flaky: [],
    };
    expect(renderMarkdown(passing)).toContain("PASSED");
  });
});
