// Output adapters for the rotation report. Markdown is human-readable for PR
// comments; JSON is machine-readable for downstream tooling.

import type { ClassifiedSecret, Report } from "./classify.ts";

const EMPTY_BUCKET = "_No secrets in this bucket._";

function expiredRow(s: ClassifiedSecret): string {
  return `| ${s.name} | ${s.lastRotated} | ${-s.daysUntilExpiry} | ${s.requiredBy.join(", ")} |`;
}

function warningRow(s: ClassifiedSecret): string {
  return `| ${s.name} | ${s.lastRotated} | ${s.daysUntilExpiry} | ${s.requiredBy.join(", ")} |`;
}

function okRow(s: ClassifiedSecret): string {
  return `| ${s.name} | ${s.lastRotated} | ${s.daysUntilExpiry} | ${s.requiredBy.join(", ")} |`;
}

function renderTable(
  header: string,
  rows: string[],
): string {
  // Header is a fully formatted "| col | col |" string; build divider from it.
  const cols = header.split("|").slice(1, -1).length;
  const divider = `|${" --- |".repeat(cols)}`;
  return [header, divider, ...rows].join("\n");
}

export function formatMarkdown(report: Report): string {
  const lines: string[] = [];
  lines.push("# Secret Rotation Report");
  lines.push("");
  lines.push(`Generated at: ${report.generatedAt}`);
  lines.push(`Warning window: ${report.warningWindowDays} days`);
  lines.push("");
  lines.push(`**Expired:** ${report.totals.expired}  `);
  lines.push(`**Warning:** ${report.totals.warning}  `);
  lines.push(`**OK:** ${report.totals.ok}`);
  lines.push("");

  // Expired section — emphasize urgency with "Days Overdue" (positive number).
  lines.push(`## Expired (${report.totals.expired})`);
  lines.push("");
  if (report.expired.length === 0) {
    lines.push(EMPTY_BUCKET);
  } else {
    lines.push(
      renderTable(
        "| Secret | Last Rotated | Days Overdue | Required By |",
        report.expired.map(expiredRow),
      ),
    );
  }
  lines.push("");

  lines.push(`## Warning (${report.totals.warning})`);
  lines.push("");
  if (report.warning.length === 0) {
    lines.push(EMPTY_BUCKET);
  } else {
    lines.push(
      renderTable(
        "| Secret | Last Rotated | Days Until Expiry | Required By |",
        report.warning.map(warningRow),
      ),
    );
  }
  lines.push("");

  lines.push(`## OK (${report.totals.ok})`);
  lines.push("");
  if (report.ok.length === 0) {
    lines.push(EMPTY_BUCKET);
  } else {
    lines.push(
      renderTable(
        "| Secret | Last Rotated | Days Until Expiry | Required By |",
        report.ok.map(okRow),
      ),
    );
  }
  lines.push("");

  return lines.join("\n");
}

export function formatJson(report: Report): string {
  return JSON.stringify(report, null, 2);
}
