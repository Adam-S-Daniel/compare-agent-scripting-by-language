// TDD Step 3: Formatter tests written FIRST (failing until src/formatter.ts is implemented).
// Tests verify the markdown output format and exact value rendering.

import { describe, it, expect } from "bun:test";
import { generateMarkdownSummary } from "../src/formatter";
import type { AggregatedResults } from "../src/types";

// Sample aggregated results matching our fixture scenario
const SAMPLE_RESULTS: AggregatedResults = {
  totalTests: 8,
  totalPassed: 6,
  totalFailed: 1,
  totalSkipped: 1,
  totalDuration: 4.3,
  suites: [
    {
      name: "MathOperations",
      file: "fixtures/run1/results.xml",
      tests: 3,
      passed: 3,
      failed: 0,
      skipped: 0,
      duration: 1.5,
      testCases: [],
    },
    {
      name: "MathOperations",
      file: "fixtures/run2/results.xml",
      tests: 3,
      passed: 1,
      failed: 1,
      skipped: 1,
      duration: 2.0,
      testCases: [],
    },
    {
      name: "StringOperations",
      file: "fixtures/run3/results.json",
      tests: 2,
      passed: 2,
      failed: 0,
      skipped: 0,
      duration: 0.8,
      testCases: [],
    },
  ],
  flakyTests: [{ name: "test-add", passCount: 1, failCount: 1 }],
};

describe("Markdown Summary Generator", () => {
  it("includes the main heading", () => {
    const md = generateMarkdownSummary(SAMPLE_RESULTS);
    expect(md).toContain("# Test Results Summary");
  });

  it("renders exact total tests value", () => {
    const md = generateMarkdownSummary(SAMPLE_RESULTS);
    expect(md).toContain("| Total Tests | 8 |");
  });

  it("renders exact passed count", () => {
    const md = generateMarkdownSummary(SAMPLE_RESULTS);
    expect(md).toContain("| Passed | 6 |");
  });

  it("renders exact failed count", () => {
    const md = generateMarkdownSummary(SAMPLE_RESULTS);
    expect(md).toContain("| Failed | 1 |");
  });

  it("renders exact skipped count", () => {
    const md = generateMarkdownSummary(SAMPLE_RESULTS);
    expect(md).toContain("| Skipped | 1 |");
  });

  it("renders duration with 2 decimal places", () => {
    const md = generateMarkdownSummary(SAMPLE_RESULTS);
    expect(md).toContain("| Duration | 4.30s |");
  });

  it("includes flaky tests section when flaky tests exist", () => {
    const md = generateMarkdownSummary(SAMPLE_RESULTS);
    expect(md).toContain("## Flaky Tests");
    expect(md).toContain("| test-add | 1 | 1 |");
  });

  it("shows no-flaky message when there are no flaky tests", () => {
    const results: AggregatedResults = { ...SAMPLE_RESULTS, flakyTests: [] };
    const md = generateMarkdownSummary(results);
    expect(md).toContain("No flaky tests detected");
  });

  it("includes the test suites table", () => {
    const md = generateMarkdownSummary(SAMPLE_RESULTS);
    expect(md).toContain("## Test Suites");
    expect(md).toContain("| MathOperations |");
    expect(md).toContain("| StringOperations |");
  });

  it("renders suite durations with 2 decimal places", () => {
    const md = generateMarkdownSummary(SAMPLE_RESULTS);
    expect(md).toContain("1.50s");
    expect(md).toContain("2.00s");
    expect(md).toContain("0.80s");
  });
});
