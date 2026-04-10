/**
 * Output formatters for rotation reports.
 * Supports Markdown table format (human-readable) and JSON (machine-readable).
 */
import type { RotationReport, SecretStatus } from "./types";

/**
 * Renders a list of secret statuses as a Markdown table.
 * Shows "_None_" when the list is empty.
 */
function renderTable(statuses: SecretStatus[]): string {
  if (statuses.length === 0) {
    return "_None_\n";
  }

  const header =
    "| Secret | Last Rotated | Expiry Date | Days | Required By |\n" +
    "|--------|-------------|-------------|------|------------|";

  const rows = statuses.map((s) => {
    // Show positive days as "N remaining", negative as "N overdue"
    const daysLabel =
      s.daysUntilExpiry < 0
        ? `${Math.abs(s.daysUntilExpiry)} overdue`
        : `${s.daysUntilExpiry} remaining`;
    const services = s.requiredBy.length > 0 ? s.requiredBy.join(", ") : "none";
    return `| ${s.name} | ${s.lastRotated} | ${s.expiryDate} | ${daysLabel} | ${services} |`;
  });

  return header + "\n" + rows.join("\n") + "\n";
}

/**
 * Formats the rotation report as a Markdown document with tables grouped by urgency.
 */
export function formatMarkdown(report: RotationReport): string {
  const lines: string[] = [
    "# Secret Rotation Report",
    "",
    `Generated: ${report.generatedAt} | Warning window: ${report.warningWindowDays} days`,
    "",
    "## Summary",
    `- Expired: ${report.summary.expired}`,
    `- Warning: ${report.summary.warning}`,
    `- OK: ${report.summary.ok}`,
    "",
    `## EXPIRED (${report.summary.expired})`,
    renderTable(report.expired),
    `## WARNING (${report.summary.warning})`,
    renderTable(report.warning),
    `## OK (${report.summary.ok})`,
    renderTable(report.ok),
  ];

  return lines.join("\n");
}

/**
 * Formats the rotation report as pretty-printed JSON.
 */
export function formatJSON(report: RotationReport): string {
  return JSON.stringify(report, null, 2);
}
