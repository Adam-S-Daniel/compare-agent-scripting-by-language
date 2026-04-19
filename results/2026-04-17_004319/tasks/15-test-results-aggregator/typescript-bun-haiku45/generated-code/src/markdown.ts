// Generate markdown summaries for test results
import type { AggregatedResults, FlakyTest } from "./aggregator";

export function generateMarkdownSummary(
  results: AggregatedResults,
  flakyTests?: FlakyTest[]
): string {
  const lines: string[] = [];

  lines.push("# Test Results Summary");
  lines.push("");

  // Overall status
  const statusEmoji = results.totalFailed === 0 ? "✅" : "❌";
  lines.push(`${statusEmoji} **Overall Status**: ${
    results.totalFailed === 0 ? "All tests passed" : "Some tests failed"
  }`);
  lines.push("");

  // Summary table
  lines.push("## Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("|--------|-------|");
  lines.push(`| Total Tests | ${results.totalTests} |`);
  lines.push(`| Passed | ${results.totalPassed} ✅ |`);
  lines.push(`| Failed | ${results.totalFailed} ❌ |`);
  lines.push(`| Skipped | ${results.totalSkipped} ⏭️ |`);
  lines.push(`| Pass Rate | ${results.avgPassRate.toFixed(2)}% |`);
  lines.push(`| Total Duration | ${results.totalDuration.toFixed(2)}s |`);
  lines.push(`| Average Duration | ${results.avgDuration.toFixed(2)}s |`);
  lines.push(`| Runs | ${results.runCount} |`);
  lines.push("");

  // Flaky tests section
  if (flakyTests && flakyTests.length > 0) {
    lines.push("## ⚠️ Flaky Tests");
    lines.push("");
    lines.push(
      "The following tests passed in some runs but failed in others:"
    );
    lines.push("");
    lines.push("| Test Name | Pass | Fail | Flaky Rate |");
    lines.push("|-----------|------|------|------------|");

    for (const test of flakyTests) {
      lines.push(
        `| \`${test.testName}\` | ${test.passCount} | ${test.failCount} | ${test.flakyRate.toFixed(1)}% |`
      );
    }
    lines.push("");
  }

  return lines.join("\n");
}
