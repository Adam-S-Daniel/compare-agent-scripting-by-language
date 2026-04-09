#!/usr/bin/env bun
// Main entry point: reads secrets config from a JSON file, validates rotation,
// and outputs a report in the requested format.
//
// Usage:
//   bun run main.ts --config secrets.json [--format json|markdown] [--warning-days 14] [--reference-date 2026-04-09]
//
// Exit codes:
//   0 = all secrets OK
//   1 = runtime error
//   2 = at least one secret expired or in warning

import { readFileSync } from "fs";
import { buildReport } from "./validator";
import { formatReport } from "./formatter";
import type { SecretConfig, OutputFormat } from "./types";

function parseArgs(args: string[]): {
  configPath: string;
  format: OutputFormat;
  warningDays: number;
  referenceDate: Date;
} {
  let configPath = "";
  let format: OutputFormat = "markdown";
  let warningDays = 14;
  let referenceDate = new Date();

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--config":
        configPath = args[++i];
        break;
      case "--format":
        format = args[++i] as OutputFormat;
        break;
      case "--warning-days":
        warningDays = parseInt(args[++i], 10);
        break;
      case "--reference-date":
        referenceDate = new Date(args[++i]);
        break;
    }
  }

  if (!configPath) {
    throw new Error("Missing required argument: --config <path-to-secrets.json>");
  }

  if (!["json", "markdown"].includes(format)) {
    throw new Error(`Invalid format '${format}'. Use 'json' or 'markdown'.`);
  }

  if (isNaN(warningDays) || warningDays < 0) {
    throw new Error("--warning-days must be a non-negative number.");
  }

  if (isNaN(referenceDate.getTime())) {
    throw new Error("--reference-date must be a valid ISO date.");
  }

  return { configPath, format, warningDays, referenceDate };
}

function main(): void {
  try {
    const { configPath, format, warningDays, referenceDate } = parseArgs(process.argv.slice(2));

    const raw = readFileSync(configPath, "utf-8");
    const secrets: SecretConfig[] = JSON.parse(raw);

    const report = buildReport(secrets, warningDays, referenceDate);
    const output = formatReport(report, format);

    console.log(output);

    // Exit 2 if any secrets need attention
    if (report.expired.length > 0 || report.warning.length > 0) {
      process.exit(2);
    }

    process.exit(0);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`Error: ${message}`);
    process.exit(1);
  }
}

main();
