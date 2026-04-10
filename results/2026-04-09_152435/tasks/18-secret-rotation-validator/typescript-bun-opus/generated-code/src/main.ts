// CLI entry point for the secret rotation validator.
// Usage: bun run src/main.ts --config <path> [--format json|markdown] [--reference-date YYYY-MM-DD]
//
// Reads a JSON config file, validates each secret, and outputs a rotation report.

import { generateReport } from "./validator";
import { formatAsJson, formatAsMarkdown } from "./formatter";
import type { RotationConfig, OutputFormat } from "./types";

/** Parse CLI arguments. */
function parseArgs(): { configPath: string; format: OutputFormat; referenceDate: Date } {
  const args = process.argv.slice(2);
  let configPath = "";
  let format: OutputFormat = "markdown";
  let referenceDate = new Date();

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--config":
        configPath = args[++i];
        break;
      case "--format":
        format = args[++i] as OutputFormat;
        break;
      case "--reference-date":
        referenceDate = new Date(args[++i]);
        break;
    }
  }

  if (!configPath) {
    console.error("Error: --config <path> is required");
    process.exit(1);
  }

  if (format !== "json" && format !== "markdown") {
    console.error(`Error: unsupported format "${format}". Use "json" or "markdown".`);
    process.exit(1);
  }

  return { configPath, format, referenceDate };
}

/** Load and validate the config file. */
async function loadConfig(path: string): Promise<RotationConfig> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    console.error(`Error: config file not found: ${path}`);
    process.exit(1);
  }

  const raw = await file.json();

  // Basic validation
  if (!Array.isArray(raw.secrets)) {
    console.error("Error: config must contain a 'secrets' array");
    process.exit(1);
  }

  if (typeof raw.warningWindowDays !== "number" || raw.warningWindowDays < 0) {
    console.error("Error: config must contain a non-negative 'warningWindowDays' number");
    process.exit(1);
  }

  return raw as RotationConfig;
}

async function main(): Promise<void> {
  const { configPath, format, referenceDate } = parseArgs();
  const config = await loadConfig(configPath);
  const report = generateReport(config, referenceDate);

  const output =
    format === "json" ? formatAsJson(report) : formatAsMarkdown(report);

  console.log(output);

  // Exit with non-zero if any secrets are expired (useful for CI gating)
  if (report.summary.expired > 0) {
    process.exit(2);
  }
}

main();
