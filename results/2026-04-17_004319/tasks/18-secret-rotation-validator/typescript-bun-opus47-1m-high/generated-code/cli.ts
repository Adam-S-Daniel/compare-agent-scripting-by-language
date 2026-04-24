#!/usr/bin/env bun
// CLI entrypoint. Reads a config file and prints a rotation report.
//
//   bun run cli.ts --config secrets.json [--format markdown|json] [--warning-days 14] [--now 2026-04-19]
//
// Exit codes:
//   0 — no expired secrets
//   1 — one or more expired secrets found
//   2 — configuration or usage error

import { loadConfig, renderReport, validateSecrets, type OutputFormat } from "./validator";

interface CliArgs {
  config: string;
  format: OutputFormat;
  warningDays: number;
  now: Date;
}

function parseArgs(argv: string[]): CliArgs {
  const args: Partial<CliArgs> = { format: "markdown", warningDays: 14, now: new Date() };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => {
      const v = argv[++i];
      if (v === undefined) throw new Error(`missing value for ${a}`);
      return v;
    };
    switch (a) {
      case "--config":       args.config = next(); break;
      case "--format": {
        const v = next();
        if (v !== "markdown" && v !== "json") throw new Error(`--format must be markdown|json (got ${v})`);
        args.format = v;
        break;
      }
      case "--warning-days": args.warningDays = Number(next()); break;
      case "--now":          args.now = new Date(`${next()}T00:00:00Z`); break;
      case "-h":
      case "--help":
        console.log(
          "Usage: bun run cli.ts --config <path> [--format markdown|json] [--warning-days N] [--now YYYY-MM-DD]",
        );
        process.exit(0);
      default:
        throw new Error(`unknown argument: ${a}`);
    }
  }
  if (!args.config) throw new Error("--config is required");
  if (!Number.isFinite(args.warningDays!) || args.warningDays! < 0) {
    throw new Error(`--warning-days must be a non-negative number`);
  }
  if (Number.isNaN(args.now!.getTime())) throw new Error(`--now could not be parsed as a date`);
  return args as CliArgs;
}

async function main(): Promise<number> {
  let args: CliArgs;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (err) {
    console.error(`error: ${(err as Error).message}`);
    return 2;
  }

  try {
    const secrets = await loadConfig(args.config);
    const report = validateSecrets(secrets, { now: args.now, warningDays: args.warningDays });
    console.log(renderReport(report, args.format));
    // Print a stable machine-readable summary line to stderr, useful for CI pipelines
    // that want to grep for the totals without re-parsing the whole report.
    console.error(
      `SUMMARY expired=${report.totals.expired} warning=${report.totals.warning} ok=${report.totals.ok} total=${report.totals.total}`,
    );
    return report.totals.expired > 0 ? 1 : 0;
  } catch (err) {
    console.error(`error: ${(err as Error).message}`);
    return 2;
  }
}

process.exit(await main());
