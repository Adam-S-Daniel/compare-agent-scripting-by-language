import { RotationReport } from "./types";

// Format report as markdown table
export function formatMarkdown(report: RotationReport): string {
  const lines: string[] = [];

  lines.push("# Secret Rotation Report\n");
  lines.push(`Generated: ${report.generated.toISOString()}\n`);
  lines.push("## Summary\n");
  lines.push(`- Expired: ${report.summary.expired}`);
  lines.push(`- Warning: ${report.summary.warning}`);
  lines.push(`- OK: ${report.summary.ok}\n`);

  lines.push("## Secrets\n");
  lines.push("| Secret Name | Status | Days Until Expiration | Expiration Date | Services |");
  lines.push("|---|---|---|---|---|");

  for (const status of report.secrets) {
    const services = status.secret.requiredByServices.join(", ");
    const statusEmoji = status.status === "expired" ? "🔴" : status.status === "warning" ? "🟡" : "🟢";
    lines.push(
      `| ${status.secret.name} | ${statusEmoji} ${status.status} | ${status.daysUntilExpiration} | ${status.expirationDate.toISOString().split("T")[0]} | ${services} |`
    );
  }

  return lines.join("\n");
}

// Format report as JSON
export function formatJSON(report: RotationReport): string {
  return JSON.stringify(report, null, 2);
}
