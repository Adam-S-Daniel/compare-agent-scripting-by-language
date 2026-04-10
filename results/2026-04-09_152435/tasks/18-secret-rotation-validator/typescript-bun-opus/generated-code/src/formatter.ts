// Output formatters for the rotation report.
// Supports JSON and Markdown table formats.

import type { RotationReport } from "./types";

/** Format the report as pretty-printed JSON. */
export function formatAsJson(report: RotationReport): string {
  return JSON.stringify(report, null, 2);
}

/** Format the report as a Markdown document with a table and summary. */
export function formatAsMarkdown(report: RotationReport): string {
  const lines: string[] = [];

  lines.push("# Secret Rotation Report");
  lines.push("");
  lines.push(`Generated: ${report.generatedAt}`);
  lines.push(`Warning Window: ${report.warningWindowDays} days`);
  lines.push("");

  // Summary
  lines.push("## Summary");
  lines.push("");
  lines.push(`- Total: ${report.summary.total}`);
  lines.push(`- Expired: ${report.summary.expired}`);
  lines.push(`- Warning: ${report.summary.warning}`);
  lines.push(`- OK: ${report.summary.ok}`);
  lines.push("");

  // Table
  lines.push("## Details");
  lines.push("");
  lines.push("| Name | Urgency | Days Since Rotation | Days Until Expiry | Policy (days) | Required By |");
  lines.push("|------|---------|--------------------:|------------------:|--------------:|-------------|");

  for (const s of report.secrets) {
    const urgencyLabel = s.urgency.toUpperCase();
    const requiredBy = s.requiredBy.join(", ");
    lines.push(
      `| ${s.name} | ${urgencyLabel} | ${s.daysSinceRotation} | ${s.daysUntilExpiry} | ${s.rotationPolicyDays} | ${requiredBy} |`
    );
  }

  lines.push("");
  return lines.join("\n");
}
