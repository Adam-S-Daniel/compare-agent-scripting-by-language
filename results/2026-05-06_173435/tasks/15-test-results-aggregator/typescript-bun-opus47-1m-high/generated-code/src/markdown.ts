// Markdown summary suitable for GitHub Actions job summaries.
//
// The output is plain GFM — no HTML — so it renders identically when piped
// to $GITHUB_STEP_SUMMARY or pasted into a PR comment. We escape pipes in
// any user-provided text that lands in a table cell, since an unescaped pipe
// terminates the cell and silently corrupts the rendered table.

import type { AggregatedResults, TestCase, TestSuite } from "./types.ts";

function fmtSecs(s: number): string {
  // Two decimals — the JUnit `time` attribute is conventionally seconds with
  // three-decimal precision; two is plenty for a human summary.
  return `${s.toFixed(2)}s`;
}

function escapeCell(s: string): string {
  // Escape characters that have special meaning inside a markdown table cell.
  // Newlines turn into <br> so multi-line failure messages stay on one row.
  return s.replace(/\|/g, "\\|").replace(/\r?\n/g, " <br> ");
}

function qualifiedName(c: { classname: string | undefined; name: string }): string {
  return c.classname ? `${c.classname}::${c.name}` : c.name;
}

function failureRows(suites: TestSuite[]): string[] {
  const rows: string[] = [];
  for (const s of suites) {
    for (const c of s.cases) {
      if (c.status !== "failed") continue;
      rows.push(
        `| \`${escapeCell(qualifiedName(c))}\` | ${escapeCell(s.source)} | ${escapeCell(c.failureMessage ?? "(no message)")} |`,
      );
    }
  }
  return rows;
}

export function renderMarkdown(r: AggregatedResults): string {
  const status =
    r.failed === 0
      ? "Status: all tests passed"
      : `Status: **FAILED** (${r.failed} failing)`;

  const lines: string[] = [];
  lines.push("# Test Results");
  lines.push("");
  lines.push(status);
  lines.push("");
  lines.push("| Total | Passed | Failed | Skipped | Duration | Files |");
  lines.push("|------:|-------:|-------:|--------:|---------:|------:|");
  lines.push(
    `| ${r.totalTests} | ${r.passed} | ${r.failed} | ${r.skipped} | ${fmtSecs(r.totalDuration)} | ${r.fileCount} |`,
  );
  lines.push("");

  const failures = failureRows(r.suites);
  if (failures.length > 0) {
    lines.push("## Failures");
    lines.push("");
    lines.push("| Test | Source | Message |");
    lines.push("|------|--------|---------|");
    lines.push(...failures);
    lines.push("");
  }

  if (r.flaky.length > 0) {
    lines.push("## Flaky Tests");
    lines.push("");
    lines.push(
      "Tests below produced both `passed` and `failed` outcomes across runs.",
    );
    lines.push("");
    lines.push("| Test | Pass | Fail | Total Runs |");
    lines.push("|------|-----:|-----:|-----------:|");
    for (const f of r.flaky) {
      lines.push(
        `| \`${escapeCell(qualifiedName(f))}\` | ${f.passCount} | ${f.failCount} | ${f.totalRuns} |`,
      );
    }
    lines.push("");
  }

  return lines.join("\n");
}
