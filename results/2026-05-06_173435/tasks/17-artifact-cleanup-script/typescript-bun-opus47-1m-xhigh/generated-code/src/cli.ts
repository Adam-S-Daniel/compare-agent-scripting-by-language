#!/usr/bin/env bun
// CLI entrypoint for the artifact cleanup tool.
//
// Reads a JSON file containing an array of artifact records, applies the
// configured retention policy, and prints a deletion plan + summary. In
// dry-run mode the plan is reported without simulating deletions; otherwise
// the mock "apply" path runs (this script never touches a real artifact
// store — deletion is mock data, as the task spec calls for).

import { readFileSync } from "node:fs";
import {
  buildDeletionPlan,
  formatPlanReport,
  parseArtifactsJson,
  type RetentionPolicy,
} from "./cleanup";

interface CliOptions {
  inputPath: string;
  policy: RetentionPolicy;
  dryRun: boolean;
  now: Date;
}

function parseArgs(argv: string[]): CliOptions {
  let inputPath: string | undefined;
  let maxAgeDays: number | undefined;
  let maxTotalSizeBytes: number | undefined;
  let keepLatestN: number | undefined;
  let dryRun = false;
  let now = new Date();

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]!;
    const next = (): string => {
      const v = argv[++i];
      if (v === undefined) {
        throw new Error(`Missing value for argument: ${arg}`);
      }
      return v;
    };
    switch (arg) {
      case "--input":
      case "-i":
        inputPath = next();
        break;
      case "--max-age-days":
        maxAgeDays = parseIntStrict(next(), arg);
        break;
      case "--max-total-size-bytes":
        maxTotalSizeBytes = parseIntStrict(next(), arg);
        break;
      case "--keep-latest-n":
        keepLatestN = parseIntStrict(next(), arg);
        break;
      case "--dry-run":
        dryRun = true;
        break;
      case "--now":
        now = parseNowOrThrow(next());
        break;
      case "--help":
      case "-h":
        printHelp();
        process.exit(0);
      // eslint-disable-next-line no-fallthrough
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!inputPath) {
    throw new Error("Missing required --input <path> argument");
  }

  return {
    inputPath,
    policy: {
      maxAgeDays,
      maxTotalSizeBytes,
      keepLatestNPerWorkflow: keepLatestN,
    },
    dryRun,
    now,
  };
}

function parseIntStrict(value: string, flag: string): number {
  const n = Number(value);
  if (!Number.isFinite(n) || !Number.isInteger(n) || n < 0) {
    throw new Error(`${flag} requires a non-negative integer, got '${value}'`);
  }
  return n;
}

function parseNowOrThrow(value: string): Date {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) {
    throw new Error(`--now requires a valid ISO date string, got '${value}'`);
  }
  return d;
}

function printHelp(): void {
  console.log(
    [
      "artifact-cleanup — apply retention policies to a list of artifacts",
      "",
      "Usage: bun run src/cli.ts --input <path> [options]",
      "",
      "Required:",
      "  --input <path>            JSON file with artifact records (array)",
      "",
      "Policies (any combination):",
      "  --max-age-days <n>        Delete artifacts older than n days",
      "  --max-total-size-bytes <n>  Cap total kept size; oldest evicted first",
      "  --keep-latest-n <n>       Keep at most N newest artifacts per workflow",
      "",
      "Options:",
      "  --dry-run                 Report only; do not apply",
      "  --now <iso>               Override 'now' for deterministic runs",
      "  --help, -h                Show this help",
    ].join("\n"),
  );
}

export async function main(argv: string[]): Promise<number> {
  let options: CliOptions;
  try {
    options = parseArgs(argv);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`error: ${msg}`);
    console.error("Run with --help for usage.");
    return 2;
  }

  let raw: string;
  try {
    raw = readFileSync(options.inputPath, "utf8");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`error: cannot read ${options.inputPath}: ${msg}`);
    return 1;
  }

  let artifacts;
  try {
    artifacts = parseArtifactsJson(raw);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`error: ${msg}`);
    return 1;
  }

  const plan = buildDeletionPlan(artifacts, options.policy, options.now);
  const report = formatPlanReport(plan, { dryRun: options.dryRun });
  console.log(report);
  return 0;
}

// Run only when invoked as a script (Bun sets import.meta.main).
if (import.meta.main) {
  const code = await main(process.argv.slice(2));
  process.exit(code);
}
