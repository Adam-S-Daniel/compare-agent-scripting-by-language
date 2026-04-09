// CLI entry point — reads a JSON input file, applies retention policies,
// and prints the deletion plan to stdout.

import { applyRetentionPolicies } from "./cleanup";
import { formatPlan } from "./format";
import type { CleanupInput } from "./types";

const inputPath = process.argv[2] || "input.json";

try {
  const file = Bun.file(inputPath);
  if (!(await file.exists())) {
    console.error(`Error: Input file not found: ${inputPath}`);
    process.exit(1);
  }

  const input: CleanupInput = await file.json();

  // Basic input validation
  if (!input.artifacts || !Array.isArray(input.artifacts)) {
    console.error("Error: Input must contain an 'artifacts' array");
    process.exit(1);
  }
  if (!input.policy || typeof input.policy !== "object") {
    console.error("Error: Input must contain a 'policy' object");
    process.exit(1);
  }

  const plan = applyRetentionPolicies(
    input.artifacts,
    input.policy,
    input.referenceDate
  );

  console.log(formatPlan(plan));
} catch (err) {
  console.error(
    `Error: ${err instanceof Error ? err.message : String(err)}`
  );
  process.exit(1);
}
