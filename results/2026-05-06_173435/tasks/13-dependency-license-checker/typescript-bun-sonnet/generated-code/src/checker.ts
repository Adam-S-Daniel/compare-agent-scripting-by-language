import type { Dependency, DependencyResult, LicenseConfig, LicenseLookupFn, LicenseStatus } from './types';

// Determines compliance status for a single license string (or null = not found).
export function checkLicense(license: string | null, config: LicenseConfig): LicenseStatus {
  if (license === null) return 'unknown';
  if (config.denyList.includes(license)) return 'denied';
  if (config.allowList.includes(license)) return 'approved';
  return 'unknown';
}

// Looks up and checks every dependency in parallel, returning one result per dep.
export async function checkDependencies(
  deps: Dependency[],
  config: LicenseConfig,
  lookup: LicenseLookupFn,
): Promise<DependencyResult[]> {
  return Promise.all(
    deps.map(async (dep): Promise<DependencyResult> => {
      const license = await lookup(dep.name, dep.version);
      const status = checkLicense(license, config);
      return { dependency: dep, license, status };
    }),
  );
}
