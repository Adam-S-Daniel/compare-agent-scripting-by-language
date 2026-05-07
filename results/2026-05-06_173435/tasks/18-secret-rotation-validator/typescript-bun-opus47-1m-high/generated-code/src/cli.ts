#!/usr/bin/env bun
// CLI: read a JSON config of secrets, classify them, and print the report.
// Exit codes encode urgency so CI gates can branch on the worst bucket:
//   0 = all OK
//   1 = warnings present (no expired)
//   2 = expired secrets present
//   3 = configuration / usage error

import { readFileSync } from "node:fs";
import { classifySecrets, type Secret } from "./classify.ts";
import { formatJson, formatMarkdown } from "./format.ts";

interface Args {
  config: string;
  warningWindowDays: number;
  format: "markdown" | "json";
  ignoreExpired: boolean;
  ignoreWarning: boolean;
}

function parseArgs(argv: string[]): Args {
  const args: Args = {
    config: "secrets.json",
    warningWindowDays: 14,
    format: "markdown",
    ignoreExpired: false,
    ignoreWarning: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case "--config":
        args.config = required(argv, ++i, "--config");
        break;
      case "--warning-window":
        args.warningWindowDays = Number(required(argv, ++i, "--warning-window"));
        if (!Number.isFinite(args.warningWindowDays) || args.warningWindowDays < 0) {
          throw new UsageError(`--warning-window must be a non-negative number`);
        }
        break;
      case "--format": {
        const v = required(argv, ++i, "--format");
        if (v !== "markdown" && v !== "json") {
          throw new UsageError(`--format must be 'markdown' or 'json', got '${v}'`);
        }
        args.format = v;
        break;
      }
      case "--ignore-expired":
        args.ignoreExpired = true;
        break;
      case "--ignore-warning":
        args.ignoreWarning = true;
        break;
      case "-h":
      case "--help":
        printHelp();
        process.exit(0);
      default:
        throw new UsageError(`Unknown argument: ${a}`);
    }
  }
  return args;
}

class UsageError extends Error {}
class ConfigError extends Error {}

function required(argv: string[], i: number, flag: string): string {
  const v = argv[i];
  if (v === undefined) throw new UsageError(`${flag} requires a value`);
  return v;
}

function printHelp(): void {
  process.stdout.write(`secret-rotation-validator
Usage: bun run src/cli.ts [options]

Options:
  --config <path>           Path to secrets JSON config (default: secrets.json)
  --warning-window <days>   Days-before-expiry that count as "warning" (default: 14)
  --format <markdown|json>  Output format (default: markdown)
  --ignore-expired          Exit 0/1 even if expired secrets are present
  --ignore-warning          Exit 0 even if warnings are present
  -h, --help                Show this help

Exit codes: 0 ok, 1 warnings, 2 expired, 3 config error.
`);
}

function loadSecrets(path: string): Secret[] {
  let raw: string;
  try {
    raw = readFileSync(path, "utf8");
  } catch (err) {
    throw new ConfigError(`Could not read config file at '${path}': ${(err as Error).message}`);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    throw new ConfigError(`Config file '${path}' is not valid JSON: ${(err as Error).message}`);
  }
  if (!Array.isArray(parsed)) {
    throw new ConfigError(`Config file must be a JSON array of secret objects`);
  }
  return parsed as Secret[];
}

function getNow(): Date {
  // FAKE_NOW lets tests pin a deterministic clock without monkey-patching Date.
  const fake = process.env.FAKE_NOW;
  if (fake) {
    const d = new Date(fake);
    if (Number.isNaN(d.getTime())) throw new ConfigError(`FAKE_NOW is not a valid ISO date: ${fake}`);
    return d;
  }
  return new Date();
}

function main(): number {
  let args: Args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (err) {
    if (err instanceof UsageError) {
      process.stderr.write(`error: ${err.message}\n`);
      printHelp();
      return 3;
    }
    throw err;
  }

  let secrets: Secret[];
  try {
    secrets = loadSecrets(args.config);
  } catch (err) {
    process.stderr.write(`error: ${(err as Error).message}\n`);
    return 3;
  }

  let report;
  try {
    report = classifySecrets(secrets, {
      warningWindowDays: args.warningWindowDays,
      now: getNow(),
    });
  } catch (err) {
    process.stderr.write(`error: ${(err as Error).message}\n`);
    return 3;
  }

  const output = args.format === "json" ? formatJson(report) : formatMarkdown(report);
  process.stdout.write(output);
  if (!output.endsWith("\n")) process.stdout.write("\n");

  if (report.totals.expired > 0 && !args.ignoreExpired) return 2;
  if (report.totals.warning > 0 && !args.ignoreWarning) return 1;
  return 0;
}

process.exit(main());
