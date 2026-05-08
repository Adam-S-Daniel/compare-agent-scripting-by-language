// Compliance report rendering. Two formats: human-readable text for CI logs
// and machine-readable JSON for downstream tooling.

import type { CheckResult } from "./checker.ts";

export type Format = "text" | "json";

export interface Summary {
  total: number;
  approved: number;
  denied: number;
  unknown: number;
}

export function summarize(results: CheckResult[]): Summary {
  const summary: Summary = { total: results.length, approved: 0, denied: 0, unknown: 0 };
  for (const r of results) summary[r.status]++;
  return summary;
}

export function renderReport(results: CheckResult[], format: Format): string {
  if (format === "json") return renderJson(results);
  return renderText(results);
}

function renderJson(results: CheckResult[]): string {
  return JSON.stringify({ summary: summarize(results), results }, null, 2);
}

function renderText(results: CheckResult[]): string {
  const lines: string[] = [];
  lines.push("Dependency License Compliance Report");
  lines.push("=====================================");
  if (results.length === 0) {
    lines.push("No dependencies found in manifest.");
  } else {
    for (const r of results) {
      const tag = `[${r.status.toUpperCase()}]`.padEnd(12, " ");
      lines.push(
        `${tag}${r.name}@${r.version}  ${r.license ?? "-"}  ${r.reason}`,
      );
    }
  }
  const s = summarize(results);
  lines.push("");
  lines.push(`Summary: total=${s.total} approved=${s.approved} denied=${s.denied} unknown=${s.unknown}`);
  return lines.join("\n");
}

