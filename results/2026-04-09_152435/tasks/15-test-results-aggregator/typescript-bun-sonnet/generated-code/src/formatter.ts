// Formatter module: renders AggregatedResults as a Markdown summary.
// The output is suitable for use as a GitHub Actions job summary ($GITHUB_STEP_SUMMARY).

import type { AggregatedResults } from "./types";

/**
 * Generate a Markdown summary from aggregated test results.
 * Includes an overview table, flaky tests table, and per-suite breakdown.
 */
export function generateMarkdownSummary(results: AggregatedResults): string {
  const lines: string[] = [];

  // --- Heading ---
  lines.push("# Test Results Summary");
  lines.push("");

  // --- Overview table ---
  lines.push("## Overview");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("|--------|-------|");
  lines.push(`| Total Tests | ${results.totalTests} |`);
  lines.push(`| Passed | ${results.totalPassed} |`);
  lines.push(`| Failed | ${results.totalFailed} |`);
  lines.push(`| Skipped | ${results.totalSkipped} |`);
  lines.push(`| Duration | ${results.totalDuration.toFixed(2)}s |`);
  lines.push("");

  // --- Flaky tests ---
  lines.push("## Flaky Tests");
  lines.push("");
  if (results.flakyTests.length > 0) {
    lines.push("The following tests had inconsistent results across runs:");
    lines.push("");
    lines.push("| Test Name | Passed Runs | Failed Runs |");
    lines.push("|-----------|-------------|-------------|");
    for (const ft of results.flakyTests) {
      lines.push(`| ${ft.name} | ${ft.passCount} | ${ft.failCount} |`);
    }
  } else {
    lines.push("No flaky tests detected.");
  }
  lines.push("");

  // --- Suite breakdown ---
  lines.push("## Test Suites");
  lines.push("");
  lines.push("| Suite | Tests | Passed | Failed | Skipped | Duration |");
  lines.push("|-------|-------|--------|--------|---------|----------|");
  for (const suite of results.suites) {
    lines.push(
      `| ${suite.name} | ${suite.tests} | ${suite.passed} | ${suite.failed} | ${suite.skipped} | ${suite.duration.toFixed(2)}s |`
    );
  }

  return lines.join("\n");
}
