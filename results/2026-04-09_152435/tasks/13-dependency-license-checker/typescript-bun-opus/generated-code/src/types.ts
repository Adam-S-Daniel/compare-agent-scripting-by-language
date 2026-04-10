// Core types for the dependency license checker

/** Represents a single dependency extracted from a manifest */
export interface Dependency {
  name: string;
  version: string;
}

/** License lookup result for a dependency */
export interface LicenseInfo {
  name: string;
  version: string;
  license: string | null; // null if lookup failed
}

/** Compliance status for a dependency */
export type ComplianceStatus = "approved" | "denied" | "unknown";

/** A single entry in the compliance report */
export interface ComplianceEntry {
  name: string;
  version: string;
  license: string | null;
  status: ComplianceStatus;
}

/** Full compliance report */
export interface ComplianceReport {
  entries: ComplianceEntry[];
  summary: {
    total: number;
    approved: number;
    denied: number;
    unknown: number;
  };
}

/** Configuration for license allow/deny lists */
export interface LicenseConfig {
  allowList: string[];
  denyList: string[];
}

/** Function signature for license lookup (allows mocking) */
export type LicenseLookupFn = (name: string, version: string) => Promise<LicenseInfo>;
