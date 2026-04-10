// main.ts — CLI entry point for the artifact cleanup script
// Usage: bun run main.ts --artifacts <file.json> [options]
//
// Options:
//   --artifacts <path>        Path to JSON file with artifact data (required)
//   --max-age-days <n>        Delete artifacts older than N days
//   --max-total-size <n>      Maximum total size in bytes
//   --keep-latest-n <n>       Keep only N most recent per workflow
//   --dry-run                 Mark plan as dry-run (default: true)
//   --execute                 Actually execute (sets dryRun=false)
//   --reference-date <date>   ISO date to use as "now" (for testing)

import { readFileSync } from "fs";
import { generateDeletionPlan, formatDeletionPlan } from "./cleanup";
import type { Artifact, RetentionPolicy } from "./types";

function parseArgs(args: string[]): {
  artifactsPath: string;
  policy: RetentionPolicy;
  dryRun: boolean;
  referenceDate?: Date;
} {
  let artifactsPath = "";
  const policy: RetentionPolicy = {};
  let dryRun = true;
  let referenceDate: Date | undefined;

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--artifacts":
        artifactsPath = args[++i];
        break;
      case "--max-age-days":
        policy.maxAgeDays = parseInt(args[++i], 10);
        break;
      case "--max-total-size":
        policy.maxTotalSizeBytes = parseInt(args[++i], 10);
        break;
      case "--keep-latest-n":
        policy.keepLatestNPerWorkflow = parseInt(args[++i], 10);
        break;
      case "--dry-run":
        dryRun = true;
        break;
      case "--execute":
        dryRun = false;
        break;
      case "--reference-date":
        referenceDate = new Date(args[++i]);
        break;
      default:
        if (args[i].startsWith("-")) {
          console.error(`Unknown option: ${args[i]}`);
          process.exit(1);
        }
    }
  }

  if (!artifactsPath) {
    console.error("Error: --artifacts <path> is required");
    process.exit(1);
  }

  return { artifactsPath, policy, dryRun, referenceDate };
}

function main(): void {
  const args = process.argv.slice(2);
  const { artifactsPath, policy, dryRun, referenceDate } = parseArgs(args);

  // Read artifact data from JSON file
  let artifacts: Artifact[];
  try {
    const raw = readFileSync(artifactsPath, "utf-8");
    artifacts = JSON.parse(raw);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Error reading artifacts file: ${msg}`);
    process.exit(1);
  }

  // Generate and display the deletion plan
  const plan = generateDeletionPlan(artifacts, policy, { dryRun, referenceDate });
  console.log(formatDeletionPlan(plan));
}

main();
