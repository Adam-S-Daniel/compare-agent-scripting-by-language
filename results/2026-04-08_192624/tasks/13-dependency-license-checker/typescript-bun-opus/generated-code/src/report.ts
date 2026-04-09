// Report formatter — produces human-readable and machine-parseable output
import type { ComplianceReport } from "./types";

/**
 * Format a compliance report as a human-readable string.
 * Each entry shows: name@version — license (STATUS)
 * Summary line shows totals.
 */
export function formatReport(report: ComplianceReport): string {
  const lines: string[] = [];

  lines.push("=== Dependency License Compliance Report ===");
  lines.push("");

  for (const entry of report.entries) {
    const tag =
      entry.status === "approved"
        ? "[APPROVED]"
        : entry.status === "denied"
          ? "[DENIED]"
          : "[UNKNOWN]";
    lines.push(`  ${entry.name}@${entry.version} — ${entry.license} ${tag}`);
  }

  lines.push("");
  lines.push("--- Summary ---");
  lines.push(`Total: ${report.total}`);
  lines.push(`Approved: ${report.approved}`);
  lines.push(`Denied: ${report.denied}`);
  lines.push(`Unknown: ${report.unknown}`);

  // Overall verdict
  if (report.denied > 0) {
    lines.push("");
    lines.push("RESULT: FAIL — denied licenses found");
  } else if (report.unknown > 0) {
    lines.push("");
    lines.push("RESULT: WARNING — unknown licenses found");
  } else {
    lines.push("");
    lines.push("RESULT: PASS — all licenses approved");
  }

  return lines.join("\n");
}
