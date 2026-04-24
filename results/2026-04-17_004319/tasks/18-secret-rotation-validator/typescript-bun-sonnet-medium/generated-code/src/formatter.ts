import type { RotationReport, SecretStatusResult } from "./types";

function isoDate(date: Date): string {
  return date.toISOString().split("T")[0];
}

function buildTable(results: SecretStatusResult[], daysHeader: string): string {
  if (results.length === 0) return "_None_\n";
  const header = `| Secret | Last Rotated | ${daysHeader} | Required By |`;
  const sep = `|--------|-------------|------------------|-------------|`;
  const rows = results.map((r) => {
    const daysLabel =
      r.daysUntilExpiry < 0
        ? `${-r.daysUntilExpiry} days overdue`
        : `${r.daysUntilExpiry} days`;
    return `| ${r.secret.name} | ${isoDate(r.secret.lastRotated)} | ${daysLabel} | ${r.secret.requiredBy.join(", ")} |`;
  });
  return [header, sep, ...rows, ""].join("\n");
}

export function formatAsMarkdown(report: RotationReport): string {
  return [
    "# Secret Rotation Report",
    `Generated: ${isoDate(report.generatedAt)}`,
    `Summary: expired=${report.summary.expired} warning=${report.summary.warning} ok=${report.summary.ok}`,
    "",
    `## EXPIRED (${report.summary.expired})`,
    buildTable(report.expired, "Days Overdue"),
    `## WARNING (${report.summary.warning})`,
    buildTable(report.warning, "Days Until Expiry"),
    `## OK (${report.summary.ok})`,
    buildTable(report.ok, "Days Until Expiry"),
  ].join("\n");
}

export function formatAsJSON(report: RotationReport): string {
  const mapResult = (r: SecretStatusResult) => ({
    name: r.secret.name,
    lastRotated: isoDate(r.secret.lastRotated),
    rotationPolicyDays: r.secret.rotationPolicyDays,
    requiredBy: r.secret.requiredBy,
    daysSinceRotation: r.daysSinceRotation,
    daysUntilExpiry: r.daysUntilExpiry,
  });

  return JSON.stringify(
    {
      generatedAt: isoDate(report.generatedAt),
      summary: report.summary,
      expired: report.expired.map(mapResult),
      warning: report.warning.map(mapResult),
      ok: report.ok.map(mapResult),
    },
    null,
    2
  );
}
