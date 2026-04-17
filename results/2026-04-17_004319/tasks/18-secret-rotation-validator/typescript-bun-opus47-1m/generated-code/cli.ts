#!/usr/bin/env bun
// CLI wrapper around validator.ts.
//
// Usage:
//   bun run cli.ts --config secrets.json \
//                  [--format json|markdown] \
//                  [--warning-days 14] \
//                  [--reference-date YYYY-MM-DD]
//
// Exit codes are designed so CI can use them directly as pipeline gates:
//   0 — everything ok
//   1 — at least one expired secret (actionable now)
//   2 — at least one secret in the warning window (nothing expired)
//   3 — usage / config error

import { readFileSync } from "node:fs";
import {
  parseConfig,
  renderJson,
  renderMarkdown,
  validateSecrets,
} from "./validator.ts";

interface CliArgs {
  config: string;
  format: "json" | "markdown";
  warningDays: number;
  referenceDate: Date;
}

function fail(msg: string): never {
  process.stderr.write(`secret-rotation-validator: ${msg}\n`);
  process.exit(3);
}

function parseArgs(argv: string[]): CliArgs {
  const out: Partial<CliArgs> = { format: "json", warningDays: 14 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]!;
    const next = (): string => {
      const v = argv[i + 1];
      if (v === undefined) fail(`${arg} requires a value`);
      i++;
      return v;
    };
    switch (arg) {
      case "--config":
        out.config = next();
        break;
      case "--format": {
        const v = next();
        if (v !== "json" && v !== "markdown") {
          fail(`unknown --format '${v}' (expected 'json' or 'markdown')`);
        }
        out.format = v;
        break;
      }
      case "--warning-days": {
        const n = Number.parseInt(next(), 10);
        if (!Number.isFinite(n) || n < 0) fail(`--warning-days must be >= 0`);
        out.warningDays = n;
        break;
      }
      case "--reference-date": {
        const v = next();
        if (!/^\d{4}-\d{2}-\d{2}$/.test(v)) {
          fail(`--reference-date must be YYYY-MM-DD`);
        }
        out.referenceDate = new Date(`${v}T00:00:00Z`);
        break;
      }
      case "-h":
      case "--help":
        process.stdout.write(
          "Usage: bun run cli.ts --config <file.json> [--format json|markdown] " +
            "[--warning-days N] [--reference-date YYYY-MM-DD]\n",
        );
        process.exit(0);
      default:
        fail(`unknown argument: ${arg}`);
    }
  }
  if (!out.config) fail("--config is required");
  if (!out.referenceDate) out.referenceDate = new Date();
  return out as CliArgs;
}

function main(argv: string[]): number {
  const args = parseArgs(argv);

  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(args.config, "utf8"));
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    fail(`failed to read config '${args.config}': ${msg}`);
  }

  let secrets;
  try {
    secrets = parseConfig(raw);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    fail(`invalid config: ${msg}`);
  }

  const report = validateSecrets(secrets, {
    referenceDate: args.referenceDate,
    warningDays: args.warningDays,
  });

  const out = args.format === "json" ? renderJson(report) : renderMarkdown(report);
  process.stdout.write(out);
  if (!out.endsWith("\n")) process.stdout.write("\n");

  if (report.summary.expired > 0) return 1;
  if (report.summary.warning > 0) return 2;
  return 0;
}

process.exit(main(process.argv.slice(2)));
