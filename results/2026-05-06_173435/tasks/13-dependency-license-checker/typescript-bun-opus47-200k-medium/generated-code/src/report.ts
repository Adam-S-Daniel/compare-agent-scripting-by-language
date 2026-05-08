// Renders the compliance report. Two consumers:
//   - formatReport: the text we print to stdout (and CI logs)
//   - summarize: counts that drive the CLI exit code
import type { ReportEntry, Status } from "./checker.ts";

export interface Summary {
  approved: number;
  denied: number;
  unknown: number;
  total: number;
}

export function summarize(entries: ReportEntry[]): Summary {
  const s: Summary = { approved: 0, denied: 0, unknown: 0, total: entries.length };
  for (const e of entries) s[e.status as Status]++;
  return s;
}

export function formatReport(entries: ReportEntry[]): string {
  const lines: string[] = [];
  lines.push("Dependency License Compliance Report");
  lines.push("=".repeat(40));
  for (const e of entries) {
    const license = e.license ?? "unknown";
    const tail = e.error ? ` (error: ${e.error})` : "";
    lines.push(`${e.status.toUpperCase().padEnd(8)} ${e.name}@${e.version}  license=${license}${tail}`);
  }
  const s = summarize(entries);
  lines.push("");
  lines.push(`Summary: total=${s.total} approved=${s.approved} denied=${s.denied} unknown=${s.unknown}`);
  return lines.join("\n");
}
