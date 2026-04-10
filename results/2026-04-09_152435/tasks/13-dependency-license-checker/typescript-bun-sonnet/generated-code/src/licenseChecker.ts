// Core license checker logic.
// Follows the TDD green phase: minimum code to pass the tests.

import type {
  Dependency,
  LicenseConfig,
  LicenseStatus,
  DependencyReport,
  ComplianceReport,
  LicenseLookupFn,
} from "./types";

/**
 * Parse a package.json string and extract its runtime dependencies.
 * Only `dependencies` is included; `devDependencies` and `peerDependencies`
 * are intentionally ignored to focus on what ships to production.
 */
export function parsePackageJson(content: string): Dependency[] {
  let pkg: Record<string, unknown>;
  try {
    pkg = JSON.parse(content) as Record<string, unknown>;
  } catch {
    throw new Error(
      `Failed to parse manifest: input is not valid JSON`
    );
  }

  const deps = pkg.dependencies as Record<string, string> | undefined;
  if (!deps) return [];

  return Object.entries(deps).map(([name, version]) => ({ name, version }));
}

/**
 * Determine the compliance status of a single license identifier.
 * Deny list is checked first so it always takes precedence over the allow list.
 */
export function checkLicense(
  license: string | null,
  config: LicenseConfig
): LicenseStatus {
  if (!license) return "unknown";

  const normalised = license.toLowerCase();

  if (config.denyList.some((d) => d.toLowerCase() === normalised)) {
    return "denied";
  }
  if (config.allowList.some((a) => a.toLowerCase() === normalised)) {
    return "approved";
  }
  return "unknown";
}

/**
 * Generate a full compliance report for a list of dependencies.
 * The `lookupFn` parameter is injected so callers can provide a real registry
 * client or a deterministic mock for testing.
 */
export async function generateReport(
  dependencies: Dependency[],
  config: LicenseConfig,
  lookupFn: LicenseLookupFn
): Promise<ComplianceReport> {
  const reports: DependencyReport[] = [];

  for (const dep of dependencies) {
    const license = await lookupFn(dep.name, dep.version);
    const status = checkLicense(license, config);
    reports.push({ name: dep.name, version: dep.version, license, status });
  }

  const summary = {
    total: reports.length,
    approved: reports.filter((r) => r.status === "approved").length,
    denied: reports.filter((r) => r.status === "denied").length,
    unknown: reports.filter((r) => r.status === "unknown").length,
  };

  return {
    dependencies: reports,
    summary,
    compliant: summary.denied === 0,
  };
}

/**
 * Format a ComplianceReport as human-readable text suitable for CI logs.
 * The exact format is relied upon by the act test harness — do not change
 * the "Total:", "Approved:", "Denied:", "Unknown:", or "Status:" lines.
 */
export function formatReport(report: ComplianceReport): string {
  const lines: string[] = [];

  lines.push("Dependency License Compliance Report");
  lines.push("=====================================");
  lines.push("");

  // Per-dependency table
  for (const dep of report.dependencies) {
    const lic = dep.license ?? "N/A";
    lines.push(`${dep.name}@${dep.version} - ${lic} [${dep.status.toUpperCase()}]`);
  }

  lines.push("");
  lines.push("Summary:");
  lines.push(`  Total: ${report.summary.total}`);
  lines.push(`  Approved: ${report.summary.approved}`);
  lines.push(`  Denied: ${report.summary.denied}`);
  lines.push(`  Unknown: ${report.summary.unknown}`);
  lines.push("");
  lines.push(`Status: ${report.compliant ? "COMPLIANT" : "NON-COMPLIANT"}`);

  return lines.join("\n");
}
