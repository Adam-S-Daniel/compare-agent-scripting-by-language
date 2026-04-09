// Output formatters: convert a RotationReport to JSON or Markdown table

import type { RotationReport, SecretStatus, OutputFormat } from "./types";

/** Format the report as a pretty-printed JSON string */
export function formatJson(report: RotationReport): string {
  return JSON.stringify(report, null, 2);
}

/** Format a single status row for the markdown table */
function mdRow(s: SecretStatus): string {
  const urgencyBadge =
    s.urgency === "expired" ? "EXPIRED" :
    s.urgency === "warning" ? "WARNING" : "OK";
  return `| ${s.name} | ${urgencyBadge} | ${s.daysSinceRotation} | ${s.daysUntilExpiry} | ${s.expiryDate} | ${s.requiredBy.join(", ")} |`;
}

/** Format the report as a Markdown table grouped by urgency */
export function formatMarkdown(report: RotationReport): string {
  const lines: string[] = [];

  lines.push(`# Secret Rotation Report`);
  lines.push(``);
  lines.push(`**Generated:** ${report.generatedAt}  `);
  lines.push(`**Warning window:** ${report.warningWindowDays} days  `);
  lines.push(`**Total secrets:** ${report.secrets.length}  `);
  lines.push(`**Expired:** ${report.expired.length} | **Warning:** ${report.warning.length} | **OK:** ${report.ok.length}`);
  lines.push(``);
  lines.push(`| Name | Status | Days Since Rotation | Days Until Expiry | Expiry Date | Required By |`);
  lines.push(`|------|--------|---------------------|-------------------|-------------|-------------|`);

  // Print expired first, then warnings, then ok
  for (const s of report.expired) lines.push(mdRow(s));
  for (const s of report.warning) lines.push(mdRow(s));
  for (const s of report.ok) lines.push(mdRow(s));

  lines.push(``);
  return lines.join("\n");
}

/** Dispatch to the right formatter based on format string */
export function formatReport(report: RotationReport, format: OutputFormat): string {
  switch (format) {
    case "json":
      return formatJson(report);
    case "markdown":
      return formatMarkdown(report);
    default:
      throw new Error(`Unsupported output format: '${format}'. Use 'json' or 'markdown'.`);
  }
}
