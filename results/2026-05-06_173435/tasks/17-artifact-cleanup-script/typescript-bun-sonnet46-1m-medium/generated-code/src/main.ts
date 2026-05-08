// Entry point for the artifact cleanup script.
// Usage: bun run src/main.ts --input <artifacts.json> --policy <policy.json> [--dry-run] [--label <name>]
//
// Outputs a human-readable deletion plan and a machine-readable summary line:
//   CLEANUP_SUMMARY_<LABEL>:{"artifactsDeleted":N,...}
// The label defaults to "DEFAULT" if not specified.

import { readFileSync } from "fs";
import { applyRetentionPolicies, formatDeletionPlan } from "./cleanup";
import type { Artifact, RetentionPolicy, CleanupOptions } from "./types";

interface ParsedArgs {
  inputFile: string;
  policyFile: string;
  dryRun: boolean;
  label: string;
}

function parseArgs(args: string[]): ParsedArgs {
  let inputFile = "";
  let policyFile = "";
  let dryRun = false;
  let label = "DEFAULT";

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--input":
        inputFile = args[++i] ?? "";
        break;
      case "--policy":
        policyFile = args[++i] ?? "";
        break;
      case "--dry-run":
        dryRun = true;
        break;
      case "--label":
        label = (args[++i] ?? "DEFAULT").toUpperCase();
        break;
    }
  }

  if (!inputFile) throw new Error("Missing required argument: --input <file>");
  if (!policyFile) throw new Error("Missing required argument: --policy <file>");

  return { inputFile, policyFile, dryRun, label };
}

function main(): void {
  const args = process.argv.slice(2);

  let parsed: ParsedArgs;
  try {
    parsed = parseArgs(args);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    console.error("Usage: bun run src/main.ts --input <artifacts.json> --policy <policy.json> [--dry-run] [--label <name>]");
    process.exit(1);
  }

  const { inputFile, policyFile, dryRun, label } = parsed;

  let artifacts: Artifact[];
  try {
    artifacts = JSON.parse(readFileSync(inputFile, "utf-8")) as Artifact[];
  } catch (err) {
    console.error(`Error reading input file '${inputFile}': ${(err as Error).message}`);
    process.exit(1);
  }

  let policy: RetentionPolicy;
  try {
    policy = JSON.parse(readFileSync(policyFile, "utf-8")) as RetentionPolicy;
  } catch (err) {
    console.error(`Error reading policy file '${policyFile}': ${(err as Error).message}`);
    process.exit(1);
  }

  const options: CleanupOptions = { dryRun };
  const plan = applyRetentionPolicies(artifacts, policy, options);

  console.log(formatDeletionPlan(plan, label));

  // Machine-readable summary line with label for CI parsing
  console.log(`CLEANUP_SUMMARY_${label}:${JSON.stringify(plan.summary)}`);
}

main();
