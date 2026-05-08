// Core TypeScript interfaces for the dependency license checker

export interface Dependency {
  name: string;
  version: string;
}

export interface LicenseConfig {
  allowList: string[];
  denyList: string[];
}

export type LicenseStatus = 'approved' | 'denied' | 'unknown';

export interface DependencyResult {
  dependency: Dependency;
  license: string | null;
  status: LicenseStatus;
}

export interface ComplianceReport {
  results: DependencyResult[];
  summary: {
    total: number;
    approved: number;
    denied: number;
    unknown: number;
  };
  passed: boolean;
}

// A function that looks up the license for a dependency; returns null if not found
export type LicenseLookupFn = (name: string, version: string) => Promise<string | null>;
