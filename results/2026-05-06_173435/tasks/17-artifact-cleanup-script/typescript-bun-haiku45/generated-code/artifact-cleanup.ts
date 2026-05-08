#!/usr/bin/env bun
import { readFileSync, writeFileSync } from "fs";
import { cleanupArtifacts, Artifact, RetentionPolicy } from "./cleanup";

interface CLIOptions {
  input: string;
  dryRun: boolean;
  maxAge?: number;
  maxTotalSize?: number;
  keepLatestN?: number;
  outputFile?: string;
}

function parseArgs(): CLIOptions {
  const args = process.argv.slice(2);
  const options: CLIOptions = {
    input: "",
    dryRun: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg === "--input" && i + 1 < args.length) {
      options.input = args[++i];
    } else if (arg === "--dry-run") {
      options.dryRun = true;
    } else if (arg === "--max-age" && i + 1 < args.length) {
      options.maxAge = parseInt(args[++i], 10);
    } else if (arg === "--max-size" && i + 1 < args.length) {
      options.maxTotalSize = parseInt(args[++i], 10);
    } else if (arg === "--keep-latest" && i + 1 < args.length) {
      options.keepLatestN = parseInt(args[++i], 10);
    } else if (arg === "--output" && i + 1 < args.length) {
      options.outputFile = args[++i];
    } else if (arg === "--help") {
      printHelp();
      process.exit(0);
    }
  }

  return options;
}

function printHelp() {
  console.log(`
Artifact Cleanup Script

Usage: artifact-cleanup [options]

Options:
  --input <file>        JSON file with artifact data
  --dry-run             Show what would be deleted without deleting
  --max-age <ms>        Max age in milliseconds
  --max-size <bytes>    Max total size in bytes
  --keep-latest <n>     Keep latest N per workflow
  --output <file>       Output file for deletion plan
  --help                Show this help
`);
}

function main() {
  const options = parseArgs();

  if (!options.input) {
    console.error("Error: --input file is required");
    process.exit(1);
  }

  // Read artifact data
  let artifacts: Artifact[];
  try {
    const data = readFileSync(options.input, "utf-8");
    const parsed = JSON.parse(data);
    artifacts = parsed.artifacts.map(
      (a: {
        name: string;
        size: number;
        createdAt: string;
        workflowRunId: string;
      }) => ({
        ...a,
        createdAt: new Date(a.createdAt),
      })
    );
  } catch (error) {
    console.error(`Error reading artifact file: ${error}`);
    process.exit(1);
  }

  // Build policy
  const policy: RetentionPolicy = {};
  if (options.maxAge !== undefined) {
    policy.maxAge = options.maxAge;
  }
  if (options.maxTotalSize !== undefined) {
    policy.maxTotalSize = options.maxTotalSize;
  }
  if (options.keepLatestN !== undefined) {
    policy.keepLatestN = options.keepLatestN;
  }

  // Run cleanup
  const result = cleanupArtifacts(artifacts, policy, options.dryRun);

  // Format output
  const output = {
    dryRun: options.dryRun,
    policy,
    summary: result.summary,
    toDelete: result.toDelete.map((a) => ({
      name: a.name,
      size: a.size,
      createdAt: a.createdAt.toISOString(),
      workflowRunId: a.workflowRunId,
    })),
    toRetain: result.toRetain.map((a) => ({
      name: a.name,
      size: a.size,
      createdAt: a.createdAt.toISOString(),
      workflowRunId: a.workflowRunId,
    })),
  };

  // Print results
  console.log(JSON.stringify(output, null, 2));

  // Save to file if specified
  if (options.outputFile) {
    writeFileSync(options.outputFile, JSON.stringify(output, null, 2));
    console.log(`\nResults saved to ${options.outputFile}`);
  }

  // Exit with success
  process.exit(0);
}

main();
