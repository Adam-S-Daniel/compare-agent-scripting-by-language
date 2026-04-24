// Generates a human-readable compliance report from check results.

import type { CheckResult } from "./types";

export function generateReport(results: CheckResult[]): string {
  const approved = results.filter((r) => r.status === "approved").length;
  const denied = results.filter((r) => r.status === "denied").length;
  const unknown = results.filter((r) => r.status === "unknown").length;
  const total = results.length;
  const passed = denied === 0;

  const lines: string[] = [
    "Dependency License Compliance Report",
    "=====================================",
  ];

  for (const r of results) {
    lines.push(`${r.name}@${r.version}: ${r.license} (${r.status})`);
  }

  lines.push("");
  lines.push("Summary:");
  lines.push(`  Approved: ${approved}`);
  lines.push(`  Denied: ${denied}`);
  lines.push(`  Unknown: ${unknown}`);
  lines.push(`  Total: ${total}`);
  lines.push(`Status: ${passed ? "PASSED" : "FAILED"}`);

  return lines.join("\n");
}
