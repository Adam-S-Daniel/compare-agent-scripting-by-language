#!/usr/bin/env bun
/**
 * Dependency License Checker - CLI Entry Point
 *
 * Usage:
 *   bun run src/main.ts --manifest <path> --config <path> [--include-dev]
 *
 * Example:
 *   bun run src/main.ts --manifest fixtures/package-approved.json \
 *                       --config fixtures/license-config.json
 */

import { parsePackageJson, checkLicenses, generateReport } from "./licenseChecker";
import { mockLicenseLookup } from "./mockLicenseDb";
import type { LicenseConfig } from "./licenseChecker";

// ─── Argument Parsing ────────────────────────────────────────────────────────

function parseArgs(args: string[]): {
  manifest: string;
  config: string;
  includeDev: boolean;
  format: "markdown" | "json";
} {
  let manifest = "";
  let config = "";
  let includeDev = false;
  let format: "markdown" | "json" = "markdown";

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--manifest" && args[i + 1]) {
      manifest = args[++i];
    } else if (args[i] === "--config" && args[i + 1]) {
      config = args[++i];
    } else if (args[i] === "--include-dev") {
      includeDev = true;
    } else if (args[i] === "--format" && args[i + 1]) {
      const f = args[++i];
      if (f === "json" || f === "markdown") {
        format = f;
      }
    }
  }

  if (!manifest) {
    throw new Error("Missing required argument: --manifest <path>");
  }
  if (!config) {
    throw new Error("Missing required argument: --config <path>");
  }

  return { manifest, config, includeDev, format };
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  let opts: ReturnType<typeof parseArgs>;
  try {
    opts = parseArgs(args);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    console.error(
      "Usage: bun run src/main.ts --manifest <path> --config <path> [--include-dev] [--format markdown|json]"
    );
    process.exit(1);
  }

  // Read manifest and config files
  let manifestContent: string;
  let configContent: string;

  try {
    manifestContent = await Bun.file(opts.manifest).text();
  } catch {
    console.error(`Error: Cannot read manifest file: ${opts.manifest}`);
    process.exit(1);
  }

  try {
    configContent = await Bun.file(opts.config).text();
  } catch {
    console.error(`Error: Cannot read config file: ${opts.config}`);
    process.exit(1);
  }

  let licenseConfig: LicenseConfig;
  try {
    licenseConfig = JSON.parse(configContent) as LicenseConfig;
  } catch {
    console.error(`Error: Invalid JSON in config file: ${opts.config}`);
    process.exit(1);
  }

  // Parse dependencies from the manifest
  let dependencies;
  try {
    dependencies = parsePackageJson(manifestContent, { includeDev: opts.includeDev });
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }

  if (dependencies.length === 0) {
    console.log("No dependencies found in manifest.");
    process.exit(0);
  }

  console.log(`Checking ${dependencies.length} dependencies...`);

  // Check licenses
  const results = await checkLicenses(dependencies, licenseConfig, mockLicenseLookup);
  const report = generateReport(results);

  // Output report
  if (opts.format === "json") {
    console.log(
      JSON.stringify(
        {
          compliant: report.compliant,
          summary: report.summary,
          results: report.results,
        },
        null,
        2
      )
    );
  } else {
    console.log(report.toMarkdown());
  }

  // Exit with non-zero if not compliant (useful for CI)
  if (!report.compliant) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(`Unexpected error: ${(err as Error).message}`);
  process.exit(1);
});
