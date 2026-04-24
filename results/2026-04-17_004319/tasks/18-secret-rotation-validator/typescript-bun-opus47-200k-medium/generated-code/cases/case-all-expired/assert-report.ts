// Case: every secret is severely overdue.
import { readFileSync } from "node:fs";

interface JsonReport {
  summary: { total: number; expired: number; warning: number; ok: number };
  expired: Array<{ name: string; daysUntilDue: number }>;
  warning: unknown[];
  ok: unknown[];
}
const md = readFileSync("report.md", "utf8");
const json = JSON.parse(readFileSync("report.json", "utf8")) as JsonReport;
const failures: string[] = [];
const check = (c: boolean, m: string) => { if (!c) failures.push(m); };

check(json.summary.total === 2, `total=2, got ${json.summary.total}`);
check(json.summary.expired === 2, `expired=2, got ${json.summary.expired}`);
check(json.summary.warning === 0, `warning=0, got ${json.summary.warning}`);
check(json.summary.ok === 0, `ok=0, got ${json.summary.ok}`);
check(json.expired[0]?.name === "ANCIENT_KEY", `expired[0]=ANCIENT_KEY, got ${json.expired[0]?.name}`);
check(json.expired[0]?.daysUntilDue === -810, `ANCIENT days=-810, got ${json.expired[0]?.daysUntilDue}`);
check(json.expired[1]?.name === "STALE_TOKEN", `expired[1]=STALE_TOKEN, got ${json.expired[1]?.name}`);
check(json.expired[1]?.daysUntilDue === -414, `STALE days=-414, got ${json.expired[1]?.daysUntilDue}`);

for (const needle of [
  "**Summary** — Total: 2, Expired: 2, Warning: 0, OK: 0",
  "| ANCIENT_KEY | 2024-01-01 | 30 | -810 | legacy-svc |",
  "| STALE_TOKEN | 2025-01-01 | 60 | -414 | cron-runner |",
  "## Warning",
  "## OK",
  "_none_",
]) {
  check(md.includes(needle), `markdown missing: ${needle}`);
}

if (failures.length) {
  console.error("CASE all-expired failures:");
  for (const f of failures) console.error("  - " + f);
  process.exit(1);
}
console.log("CASE all-expired OK");
