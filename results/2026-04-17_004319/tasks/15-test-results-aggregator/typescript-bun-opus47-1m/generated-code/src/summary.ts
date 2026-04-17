// Render an AggregatedReport as markdown suitable for a GitHub Actions
// Job Summary ($GITHUB_STEP_SUMMARY).
//
// Design: keep the main totals in a single-row table so it renders as a
// compact status card at the top. Optional sections (flaky, consistently
// failing) only appear when relevant so the summary stays tight on green
// builds and expands only when something interesting happened.

import type { AggregatedReport, FlakyTest } from "./types.ts";

function formatDuration(ms: number): string {
  if (ms === 0) return "0s";
  // Display seconds with two decimals — generally enough precision for a
  // CI summary without being noisy.
  const seconds = ms / 1000;
  return `${seconds.toFixed(2)}s`;
}

function passRate(passed: number, failed: number): string {
  const executed = passed + failed;
  if (executed === 0) return "n/a";
  return `${((passed / executed) * 100).toFixed(1)}%`;
}

function escapePipe(s: string): string {
  // GFM tables use `|` as the column separator. Escape any literal pipes
  // that appear in test names / messages so the table doesn't break.
  return s.replace(/\|/g, "\\|");
}

function renderFlakyRow(f: FlakyTest): string {
  return `| ${escapePipe(f.name)} | ${f.passCount} | ${f.failCount} | ${
    f.failedIn.map(escapePipe).join(", ")
  } |`;
}

export function renderMarkdown(report: AggregatedReport): string {
  const { totals, flaky, consistentlyFailing, runs } = report;

  const lines: string[] = [];
  lines.push("# Test Results Summary");
  lines.push("");

  lines.push("| Passed | Failed | Skipped | Total | Duration |");
  lines.push("| ------ | ------ | ------- | ----- | -------- |");
  lines.push(
    `| ${totals.passed} | ${totals.failed} | ${totals.skipped} | ${totals.total} | ${
      formatDuration(totals.durationMs)
    } |`,
  );
  lines.push("");
  lines.push(`**Pass rate:** ${passRate(totals.passed, totals.failed)}`);
  lines.push("");

  lines.push("## Runs");
  if (runs.length === 0) {
    lines.push("_No runs provided._");
  } else {
    for (const r of runs) {
      const counts = r.tests.reduce(
        (a, t) => {
          if (t.status === "passed") a.p += 1;
          else if (t.status === "failed") a.f += 1;
          else a.s += 1;
          return a;
        },
        { p: 0, f: 0, s: 0 },
      );
      lines.push(`- \`${escapePipe(r.source)}\` — ${counts.p} passed, ${counts.f} failed, ${counts.s} skipped`);
    }
  }
  lines.push("");

  if (flaky.length > 0) {
    lines.push("## Flaky Tests");
    lines.push("");
    lines.push("Tests that passed in some runs and failed in others.");
    lines.push("");
    lines.push("| Test | Passes | Failures | Failed In |");
    lines.push("| ---- | ------ | -------- | --------- |");
    for (const f of flaky) lines.push(renderFlakyRow(f));
    lines.push("");
  }

  if (consistentlyFailing.length > 0) {
    lines.push("## Consistently Failing");
    lines.push("");
    for (const name of consistentlyFailing) lines.push(`- ${escapePipe(name)}`);
    lines.push("");
  }

  return lines.join("\n");
}
