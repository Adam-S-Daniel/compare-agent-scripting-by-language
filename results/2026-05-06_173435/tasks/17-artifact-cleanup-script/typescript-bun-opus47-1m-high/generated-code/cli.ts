// CLI entrypoint for the artifact cleanup planner.
//
// Usage:
//   bun run cli.ts --input <path> [--max-age-days N] [--keep-latest-per-workflow N]
//                  [--max-total-size-bytes N] [--dry-run|--execute] [--now <iso>]
//
// `--input` accepts JSON (an array of {name, sizeBytes, createdAt, workflowRunId}).
// All policy flags are optional — the union of supplied policies is applied.
// `--now` is an internal/test hook that pins the current time; CI usually omits it.

import { readFileSync } from "node:fs";
import {
  planCleanup,
  formatPlan,
  parseArtifactsJson,
  type RetentionPolicy,
} from "./cleanup";

interface CliOptions {
  inputPath: string;
  policy: RetentionPolicy;
  dryRun: boolean;
  nowMs: number;
}

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = {
    inputPath: "",
    policy: {},
    dryRun: true, // dry-run by default — safer for any "delete" tool.
    nowMs: Date.now(),
  };

  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    const next = (): string => {
      const v = argv[++i];
      if (v === undefined) throw new Error(`Missing value for ${flag}`);
      return v;
    };
    switch (flag) {
      case "--input":
        opts.inputPath = next();
        break;
      case "--max-age-days":
        opts.policy.maxAgeDays = parseIntStrict(next(), flag);
        break;
      case "--keep-latest-per-workflow":
        opts.policy.keepLatestPerWorkflow = parseIntStrict(next(), flag);
        break;
      case "--max-total-size-bytes":
        opts.policy.maxTotalSizeBytes = parseIntStrict(next(), flag);
        break;
      case "--dry-run":
        opts.dryRun = true;
        break;
      case "--execute":
        opts.dryRun = false;
        break;
      case "--now": {
        const ms = Date.parse(next());
        if (Number.isNaN(ms)) throw new Error(`--now must be ISO date`);
        opts.nowMs = ms;
        break;
      }
      case "-h":
      case "--help":
        printHelp();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${flag}`);
    }
  }

  if (!opts.inputPath) {
    throw new Error("--input <path-to-artifacts.json> is required");
  }
  return opts;
}

function parseIntStrict(s: string, flag: string): number {
  const n = Number(s);
  if (!Number.isFinite(n) || n < 0 || !Number.isInteger(n)) {
    throw new Error(`${flag} expected a non-negative integer, got: ${s}`);
  }
  return n;
}

function printHelp(): void {
  console.log(`Artifact cleanup planner

Usage:
  bun run cli.ts --input <path> [policy flags...] [--dry-run|--execute]

Policy flags (any combination):
  --max-age-days N              Delete artifacts older than N days
  --keep-latest-per-workflow N  Per workflow run, keep newest N
  --max-total-size-bytes N      If kept total exceeds N, delete oldest first

Mode:
  --dry-run        (default) Print plan only
  --execute        Print plan tagged for execution

Other:
  --input <path>   Path to JSON file containing the artifact list
  --now <iso>      Pin "now" (test hook)
`);
}

function main(): void {
  const opts = parseArgs(process.argv.slice(2));

  let raw: string;
  try {
    raw = readFileSync(opts.inputPath, "utf8");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Failed to read input file ${opts.inputPath}: ${msg}`);
    process.exit(2);
  }

  let artifacts;
  try {
    artifacts = parseArtifactsJson(raw);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Failed to parse ${opts.inputPath}: ${msg}`);
    process.exit(2);
  }

  const plan = planCleanup(artifacts, opts.policy, opts.nowMs);
  console.log(formatPlan(plan, { dryRun: opts.dryRun }));

  // Machine-readable summary line — easy for the workflow to grep on.
  console.log(
    `RESULT mode=${opts.dryRun ? "dry-run" : "execute"} ` +
      `total=${plan.summary.totalCount} ` +
      `kept=${plan.summary.keptCount} ` +
      `deleted=${plan.summary.deletedCount} ` +
      `reclaimed_bytes=${plan.summary.bytesReclaimed}`,
  );
}

try {
  main();
} catch (err) {
  const msg = err instanceof Error ? err.message : String(err);
  console.error(`Error: ${msg}`);
  process.exit(1);
}
