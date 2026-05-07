import type { ComplianceReport } from "./types";

export function generateReport(report: ComplianceReport): string {
  const lines: string[] = [];

  lines.push("# Dependency License Compliance Report");
  lines.push("");
  lines.push("## Summary");
  lines.push("");
  lines.push(`- Total: ${report.summary.total}`);
  lines.push(`- Approved: ${report.summary.approved}`);
  lines.push(`- Denied: ${report.summary.denied}`);
  lines.push(`- Unknown: ${report.summary.unknown}`);
  lines.push("");

  if (report.entries.length > 0) {
    lines.push("## Details");
    lines.push("");
    lines.push("| Dependency | Version | License | Status |");
    lines.push("|------------|---------|---------|--------|");

    for (const entry of report.entries) {
      const license = entry.license ?? "N/A";
      const status = entry.status.toUpperCase();
      lines.push(`| ${entry.name} | ${entry.version} | ${license} | ${status} |`);
    }

    lines.push("");
  }

  return lines.join("\n");
}
