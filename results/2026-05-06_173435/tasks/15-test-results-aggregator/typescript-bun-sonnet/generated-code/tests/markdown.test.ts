// TDD tests for markdown summary generation
// Written FIRST (red phase) before implementation exists

import { test, expect, describe } from "bun:test";
import { generateMarkdownSummary } from "../src/markdown";
import type { AggregatedResults } from "../src/types";

const sampleResults: AggregatedResults = {
  stats: {
    totalTests: 12,
    passed: 9,
    failed: 2,
    skipped: 1,
    duration: 3.75,
  },
  runs: [
    { runId: "run1", suites: [] },
    { runId: "run2", suites: [] },
    { runId: "run3", suites: [] },
  ],
  flakyTests: [
    { name: "TestFlaky", passedInRuns: ["run2"], failedInRuns: ["run1"] },
    { name: "TestGamma", passedInRuns: ["run1"], failedInRuns: ["run2"] },
  ],
};

describe("generateMarkdownSummary", () => {
  test("includes heading", () => {
    const md = generateMarkdownSummary(sampleResults);
    expect(md).toContain("## Test Results Summary");
  });

  test("includes total tests count", () => {
    const md = generateMarkdownSummary(sampleResults);
    expect(md).toContain("| Total Tests | 12 |");
  });

  test("includes passed count", () => {
    const md = generateMarkdownSummary(sampleResults);
    expect(md).toContain("| Passed | 9 |");
  });

  test("includes failed count", () => {
    const md = generateMarkdownSummary(sampleResults);
    expect(md).toContain("| Failed | 2 |");
  });

  test("includes skipped count", () => {
    const md = generateMarkdownSummary(sampleResults);
    expect(md).toContain("| Skipped | 1 |");
  });

  test("includes duration", () => {
    const md = generateMarkdownSummary(sampleResults);
    expect(md).toContain("| Duration | 3.75s |");
  });

  test("includes run count", () => {
    const md = generateMarkdownSummary(sampleResults);
    expect(md).toContain("| Runs | 3 |");
  });

  test("includes flaky tests section with count", () => {
    const md = generateMarkdownSummary(sampleResults);
    expect(md).toContain("### Flaky Tests (2)");
  });

  test("lists each flaky test by name", () => {
    const md = generateMarkdownSummary(sampleResults);
    expect(md).toContain("**TestFlaky**");
    expect(md).toContain("**TestGamma**");
  });

  test("shows no flaky section when there are none", () => {
    const noFlaky: AggregatedResults = { ...sampleResults, flakyTests: [] };
    const md = generateMarkdownSummary(noFlaky);
    expect(md).toContain("### Flaky Tests (0)");
    expect(md).toContain("No flaky tests detected");
  });

  test("passes/fails counts appear in status emoji row", () => {
    const md = generateMarkdownSummary(sampleResults);
    // Should have some visual indicator that tests failed
    expect(md).toContain("Failed");
  });
});
