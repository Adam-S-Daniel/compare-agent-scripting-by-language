// CI assertion script: validates the JSON report output against known-good values
// Used by the GitHub Actions workflow to assert exact expected values

import { readFileSync } from "fs";
import type { RotationReport } from "./types";

const reportPath = process.argv[2];
if (!reportPath) {
  console.error("Usage: bun run src/assert-report.ts <report.json>");
  process.exit(1);
}

let data: RotationReport;
try {
  data = JSON.parse(readFileSync(reportPath, "utf-8")) as RotationReport;
} catch (err) {
  console.error(`Failed to read report: ${(err as Error).message}`);
  process.exit(1);
}

const errors: string[] = [];

if (data.expired.length !== 1)
  errors.push(`Expected 1 expired secret, got ${data.expired.length}`);
if (data.warning.length !== 1)
  errors.push(`Expected 1 warning secret, got ${data.warning.length}`);
if (data.ok.length !== 1)
  errors.push(`Expected 1 ok secret, got ${data.ok.length}`);

if (data.expired[0]?.name !== "DB_PASSWORD")
  errors.push(`Expected expired[0].name=DB_PASSWORD, got ${data.expired[0]?.name}`);
if (data.warning[0]?.name !== "API_KEY")
  errors.push(`Expected warning[0].name=API_KEY, got ${data.warning[0]?.name}`);
if (data.ok[0]?.name !== "JWT_SECRET")
  errors.push(`Expected ok[0].name=JWT_SECRET, got ${data.ok[0]?.name}`);
if (data.expired[0]?.daysUntilExpiry !== -14)
  errors.push(`Expected expired[0].daysUntilExpiry=-14, got ${data.expired[0]?.daysUntilExpiry}`);
if (data.warning[0]?.daysUntilExpiry !== 3)
  errors.push(`Expected warning[0].daysUntilExpiry=3, got ${data.warning[0]?.daysUntilExpiry}`);
if (data.ok[0]?.daysUntilExpiry !== 76)
  errors.push(`Expected ok[0].daysUntilExpiry=76, got ${data.ok[0]?.daysUntilExpiry}`);

if (errors.length > 0) {
  console.error("Assertion failures:");
  errors.forEach((e) => console.error("  - " + e));
  process.exit(1);
}

console.log("Expired secrets: 1 (DB_PASSWORD, daysUntilExpiry=-14)");
console.log("Warning secrets: 1 (API_KEY, daysUntilExpiry=3)");
console.log("OK secrets: 1 (JWT_SECRET, daysUntilExpiry=76)");
console.log("All assertions passed");
