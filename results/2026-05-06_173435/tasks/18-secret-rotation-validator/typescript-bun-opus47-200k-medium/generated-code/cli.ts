#!/usr/bin/env bun
// CLI entrypoint. Reads a secrets config JSON and emits a rotation report.
//
// Usage:
//   bun run cli.ts --config secrets.json [--format md|json] [--warn 7] [--now 2026-05-08]
// Exit codes:
//   0 - all secrets ok
//   1 - one or more warnings (no expirations)
//   2 - one or more expirations
//   3 - usage / parse error

import { generateReport, formatJson, formatMarkdown, parseSecrets } from "./validator.ts";

interface Args {
  config: string;
  format: "md" | "json";
  warn: number;
  now: Date;
}

function parseArgs(argv: string[]): Args {
  const args: Partial<Args> = { format: "md", warn: 7, now: new Date() };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = (): string => {
      const v = argv[++i];
      if (v === undefined) throw new Error(`Missing value for ${a}`);
      return v;
    };
    switch (a) {
      case "--config": args.config = next(); break;
      case "--format": {
        const v = next();
        if (v !== "md" && v !== "json") throw new Error(`--format must be md|json, got ${v}`);
        args.format = v;
        break;
      }
      case "--warn": {
        const n = Number(next());
        if (!Number.isFinite(n) || n < 0) throw new Error("--warn must be a non-negative number");
        args.warn = n;
        break;
      }
      case "--now": {
        const raw = next();
        const parsed = new Date(raw.includes("T") ? raw : raw + "T00:00:00Z");
        if (Number.isNaN(parsed.getTime())) throw new Error(`--now invalid date: ${raw}`);
        args.now = parsed;
        break;
      }
      case "-h":
      case "--help":
        printHelp();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${a}`);
    }
  }
  if (!args.config) throw new Error("--config <path> is required");
  return args as Args;
}

function printHelp(): void {
  console.log(`secret-rotation-validator
  --config <file>   path to JSON config with { "secrets": [...] }
  --format md|json  output format (default: md)
  --warn <days>     warning window in days (default: 7)
  --now <date>      override current date (YYYY-MM-DD), for tests
`);
}

async function main(): Promise<number> {
  let parsed: Args;
  try {
    parsed = parseArgs(process.argv.slice(2));
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    printHelp();
    return 3;
  }

  let text: string;
  try {
    text = await Bun.file(parsed.config).text();
  } catch (err) {
    console.error(`Error: cannot read config "${parsed.config}": ${(err as Error).message}`);
    return 3;
  }

  let secrets;
  try {
    secrets = parseSecrets(text);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    return 3;
  }

  const report = generateReport(secrets, parsed.now, parsed.warn);
  const output = parsed.format === "json" ? formatJson(report) : formatMarkdown(report);
  console.log(output);

  if (report.summary.expired > 0) return 2;
  if (report.summary.warning > 0) return 1;
  return 0;
}

const code = await main();
process.exit(code);
