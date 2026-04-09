/**
 * Secret Rotation Validator — Core Logic
 *
 * Implements the TDD-driven functionality:
 *   1. classifySecret  — determine urgency for a single secret
 *   2. analyzeSecrets  — classify a list of secrets
 *   3. generateReport  — build a grouped RotationReport
 *   4. formatAsMarkdown — render the report as a Markdown table
 *   5. formatAsJson     — render the report as pretty-printed JSON
 */

import type {
  SecretConfig,
  SecretStatus,
  RotationReport,
  Urgency,
} from "./types";

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Return the whole number of days between two dates (floor). */
function daysBetween(a: Date, b: Date): number {
  const msPerDay = 1000 * 60 * 60 * 24;
  return Math.floor((b.getTime() - a.getTime()) / msPerDay);
}

// ─── Core Functions ───────────────────────────────────────────────────────────

/**
 * Classify a single secret's urgency given a reference date and warning window.
 *
 * @param secret          - The secret config to evaluate.
 * @param referenceDate   - The date to treat as "now" (injectable for testing).
 * @param warningWindowDays - Secrets expiring within this many days get "warning".
 */
export function classifySecret(
  secret: SecretConfig,
  referenceDate: Date,
  warningWindowDays: number
): SecretStatus {
  // Compute expiry date: lastRotated + rotationPolicyDays
  const expiresAt = new Date(secret.lastRotated);
  expiresAt.setDate(expiresAt.getDate() + secret.rotationPolicyDays);

  // Positive = days remaining, negative = days past expiry
  const daysUntilExpiry = daysBetween(referenceDate, expiresAt);

  let urgency: Urgency;
  if (daysUntilExpiry < 0) {
    urgency = "expired";
  } else if (daysUntilExpiry <= warningWindowDays) {
    urgency = "warning";
  } else {
    urgency = "ok";
  }

  return {
    name: secret.name,
    urgency,
    daysUntilExpiry,
    expiresAt: expiresAt.toISOString(),
    requiredBy: secret.requiredBy,
    rotationPolicyDays: secret.rotationPolicyDays,
    lastRotated: secret.lastRotated,
  };
}

/**
 * Analyze a list of secrets, returning a status object for each.
 *
 * @param secrets         - Array of secret configurations.
 * @param referenceDate   - The date to treat as "now".
 * @param warningWindowDays - Warning threshold in days.
 */
export function analyzeSecrets(
  secrets: SecretConfig[],
  referenceDate: Date,
  warningWindowDays: number
): SecretStatus[] {
  return secrets.map((s) => classifySecret(s, referenceDate, warningWindowDays));
}

/**
 * Generate a grouped RotationReport from a list of secrets.
 *
 * @param secrets           - Array of secret configurations.
 * @param referenceDate     - The date to treat as "now".
 * @param warningWindowDays - Warning threshold in days.
 */
export function generateReport(
  secrets: SecretConfig[],
  referenceDate: Date,
  warningWindowDays: number
): RotationReport {
  const statuses = analyzeSecrets(secrets, referenceDate, warningWindowDays);

  const expired = statuses.filter((s) => s.urgency === "expired");
  const warning = statuses.filter((s) => s.urgency === "warning");
  const ok = statuses.filter((s) => s.urgency === "ok");

  return {
    generatedAt: referenceDate,
    warningWindowDays,
    summary: {
      totalSecrets: statuses.length,
      expiredCount: expired.length,
      warningCount: warning.length,
      okCount: ok.length,
    },
    expired,
    warning,
    ok,
  };
}

// ─── Output Formatters ────────────────────────────────────────────────────────

/** Pad a string to a fixed width (left-aligned). */
function padEnd(str: string, width: number): string {
  return str.padEnd(width, " ");
}

/**
 * Format a RotationReport as a Markdown document with a status table.
 */
export function formatAsMarkdown(report: RotationReport): string {
  const lines: string[] = [];

  lines.push("# Secret Rotation Report");
  lines.push("");
  lines.push(`**Generated:** ${report.generatedAt.toISOString()}`);
  lines.push(`**Warning Window:** ${report.warningWindowDays} days`);
  lines.push("");

  // Summary section
  lines.push("## Summary");
  lines.push("");
  lines.push(`| Metric | Count |`);
  lines.push(`|--------|-------|`);
  lines.push(`| Total  | ${report.summary.totalSecrets} |`);
  lines.push(`| Expired | ${report.summary.expiredCount} |`);
  lines.push(`| Warning | ${report.summary.warningCount} |`);
  lines.push(`| OK | ${report.summary.okCount} |`);
  lines.push("");

  // Full notification table — all secrets in one table, sorted by urgency
  lines.push("## Rotation Status");
  lines.push("");
  lines.push("| Name | Status | Days Until Expiry | Expires At | Required By |");
  lines.push("|------|--------|-------------------|------------|-------------|");

  const allStatuses = [
    ...report.expired,
    ...report.warning,
    ...report.ok,
  ];

  for (const s of allStatuses) {
    const urgencyLabel = s.urgency.toUpperCase();
    const daysStr =
      s.daysUntilExpiry < 0
        ? `${Math.abs(s.daysUntilExpiry)} days ago`
        : `${s.daysUntilExpiry} days`;
    const services = s.requiredBy.join(", ");
    const expiresDate = s.expiresAt.split("T")[0]; // YYYY-MM-DD
    lines.push(
      `| ${s.name} | ${urgencyLabel} | ${daysStr} | ${expiresDate} | ${services} |`
    );
  }

  lines.push("");

  // Grouped notification sections
  if (report.expired.length > 0) {
    lines.push("## Expired Secrets (Action Required)");
    lines.push("");
    for (const s of report.expired) {
      lines.push(
        `- **${s.name}** expired ${Math.abs(s.daysUntilExpiry)} days ago. Required by: ${s.requiredBy.join(", ")}`
      );
    }
    lines.push("");
  }

  if (report.warning.length > 0) {
    lines.push("## Expiring Soon (Warning)");
    lines.push("");
    for (const s of report.warning) {
      lines.push(
        `- **${s.name}** expires in ${s.daysUntilExpiry} days. Required by: ${s.requiredBy.join(", ")}`
      );
    }
    lines.push("");
  }

  if (report.ok.length > 0) {
    lines.push("## Healthy Secrets");
    lines.push("");
    for (const s of report.ok) {
      lines.push(
        `- **${s.name}** — ${s.daysUntilExpiry} days remaining.`
      );
    }
    lines.push("");
  }

  return lines.join("\n");
}

/**
 * Format a RotationReport as pretty-printed JSON.
 * Dates are serialized as ISO strings for portability.
 */
export function formatAsJson(report: RotationReport): string {
  // Convert Date objects to ISO strings for JSON serialization
  const serializable = {
    generatedAt: report.generatedAt.toISOString(),
    warningWindowDays: report.warningWindowDays,
    summary: report.summary,
    expired: report.expired.map((s) => ({
      ...s,
      lastRotated: s.lastRotated.toISOString(),
    })),
    warning: report.warning.map((s) => ({
      ...s,
      lastRotated: s.lastRotated.toISOString(),
    })),
    ok: report.ok.map((s) => ({
      ...s,
      lastRotated: s.lastRotated.toISOString(),
    })),
  };
  return JSON.stringify(serializable, null, 2);
}
