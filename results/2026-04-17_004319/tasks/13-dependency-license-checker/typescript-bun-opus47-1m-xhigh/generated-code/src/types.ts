// Shared domain types for the dependency license checker.

// One dependency row pulled from a manifest.
export interface Dependency {
  name: string;
  version: string;
}

// A license lookup returns either a known SPDX-ish identifier
// or null to signal the license could not be determined.
export type LicenseLookup = (dep: Dependency) => string | null;

// Policy configuration: allowed and denied license identifiers.
// Identifiers are compared case-insensitively.
export interface LicensePolicy {
  allow: string[];
  deny: string[];
}

// Per-dependency verdict. "unknown" covers both "lookup returned null"
// and "license is neither on allow nor deny list".
export type ComplianceStatus = "approved" | "denied" | "unknown";

export interface ComplianceEntry {
  name: string;
  version: string;
  license: string | null;
  status: ComplianceStatus;
}

export interface ComplianceReport {
  entries: ComplianceEntry[];
  summary: {
    approved: number;
    denied: number;
    unknown: number;
    total: number;
  };
}
