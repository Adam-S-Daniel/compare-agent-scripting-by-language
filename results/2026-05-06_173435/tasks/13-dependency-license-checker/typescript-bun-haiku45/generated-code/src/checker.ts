// Main dependency license checker implementation
// Uses red/green TDD approach: tests drive implementation

import { mockLicenseLookup } from "./mockLicenses";
import type {
  Dependency,
  LicenseConfig,
  LicenseInfo,
  ComplianceReport,
  LicenseLookup
} from "./types";

/**
 * Parse dependencies from a package.json object
 * Extracts both dependencies and devDependencies
 */
export function parsePackageJson(packageJson: Record<string, any>): Dependency[] {
  const deps: Dependency[] = [];

  // Process regular dependencies
  if (packageJson.dependencies && typeof packageJson.dependencies === "object") {
    for (const [name, version] of Object.entries(packageJson.dependencies)) {
      deps.push({ name, version: String(version) });
    }
  }

  // Process devDependencies
  if (packageJson.devDependencies && typeof packageJson.devDependencies === "object") {
    for (const [name, version] of Object.entries(packageJson.devDependencies)) {
      deps.push({ name, version: String(version) });
    }
  }

  return deps;
}

/**
 * Parse dependencies from requirements.txt format
 * Handles standard Python requirements format with version specifiers
 */
export function parseRequirementsTxt(content: string): Dependency[] {
  const deps: Dependency[] = [];

  const lines = content.split("\n");
  for (const line of lines) {
    // Remove whitespace and comments
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    // Handle inline comments
    const mainPart = trimmed.split("#")[0].trim();

    // Parse version specifiers: ==, >=, <=, ~=, >, <
    // Matches: package_name followed by optional version spec
    const match = mainPart.match(/^([a-zA-Z0-9_-]+)(.*?)$/);
    if (match) {
      const [, name, versionSpec] = match;
      const version = versionSpec.trim() || "*";
      deps.push({
        name: name.toLowerCase(),
        version
      });
    }
  }

  return deps;
}

/**
 * Check licenses of dependencies against allow/deny lists
 * Returns a comprehensive compliance report
 */
export async function checkLicenses(
  dependencies: Dependency[],
  config: LicenseConfig,
  licenseLookup: LicenseLookup = mockLicenseLookup
): Promise<ComplianceReport> {
  const licenses: LicenseInfo[] = [];
  let approved = 0;
  let denied = 0;
  let unknown = 0;

  // Process each dependency
  for (const dep of dependencies) {
    const license = await licenseLookup(dep.name);

    let status: "approved" | "denied" | "unknown";
    if (license === null) {
      status = "unknown";
      unknown++;
    } else if (config.denyList.includes(license)) {
      status = "denied";
      denied++;
    } else if (config.allowList.includes(license)) {
      status = "approved";
      approved++;
    } else {
      status = "unknown";
      unknown++;
    }

    licenses.push({
      name: dep.name,
      version: dep.version,
      license,
      status
    });
  }

  return {
    timestamp: new Date().toISOString(),
    totalDependencies: dependencies.length,
    approved,
    denied,
    unknown,
    licenses
  };
}

/**
 * Load configuration from a JSON object
 * Validates that allowList and denyList are present
 */
export function loadConfig(configObj: Record<string, any>): LicenseConfig {
  const { allowList, denyList } = configObj;

  if (!Array.isArray(allowList)) {
    throw new Error("Config must have allowList array");
  }
  if (!Array.isArray(denyList)) {
    throw new Error("Config must have denyList array");
  }

  return { allowList, denyList };
}

/**
 * Format compliance report as readable text
 */
export function formatReport(report: ComplianceReport): string {
  const lines: string[] = [
    `Dependency License Compliance Report`,
    `Generated: ${report.timestamp}`,
    ``,
    `Summary:`,
    `  Total Dependencies: ${report.totalDependencies}`,
    `  Approved:          ${report.approved}`,
    `  Denied:            ${report.denied}`,
    `  Unknown:           ${report.unknown}`,
    ``
  ];

  if (report.denied > 0) {
    lines.push(`⚠️  DENIED LICENSES FOUND:`);
    for (const info of report.licenses) {
      if (info.status === "denied") {
        lines.push(`  - ${info.name}@${info.version} (${info.license})`);
      }
    }
    lines.push(``);
  }

  if (report.unknown > 0) {
    lines.push(`❓ UNKNOWN LICENSES:`);
    for (const info of report.licenses) {
      if (info.status === "unknown") {
        lines.push(`  - ${info.name}@${info.version}`);
      }
    }
    lines.push(``);
  }

  if (report.approved > 0) {
    lines.push(`✅ APPROVED LICENSES:`);
    for (const info of report.licenses) {
      if (info.status === "approved") {
        lines.push(`  - ${info.name}@${info.version} (${info.license})`);
      }
    }
    lines.push(``);
  }

  return lines.join("\n");
}
