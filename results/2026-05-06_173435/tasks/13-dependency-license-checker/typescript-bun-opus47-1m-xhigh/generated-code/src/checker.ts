// License-compliance checker. Pure-ish logic: takes a list of deps,
// a policy, and an injectable license-lookup function (mocked in tests,
// real in CI). Deny wins over allow on conflict.

import type { Dependency } from "./parser.ts";

export type Status = "approved" | "denied" | "unknown";

export interface Policy {
  allow: string[];
  deny: string[];
}

export interface CheckResult extends Dependency {
  license: string | null;
  status: Status;
  reason: string;
}

export type LicenseLookup = (name: string, version: string) => Promise<string | null>;

export async function checkDependencies(
  deps: Dependency[],
  policy: Policy,
  lookup: LicenseLookup,
): Promise<CheckResult[]> {
  const results: CheckResult[] = [];
  for (const dep of deps) {
    let license: string | null;
    try {
      license = await lookup(dep.name, dep.version);
    } catch (err) {
      throw new Error(
        `license lookup failed for ${dep.name}: ${(err as Error).message}`,
      );
    }
    results.push({ ...dep, ...classify(license, policy) });
  }
  // Sort by status then name so "denied" issues surface first, with
  // "unknown" pushed to the end where reviewers expect to triage them.
  const order: Record<Status, number> = { denied: 0, approved: 1, unknown: 2 };
  results.sort((a, b) => {
    const byStatus = order[a.status] - order[b.status];
    return byStatus !== 0 ? byStatus : a.name.localeCompare(b.name);
  });
  return results;
}

function classify(license: string | null, policy: Policy): {
  license: string | null;
  status: Status;
  reason: string;
} {
  if (license === null) {
    return {
      license,
      status: "unknown",
      reason: "license could not be determined",
    };
  }
  // Deny-list takes precedence so a misconfigured allow-list entry
  // can't accidentally green-light something explicitly forbidden.
  if (policy.deny.includes(license)) {
    return {
      license,
      status: "denied",
      reason: `license ${license} is on the deny-list`,
    };
  }
  if (policy.allow.includes(license)) {
    return {
      license,
      status: "approved",
      reason: `license ${license} is on the allow-list`,
    };
  }
  return {
    license,
    status: "unknown",
    reason: `license ${license} is not on the allow-list or deny-list`,
  };
}
