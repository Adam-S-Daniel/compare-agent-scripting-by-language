import type { AggregatedResults } from "./types";

// Render an aggregation as a markdown summary suitable for $GITHUB_STEP_SUMMARY.
export function renderMarkdown(r: AggregatedResults): string {
  const { passed, failed, skipped, total, durationMs } = r.totals;
  const overall = failed > 0 ? "FAILED" : "PASSED";
  const seconds = (durationMs / 1000).toFixed(2);

  const lines: string[] = [];
  lines.push(`# Test Results: ${overall}`);
  lines.push("");
  lines.push(`- ${passed} passed, ${failed} failed, ${skipped} skipped (of ${total})`);
  lines.push(`- Duration: ${seconds}s`);
  lines.push(`- Runs aggregated: ${r.runs.length}`);
  lines.push("");
  lines.push("| Status | Count |");
  lines.push("| --- | --- |");
  lines.push(`| Passed | ${passed} |`);
  lines.push(`| Failed | ${failed} |`);
  lines.push(`| Skipped | ${skipped} |`);
  lines.push("");

  if (r.flaky.length > 0) {
    lines.push("## Flaky tests");
    lines.push("");
    lines.push("| Test | Passes | Failures |");
    lines.push("| --- | --- | --- |");
    for (const f of r.flaky) {
      lines.push(`| ${f.suite}::${f.name} | ${f.passes} | ${f.failures} |`);
    }
    lines.push("");
  }

  if (r.failures.length > 0) {
    lines.push("## Failures");
    lines.push("");
    for (const f of r.failures) {
      lines.push(`- **${f.suite}::${f.name}** — ${f.message ?? "(no message)"}`);
    }
    lines.push("");
  }

  return lines.join("\n");
}
