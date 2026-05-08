// Generates a GitHub-Actions-friendly markdown summary from aggregated results.
// Output is intentionally deterministic (sorted lists, fixed-precision numbers)
// so that CI workflows can grep / assert on it.
import type { AggregatedResults, TestRun } from "./types.ts";

function fmtSeconds(s: number): string {
  return `${s.toFixed(2)}s`;
}

function tally(run: TestRun): { passed: number; failed: number; skipped: number; duration: number } {
  let passed = 0, failed = 0, skipped = 0, duration = 0;
  for (const suite of run.suites) {
    for (const tc of suite.cases) {
      duration += tc.duration;
      if (tc.status === "passed") passed += 1;
      else if (tc.status === "failed") failed += 1;
      else skipped += 1;
    }
  }
  return { passed, failed, skipped, duration };
}

export function generateMarkdown(agg: AggregatedResults): string {
  const status = agg.totalFailed > 0 ? "FAILED" : "PASSED";
  const lines: string[] = [];
  lines.push("# Test Results Summary");
  lines.push("");
  lines.push(`**Status:** ${status}`);
  lines.push("");
  lines.push(`Aggregated across ${agg.runCount} run${agg.runCount === 1 ? "" : "s"}.`);
  lines.push("");
  lines.push("## Totals");
  lines.push("");
  lines.push("| Metric | Count |");
  lines.push("|--------|-------|");
  lines.push(`| Total | ${agg.totalTests} |`);
  lines.push(`| Passed | ${agg.totalPassed} |`);
  lines.push(`| Failed | ${agg.totalFailed} |`);
  lines.push(`| Skipped | ${agg.totalSkipped} |`);
  lines.push(`| Duration | ${fmtSeconds(agg.totalDuration)} |`);
  lines.push("");

  if (agg.flakyTests.length > 0) {
    lines.push("## Flaky Tests");
    lines.push("");
    lines.push(
      `Detected ${agg.flakyTests.length} flaky test${agg.flakyTests.length === 1 ? "" : "s"} (passed in some runs, failed in others).`,
    );
    lines.push("");
    lines.push("| Test | Passed | Failed | Total |");
    lines.push("|------|--------|--------|-------|");
    for (const ft of agg.flakyTests) {
      lines.push(`| ${ft.id} | ${ft.passed} | ${ft.failed} | ${ft.total} |`);
    }
    lines.push("");
  }

  if (agg.failingTests.length > 0) {
    lines.push("## Failing Tests");
    lines.push("");
    lines.push("| Test | Message |");
    lines.push("|------|---------|");
    for (const ft of agg.failingTests) {
      const msg = (ft.message ?? "").replace(/\|/g, "\\|").replace(/\n/g, " ");
      lines.push(`| ${ft.id} | ${msg} |`);
    }
    lines.push("");
  }

  lines.push("## Per-Run Breakdown");
  lines.push("");
  lines.push("| Source | Passed | Failed | Skipped | Duration |");
  lines.push("|--------|--------|--------|---------|----------|");
  for (const r of agg.runs) {
    const t = tally(r);
    lines.push(
      `| ${r.source} | ${t.passed} | ${t.failed} | ${t.skipped} | ${fmtSeconds(t.duration)} |`,
    );
  }
  lines.push("");

  return lines.join("\n");
}
