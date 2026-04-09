// Markdown reporter
// Generates a GitHub Actions-compatible markdown summary from aggregated test results.

import type { TestReport, FlakyTest } from "./types";

/**
 * Generate a markdown report suitable for GitHub Actions job summaries.
 * Includes totals, per-suite breakdown, failed test details, and flaky test detection.
 */
export function generateMarkdownReport(report: TestReport): string {
  const { aggregated, flakyTests } = report;
  const { totalPassed, totalFailed, totalSkipped, totalDuration, suites } = aggregated;

  const totalTests = totalPassed + totalFailed + totalSkipped;
  const statusIcon = totalFailed === 0 ? "✅" : "❌";
  const statusLabel = totalFailed === 0 ? "All tests passed" : `${totalFailed} test(s) failed`;

  const lines: string[] = [];

  // Header
  lines.push(`# Test Results ${statusIcon}`);
  lines.push("");
  lines.push(`**Status:** ${statusLabel}`);
  lines.push("");

  // Summary table
  lines.push("## Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("|--------|-------|");
  lines.push(`| Total Tests | ${totalTests} |`);
  lines.push(`| ✅ Passed | ${totalPassed} |`);
  lines.push(`| ❌ Failed | ${totalFailed} |`);
  lines.push(`| ⏭️ Skipped | ${totalSkipped} |`);
  lines.push(`| ⏱️ Duration | ${totalDuration.toFixed(2)}s |`);
  lines.push("");

  // Per-suite breakdown
  if (suites.length > 0) {
    lines.push("## Suite Breakdown");
    lines.push("");
    lines.push("| Suite | Matrix | Tests | Passed | Failed | Skipped | Duration |");
    lines.push("|-------|--------|-------|--------|--------|---------|----------|");

    for (const suite of suites) {
      const passed = suite.testCases.filter((t) => t.status === "passed").length;
      const failed = suite.testCases.filter((t) => t.status === "failed").length;
      const skipped = suite.testCases.filter((t) => t.status === "skipped").length;
      const matrixKey = suite.matrixKey ?? "—";
      lines.push(
        `| \`${suite.name}\` | ${matrixKey} | ${suite.tests} | ${passed} | ${failed} | ${skipped} | ${suite.duration.toFixed(3)}s |`
      );
    }
    lines.push("");
  }

  // Failed test details
  const failedCases = suites.flatMap((s) =>
    s.testCases
      .filter((tc) => tc.status === "failed")
      .map((tc) => ({ suite: s.name, matrixKey: s.matrixKey ?? "—", tc }))
  );

  if (failedCases.length > 0) {
    lines.push("## Failed Tests");
    lines.push("");
    for (const { suite, matrixKey, tc } of failedCases) {
      lines.push(`### ❌ \`${tc.name}\``);
      lines.push("");
      lines.push(`- **Suite:** \`${suite}\``);
      lines.push(`- **Matrix:** ${matrixKey}`);
      if (tc.errorType) lines.push(`- **Error Type:** \`${tc.errorType}\``);
      if (tc.errorMessage) lines.push(`- **Message:** ${tc.errorMessage}`);
      lines.push(`- **Duration:** ${tc.duration.toFixed(3)}s`);
      lines.push("");
    }
  }

  // Flaky test section
  lines.push("## Flaky Tests");
  lines.push("");

  if (flakyTests.length === 0) {
    lines.push("No flaky tests detected. ✨");
  } else {
    lines.push(`**${flakyTests.length} flaky test(s) detected** — passed in some runs, failed in others:`);
    lines.push("");
    for (const flaky of flakyTests) {
      lines.push(`### ⚠️ \`${flaky.name}\``);
      lines.push("");
      lines.push(`- **Class:** \`${flaky.className}\``);
      lines.push(`- **Passed in:** ${flaky.passedIn.join(", ")}`);
      lines.push(`- **Failed in:** ${flaky.failedIn.join(", ")}`);
      lines.push("");
    }
  }

  return lines.join("\n");
}
