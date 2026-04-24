// Core types for the dependency license checker

export interface Dependency {
  name: string;
  version: string;
}

export interface LicenseConfig {
  allowList: string[];
  denyList: string[];
}

export type LicenseStatus = "approved" | "denied" | "unknown";

export interface CheckResult {
  name: string;
  version: string;
  license: string;
  status: LicenseStatus;
}

export interface ComplianceReport {
  results: CheckResult[];
  summary: {
    approved: number;
    denied: number;
    unknown: number;
    total: number;
  };
  passed: boolean;
}

// License lookup function signature — accepts a package name, returns license or null
export type LicenseLookupFn = (packageName: string) => string | null;
