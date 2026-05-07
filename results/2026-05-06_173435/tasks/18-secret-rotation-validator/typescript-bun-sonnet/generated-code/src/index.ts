// CLI entry point for the secret rotation validator.
// Usage: bun run src/index.ts --config <path> [--format markdown|json] [--warning-window <days>] [--date YYYY-MM-DD]

import { readFileSync } from "fs";
import { generateReport } from "./validator";
import { formatMarkdown, formatJSON } from "./formatter";
import type { SecretsConfigFile, OutputFormat } from "./types";

function parseArgs(argv: string[]): {
  configPath: string;
  format: OutputFormat;
  warningWindow: number | null;
  dateOverride: string | null;
} {
  let configPath = "";
  let format: OutputFormat = "markdown";
  let warningWindow: number | null = null;
  let dateOverride: string | null = null;

  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case "--config":
        configPath = argv[++i] ?? "";
        break;
      case "--format":
        const fmt = argv[++i] ?? "";
        if (fmt !== "markdown" && fmt !== "json") {
          console.error(`Error: --format must be "markdown" or "json", got "${fmt}"`);
          process.exit(1);
        }
        format = fmt;
        break;
      case "--warning-window": {
        const n = parseInt(argv[++i] ?? "", 10);
        if (isNaN(n) || n < 0) {
          console.error("Error: --warning-window must be a non-negative integer");
          process.exit(1);
        }
        warningWindow = n;
        break;
      }
      case "--date":
        dateOverride = argv[++i] ?? "";
        break;
      default:
        console.error(`Error: Unknown argument "${argv[i]}"`);
        process.exit(1);
    }
  }

  if (!configPath) {
    console.error("Error: --config <path> is required");
    process.exit(1);
  }

  return { configPath, format, warningWindow, dateOverride };
}

function loadConfig(configPath: string): SecretsConfigFile {
  let raw: string;
  try {
    raw = readFileSync(configPath, "utf8");
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Error: Could not read config file "${configPath}": ${msg}`);
    process.exit(1);
  }

  let config: SecretsConfigFile;
  try {
    config = JSON.parse(raw) as SecretsConfigFile;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Error: Invalid JSON in config file "${configPath}": ${msg}`);
    process.exit(1);
  }

  if (!Array.isArray(config.secrets)) {
    console.error('Error: Config file must have a "secrets" array');
    process.exit(1);
  }

  return config;
}

function main(): void {
  const { configPath, format, warningWindow, dateOverride } = parseArgs(process.argv);
  const config = loadConfig(configPath);

  // Determine reference date: CLI flag overrides system clock
  const today = dateOverride
    ? new Date(`${dateOverride}T00:00:00.000Z`)
    : new Date();

  if (dateOverride && isNaN(today.getTime())) {
    console.error(`Error: Invalid --date value "${dateOverride}" (expected YYYY-MM-DD)`);
    process.exit(1);
  }

  // --warning-window flag overrides config file value; default is 7
  const effectiveWarningWindow = warningWindow ?? config.warningWindowDays ?? 7;

  const report = generateReport(config.secrets, today, effectiveWarningWindow);

  const output = format === "json" ? formatJSON(report) : formatMarkdown(report);
  console.log(output);
}

main();
