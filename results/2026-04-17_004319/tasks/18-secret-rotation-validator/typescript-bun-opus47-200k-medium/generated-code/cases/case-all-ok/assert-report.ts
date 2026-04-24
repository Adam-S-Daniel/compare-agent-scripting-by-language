// Case: all secrets are freshly rotated — expect no expired, no warnings.
import { readFileSync } from "node:fs";

interface JsonReport {
  summary: { total: number; expired: number; warning: number; ok: number };
  expired: unknown[];
  warning: unknown[];
  ok: Array<{ name: string; daysUntilDue: number }>;
}
const md = readFileSync("report.md", "utf8");
const json = JSON.parse(readFileSync("report.json", "utf8")) as JsonReport;
const failures: string[] = [];
const check = (c: boolean, m: string) => { if (!c) failures.push(m); };

check(json.summary.total === 2, `total=2, got ${json.summary.total}`);
check(json.summary.expired === 0, `expired=0, got ${json.summary.expired}`);
check(json.summary.warning === 0, `warning=0, got ${json.summary.warning}`);
check(json.summary.ok === 2, `ok=2, got ${json.summary.ok}`);
check(json.ok[0]?.name === "FRESH_KEY_B", `ok[0]=FRESH_KEY_B, got ${json.ok[0]?.name}`);
check(json.ok[0]?.daysUntilDue === 161, `FRESH_KEY_B days=161, got ${json.ok[0]?.daysUntilDue}`);
check(json.ok[1]?.name === "FRESH_KEY_A", `ok[1]=FRESH_KEY_A, got ${json.ok[1]?.name}`);
check(json.ok[1]?.daysUntilDue === 89, `FRESH_KEY_A days=89, got ${json.ok[1]?.daysUntilDue}`);

for (const needle of [
  "**Summary** — Total: 2, Expired: 0, Warning: 0, OK: 2",
  "## Expired",
  "_none_",
  "| FRESH_KEY_B | 2026-04-01 | 180 | 161 | svc-b |",
  "| FRESH_KEY_A | 2026-04-19 | 90 | 89 | svc-a |",
]) {
  check(md.includes(needle), `markdown missing: ${needle}`);
}

if (failures.length) {
  console.error("CASE all-ok failures:");
  for (const f of failures) console.error("  - " + f);
  process.exit(1);
}
console.log("CASE all-ok OK");
