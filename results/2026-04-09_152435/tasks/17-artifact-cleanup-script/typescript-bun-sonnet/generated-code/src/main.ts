// Entry point for the artifact cleanup script.
// Usage:
//   bun run src/main.ts --fixture <path> [policy options] [--dry-run] [--reference-date YYYY-MM-DD]
//
// Policy options (at least one required):
//   --max-age-days <n>            Delete artifacts older than N days
//   --max-total-size-bytes <n>    Delete oldest artifacts exceeding N bytes total
//   --keep-latest-n <n>           Keep N most recent per artifact name
//
// Flags:
//   --dry-run                     Show plan without deleting
//   --reference-date YYYY-MM-DD   Override today's date (useful for reproducible tests)

import { readFileSync } from "fs";
import { generateDeletionPlan, formatPlan } from "./cleanup";
import type { Artifact, RetentionPolicy } from "./types";

// Parse ISO date strings from JSON into Date objects
function parseArtifacts(raw: unknown[]): Artifact[] {
  return raw.map((item) => {
    const obj = item as Record<string, unknown>;
    return {
      id: String(obj.id),
      name: String(obj.name),
      sizeBytes: Number(obj.sizeBytes),
      createdAt: new Date(String(obj.createdAt)),
      workflowRunId: String(obj.workflowRunId),
    };
  });
}

function parseArgs(args: string[]): {
  fixturePath: string;
  policy: RetentionPolicy;
  dryRun: boolean;
  referenceDate: Date;
} {
  let fixturePath = "fixtures/artifacts.json";
  let maxAgeDays: number | undefined;
  let maxTotalSizeBytes: number | undefined;
  let keepLatestN: number | undefined;
  let dryRun = false;
  let referenceDate = new Date();

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case "--fixture":
        fixturePath = args[++i];
        break;
      case "--max-age-days":
        maxAgeDays = parseInt(args[++i], 10);
        if (isNaN(maxAgeDays) || maxAgeDays < 0) {
          throw new Error(`Invalid --max-age-days value: ${args[i]}`);
        }
        break;
      case "--max-total-size-bytes":
        maxTotalSizeBytes = parseInt(args[++i], 10);
        if (isNaN(maxTotalSizeBytes) || maxTotalSizeBytes < 0) {
          throw new Error(`Invalid --max-total-size-bytes value: ${args[i]}`);
        }
        break;
      case "--keep-latest-n":
        keepLatestN = parseInt(args[++i], 10);
        if (isNaN(keepLatestN) || keepLatestN < 0) {
          throw new Error(`Invalid --keep-latest-n value: ${args[i]}`);
        }
        break;
      case "--dry-run":
        dryRun = true;
        break;
      case "--reference-date":
        referenceDate = new Date(args[++i] + "T00:00:00Z");
        if (isNaN(referenceDate.getTime())) {
          throw new Error(`Invalid --reference-date value: ${args[i]}`);
        }
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  const policy: RetentionPolicy = {};
  if (maxAgeDays !== undefined) policy.maxAgeDays = maxAgeDays;
  if (maxTotalSizeBytes !== undefined) policy.maxTotalSizeBytes = maxTotalSizeBytes;
  if (keepLatestN !== undefined) policy.keepLatestNPerWorkflow = keepLatestN;

  return { fixturePath, policy, dryRun, referenceDate };
}

function main(): void {
  const args = process.argv.slice(2);

  let config: ReturnType<typeof parseArgs>;
  try {
    config = parseArgs(args);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }

  const { fixturePath, policy, dryRun, referenceDate } = config;

  let rawData: unknown[];
  try {
    const content = readFileSync(fixturePath, "utf-8");
    rawData = JSON.parse(content) as unknown[];
  } catch (err) {
    console.error(`Error reading fixture file '${fixturePath}': ${(err as Error).message}`);
    process.exit(1);
  }

  let artifacts: Artifact[];
  try {
    artifacts = parseArtifacts(rawData);
  } catch (err) {
    console.error(`Error parsing artifacts: ${(err as Error).message}`);
    process.exit(1);
  }

  let plan;
  try {
    plan = generateDeletionPlan(artifacts, policy, referenceDate, dryRun);
  } catch (err) {
    console.error(`Error generating deletion plan: ${(err as Error).message}`);
    process.exit(1);
  }

  console.log(formatPlan(plan));
}

main();
