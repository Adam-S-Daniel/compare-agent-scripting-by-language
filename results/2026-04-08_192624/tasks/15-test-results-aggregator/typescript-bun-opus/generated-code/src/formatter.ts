// Formatter module: generates a markdown summary suitable for GitHub Actions job summary

import type { AggregatedSummary } from "./types";

/**
 * Generate a markdown summary from aggregated test results.
 * Format is suitable for GitHub Actions $GITHUB_STEP_SUMMARY.
 */
export function formatMarkdownSummary(summary: AggregatedSummary): string {
  const lines: string[] = [];

  // Header with overall status icon
  const overallStatus = summary.totalFailed > 0 ? "FAIL" : "PASS";
  const statusIcon = summary.totalFailed > 0 ? ":x:" : ":white_check_mark:";
  lines.push(`# ${statusIcon} Test Results Summary`);
  lines.push("");

  // Overall totals table
  lines.push("## Totals");
  lines.push("");
  lines.push("| Metric | Count |");
  lines.push("|--------|-------|");
  lines.push(`| Total Tests | ${summary.totalTests} |`);
  lines.push(`| Passed | ${summary.totalPassed} |`);
  lines.push(`| Failed | ${summary.totalFailed} |`);
  lines.push(`| Skipped | ${summary.totalSkipped} |`);
  lines.push(`| Duration | ${summary.totalDuration.toFixed(2)}s |`);
  lines.push(`| Status | **${overallStatus}** |`);
  lines.push("");

  // Per-suite breakdown
  if (summary.suites.length > 0) {
    lines.push("## Suite Breakdown");
    lines.push("");
    lines.push("| Suite | Passed | Failed | Skipped | Duration |");
    lines.push("|-------|--------|--------|---------|----------|");
    for (const suite of summary.suites) {
      lines.push(
        `| ${suite.name} | ${suite.passed} | ${suite.failed} | ${suite.skipped} | ${suite.duration.toFixed(2)}s |`
      );
    }
    lines.push("");
  }

  // Flaky tests section
  if (summary.flakyTests.length > 0) {
    lines.push("## :warning: Flaky Tests");
    lines.push("");
    lines.push("These tests produced different results across runs:");
    lines.push("");
    lines.push("| Suite | Test | Pass Count | Fail Count |");
    lines.push("|-------|------|------------|------------|");
    for (const flaky of summary.flakyTests) {
      lines.push(`| ${flaky.suite} | ${flaky.name} | ${flaky.passCount} | ${flaky.failCount} |`);
    }
    lines.push("");
  }

  return lines.join("\n");
}
