// Report formatting. Re-exports the ReportEntry type so callers don't need to
// know it lives in the compliance module.
export type { ReportEntry, Status } from "./compliance.ts";
import type { ReportEntry } from "./compliance.ts";

export interface Summary {
  total: number;
  approved: number;
  denied: number;
  unknown: number;
}

export function summarize(entries: ReportEntry[]): Summary {
  const s: Summary = { total: entries.length, approved: 0, denied: 0, unknown: 0 };
  for (const e of entries) s[e.status]++;
  return s;
}

export function formatReport(entries: ReportEntry[]): string {
  const lines: string[] = [];
  lines.push("Dependency License Compliance Report");
  lines.push("=====================================");
  for (const e of entries) {
    const license = e.license ?? "(no license info)";
    lines.push(`[${e.status.toUpperCase()}] ${e.name}@${e.version} -> ${license}`);
  }
  const s = summarize(entries);
  lines.push(`Totals: ${s.total} deps, ${s.approved} approved, ${s.denied} denied, ${s.unknown} unknown`);
  return lines.join("\n");
}
