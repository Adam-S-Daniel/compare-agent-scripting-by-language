// Main entry point: reads a manifest file and license config,
// runs the compliance check, and prints the report.

import { parseManifest } from "./parser";
import { checkCompliance } from "./checker";
import { formatReport } from "./report";
import { mockLicenseLookup } from "./license-lookup";
import type { LicenseConfig } from "./types";

async function main(): Promise<void> {
  // Read manifest path from CLI args or environment variable
  const manifestPath = process.argv[2] || process.env.MANIFEST_PATH;
  if (!manifestPath) {
    console.error("Error: No manifest file specified.");
    console.error("Usage: bun run src/main.ts <manifest-file> [config-file]");
    process.exit(1);
  }

  // Read optional config file path
  const configPath = process.argv[3] || process.env.LICENSE_CONFIG_PATH;

  // Load the manifest file
  let manifestContent: string;
  try {
    manifestContent = await Bun.file(manifestPath).text();
  } catch (err) {
    console.error(`Error: Could not read manifest file: ${manifestPath}`);
    console.error((err as Error).message);
    process.exit(1);
  }

  // Load or use default license config
  let config: LicenseConfig;
  if (configPath) {
    try {
      const configContent = await Bun.file(configPath).text();
      config = JSON.parse(configContent) as LicenseConfig;
    } catch (err) {
      console.error(`Error: Could not read config file: ${configPath}`);
      console.error((err as Error).message);
      process.exit(1);
    }
  } else {
    // Default config: common permissive licenses allowed, copyleft denied
    config = {
      allowList: ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"],
      denyList: ["GPL-3.0", "AGPL-3.0", "GPL-2.0"],
    };
  }

  // Parse the manifest
  const filename = manifestPath.split("/").pop() ?? manifestPath;
  let deps;
  try {
    deps = parseManifest(filename, manifestContent);
  } catch (err) {
    console.error(`Error: Failed to parse manifest: ${(err as Error).message}`);
    process.exit(1);
  }

  console.log(`Found ${deps.length} dependencies in ${filename}`);

  // Run compliance check using mock license lookup
  const report = await checkCompliance(deps, config, mockLicenseLookup);

  // Print the report
  console.log("");
  console.log(formatReport(report));

  // Exit with code 1 if any denied dependencies found
  if (report.summary.denied > 0) {
    console.log("");
    console.log(
      `FAIL: ${report.summary.denied} denied license(s) found.`
    );
    process.exit(1);
  }

  console.log("");
  console.log("PASS: All dependencies have acceptable licenses.");
}

main();
