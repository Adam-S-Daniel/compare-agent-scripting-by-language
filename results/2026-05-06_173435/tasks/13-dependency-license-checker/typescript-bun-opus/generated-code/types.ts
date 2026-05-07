// Types for the dependency license checker

export interface Dependency {
  name: string;
  version: string;
}

export interface LicenseConfig {
  allowList: string[];
  denyList: string[];
}

export type LicenseStatus = "approved" | "denied" | "unknown";

export interface LicenseInfo {
  name: string;
  version: string;
  license: string | null;
  status: LicenseStatus;
}

export interface ComplianceReport {
  entries: LicenseInfo[];
  summary: {
    total: number;
    approved: number;
    denied: number;
    unknown: number;
  };
}

export type LicenseLookup = (name: string, version: string) => Promise<string | null>;
