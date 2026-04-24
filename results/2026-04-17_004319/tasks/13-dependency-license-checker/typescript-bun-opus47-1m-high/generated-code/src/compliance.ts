// Classifies each dependency's licence against a policy:
// - "approved" — on the allow list
// - "denied"   — on the deny list (wins over allow when a licence appears on both)
// - "unknown"  — licence missing, or not on either list
//
// The deny list being authoritative is intentional: it's safer to flag a
// borderline dependency than to silently approve something banned.

import type { Dependency } from "./parser";
import type { LicenseResolver } from "./resolver";

export interface PolicyConfig {
  allow: string[];
  deny: string[];
}

export type ComplianceStatus = "approved" | "denied" | "unknown";

export interface ComplianceRecord {
  name: string;
  version: string;
  license: string | null;
  status: ComplianceStatus;
}

export async function checkCompliance(
  deps: Dependency[],
  policy: PolicyConfig,
  resolver: LicenseResolver,
): Promise<ComplianceRecord[]> {
  const allow = new Set(policy.allow);
  const deny = new Set(policy.deny);

  const records: ComplianceRecord[] = [];
  for (const dep of deps) {
    const license = await resolver(dep.name);
    let status: ComplianceStatus;
    if (license === null) {
      status = "unknown";
    } else if (deny.has(license)) {
      status = "denied";
    } else if (allow.has(license)) {
      status = "approved";
    } else {
      status = "unknown";
    }
    records.push({ name: dep.name, version: dep.version, license, status });
  }
  return records;
}
