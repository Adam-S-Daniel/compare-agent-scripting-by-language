/**
 * Secret Rotation Validator — CLI Entry Point
 *
 * Usage:
 *   bun run src/index.ts [--format markdown|json] [--warning-days N] [--config path]
 *
 * Reads secret configurations from a JSON file (default: secrets.json)
 * and outputs a rotation report. Exits with code 1 if any secrets are expired.
 */

import { generateReport, formatAsMarkdown, formatAsJson } from "./rotation-validator";
import type { SecretConfig, OutputFormat } from "./types";

// ─── CLI Argument Parsing ─────────────────────────────────────────────────────

function parseArgs(args: string[]): {
  format: OutputFormat;
  warningDays: number;
  configPath: string;
} {
  let format: OutputFormat = "markdown";
  let warningDays = 14;
  let configPath = "secrets.json";

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--format":
        const fmt = args[++i];
        if (fmt !== "markdown" && fmt !== "json") {
          console.error(`Error: --format must be 'markdown' or 'json', got '${fmt}'`);
          process.exit(1);
        }
        format = fmt;
        break;
      case "--warning-days":
        const days = parseInt(args[++i], 10);
        if (isNaN(days) || days < 0) {
          console.error(`Error: --warning-days must be a non-negative integer`);
          process.exit(1);
        }
        warningDays = days;
        break;
      case "--config":
        configPath = args[++i];
        break;
    }
  }

  return { format, warningDays, configPath };
}

// ─── Config Loading ───────────────────────────────────────────────────────────

interface RawSecretConfig {
  name: string;
  lastRotated: string;
  rotationPolicyDays: number;
  requiredBy: string[];
}

async function loadSecrets(configPath: string): Promise<SecretConfig[]> {
  let raw: RawSecretConfig[];
  try {
    const file = Bun.file(configPath);
    const text = await file.text();
    raw = JSON.parse(text);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`Error: Could not load secrets config from '${configPath}': ${message}`);
    process.exit(1);
  }

  // Convert raw JSON dates (strings) to Date objects
  return raw.map((s) => ({
    name: s.name,
    lastRotated: new Date(s.lastRotated),
    rotationPolicyDays: s.rotationPolicyDays,
    requiredBy: s.requiredBy,
  }));
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const { format, warningDays, configPath } = parseArgs(args);

  const secrets = await loadSecrets(configPath);
  const report = generateReport(secrets, new Date(), warningDays);

  const output = format === "json" ? formatAsJson(report) : formatAsMarkdown(report);
  console.log(output);

  // Exit 1 if any secrets are expired (useful for CI/CD gating)
  if (report.summary.expiredCount > 0) {
    process.exit(1);
  }
}

main();
