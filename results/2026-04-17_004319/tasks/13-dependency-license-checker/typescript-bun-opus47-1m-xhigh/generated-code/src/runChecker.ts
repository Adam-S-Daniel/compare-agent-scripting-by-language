// Top-level orchestration: glue parser + license DB lookup + policy check.
// Kept separate from the CLI so it can be unit-tested without I/O.

import { parsePackageJson } from "./parser.ts";
import { checkLicenses } from "./licenseChecker.ts";
import { buildReport } from "./reporter.ts";
import type {
  ComplianceReport,
  Dependency,
  LicenseLookup,
  LicensePolicy,
} from "./types.ts";

export interface RunInput {
  manifest: string;          // raw JSON text of package.json
  policy: LicensePolicy;     // parsed allow/deny lists
  licenseDb: Record<string, string>; // mock DB: name OR name@version -> license
}

// Build a lookup from the mock DB. A version-specific entry (name@version)
// takes precedence over a name-only entry, matching typical registry semantics.
function buildLookup(db: Record<string, string>): LicenseLookup {
  return (dep: Dependency) => {
    const versioned = `${dep.name}@${dep.version}`;
    if (versioned in db) return db[versioned]!;
    if (dep.name in db) return db[dep.name]!;
    return null;
  };
}

export function runChecker(input: RunInput): ComplianceReport {
  const deps = parsePackageJson(input.manifest);
  const entries = checkLicenses(deps, input.policy, buildLookup(input.licenseDb));
  return buildReport(entries);
}
