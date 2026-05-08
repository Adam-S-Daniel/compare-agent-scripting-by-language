#!/usr/bin/env bun
// CLI for dependency license checker

import { parsePackageJson, checkLicenses, loadConfig, formatReport, parseRequirementsTxt } from "./checker";
import { mockLicenseLookup } from "./mockLicenses";
import { readFileSync } from "fs";
import { extname } from "path";

const args = process.argv.slice(2);

// Parse command line arguments
let manifestPath = "package.json";
let configPath = "license-config.json";
let outputFormat: "text" | "json" = "text";

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--manifest" && args[i + 1]) {
    manifestPath = args[++i];
  } else if (args[i] === "--config" && args[i + 1]) {
    configPath = args[++i];
  } else if (args[i] === "--format" && args[i + 1]) {
    outputFormat = args[++i] as "text" | "json";
  }
}

async function main() {
  try {
    // Load manifest
    console.error(`Reading manifest from: ${manifestPath}`);
    const manifestContent = readFileSync(manifestPath, "utf-8");
    let dependencies;

    if (manifestPath.endsWith("package.json")) {
      const packageJson = JSON.parse(manifestContent);
      dependencies = parsePackageJson(packageJson);
    } else if (manifestPath.endsWith("requirements.txt")) {
      dependencies = parseRequirementsTxt(manifestContent);
    } else {
      throw new Error(`Unknown manifest type: ${manifestPath}`);
    }

    console.error(`Found ${dependencies.length} dependencies`);

    // Load config
    console.error(`Reading config from: ${configPath}`);
    const configContent = readFileSync(configPath, "utf-8");
    const config = loadConfig(JSON.parse(configContent));

    console.error(`Allowed licenses: ${config.allowList.join(", ")}`);
    console.error(`Denied licenses: ${config.denyList.join(", ")}`);
    console.error("");

    // Check licenses
    const report = await checkLicenses(dependencies, config, mockLicenseLookup);

    // Output result
    if (outputFormat === "json") {
      console.log(JSON.stringify(report, null, 2));
    } else {
      console.log(formatReport(report));
    }

    // Exit with appropriate code
    if (report.denied > 0) {
      process.exit(1);
    }
  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

main();
