import type { RotationReport, SecretStatus } from "./types";

export function formatJson(report: RotationReport): string {
  return JSON.stringify(report, null, 2);
}

export function formatMarkdown(report: RotationReport): string {
  const lines: string[] = [];

  lines.push("# Secret Rotation Report");
  lines.push("");
  lines.push(
    `Generated: ${report.generatedAt} | Warning Window: ${report.warningWindowDays} days`
  );
  lines.push("");
  lines.push("## Summary");
  lines.push("");
  lines.push("| Status | Count |");
  lines.push("|--------|-------|");
  lines.push(`| Expired | ${report.summary.expired} |`);
  lines.push(`| Warning | ${report.summary.warning} |`);
  lines.push(`| OK | ${report.summary.ok} |`);
  lines.push(`| **Total** | **${report.summary.total}** |`);

  const expired = report.secrets.filter((s) => s.urgency === "expired");
  const warning = report.secrets.filter((s) => s.urgency === "warning");
  const ok = report.secrets.filter((s) => s.urgency === "ok");

  if (expired.length > 0) {
    lines.push("");
    lines.push("## Expired");
    lines.push("");
    lines.push(
      "| Name | Last Rotated | Policy (days) | Expiry Date | Days Overdue | Required By |"
    );
    lines.push(
      "|------|--------------|---------------|-------------|--------------|-------------|"
    );
    for (const s of expired) {
      lines.push(formatExpiredRow(s));
    }
  }

  if (warning.length > 0) {
    lines.push("");
    lines.push("## Warning");
    lines.push("");
    lines.push(
      "| Name | Last Rotated | Policy (days) | Expiry Date | Days Until Expiry | Required By |"
    );
    lines.push(
      "|------|--------------|---------------|-------------|-------------------|-------------|"
    );
    for (const s of warning) {
      lines.push(formatOkRow(s));
    }
  }

  if (ok.length > 0) {
    lines.push("");
    lines.push("## OK");
    lines.push("");
    lines.push(
      "| Name | Last Rotated | Policy (days) | Expiry Date | Days Until Expiry | Required By |"
    );
    lines.push(
      "|------|--------------|---------------|-------------|-------------------|-------------|"
    );
    for (const s of ok) {
      lines.push(formatOkRow(s));
    }
  }

  lines.push("");
  return lines.join("\n");
}

function formatExpiredRow(s: SecretStatus): string {
  const daysOverdue = Math.abs(s.daysUntilExpiry);
  return `| ${s.name} | ${s.lastRotated} | ${s.rotationPolicyDays} | ${s.expiryDate} | ${daysOverdue} | ${s.requiredBy.join(", ")} |`;
}

function formatOkRow(s: SecretStatus): string {
  return `| ${s.name} | ${s.lastRotated} | ${s.rotationPolicyDays} | ${s.expiryDate} | ${s.daysUntilExpiry} | ${s.requiredBy.join(", ")} |`;
}
