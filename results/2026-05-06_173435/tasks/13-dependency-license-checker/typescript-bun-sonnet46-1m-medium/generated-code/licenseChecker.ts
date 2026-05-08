// Dependency License Checker
// Parses a package.json manifest, looks up licenses via a mock registry,
// compares against an allow/deny config, and prints a compliance report.

import { readFileSync } from "fs";

// --- Types ---

export interface Dependency {
  name: string;
  version: string;
}

export interface LicenseConfig {
  allowed: string[];
  denied: string[];
}

export interface LicenseStatus {
  dependency: string;
  version: string;
  license: string | null;
  status: "approved" | "denied" | "unknown";
}

export interface ComplianceReport {
  results: LicenseStatus[];
  summary: {
    approved: number;
    denied: number;
    unknown: number;
    total: number;
  };
}

// --- Core functions ---

// Parse production dependencies from a package.json file.
// Returns an array of { name, version } objects.
export function parseDependencies(manifestPath: string): Dependency[] {
  let raw: string;
  try {
    raw = readFileSync(manifestPath, "utf8");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Cannot read manifest "${manifestPath}": ${msg}`);
  }

  let manifest: Record<string, unknown>;
  try {
    manifest = JSON.parse(raw) as Record<string, unknown>;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Invalid JSON in "${manifestPath}": ${msg}`);
  }

  const deps: Dependency[] = [];
  const section = manifest.dependencies as Record<string, string> | undefined;
  if (section) {
    for (const [name, version] of Object.entries(section)) {
      deps.push({ name, version });
    }
  }
  return deps;
}

// Look up a package's license from a mock data map.
// Returns null if the package is not in the map or has no license.
export function lookupLicense(
  name: string,
  mockData: Record<string, string | null>
): string | null {
  if (Object.prototype.hasOwnProperty.call(mockData, name)) {
    return mockData[name];
  }
  return null;
}

// Determine the compliance status of a single license against the config.
// Denial takes precedence over approval; unlisted licenses are "unknown".
export function checkLicenseStatus(
  license: string | null,
  config: LicenseConfig
): "approved" | "denied" | "unknown" {
  if (license === null) return "unknown";
  if (config.denied.includes(license)) return "denied";
  if (config.allowed.includes(license)) return "approved";
  return "unknown";
}

// Check all dependencies and return an array of license status objects.
export function checkLicenses(
  deps: Dependency[],
  config: LicenseConfig,
  mockData: Record<string, string | null>
): LicenseStatus[] {
  return deps.map((dep) => {
    const license = lookupLicense(dep.name, mockData);
    const status = checkLicenseStatus(license, config);
    return { dependency: dep.name, version: dep.version, license, status };
  });
}

// Aggregate an array of LicenseStatus entries into a ComplianceReport.
export function generateReport(statuses: LicenseStatus[]): ComplianceReport {
  return {
    results: statuses,
    summary: {
      approved: statuses.filter((s) => s.status === "approved").length,
      denied: statuses.filter((s) => s.status === "denied").length,
      unknown: statuses.filter((s) => s.status === "unknown").length,
      total: statuses.length,
    },
  };
}

// Render a ComplianceReport as a human-readable string.
// Each dependency line uses the format: name@version: license -> STATUS
export function formatReport(report: ComplianceReport): string {
  const lines: string[] = ["=== Dependency License Compliance Report ===", ""];
  for (const r of report.results) {
    const lic = r.license ?? "unknown";
    lines.push(`${r.dependency}@${r.version}: ${lic} -> ${r.status.toUpperCase()}`);
  }
  lines.push("");
  lines.push("=== Summary ===");
  lines.push(`Total: ${report.summary.total}`);
  lines.push(`Approved: ${report.summary.approved}`);
  lines.push(`Denied: ${report.summary.denied}`);
  lines.push(`Unknown: ${report.summary.unknown}`);
  return lines.join("\n");
}

// --- Script entry point ---
// Only runs when invoked directly (not when imported by tests).

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const manifestPath = args[0] ?? "fixtures/package.json";
  const configPath = args[1] ?? "fixtures/license-config.json";
  const mockDataPath = args[2] ?? "fixtures/mock-licenses.json";

  try {
    const deps = parseDependencies(manifestPath);
    const config = JSON.parse(readFileSync(configPath, "utf8")) as LicenseConfig;
    const mockData = JSON.parse(
      readFileSync(mockDataPath, "utf8")
    ) as Record<string, string | null>;

    const statuses = checkLicenses(deps, config, mockData);
    const report = generateReport(statuses);
    console.log(formatReport(report));
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Error: ${msg}`);
    process.exit(1);
  }
}

if (import.meta.main) {
  main();
}
