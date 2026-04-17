// Compliance report assembly and rendering.
// The JSON rendering is what the CI pipeline parses for assertions,
// while the text rendering is for humans reading logs.

import type { ComplianceEntry, ComplianceReport } from "./types.ts";

export function buildReport(entries: ComplianceEntry[]): ComplianceReport {
  const summary = { approved: 0, denied: 0, unknown: 0, total: entries.length };
  for (const e of entries) {
    summary[e.status] += 1;
  }
  return { entries, summary };
}

export function renderText(report: ComplianceReport): string {
  const lines = report.entries.map((e) => {
    const license = e.license ?? "UNKNOWN";
    return `${e.name}@${e.version} ${license} ${e.status}`;
  });
  lines.push(
    `Total: ${report.summary.total} | Approved: ${report.summary.approved} ` +
      `| Denied: ${report.summary.denied} | Unknown: ${report.summary.unknown}`,
  );
  return lines.join("\n");
}

export function renderJson(report: ComplianceReport): string {
  // Pretty-print so the CI log is readable, but still machine-parseable.
  return JSON.stringify(report, null, 2);
}
