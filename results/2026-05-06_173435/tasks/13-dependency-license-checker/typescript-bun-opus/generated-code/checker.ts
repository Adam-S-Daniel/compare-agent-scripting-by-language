import type { Dependency, LicenseConfig, LicenseLookup, LicenseStatus, ComplianceReport } from "./types";

export async function checkLicenses(
  deps: Dependency[],
  config: LicenseConfig,
  lookup: LicenseLookup
): Promise<ComplianceReport> {
  const entries = await Promise.all(
    deps.map(async (dep) => {
      const license = await lookup(dep.name, dep.version);
      let status: LicenseStatus;

      if (license === null) {
        status = "unknown";
      } else if (config.denyList.includes(license)) {
        status = "denied";
      } else if (config.allowList.includes(license)) {
        status = "approved";
      } else {
        status = "unknown";
      }

      return { name: dep.name, version: dep.version, license, status };
    })
  );

  const summary = {
    total: entries.length,
    approved: entries.filter((e) => e.status === "approved").length,
    denied: entries.filter((e) => e.status === "denied").length,
    unknown: entries.filter((e) => e.status === "unknown").length,
  };

  return { entries, summary };
}
