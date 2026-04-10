// License compliance checker: classifies dependencies against
// allow/deny lists and builds a compliance report.

import type {
  ComplianceEntry,
  ComplianceReport,
  ComplianceStatus,
  Dependency,
  LicenseConfig,
  LicenseLookupFn,
} from "./types";

/** Classify a single license string against the config lists.
 *  Matching is case-insensitive. Returns 'unknown' if license is null
 *  or not found in either list. */
export function classifyLicense(
  license: string | null,
  config: LicenseConfig
): ComplianceStatus {
  if (license === null) return "unknown";

  const lower = license.toLowerCase();

  if (config.allowList.some((l) => l.toLowerCase() === lower)) {
    return "approved";
  }
  if (config.denyList.some((l) => l.toLowerCase() === lower)) {
    return "denied";
  }

  return "unknown";
}

/** Check all dependencies against the license config.
 *  Uses the provided lookup function to resolve licenses (allows mocking). */
export async function checkCompliance(
  deps: Dependency[],
  config: LicenseConfig,
  lookupFn: LicenseLookupFn
): Promise<ComplianceReport> {
  const entries: ComplianceEntry[] = [];
  let approved = 0;
  let denied = 0;
  let unknown = 0;

  for (const dep of deps) {
    const info = await lookupFn(dep.name, dep.version);
    const status = classifyLicense(info.license, config);

    entries.push({
      name: dep.name,
      version: dep.version,
      license: info.license,
      status,
    });

    if (status === "approved") approved++;
    else if (status === "denied") denied++;
    else unknown++;
  }

  return {
    entries,
    summary: {
      total: deps.length,
      approved,
      denied,
      unknown,
    },
  };
}
