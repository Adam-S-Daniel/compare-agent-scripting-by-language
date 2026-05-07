// Generates a GitHub Actions job summary in Markdown format

import type { AggregatedResults } from "./types";

export function generateMarkdownSummary(results: AggregatedResults): string {
  const { stats, runs, flakyTests } = results;
  const lines: string[] = [];

  lines.push("## Test Results Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("|--------|-------|");
  lines.push(`| Total Tests | ${stats.totalTests} |`);
  lines.push(`| Passed | ${stats.passed} |`);
  lines.push(`| Failed | ${stats.failed} |`);
  lines.push(`| Skipped | ${stats.skipped} |`);
  lines.push(`| Duration | ${stats.duration.toFixed(2)}s |`);
  lines.push(`| Runs | ${runs.length} |`);
  lines.push("");

  // Status indicator
  const statusEmoji = stats.failed > 0 ? "FAILED" : "PASSED";
  lines.push(`**Overall Status: ${statusEmoji}**`);
  lines.push("");

  // Flaky tests section
  lines.push(`### Flaky Tests (${flakyTests.length})`);
  lines.push("");
  if (flakyTests.length === 0) {
    lines.push("No flaky tests detected.");
  } else {
    for (const ft of flakyTests) {
      lines.push(
        `- **${ft.name}** — passed in: ${ft.passedInRuns.join(", ")}; failed in: ${ft.failedInRuns.join(", ")}`
      );
    }
  }
  lines.push("");

  return lines.join("\n");
}
