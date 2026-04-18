// License checker: apply a policy to a list of dependencies.
// The lookup function is injected so tests can substitute a mock
// and production can plug in a real registry client.

import type {
  ComplianceEntry,
  ComplianceStatus,
  Dependency,
  LicenseLookup,
  LicensePolicy,
} from "./types.ts";

// Build a lookup map keyed by lower-cased license id so the
// allow/deny comparison is case-insensitive.
function toSet(ids: string[]): Set<string> {
  return new Set(ids.map((id) => id.toLowerCase()));
}

function classify(
  license: string | null,
  allow: Set<string>,
  deny: Set<string>,
): ComplianceStatus {
  if (license === null) return "unknown";
  const key = license.toLowerCase();
  // Deny first — a deny-listed license is a hard failure even if the
  // policy also (mistakenly) allow-lists it.
  if (deny.has(key)) return "denied";
  if (allow.has(key)) return "approved";
  return "unknown";
}

export function checkLicenses(
  deps: Dependency[],
  policy: LicensePolicy,
  lookup: LicenseLookup,
): ComplianceEntry[] {
  const allow = toSet(policy.allow);
  const deny = toSet(policy.deny);
  return deps.map((dep) => {
    const license = lookup(dep);
    return {
      name: dep.name,
      version: dep.version,
      license,
      status: classify(license, allow, deny),
    };
  });
}
