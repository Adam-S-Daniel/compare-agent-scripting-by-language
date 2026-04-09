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
  license: string;
}

/** Compliance status for a single dependency */
export type ComplianceStatus = "approved" | "denied" | "unknown";

/** A single entry in the compliance report */
export interface ComplianceEntry {
  name: string;
  version: string;
  license: string;
  status: ComplianceStatus;
}

/** The full compliance report */
export interface ComplianceReport {
  total: number;
  approved: number;
  denied: number;
  unknown: number;
  entries: ComplianceEntry[];
}

/** Configuration for license policy */
export interface LicenseConfig {
  allowedLicenses: string[];
  deniedLicenses: string[];
}

/** Function type for looking up a license for a dependency */
export type LicenseLookupFn = (dep: Dependency) => Promise<string>;
