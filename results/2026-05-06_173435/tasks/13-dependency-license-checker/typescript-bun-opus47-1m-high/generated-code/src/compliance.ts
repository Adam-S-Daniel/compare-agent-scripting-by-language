// Compliance engine: classifies each dependency by its license against an
// allow/deny config. License lookup is injected so tests can mock it
// deterministically — in production it would hit a registry (npm, PyPI, etc).
import type { Dependency } from "./parse.ts";

export type Status = "approved" | "denied" | "unknown";

export interface LicenseConfig {
  allow: string[];
  deny: string[];
}

export interface ReportEntry {
  name: string;
  version: string;
  license: string | null;
  status: Status;
}

// Lookup is async to match real-world I/O while letting tests pass simple
// in-memory tables. Returns null when the license is not known.
export type LicenseLookup = (dep: Dependency) => Promise<string | null>;

function classify(license: string | null, config: LicenseConfig): Status {
  if (!license) return "unknown";
  const norm = license.toLowerCase();
  if (config.deny.some((l) => l.toLowerCase() === norm)) return "denied";
  if (config.allow.some((l) => l.toLowerCase() === norm)) return "approved";
  return "unknown";
}

export async function checkCompliance(
  deps: Dependency[],
  lookup: LicenseLookup,
  config: LicenseConfig,
): Promise<ReportEntry[]> {
  const out: ReportEntry[] = [];
  for (const dep of deps) {
    let license: string | null;
    try {
      license = await lookup(dep);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      throw new Error(`license lookup failed for ${dep.name}: ${msg}`);
    }
    out.push({
      name: dep.name,
      version: dep.version,
      license,
      status: classify(license, config),
    });
  }
  return out;
}
