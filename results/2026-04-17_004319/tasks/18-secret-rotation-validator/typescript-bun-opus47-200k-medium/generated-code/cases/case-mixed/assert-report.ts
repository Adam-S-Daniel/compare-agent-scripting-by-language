// Case: mixed statuses — two expired (LEGACY, GITHUB), one warning (DATABASE), one ok (STRIPE).
import { readFileSync } from "node:fs";

interface JsonReport {
  summary: { total: number; expired: number; warning: number; ok: number };
  expired: Array<{ name: string; daysUntilDue: number }>;
  warning: Array<{ name: string; daysUntilDue: number }>;
  ok: Array<{ name: string; daysUntilDue: number }>;
}

const md = readFileSync("report.md", "utf8");
const json = JSON.parse(readFileSync("report.json", "utf8")) as JsonReport;
const failures: string[] = [];
const check = (c: boolean, m: string) => { if (!c) failures.push(m); };

check(json.summary.total === 4, `total=4 expected, got ${json.summary.total}`);
check(json.summary.expired === 2, `expired=2 expected, got ${json.summary.expired}`);
check(json.summary.warning === 1, `warning=1 expected, got ${json.summary.warning}`);
check(json.summary.ok === 1, `ok=1 expected, got ${json.summary.ok}`);
check(json.expired[0]?.name === "LEGACY_SIGNING_KEY", "expired[0]=LEGACY_SIGNING_KEY");
check(json.expired[0]?.daysUntilDue === -141, `LEGACY days=-141, got ${json.expired[0]?.daysUntilDue}`);
check(json.expired[1]?.name === "GITHUB_DEPLOY_TOKEN", "expired[1]=GITHUB_DEPLOY_TOKEN");
check(json.expired[1]?.daysUntilDue === -6, `GITHUB days=-6, got ${json.expired[1]?.daysUntilDue}`);
check(json.warning[0]?.name === "DATABASE_PASSWORD", "warning[0]=DATABASE_PASSWORD");
check(json.warning[0]?.daysUntilDue === 5, `DB days=5, got ${json.warning[0]?.daysUntilDue}`);
check(json.ok[0]?.name === "STRIPE_API_KEY", "ok[0]=STRIPE_API_KEY");
check(json.ok[0]?.daysUntilDue === 80, `STRIPE days=80, got ${json.ok[0]?.daysUntilDue}`);

for (const needle of [
  "# Secret Rotation Report",
  "Warning window: 14 days",
  "**Summary** — Total: 4, Expired: 2, Warning: 1, OK: 1",
  "| LEGACY_SIGNING_KEY | 2025-09-01 | 90 | -141 | auth-service |",
  "| GITHUB_DEPLOY_TOKEN | 2026-03-15 | 30 | -6 | ci-runner |",
  "| DATABASE_PASSWORD | 2026-01-25 | 90 | 5 | orders-api, analytics-batch |",
  "| STRIPE_API_KEY | 2026-04-10 | 90 | 80 | billing-api, checkout-web |",
]) {
  check(md.includes(needle), `markdown missing: ${needle}`);
}

if (failures.length) {
  console.error("CASE mixed failures:");
  for (const f of failures) console.error("  - " + f);
  process.exit(1);
}
console.log("CASE mixed OK");
