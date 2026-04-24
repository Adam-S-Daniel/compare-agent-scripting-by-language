// Core secret rotation validator logic

import type {
  Secret,
  SecretReport,
  SecretStatus,
  RotationReport,
  ValidatorConfig,
} from "./types";

/**
 * Compute how many days remain until a secret expires.
 * Returns negative if already expired.
 */
export function computeDaysUntilExpiry(
  lastRotated: string,
  rotationPolicyDays: number,
  today: string
): number {
  const rotatedMs = new Date(lastRotated).getTime();
  const todayMs = new Date(today).getTime();
  const msPerDay = 24 * 60 * 60 * 1000;
  const daysSinceRotation = Math.floor((todayMs - rotatedMs) / msPerDay);
  return rotationPolicyDays - daysSinceRotation;
}

/**
 * Classify a secret based on days until expiry and the warning window.
 * 0 or negative → expired; within warningWindow → warning; else → ok.
 */
export function classifySecret(
  daysUntilExpiry: number,
  warningWindowDays: number
): SecretStatus {
  if (daysUntilExpiry <= 0) return "expired";
  if (daysUntilExpiry <= warningWindowDays) return "warning";
  return "ok";
}

/**
 * Generate a full rotation report from config and a reference date.
 * The today parameter defaults to current date, but is injectable for testing.
 */
export function generateReport(
  config: ValidatorConfig,
  today: string = new Date().toISOString().slice(0, 10)
): RotationReport {
  const { warningWindowDays, secrets } = config;

  const reports: SecretReport[] = secrets.map((secret: Secret) => {
    const daysUntilExpiry = computeDaysUntilExpiry(
      secret.lastRotated,
      secret.rotationPolicyDays,
      today
    );
    const status = classifySecret(daysUntilExpiry, warningWindowDays);
    return {
      name: secret.name,
      lastRotated: secret.lastRotated,
      rotationPolicyDays: secret.rotationPolicyDays,
      requiredBy: secret.requiredBy,
      daysUntilExpiry,
      status,
    };
  });

  return {
    generatedAt: today,
    warningWindowDays,
    expired: reports.filter((r) => r.status === "expired"),
    warning: reports.filter((r) => r.status === "warning"),
    ok: reports.filter((r) => r.status === "ok"),
  };
}

/**
 * Format a rotation report as a markdown table grouped by urgency.
 */
export function formatMarkdown(report: RotationReport): string {
  const lines: string[] = [];
  lines.push(`# Secret Rotation Report`);
  lines.push(`Generated: ${report.generatedAt} | Warning window: ${report.warningWindowDays} days`);
  lines.push("");

  const tableHeader = `| Name | Status | Days Until Expiry | Last Rotated | Policy (days) | Required By |`;
  const tableSep   = `|------|--------|-------------------|--------------|---------------|-------------|`;

  const row = (r: SecretReport) =>
    `| ${r.name} | ${r.status} | ${r.daysUntilExpiry} | ${r.lastRotated} | ${r.rotationPolicyDays} | ${r.requiredBy.join(", ")} |`;

  if (report.expired.length > 0) {
    lines.push("## Expired");
    lines.push(tableHeader);
    lines.push(tableSep);
    report.expired.forEach((r) => lines.push(row(r)));
    lines.push("");
  }

  if (report.warning.length > 0) {
    lines.push("## Warning");
    lines.push(tableHeader);
    lines.push(tableSep);
    report.warning.forEach((r) => lines.push(row(r)));
    lines.push("");
  }

  if (report.ok.length > 0) {
    lines.push("## OK");
    lines.push(tableHeader);
    lines.push(tableSep);
    report.ok.forEach((r) => lines.push(row(r)));
    lines.push("");
  }

  return lines.join("\n");
}

/**
 * Format a rotation report as a JSON string.
 */
export function formatJSON(report: RotationReport): string {
  return JSON.stringify(report, null, 2);
}
