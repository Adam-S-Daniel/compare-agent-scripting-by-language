// License checker core. Pure functions + an injectable license lookup so
// real resolvers (npm registry, file-based mock) can be swapped without
// changing tests.

export interface Dependency {
  name: string;
  version: string;
}

export interface PolicyConfig {
  allow: string[];
  deny: string[];
}

export type Status = "approved" | "denied" | "unknown";

export interface CheckResult {
  name: string;
  version: string;
  license: string | null;
  status: Status;
  reason?: string;
}

export type LicenseLookup = (
  name: string,
  version: string,
) => Promise<string | null>;

// Accepts a package.json string and returns a flat list of dependency
// entries from both "dependencies" and "devDependencies".
export function parseManifest(source: string): Dependency[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(source);
  } catch (err) {
    throw new Error(`Failed to parse manifest: ${(err as Error).message}`);
  }
  if (typeof parsed !== "object" || parsed === null) {
    throw new Error("Failed to parse manifest: root is not an object");
  }
  const obj = parsed as Record<string, unknown>;
  const out: Dependency[] = [];
  for (const key of ["dependencies", "devDependencies"] as const) {
    const section = obj[key];
    if (section && typeof section === "object") {
      for (const [name, version] of Object.entries(
        section as Record<string, string>,
      )) {
        out.push({ name, version: String(version) });
      }
    }
  }
  return out;
}

// Classify a single license string against policy. Deny wins over allow
// if (somehow) both lists contain the same identifier.
function classify(license: string | null, policy: PolicyConfig): Status {
  if (license === null) return "unknown";
  if (policy.deny.includes(license)) return "denied";
  if (policy.allow.includes(license)) return "approved";
  return "unknown";
}

export async function checkDependencies(
  deps: Dependency[],
  policy: PolicyConfig,
  lookup: LicenseLookup,
): Promise<CheckResult[]> {
  const results: CheckResult[] = [];
  for (const dep of deps) {
    try {
      const license = await lookup(dep.name, dep.version);
      results.push({
        name: dep.name,
        version: dep.version,
        license,
        status: classify(license, policy),
      });
    } catch (err) {
      // Lookup failures shouldn't abort the whole report — record as unknown.
      results.push({
        name: dep.name,
        version: dep.version,
        license: null,
        status: "unknown",
        reason: `lookup failed: ${(err as Error).message}`,
      });
    }
  }
  return results;
}

export function formatReport(results: CheckResult[]): string {
  const summary = {
    total: results.length,
    approved: results.filter((r) => r.status === "approved").length,
    denied: results.filter((r) => r.status === "denied").length,
    unknown: results.filter((r) => r.status === "unknown").length,
  };
  return JSON.stringify({ summary, dependencies: results }, null, 2);
}

// Build a lookup that reads from a static JSON map. Used in CI and tests
// to avoid hitting a real registry.
export function staticLookup(
  table: Record<string, string | null>,
): LicenseLookup {
  return async (name: string) =>
    Object.prototype.hasOwnProperty.call(table, name) ? table[name] : null;
}
