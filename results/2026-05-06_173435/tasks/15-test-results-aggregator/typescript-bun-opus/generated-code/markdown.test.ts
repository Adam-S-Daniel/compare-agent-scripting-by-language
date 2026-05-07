import { describe, test, expect } from "bun:test";
import { generateMarkdown } from "./markdown";
import type { AggregatedReport } from "./types";

const sampleReport: AggregatedReport = {
  totals: {
    totalTests: 10,
    passed: 7,
    failed: 2,
    skipped: 1,
    duration: 24.345,
  },
  flakyTests: [
    {
      name: "session expires after timeout",
      suite: "AuthTests",
      passedIn: ["run2"],
      failedIn: ["run1"],
    },
  ],
  runs: [
    {
      source: "run1.xml",
      results: [
        {
          name: "login succeeds",
          suite: "AuthTests",
          status: "passed",
          duration: 2.1,
        },
        {
          name: "session expires after timeout",
          suite: "AuthTests",
          status: "failed",
          duration: 4.3,
          error: "Timeout",
        },
      ],
    },
    {
      source: "run2.xml",
      results: [
        {
          name: "login succeeds",
          suite: "AuthTests",
          status: "passed",
          duration: 1.9,
        },
        {
          name: "session expires after timeout",
          suite: "AuthTests",
          status: "passed",
          duration: 4.0,
        },
      ],
    },
  ],
};

describe("generateMarkdown", () => {
  test("includes title header", () => {
    const md = generateMarkdown(sampleReport);
    expect(md).toContain("# Test Results Summary");
  });

  test("includes totals section with correct values", () => {
    const md = generateMarkdown(sampleReport);
    expect(md).toContain("| Total | 10 |");
    expect(md).toContain("| Passed | 7 |");
    expect(md).toContain("| Failed | 2 |");
    expect(md).toContain("| Skipped | 1 |");
    expect(md).toContain("| Duration | 24.34s |");
  });

  test("includes flaky tests section", () => {
    const md = generateMarkdown(sampleReport);
    expect(md).toContain("## Flaky Tests");
    expect(md).toContain("session expires after timeout");
    expect(md).toContain("AuthTests");
  });

  test("includes per-run breakdown", () => {
    const md = generateMarkdown(sampleReport);
    expect(md).toContain("## Per-Run Breakdown");
    expect(md).toContain("run1.xml");
    expect(md).toContain("run2.xml");
  });

  test("shows pass rate", () => {
    const md = generateMarkdown(sampleReport);
    // 7/10 = 70%
    expect(md).toContain("70.0%");
  });

  test("report with no flaky tests says none found", () => {
    const noFlaky: AggregatedReport = {
      totals: {
        totalTests: 5,
        passed: 5,
        failed: 0,
        skipped: 0,
        duration: 3.0,
      },
      flakyTests: [],
      runs: [
        {
          source: "run1",
          results: [
            {
              name: "test1",
              suite: "S",
              status: "passed",
              duration: 1.0,
            },
          ],
        },
      ],
    };
    const md = generateMarkdown(noFlaky);
    expect(md).toContain("No flaky tests detected");
  });
});
