/**
 * Secret Rotation Validator CLI
 *
 * Usage:
 *   bun run app.ts [options]
 *
 * Options:
 *   --config <file>       Path to secrets JSON config (default: fixtures/secrets.json)
 *   --warning-days <N>    Warning window in days (default: 14)
 *   --format <fmt>        Output format: json or markdown (default: markdown)
 *   --today <YYYY-MM-DD>  Override today's date for deterministic output (default: today)
 *
 * Example:
 *   bun run app.ts --config fixtures/secrets.json --format json --today 2026-04-10
 */
import { readFileSync } from "fs";
import type { SecretConfig } from "./src/types";
import { generateReport } from "./src/validator";
import { formatMarkdown, formatJSON } from "./src/formatter";

/** Parses CLI arguments into a structured options object */
function parseArgs(): {
  config: string;
  warningDays: number;
  format: string;
  today: string;
} {
  const args = process.argv.slice(2);
  let config = "fixtures/secrets.json";
  let warningDays = 14;
  let format = "markdown";
  let today = new Date().toISOString().slice(0, 10);

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg.startsWith("--config=")) {
      config = arg.slice("--config=".length);
    } else if (arg === "--config") {
      config = args[++i];
    } else if (arg.startsWith("--warning-days=")) {
      warningDays = parseInt(arg.slice("--warning-days=".length), 10);
    } else if (arg === "--warning-days") {
      warningDays = parseInt(args[++i], 10);
    } else if (arg.startsWith("--format=")) {
      format = arg.slice("--format=".length);
    } else if (arg === "--format") {
      format = args[++i];
    } else if (arg.startsWith("--today=")) {
      today = arg.slice("--today=".length);
    } else if (arg === "--today") {
      today = args[++i];
    }
  }

  return { config, warningDays, format, today };
}

function main(): void {
  const { config, warningDays, format, today } = parseArgs();

  // Validate format early
  if (format !== "json" && format !== "markdown") {
    console.error(`Error: Unknown format '${format}'. Use 'json' or 'markdown'.`);
    process.exit(1);
  }

  // Load secrets configuration
  let secrets: SecretConfig[];
  try {
    const content = readFileSync(config, "utf-8");
    secrets = JSON.parse(content) as SecretConfig[];
  } catch (err) {
    if (err instanceof Error) {
      console.error(`Error reading config '${config}': ${err.message}`);
    } else {
      console.error(`Error reading config '${config}'.`);
    }
    process.exit(1);
  }

  // Generate report
  const report = generateReport(secrets, today, warningDays);

  // Output in requested format
  if (format === "json") {
    console.log(formatJSON(report));
  } else {
    console.log(formatMarkdown(report));
  }
}

main();
