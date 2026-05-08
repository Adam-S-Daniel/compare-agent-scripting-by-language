// Report formatters: converts a RotationReport to markdown table or JSON.

import type { RotationReport, SecretStatus } from "./types";

// Render a single markdown table of SecretStatus entries.
function renderTable(rows: SecretStatus[]): string {
  if (rows.length === 0) {
    return "_None_\n";
  }
  const header =
    "| Secret | Required By | Last Rotated | Days Since Rotation | Days Until Expiry |\n" +
    "|--------|-------------|--------------|---------------------|-------------------|\n";
  const body = rows
    .map(
      (r) =>
        `| ${r.secret.name} | ${r.secret.requiredBy.join(", ")} | ${r.secret.lastRotated} | ${r.daysSinceRotation} | ${r.daysUntilExpiry} |`
    )
    .join("\n");
  return header + body + "\n";
}

// Format a RotationReport as a GitHub-flavored markdown document.
export function formatMarkdown(report: RotationReport): string {
  const lines: string[] = [
    "# Secret Rotation Report",
    "",
    `**Generated:** ${report.generatedAt}`,
    `**Reference Date:** ${report.referenceDate}`,
    `**Warning Window:** ${report.warningWindowDays} days`,
    "",
    `## Expired (${report.expired.length})`,
    "",
    renderTable(report.expired),
    `## Warning (${report.warning.length})`,
    "",
    renderTable(report.warning),
    `## OK (${report.ok.length})`,
    "",
    renderTable(report.ok),
  ];
  return lines.join("\n");
}

// Format a RotationReport as pretty-printed JSON with a summary block.
export function formatJSON(report: RotationReport): string {
  const output = {
    generatedAt: report.generatedAt,
    referenceDate: report.referenceDate,
    warningWindowDays: report.warningWindowDays,
    summary: {
      expiredCount: report.expired.length,
      warningCount: report.warning.length,
      okCount: report.ok.length,
    },
    expired: report.expired.map((s) => ({
      urgency: s.urgency,
      daysSinceRotation: s.daysSinceRotation,
      daysUntilExpiry: s.daysUntilExpiry,
      secret: s.secret,
    })),
    warning: report.warning.map((s) => ({
      urgency: s.urgency,
      daysSinceRotation: s.daysSinceRotation,
      daysUntilExpiry: s.daysUntilExpiry,
      secret: s.secret,
    })),
    ok: report.ok.map((s) => ({
      urgency: s.urgency,
      daysSinceRotation: s.daysSinceRotation,
      daysUntilExpiry: s.daysUntilExpiry,
      secret: s.secret,
    })),
  };
  return JSON.stringify(output, null, 2);
}
