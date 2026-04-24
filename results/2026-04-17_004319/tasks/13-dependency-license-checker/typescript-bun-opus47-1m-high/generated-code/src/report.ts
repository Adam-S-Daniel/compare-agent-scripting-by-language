// Formats compliance results as a human-readable Markdown report.
// Re-exports ComplianceRecord so callers can import everything report-related
// from one place.

export type { ComplianceRecord, ComplianceStatus } from "./compliance";
import type { ComplianceRecord } from "./compliance";

export interface Summary {
  approved: number;
  denied: number;
  unknown: number;
  total: number;
}

export function summarise(records: ComplianceRecord[]): Summary {
  const s: Summary = { approved: 0, denied: 0, unknown: 0, total: records.length };
  for (const r of records) s[r.status] += 1;
  return s;
}

export function generateReport(records: ComplianceRecord[]): string {
  const s = summarise(records);
  const lines: string[] = [];
  lines.push("# Dependency License Compliance Report");
  lines.push("");
  lines.push(`Total dependencies: ${s.total}`);
  lines.push(`Approved: ${s.approved}`);
  lines.push(`Denied: ${s.denied}`);
  lines.push(`Unknown: ${s.unknown}`);
  lines.push("");

  if (records.length === 0) {
    lines.push("No dependencies found.");
    return lines.join("\n") + "\n";
  }

  lines.push("| Name | Version | License | Status |");
  lines.push("| --- | --- | --- | --- |");
  for (const r of records) {
    const licence = r.license ?? "UNKNOWN";
    lines.push(`| ${r.name} | ${r.version} | ${licence} | ${r.status} |`);
  }
  return lines.join("\n") + "\n";
}
