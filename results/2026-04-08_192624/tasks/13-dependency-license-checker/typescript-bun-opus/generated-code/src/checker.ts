// License compliance checker — classifies dependencies against allow/deny lists
import type {
  Dependency,
  LicenseConfig,
  LicenseLookupFn,
  ComplianceStatus,
  ComplianceEntry,
  ComplianceReport,
} from "./types";

/**
 * Classify a license string against the config's allow/deny lists.
 * Comparison is case-insensitive.
 * If the license is on the allow list → "approved"
 * If on the deny list → "denied"
 * Otherwise → "unknown"
 */
export function classifyLicense(license: string, config: LicenseConfig): ComplianceStatus {
  const lower = license.toLowerCase();

  if (config.allowedLicenses.some((l) => l.toLowerCase() === lower)) {
    return "approved";
  }
  if (config.deniedLicenses.some((l) => l.toLowerCase() === lower)) {
    return "denied";
  }
  return "unknown";
}

/**
 * Check compliance for a list of dependencies.
 * Uses the provided lookup function to resolve licenses.
 * Handles lookup failures gracefully by marking them as "unknown" with "LOOKUP_FAILED".
 */
export async function checkCompliance(
  deps: Dependency[],
  config: LicenseConfig,
  lookupFn: LicenseLookupFn
): Promise<ComplianceReport> {
  const entries: ComplianceEntry[] = [];

  for (const dep of deps) {
    let license: string;
    try {
      license = await lookupFn(dep);
    } catch {
      // Graceful degradation: mark as unknown rather than crashing
      license = "LOOKUP_FAILED";
    }

    const status = classifyLicense(license, config);
    entries.push({
      name: dep.name,
      version: dep.version,
      license,
      status,
    });
  }

  return {
    total: entries.length,
    approved: entries.filter((e) => e.status === "approved").length,
    denied: entries.filter((e) => e.status === "denied").length,
    unknown: entries.filter((e) => e.status === "unknown").length,
    entries,
  };
}
