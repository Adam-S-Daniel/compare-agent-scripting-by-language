// Main entry point — reads a manifest file, checks licenses, prints report.
// Usage: bun run src/main.ts <manifest-file> <config-file>
import { parseManifest } from "./parser";
import { checkCompliance } from "./checker";
import { formatReport } from "./report";
import { createMockLookup } from "./license-lookup";
import type { LicenseConfig } from "./types";

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error("Usage: bun run src/main.ts <manifest-file> <config-file>");
    console.error("  manifest-file: path to package.json or requirements.txt");
    console.error("  config-file: path to JSON config with allowedLicenses and deniedLicenses");
    process.exit(1);
  }

  const [manifestPath, configPath] = args;

  // Read manifest file
  let manifestContent: string;
  try {
    manifestContent = await Bun.file(manifestPath).text();
  } catch {
    console.error(`Error: Cannot read manifest file: ${manifestPath}`);
    process.exit(1);
  }

  // Read config file
  let config: LicenseConfig;
  try {
    const configContent = await Bun.file(configPath).text();
    config = JSON.parse(configContent) as LicenseConfig;
  } catch {
    console.error(`Error: Cannot read or parse config file: ${configPath}`);
    process.exit(1);
  }

  // Validate config has required fields
  if (!Array.isArray(config.allowedLicenses) || !Array.isArray(config.deniedLicenses)) {
    console.error("Error: Config must have 'allowedLicenses' and 'deniedLicenses' arrays");
    process.exit(1);
  }

  // Parse the manifest
  const filename = manifestPath.split("/").pop() ?? manifestPath;
  const deps = parseManifest(filename, manifestContent);

  // Use mock license lookup (in production, this would be a real registry call)
  const lookupFn = createMockLookup();

  // Check compliance
  const report = await checkCompliance(deps, config, lookupFn);

  // Print report
  console.log(formatReport(report));

  // Exit with non-zero if denied licenses found
  if (report.denied > 0) {
    process.exit(2);
  }
}

main();
