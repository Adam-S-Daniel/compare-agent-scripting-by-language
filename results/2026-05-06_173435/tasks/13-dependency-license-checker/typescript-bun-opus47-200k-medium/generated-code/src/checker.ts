// Compliance decision engine. Given a list of dependencies, a policy
// (allow- and deny-lists), and an injected license lookup function, produce
// a per-dependency report. Lookup is injected so tests can pass a mock and
// production can wire in a real registry call.

import type { Dependency } from "./parser.ts";

export type Status = "approved" | "denied" | "unknown";

export interface PolicyConfig {
  allow: string[];
  deny: string[];
}

export interface ReportEntry {
  name: string;
  version: string;
  license: string | null;
  status: Status;
  error?: string;
}

export type LicenseLookup = (name: string, version: string) => Promise<string | null>;

export async function checkDependencies(
  deps: Dependency[],
  policy: PolicyConfig,
  lookup: LicenseLookup,
): Promise<ReportEntry[]> {
  const denySet = new Set(policy.deny.map((s) => s.toLowerCase()));
  const allowSet = new Set(policy.allow.map((s) => s.toLowerCase()));

  const out: ReportEntry[] = [];
  for (const dep of deps) {
    let license: string | null = null;
    let error: string | undefined;
    try {
      license = await lookup(dep.name, dep.version);
    } catch (err) {
      error = (err as Error).message;
    }

    let status: Status;
    if (license === null) {
      status = "unknown";
    } else if (denySet.has(license.toLowerCase())) {
      // Deny-list wins over allow-list when a license appears on both.
      status = "denied";
    } else if (allowSet.has(license.toLowerCase())) {
      status = "approved";
    } else {
      // Conservative default: anything not explicitly allowed is unknown.
      status = "unknown";
    }

    const entry: ReportEntry = { name: dep.name, version: dep.version, license, status };
    if (error) entry.error = error;
    out.push(entry);
  }
  return out;
}
