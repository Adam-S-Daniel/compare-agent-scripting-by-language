// Render an aggregated result to markdown formatted for a GitHub Actions job
// summary (writes nicely into $GITHUB_STEP_SUMMARY). Keep tables compact so
// they fit under the summary's size limits.
import type { AggregateResult } from "./types";

function escapeCell(s: string): string {
  // Markdown tables break on unescaped pipes and newlines.
  return s.replace(/\|/g, "\\|").replace(/\r?\n/g, " ");
}

function truncate(s: string, max = 160): string {
  if (s.length <= max) return s;
  return s.slice(0, max - 3) + "...";
}

export function renderMarkdown(result: AggregateResult): string {
  const { totals, flaky, failures } = result;
  const lines: string[] = [];

  lines.push("# Test Results Summary");
  lines.push("");
  lines.push("| Total | Passed | Failed | Skipped | Duration | Files |");
  lines.push("| ----- | ------ | ------ | ------- | -------- | ----- |");
  lines.push(
    `| ${totals.total} | ${totals.passed} | ${totals.failed} | ${totals.skipped} | ${totals.duration.toFixed(2)}s | ${totals.fileCount} |`,
  );
  lines.push("");

  if (failures.length === 0 && flaky.length === 0 && totals.failed === 0) {
    lines.push("All tests passed.");
    lines.push("");
  }

  if (flaky.length > 0) {
    lines.push("## Flaky Tests");
    lines.push("");
    lines.push("| Test | Pass/Total |");
    lines.push("| ---- | ---------- |");
    for (const f of flaky) {
      lines.push(`| ${escapeCell(f.id)} | ${f.passedRuns}/${f.totalRuns} |`);
    }
    lines.push("");
  }

  if (failures.length > 0) {
    lines.push("## Failures");
    lines.push("");
    lines.push("| Test | Message |");
    lines.push("| ---- | ------- |");
    for (const f of failures) {
      lines.push(`| ${escapeCell(f.id)} | ${escapeCell(truncate(f.message))} |`);
    }
    lines.push("");
  }

  return lines.join("\n");
}
