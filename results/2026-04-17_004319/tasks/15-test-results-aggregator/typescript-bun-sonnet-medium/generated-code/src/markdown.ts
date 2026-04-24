// Generates a GitHub Actions job summary in Markdown format
import type { AggregatedResults } from "./types";

export function generateMarkdown(results: AggregatedResults): string {
  const lines: string[] = [];

  lines.push("## Test Results Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("|--------|-------|");
  lines.push(`| Total Tests | ${results.totalTests} |`);
  lines.push(`| Passed | ${results.passed} |`);
  lines.push(`| Failed | ${results.failed} |`);
  lines.push(`| Skipped | ${results.skipped} |`);
  lines.push(`| Duration | ${results.duration.toFixed(2)}s |`);
  lines.push(`| Files Processed | ${results.fileCount} |`);
  lines.push("");

  if (results.flakyTests.length > 0) {
    lines.push(`## Flaky Tests (${results.flakyTests.length})`);
    lines.push("");
    lines.push("These tests passed in some runs and failed in others.");
    lines.push("");
    lines.push("| Test | Suite | Passed Runs | Failed Runs |");
    lines.push("|------|-------|-------------|-------------|");
    for (const ft of results.flakyTests) {
      lines.push(
        `| ${ft.name} | ${ft.suiteName} | ${ft.passedRuns} | ${ft.failedRuns} |`
      );
    }
    lines.push("");
  } else {
    lines.push("## Flaky Tests (0)");
    lines.push("");
    lines.push("No flaky tests detected.");
    lines.push("");
  }

  if (results.failedTests.length > 0) {
    lines.push(`## Failed Tests (${results.failedTests.length})`);
    lines.push("");
    lines.push("| Test | Suite | Run | Error |");
    lines.push("|------|-------|-----|-------|");
    for (const ft of results.failedTests) {
      const error = ft.error ?? "No error message";
      lines.push(`| ${ft.name} | ${ft.suiteName} | ${ft.runId} | ${error} |`);
    }
  } else {
    lines.push("## Failed Tests (0)");
    lines.push("");
    lines.push("All tests passed.");
  }

  return lines.join("\n");
}
