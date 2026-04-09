/**
 * Dependency License Checker
 *
 * Parses package.json manifests, looks up licenses for each dependency,
 * checks them against allow/deny lists, and generates a compliance report.
 */

// ─── Types ────────────────────────────────────────────────────────────────────

/** A single dependency with its name and version specifier */
export interface Dependency {
  name: string;
  version: string;
}

/** Configuration for license allow/deny lists */
export interface LicenseConfig {
  allowList: string[];
  denyList: string[];
}

/** The compliance status of a single dependency */
export type LicenseStatus = "approved" | "denied" | "unknown";

/** Result of checking a single dependency's license */
export interface ComplianceResult {
  dependency: Dependency;
  license: string | null;
  status: LicenseStatus;
}

/** Options for parsePackageJson */
export interface ParseOptions {
  includeDev: boolean;
}

/** A function type for looking up a package's license (injectable for mocking) */
export type LicenseLookupFn = (
  packageName: string,
  version: string
) => Promise<string | null>;

/** Full compliance report with summary and markdown rendering */
export interface ComplianceReport {
  results: ComplianceResult[];
  summary: {
    total: number;
    approved: number;
    denied: number;
    unknown: number;
  };
  compliant: boolean;
  toMarkdown(): string;
}

// ─── Parsing ──────────────────────────────────────────────────────────────────

/**
 * Parse a package.json (object or JSON string) and extract dependency entries.
 * Throws a meaningful error if the input is an invalid JSON string.
 */
export function parsePackageJson(
  input: Record<string, unknown> | string,
  options: ParseOptions
): Dependency[] {
  let pkg: Record<string, unknown>;

  if (typeof input === "string") {
    try {
      pkg = JSON.parse(input) as Record<string, unknown>;
    } catch {
      throw new Error(
        `Invalid package.json: could not parse JSON string. ` +
          `Ensure the input is valid JSON.`
      );
    }
  } else {
    pkg = input;
  }

  const deps: Dependency[] = [];

  // Extract production dependencies
  if (pkg.dependencies && typeof pkg.dependencies === "object") {
    for (const [name, version] of Object.entries(pkg.dependencies as Record<string, string>)) {
      deps.push({ name, version });
    }
  }

  // Optionally include devDependencies
  if (options.includeDev && pkg.devDependencies && typeof pkg.devDependencies === "object") {
    for (const [name, version] of Object.entries(
      pkg.devDependencies as Record<string, string>
    )) {
      deps.push({ name, version });
    }
  }

  return deps;
}

// ─── License Checking ────────────────────────────────────────────────────────

/**
 * Check each dependency's license against the allow/deny lists.
 * Uses the provided lookup function (allows mocking in tests).
 */
export async function checkLicenses(
  dependencies: Dependency[],
  config: LicenseConfig,
  lookupFn: LicenseLookupFn
): Promise<ComplianceResult[]> {
  const results: ComplianceResult[] = [];

  for (const dep of dependencies) {
    let license: string | null = null;
    let status: LicenseStatus = "unknown";

    try {
      license = await lookupFn(dep.name, dep.version);
    } catch (err) {
      // Lookup failure means we can't determine the license
      license = null;
    }

    if (license === null) {
      status = "unknown";
    } else if (config.denyList.includes(license)) {
      status = "denied";
    } else if (config.allowList.includes(license)) {
      status = "approved";
    } else {
      // License exists but is neither explicitly allowed nor denied → unknown
      status = "unknown";
    }

    results.push({ dependency: dep, license, status });
  }

  return results;
}

// ─── Report Generation ───────────────────────────────────────────────────────

/**
 * Generate a compliance report from a list of check results.
 * A build is compliant only if all dependencies are approved
 * (unknown or denied statuses cause failure).
 */
export function generateReport(results: ComplianceResult[]): ComplianceReport {
  const approved = results.filter((r) => r.status === "approved").length;
  const denied = results.filter((r) => r.status === "denied").length;
  const unknown = results.filter((r) => r.status === "unknown").length;
  const total = results.length;

  // Strict mode: unknown licenses also fail compliance
  const compliant = denied === 0 && unknown === 0;

  return {
    results,
    summary: { total, approved, denied, unknown },
    compliant,
    toMarkdown() {
      const lines: string[] = [
        "# Dependency License Compliance Report",
        "",
        `COMPLIANT: ${compliant}`,
        "",
        "## Summary",
        "",
        `| Metric   | Count |`,
        `|----------|-------|`,
        `| Total    | ${total} |`,
        `| Approved | ${approved} |`,
        `| Denied   | ${denied} |`,
        `| Unknown  | ${unknown} |`,
        "",
        "## Dependency Details",
        "",
        `| Package | Version | License | Status |`,
        `|---------|---------|---------|--------|`,
      ];

      for (const r of results) {
        const license = r.license ?? "UNKNOWN";
        lines.push(
          `| ${r.dependency.name} | ${r.dependency.version} | ${license} | ${r.status} |`
        );
      }

      return lines.join("\n");
    },
  };
}
