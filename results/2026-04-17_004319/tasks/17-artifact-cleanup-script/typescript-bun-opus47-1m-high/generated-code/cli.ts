#!/usr/bin/env bun
// CLI wrapper around the cleanup library. Parsed flags:
//   --input <path>              JSON file with artifact array (required)
//   --max-age-days <n>          delete artifacts older than n days
//   --max-total-size <bytes>    cap total retained size at bytes
//   --keep-latest <n>           keep only n newest per workflowRunId
//   --dry-run                   report plan but do not claim deletions
//   --now <iso>                 override "now" (for deterministic tests)
//   --json                      emit summary JSON alongside human output

import {
  planCleanup,
  formatPlanSummary,
  type Artifact,
  type RetentionPolicy,
} from "./cleanup";

export interface CliArgs {
  input: string;
  maxAgeDays?: number;
  maxTotalSizeBytes?: number;
  keepLatestPerWorkflow?: number;
  dryRun: boolean;
  now?: number;
  json: boolean;
}

export function parseArgs(argv: string[]): CliArgs {
  const out: Partial<CliArgs> = { dryRun: false, json: false };
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    const next = () => {
      const v = argv[++i];
      if (v === undefined) throw new Error(`missing value for ${flag}`);
      return v;
    };
    switch (flag) {
      case "--input":
        out.input = next();
        break;
      case "--max-age-days":
        out.maxAgeDays = Number(next());
        break;
      case "--max-total-size":
        out.maxTotalSizeBytes = Number(next());
        break;
      case "--keep-latest":
        out.keepLatestPerWorkflow = Number(next());
        break;
      case "--dry-run":
        out.dryRun = true;
        break;
      case "--now": {
        const v = next();
        const t = Date.parse(v);
        if (Number.isNaN(t)) throw new Error(`--now: cannot parse '${v}'`);
        out.now = t;
        break;
      }
      case "--json":
        out.json = true;
        break;
      default:
        throw new Error(`unknown flag: ${flag}`);
    }
  }
  if (!out.input) throw new Error("--input is required");
  return out as CliArgs;
}

export async function runCli(
  argv: string[],
  write: (s: string) => void = console.log
): Promise<number> {
  let args: CliArgs;
  try {
    args = parseArgs(argv);
  } catch (e) {
    write(`error: ${(e as Error).message}`);
    return 2;
  }

  let artifacts: Artifact[];
  try {
    const text = await Bun.file(args.input).text();
    artifacts = JSON.parse(text);
    if (!Array.isArray(artifacts)) {
      throw new Error("fixture must be a JSON array of artifacts");
    }
  } catch (e) {
    write(`error: failed to read artifacts from ${args.input}: ${(e as Error).message}`);
    return 1;
  }

  const policy: RetentionPolicy = {
    maxAgeDays: args.maxAgeDays,
    maxTotalSizeBytes: args.maxTotalSizeBytes,
    keepLatestPerWorkflow: args.keepLatestPerWorkflow,
  };

  let plan;
  try {
    plan = planCleanup(artifacts, policy, args.now ?? Date.now(), {
      dryRun: args.dryRun,
    });
  } catch (e) {
    write(`error: ${(e as Error).message}`);
    return 1;
  }

  write(formatPlanSummary(plan));
  if (args.json) {
    write(
      JSON.stringify({
        summary: plan.summary,
        dryRun: plan.dryRun,
        toDelete: plan.toDelete.map((a) => a.id),
        toRetain: plan.toRetain.map((a) => a.id),
      })
    );
  }
  return 0;
}

// Entry point when executed directly (`bun run cli.ts ...`).
if (import.meta.main) {
  const code = await runCli(Bun.argv.slice(2));
  process.exit(code);
}
