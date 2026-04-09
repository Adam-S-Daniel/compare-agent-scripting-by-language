// Core types for the dependency license checker.

/** A single dependency extracted from a manifest file. */
export interface Dependency {
  name: string;
  version: string;
}

/** Configuration specifying which licenses are allowed or denied. */
export interface LicenseConfig {
  /** Licenses explicitly permitted (e.g. "MIT", "Apache-2.0"). */
  allowList: string[];
  /** Licenses explicitly prohibited (e.g. "GPL-3.0"). Deny takes precedence. */
  denyList: string[];
}

/** Result of checking a single dependency's license. */
export type LicenseStatus = "approved" | "denied" | "unknown";

/** Full report entry for one dependency. */
export interface DependencyReport {
  name: string;
  version: string;
  license: string | null;
  status: LicenseStatus;
}

/** Aggregated compliance report for all dependencies. */
export interface ComplianceReport {
  dependencies: DependencyReport[];
  summary: {
    total: number;
    approved: number;
    denied: number;
    unknown: number;
  };
  /** true if no dependency has status "denied" */
  compliant: boolean;
}

/**
 * Function signature for license lookup.
 * Accepts package name + version, returns the SPDX license identifier or null.
 * Use a mock implementation for tests; swap in a real registry call for production.
 */
export type LicenseLookupFn = (
  name: string,
  version: string
) => Promise<string | null>;
