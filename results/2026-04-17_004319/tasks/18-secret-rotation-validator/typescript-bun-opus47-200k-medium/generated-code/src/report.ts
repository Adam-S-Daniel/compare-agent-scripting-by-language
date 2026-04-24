// Output formatters: JSON and Markdown table grouped by urgency.
import type { ClassifiedSecret, Report } from "./validator.ts";

export function renderJson(report: Report): string {
  return JSON.stringify(report, null, 2);
}

function tableRow(s: ClassifiedSecret): string {
  const required = s.requiredBy.length ? s.requiredBy.join(", ") : "-";
  return `| ${s.name} | ${s.lastRotated} | ${s.rotationPolicyDays} | ${s.daysUntilDue} | ${required} |`;
}

function section(title: string, rows: ClassifiedSecret[]): string {
  const header =
    "| Name | Last Rotated | Policy (days) | Days Until Due | Required By |\n" +
    "| --- | --- | --- | --- | --- |";
  const body = rows.length
    ? rows.map(tableRow).join("\n")
    : "_none_";
  return `## ${title}\n\n${rows.length ? header + "\n" + body : body}\n`;
}

export function renderMarkdown(report: Report): string {
  const lines: string[] = [];
  lines.push("# Secret Rotation Report");
  lines.push("");
  lines.push(`Generated: ${report.generatedAt}`);
  lines.push(`Warning window: ${report.warningDays} days`);
  lines.push("");
  lines.push(
    `**Summary** — Total: ${report.summary.total}, Expired: ${report.summary.expired}, Warning: ${report.summary.warning}, OK: ${report.summary.ok}`,
  );
  lines.push("");
  lines.push(section("Expired", report.expired));
  lines.push(section("Warning", report.warning));
  lines.push(section("OK", report.ok));
  return lines.join("\n");
}
