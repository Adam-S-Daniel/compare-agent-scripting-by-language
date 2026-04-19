#!/usr/bin/env bun
// CLI tool for dependency license checking

import { readFileSync, writeFileSync } from "fs";
import { resolve } from "path";
import {
  parseDependencies,
  checkLicenseCompliance,
  parseRequirementsTxt,
  generateComplianceReport,
  DependencyManifest,
  LicenseConfig,
} from "./license-checker";

// Mock license database for testing
const mockLicenseDatabase: Record<string, string> = {
  express: "MIT",
  "lodash-es": "MIT",
  requests: "Apache-2.0",
  numpy: "BSD-3-Clause",
  pandas: "BSD-3-Clause",
  "bad-lib": "GPL-3.0",
  "flask": "BSD-3-Clause",
  "django": "BSD-3-Clause",
  "typescript": "Apache-2.0",
  "bun": "MIT",
};

// Mock lookup function for license data
function licenseLookup(packageName: string): string | undefined {
  return mockLicenseDatabase[packageName];
}

// Load manifest file (package.json or requirements.txt)
function loadManifest(filePath: string): { manifest: DependencyManifest; rawContent?: string } {
  const content = readFileSync(filePath, "utf-8");

  if (filePath.endsWith("package.json")) {
    return {
      manifest: {
        type: "package.json",
        content: JSON.parse(content),
      },
    };
  } else if (filePath.endsWith("requirements.txt")) {
    return {
      manifest: {
        type: "requirements.txt",
        content: {},
      },
      rawContent: content,
    };
  }

  throw new Error(`Unsupported manifest file: ${filePath}`);
}

// Load license config (allow/deny lists)
function loadConfig(filePath: string): LicenseConfig {
  const content = readFileSync(filePath, "utf-8");
  return JSON.parse(content);
}

// Main CLI entry point
async function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.log("Usage: bun run cli.ts <manifest-file> <config-file> [output-file]");
    console.log(
      "  manifest-file: package.json or requirements.txt"
    );
    console.log("  config-file: JSON file with allowlist and denylist");
    console.log("  output-file: optional, write report to file");
    process.exit(1);
  }

  try {
    const manifestPath = resolve(args[0]);
    const configPath = resolve(args[1]);
    const outputPath = args[2] ? resolve(args[2]) : null;

    // Load files
    const { manifest, rawContent } = loadManifest(manifestPath);
    const config = loadConfig(configPath);

    // Parse dependencies
    let dependencies;
    if (manifest.type === "package.json") {
      dependencies = parseDependencies(manifest);
    } else {
      // For requirements.txt, use the raw content
      dependencies = parseRequirementsTxt(rawContent || "");
    }

    // Check compliance
    const report = checkLicenseCompliance(dependencies, config, licenseLookup);

    // Generate report
    const reportText = generateComplianceReport(report);

    // Output results
    console.log(reportText);

    if (outputPath) {
      writeFileSync(outputPath, reportText);
      console.log(`\nReport written to: ${outputPath}`);
    }

    // Exit with error code if there are denied dependencies
    if (report.summary.denied > 0) {
      process.exit(1);
    }
  } catch (error) {
    if (error instanceof Error) {
      console.error("Error:", error.message);
    } else {
      console.error("Unknown error occurred");
    }
    process.exit(1);
  }
}

main();
