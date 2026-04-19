// Dependency License Checker - Red/Green TDD implementation

// Interfaces for type safety
interface Dependency {
  name: string;
  version: string;
}

interface LicenseConfig {
  allowlist: string[];
  denylist: string[];
}

interface DependencyManifest {
  type: "package.json" | "requirements.txt";
  content: any;
}

type LicenseStatus = "approved" | "denied" | "unknown";

interface DependencyResult {
  name: string;
  version: string;
  license?: string;
  status: LicenseStatus;
}

interface ComplianceReport {
  dependencies: DependencyResult[];
  summary: {
    approved: number;
    denied: number;
    unknown: number;
  };
}

type LicenseLookup = (name: string) => string | undefined;

// Parse dependencies from a manifest
function parseDependencies(manifest: DependencyManifest): Dependency[] {
  if (manifest.type === "package.json") {
    const deps = manifest.content.dependencies || {};
    return Object.entries(deps).map(([name, version]) => ({
      name,
      version: version as string,
    }));
  }
  // Additional manifest types can be added here
  return [];
}

// Check license compliance for dependencies
function checkLicenseCompliance(
  dependencies: Dependency[],
  config: LicenseConfig,
  licenseLookup: LicenseLookup
): ComplianceReport {
  const results: DependencyResult[] = [];
  let approved = 0;
  let denied = 0;
  let unknown = 0;

  for (const dep of dependencies) {
    const license = licenseLookup(dep.name);

    let status: LicenseStatus;
    if (!license) {
      status = "unknown";
      unknown++;
    } else if (config.denylist.includes(license)) {
      status = "denied";
      denied++;
    } else if (config.allowlist.includes(license)) {
      status = "approved";
      approved++;
    } else {
      status = "unknown";
      unknown++;
    }

    results.push({
      name: dep.name,
      version: dep.version,
      license,
      status,
    });
  }

  return {
    dependencies: results,
    summary: { approved, denied, unknown },
  };
}

// Parse requirements.txt format (Python dependencies)
function parseRequirementsTxt(content: string): Dependency[] {
  return content
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => {
      // Handle various version specifiers: ==, >=, <=, ~=, etc.
      const match = line.match(/^([a-zA-Z0-9_-]+)(.*)/);
      if (!match) return null;

      const name = match[1];
      // Extract version from any operator (==, >=, <=, ~=, etc.)
      const versionMatch = match[2].match(/^[><=~!]+(.*)$/);
      const version = versionMatch ? versionMatch[1].trim() : "";

      return { name, version };
    })
    .filter((dep): dep is Dependency => dep !== null);
}

// Generate a text report from compliance results
function generateComplianceReport(report: ComplianceReport): string {
  const lines: string[] = [];
  lines.push("=== Dependency License Compliance Report ===\n");

  for (const dep of report.dependencies) {
    const status = dep.status.toUpperCase();
    const license = dep.license || "UNKNOWN";
    lines.push(`[${status}] ${dep.name}@${dep.version} (${license})`);
  }

  lines.push("");
  lines.push(
    `Summary: ${report.summary.approved} approved, ${report.summary.denied} denied, ${report.summary.unknown} unknown`
  );

  return lines.join("\n");
}

export {
  parseDependencies,
  checkLicenseCompliance,
  parseRequirementsTxt,
  generateComplianceReport,
  DependencyManifest,
  Dependency,
  LicenseConfig,
  DependencyResult,
  ComplianceReport,
  LicenseStatus,
  LicenseLookup,
};
