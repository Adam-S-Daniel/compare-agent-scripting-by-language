// Runs inside the GitHub Actions workflow after the CLI has written
// report.md and report.json. Exits non-zero if any expected value is missing.
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
function expect(cond: boolean, msg: string): void {
  if (!cond) failures.push(msg);
}

// --- JSON report assertions ---
expect(json.summary.total === 4, `summary.total should be 4, got ${json.summary.total}`);
expect(
  json.summary.expired === 2,
  `summary.expired should be 2, got ${json.summary.expired}`,
);
expect(
  json.summary.warning === 1,
  `summary.warning should be 1, got ${json.summary.warning}`,
);
expect(json.summary.ok === 1, `summary.ok should be 1, got ${json.summary.ok}`);

// Order: most-overdue first.
expect(
  json.expired[0]?.name === "LEGACY_SIGNING_KEY",
  `expected first expired to be LEGACY_SIGNING_KEY, got ${json.expired[0]?.name}`,
);
expect(
  json.expired[0]?.daysUntilDue === -141,
  `LEGACY_SIGNING_KEY daysUntilDue should be -141, got ${json.expired[0]?.daysUntilDue}`,
);
expect(
  json.expired[1]?.name === "GITHUB_DEPLOY_TOKEN",
  `expected second expired to be GITHUB_DEPLOY_TOKEN, got ${json.expired[1]?.name}`,
);
expect(
  json.expired[1]?.daysUntilDue === -6,
  `GITHUB_DEPLOY_TOKEN daysUntilDue should be -6, got ${json.expired[1]?.daysUntilDue}`,
);
expect(
  json.warning[0]?.name === "DATABASE_PASSWORD",
  `expected warning to be DATABASE_PASSWORD, got ${json.warning[0]?.name}`,
);
expect(
  json.warning[0]?.daysUntilDue === 5,
  `DATABASE_PASSWORD daysUntilDue should be 5, got ${json.warning[0]?.daysUntilDue}`,
);
expect(
  json.ok[0]?.name === "STRIPE_API_KEY",
  `expected ok to be STRIPE_API_KEY, got ${json.ok[0]?.name}`,
);
expect(
  json.ok[0]?.daysUntilDue === 80,
  `STRIPE_API_KEY daysUntilDue should be 80, got ${json.ok[0]?.daysUntilDue}`,
);

// --- Markdown report assertions ---
const mustContain = [
  "# Secret Rotation Report",
  "Warning window: 14 days",
  "**Summary** — Total: 4, Expired: 2, Warning: 1, OK: 1",
  "## Expired",
  "## Warning",
  "## OK",
  "| LEGACY_SIGNING_KEY | 2025-09-01 | 90 | -141 | auth-service |",
  "| GITHUB_DEPLOY_TOKEN | 2026-03-15 | 30 | -6 | ci-runner |",
  "| DATABASE_PASSWORD | 2026-01-25 | 90 | 5 | orders-api, analytics-batch |",
  "| STRIPE_API_KEY | 2026-04-10 | 90 | 80 | billing-api, checkout-web |",
];
for (const needle of mustContain) {
  expect(md.includes(needle), `report.md missing expected line: ${needle}`);
}

if (failures.length > 0) {
  console.error("ASSERTION FAILURES:");
  for (const f of failures) console.error("  - " + f);
  process.exit(1);
}
console.log("All report assertions passed.");
