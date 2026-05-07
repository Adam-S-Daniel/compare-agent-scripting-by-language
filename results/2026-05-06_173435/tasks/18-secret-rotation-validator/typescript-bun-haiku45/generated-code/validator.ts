// Secret rotation validator: detects expired/expiring secrets and generates rotation reports

export enum RotationStatus {
  EXPIRED = "expired",
  WARNING = "warning",
  OK = "ok",
}

export interface Secret {
  name: string;
  lastRotated: Date;
  rotationPolicyDays: number;
  requiredBy: string[];
}

export interface SecretStatus {
  name: string;
  status: RotationStatus;
  lastRotated: Date;
  daysOld: number;
  rotationPolicyDays: number;
  daysUntilExpiry: number;
  requiredBy: string[];
}

export interface RotationReport {
  expired: SecretStatus[];
  warning: SecretStatus[];
  ok: SecretStatus[];
  generatedAt: Date;
}

// Calculate days between two dates
function daysBetween(date1: Date, date2: Date): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.floor((date2.getTime() - date1.getTime()) / msPerDay);
}

export function detectExpiredSecrets(
  secrets: Secret[],
  warningWindowDays: number,
  now: Date = new Date()
): RotationReport {
  const report: RotationReport = {
    expired: [],
    warning: [],
    ok: [],
    generatedAt: now,
  };

  for (const secret of secrets) {
    const daysOld = daysBetween(secret.lastRotated, now);
    const daysUntilExpiry = secret.rotationPolicyDays - daysOld;

    const status: SecretStatus = {
      name: secret.name,
      lastRotated: secret.lastRotated,
      daysOld,
      rotationPolicyDays: secret.rotationPolicyDays,
      daysUntilExpiry,
      requiredBy: secret.requiredBy,
      status: RotationStatus.OK,
    };

    // Determine status based on days until expiry
    if (daysUntilExpiry < 0) {
      status.status = RotationStatus.EXPIRED;
      report.expired.push(status);
    } else if (daysUntilExpiry <= warningWindowDays) {
      status.status = RotationStatus.WARNING;
      report.warning.push(status);
    } else {
      status.status = RotationStatus.OK;
      report.ok.push(status);
    }
  }

  return report;
}

function formatTable(secrets: SecretStatus[]): string {
  if (secrets.length === 0) return "";

  const headers =
    "| Name | Days Old | Days Until Expiry | Policy (days) | Required By |";
  const separator = "|---|---|---|---|---|";

  const rows = secrets.map((s) => {
    const requiredBy = s.requiredBy.join(", ");
    return `| ${s.name} | ${s.daysOld} | ${s.daysUntilExpiry} | ${s.rotationPolicyDays} | ${requiredBy} |`;
  });

  return [headers, separator, ...rows].join("\n");
}

export function generateMarkdownReport(report: RotationReport): string {
  const sections: string[] = [];

  if (report.expired.length > 0) {
    sections.push("## 🔴 Expired Secrets\n");
    sections.push(formatTable(report.expired));
    sections.push("");
  }

  if (report.warning.length > 0) {
    sections.push("## 🟡 Warning\n");
    sections.push(formatTable(report.warning));
    sections.push("");
  }

  if (report.ok.length > 0) {
    sections.push("## 🟢 OK\n");
    sections.push(formatTable(report.ok));
    sections.push("");
  }

  return sections.join("\n").trim();
}

export function generateJsonReport(report: RotationReport): string {
  const jsonReport = {
    expired: report.expired,
    warning: report.warning,
    ok: report.ok,
    generatedAt: report.generatedAt.toISOString(),
  };

  return JSON.stringify(jsonReport, null, 2);
}
