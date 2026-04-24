// Checks each dependency's license against allow/deny lists and produces results.

import type {
  Dependency,
  LicenseConfig,
  CheckResult,
  LicenseLookupFn,
} from "./types";

export function checkLicenses(
  deps: Dependency[],
  config: LicenseConfig,
  lookupFn: LicenseLookupFn
): CheckResult[] {
  return deps.map((dep) => {
    const license = lookupFn(dep.name);

    if (license === null) {
      return { ...dep, license: "UNKNOWN", status: "unknown" };
    }

    if (config.denyList.includes(license)) {
      return { ...dep, license, status: "denied" };
    }

    if (config.allowList.includes(license)) {
      return { ...dep, license, status: "approved" };
    }

    // License found but not in either list — treat as unknown
    return { ...dep, license, status: "unknown" };
  });
}
