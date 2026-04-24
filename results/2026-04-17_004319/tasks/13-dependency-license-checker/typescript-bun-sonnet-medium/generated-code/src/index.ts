// Main CLI entry point.
// Usage: bun run src/index.ts --config <config.json> <manifest.json>

import { parseDependencies } from "./parser";
import { checkLicenses } from "./licenseChecker";
import { generateReport } from "./reporter";
import { mockLicenseLookup } from "./mockLicenseLookup";
import type { LicenseConfig } from "./types";

function printUsage(): void {
  console.error(
    "Usage: bun run src/index.ts --config <license-config.json> <manifest.json>"
  );
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  const configIdx = args.indexOf("--config");
  if (configIdx === -1 || !args[configIdx + 1]) {
    printUsage();
    process.exit(1);
  }

  const configPath = args[configIdx + 1];
  const manifestPath = args.find((a, i) => i !== configIdx && i !== configIdx + 1 && !a.startsWith("--"));

  if (!manifestPath) {
    printUsage();
    process.exit(1);
  }

  let config: LicenseConfig;
  let manifestContent: string;

  try {
    config = JSON.parse(await Bun.file(configPath).text());
  } catch (e) {
    console.error(`Error reading config file "${configPath}": ${e instanceof Error ? e.message : e}`);
    process.exit(1);
  }

  try {
    manifestContent = await Bun.file(manifestPath).text();
  } catch (e) {
    console.error(`Error reading manifest file "${manifestPath}": ${e instanceof Error ? e.message : e}`);
    process.exit(1);
  }

  const deps = parseDependencies(manifestContent);
  const results = checkLicenses(deps, config, mockLicenseLookup);
  const report = generateReport(results);

  console.log(report);

  // Exit with non-zero if any licenses are denied
  const hasDenied = results.some((r) => r.status === "denied");
  process.exit(hasDenied ? 1 : 0);
}

main();
