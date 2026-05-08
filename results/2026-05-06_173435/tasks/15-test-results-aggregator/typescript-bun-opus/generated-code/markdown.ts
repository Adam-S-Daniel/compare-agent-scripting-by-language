import type { AggregatedReport } from "./types";

export function generateMarkdown(report: AggregatedReport): string {
  const { totals, flakyTests, runs } = report;
  const passRate =
    totals.totalTests > 0
      ? ((totals.passed / totals.totalTests) * 100).toFixed(1)
      : "0.0";

  const lines: string[] = [];

  lines.push("# Test Results Summary");
  lines.push("");
  lines.push(`**Pass Rate: ${passRate}%**`);
  lines.push("");

  lines.push("## Totals");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("|--------|-------|");
  lines.push(`| Total | ${totals.totalTests} |`);
  lines.push(`| Passed | ${totals.passed} |`);
  lines.push(`| Failed | ${totals.failed} |`);
  lines.push(`| Skipped | ${totals.skipped} |`);
  lines.push(`| Duration | ${totals.duration.toFixed(2)}s |`);
  lines.push("");

  lines.push("## Flaky Tests");
  lines.push("");
  if (flakyTests.length === 0) {
    lines.push("No flaky tests detected.");
  } else {
    lines.push("| Test | Suite | Passed In | Failed In |");
    lines.push("|------|-------|-----------|-----------|");
    for (const ft of flakyTests) {
      lines.push(
        `| ${ft.name} | ${ft.suite} | ${ft.passedIn.join(", ")} | ${ft.failedIn.join(", ")} |`
      );
    }
  }
  lines.push("");

  lines.push("## Per-Run Breakdown");
  lines.push("");
  for (const run of runs) {
    const p = run.results.filter((r) => r.status === "passed").length;
    const f = run.results.filter((r) => r.status === "failed").length;
    const s = run.results.filter((r) => r.status === "skipped").length;
    const d = run.results
      .reduce((sum, r) => sum + r.duration, 0)
      .toFixed(2);
    lines.push(`### ${run.source}`);
    lines.push("");
    lines.push(`- Passed: ${p}, Failed: ${f}, Skipped: ${s}`);
    lines.push(`- Duration: ${d}s`);

    const failures = run.results.filter((r) => r.status === "failed");
    if (failures.length > 0) {
      lines.push("- Failures:");
      for (const fail of failures) {
        lines.push(`  - **${fail.suite}/${fail.name}**: ${fail.error || "No message"}`);
      }
    }
    lines.push("");
  }

  return lines.join("\n");
}
