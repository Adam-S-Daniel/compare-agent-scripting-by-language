#!/usr/bin/env bun
// CLI entry point for the dependency license checker.
// Usage: bun run src/index.ts --manifest <path> --config <path> [--mock-licenses <path>]
//
// --manifest      Path to a package.json (or compatible manifest) file.
// --config        Path to a JSON file with { allowList: string[], denyList: string[] }.
// --mock-licenses Path to a JSON file mapping package names to SPDX license IDs.
//                 When provided, license lookup uses this file instead of a live registry.
//                 Required for reproducible CI runs; omit to get stubbed "unknown" results.

import { readFileSync } from "fs";
import { resolve } from "path";
import { parsePackageJson, generateReport, formatReport } from "./licenseChecker";
import type { LicenseConfig, LicenseLookupFn } from "./types";

// ---------- Argument parsing ----------

function getArg(flag: string): string | undefined {
  const idx = process.argv.indexOf(flag);
  return idx !== -1 ? process.argv[idx + 1] : undefined;
}

function requireArg(flag: string): string {
  const val = getArg(flag);
  if (!val) {
    console.error(`Error: missing required argument ${flag}`);
    process.exit(1);
  }
  return val;
}

// ---------- File helpers ----------

function readJson<T>(filePath: string, label: string): T {
  try {
    return JSON.parse(readFileSync(resolve(filePath), "utf-8")) as T;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Error: could not read ${label} at '${filePath}': ${msg}`);
    process.exit(1);
  }
}

// ---------- Mock license lookup ----------

function makeMockLookup(db: Record<string, string>): LicenseLookupFn {
  // Returns a lookup function backed by a static JSON map.
  // Packages not present in the map return null (treated as "unknown").
  return async (name: string) => db[name] ?? null;
}

// ---------- Main ----------

async function main(): Promise<void> {
  const manifestPath = requireArg("--manifest");
  const configPath = requireArg("--config");
  const mockLicensesPath = getArg("--mock-licenses");

  // Read and parse the manifest
  const manifestContent = (() => {
    try {
      return readFileSync(resolve(manifestPath), "utf-8");
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`Error: could not read manifest at '${manifestPath}': ${msg}`);
      process.exit(1);
    }
  })();

  const dependencies = parsePackageJson(manifestContent);

  // Read the license config
  const config = readJson<LicenseConfig>(configPath, "license config");

  // Build the lookup function
  let lookupFn: LicenseLookupFn;
  if (mockLicensesPath) {
    const db = readJson<Record<string, string>>(mockLicensesPath, "mock licenses");
    lookupFn = makeMockLookup(db);
  } else {
    // Without a mock, every package license is unknown.
    // In a real implementation this would call the npm registry API.
    lookupFn = async () => null;
  }

  // Generate and print the report
  const report = await generateReport(dependencies, config, lookupFn);
  console.log(formatReport(report));

  // Exit 0 regardless of compliance status so the CI step always completes.
  // Callers can inspect the output for "Status: NON-COMPLIANT" if needed.
}

main();
