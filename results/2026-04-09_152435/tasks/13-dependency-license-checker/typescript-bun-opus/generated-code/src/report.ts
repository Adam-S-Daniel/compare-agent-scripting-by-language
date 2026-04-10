// Report formatter: renders a ComplianceReport as a human-readable string

import type { ComplianceReport } from "./types";

/** Format the compliance report as a text table with summary */
export function formatReport(report: ComplianceReport): string {
  const lines: string[] = [];

  lines.push("=== Dependency License Compliance Report ===");
  lines.push("");

  if (report.entries.length === 0) {
    lines.push("No dependencies found.");
  } else {
    // Table header
    lines.push(
      padRight("Package", 30) +
        padRight("Version", 20) +
        padRight("License", 20) +
        "Status"
    );
    lines.push("-".repeat(80));

    for (const entry of report.entries) {
      const statusStr = entry.status.toUpperCase();
      const licenseStr = entry.license ?? "N/A";
      lines.push(
        padRight(entry.name, 30) +
          padRight(entry.version, 20) +
          padRight(licenseStr, 20) +
          statusStr
      );
    }
  }

  lines.push("");
  lines.push("--- Summary ---");
  lines.push(`Total: ${report.summary.total}`);
  lines.push(`Approved: ${report.summary.approved}`);
  lines.push(`Denied: ${report.summary.denied}`);
  lines.push(`Unknown: ${report.summary.unknown}`);

  return lines.join("\n");
}

function padRight(str: string, width: number): string {
  return str.length >= width ? str + " " : str + " ".repeat(width - str.length);
}
