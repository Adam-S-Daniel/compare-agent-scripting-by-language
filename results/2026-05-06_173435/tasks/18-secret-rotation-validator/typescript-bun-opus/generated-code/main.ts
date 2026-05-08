import { readFileSync } from "fs";
import { generateReport } from "./validator";
import { formatJson, formatMarkdown } from "./formatter";
import type { ValidationConfig } from "./types";

function parseArgs(argv: string[]): {
  config: string;
  format: "json" | "markdown";
  warningDays: number;
  referenceDate?: string;
} {
  const args = argv.slice(2);
  let config = "";
  let format: "json" | "markdown" = "json";
  let warningDays = 14;
  let referenceDate: string | undefined;

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--config":
        config = args[++i];
        break;
      case "--format":
        const fmt = args[++i];
        if (fmt !== "json" && fmt !== "markdown") {
          console.error(`Error: Invalid format "${fmt}". Must be "json" or "markdown".`);
          process.exit(1);
        }
        format = fmt;
        break;
      case "--warning-days":
        warningDays = parseInt(args[++i], 10);
        if (isNaN(warningDays) || warningDays < 0) {
          console.error("Error: --warning-days must be a non-negative integer.");
          process.exit(1);
        }
        break;
      case "--reference-date":
        referenceDate = args[++i];
        break;
      default:
        console.error(`Error: Unknown argument "${args[i]}".`);
        process.exit(1);
    }
  }

  if (!config) {
    console.error("Error: --config is required.");
    process.exit(1);
  }

  return { config, format, warningDays, referenceDate };
}

function main(): void {
  const { config, format, warningDays, referenceDate } = parseArgs(process.argv);

  let rawConfig: string;
  try {
    rawConfig = readFileSync(config, "utf-8");
  } catch (e: any) {
    console.error(`Error: Cannot read config file "${config}": ${e.message}`);
    process.exit(1);
  }

  let secrets: any;
  try {
    secrets = JSON.parse(rawConfig);
  } catch (e: any) {
    console.error(`Error: Invalid JSON in config file: ${e.message}`);
    process.exit(1);
  }

  const validationConfig: ValidationConfig = {
    secrets: secrets.secrets || secrets,
    warningWindowDays: warningDays,
    referenceDate,
  };

  try {
    const report = generateReport(validationConfig);
    const output = format === "json" ? formatJson(report) : formatMarkdown(report);
    console.log(output);
  } catch (e: any) {
    console.error(`Error: ${e.message}`);
    process.exit(1);
  }
}

main();
