// CLI entry point for the secret rotation validator
// Usage: bun run src/main.ts <config.json> [--format markdown|json] [--today YYYY-MM-DD]

import { generateReport, formatMarkdown, formatJSON } from "./validator";
import type { ValidatorConfig } from "./types";
import { readFileSync } from "fs";

function parseArgs(args: string[]): {
  configPath: string;
  format: "markdown" | "json";
  today?: string;
} {
  const configPath = args[0];
  if (!configPath) {
    console.error("Usage: bun run src/main.ts <config.json> [--format markdown|json] [--today YYYY-MM-DD]");
    process.exit(1);
  }

  let format: "markdown" | "json" = "markdown";
  let today: string | undefined;

  for (let i = 1; i < args.length; i++) {
    if (args[i] === "--format" && args[i + 1]) {
      const fmt = args[i + 1];
      if (fmt !== "markdown" && fmt !== "json") {
        console.error(`Invalid format: ${fmt}. Must be 'markdown' or 'json'.`);
        process.exit(1);
      }
      format = fmt;
      i++;
    } else if (args[i] === "--today" && args[i + 1]) {
      today = args[i + 1];
      i++;
    }
  }

  return { configPath, format, today };
}

function main(): void {
  const args = process.argv.slice(2);
  const { configPath, format, today } = parseArgs(args);

  let config: ValidatorConfig;
  try {
    const raw = readFileSync(configPath, "utf-8");
    config = JSON.parse(raw) as ValidatorConfig;
  } catch (err) {
    console.error(`Failed to read config file '${configPath}': ${(err as Error).message}`);
    process.exit(1);
  }

  if (!Array.isArray(config.secrets)) {
    console.error("Config must have a 'secrets' array.");
    process.exit(1);
  }
  if (typeof config.warningWindowDays !== "number") {
    console.error("Config must have a numeric 'warningWindowDays' field.");
    process.exit(1);
  }

  const report = generateReport(config, today);

  if (format === "json") {
    console.log(formatJSON(report));
  } else {
    console.log(formatMarkdown(report));
  }
}

main();
