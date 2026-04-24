// Core domain types for the dependency license checker

export interface Dependency {
  name: string;
  version: string;
}

export interface LicenseConfig {
  allowList: string[];
  denyList: string[];
}

export type LicenseStatus = "approved" | "denied" | "unknown";

export interface DependencyReport {
  name: string;
  version: string;
  license: string | null;
  status: LicenseStatus;
}

export interface ComplianceSummary {
  total: number;
  approved: number;
  denied: number;
  unknown: number;
}

export interface ComplianceReport {
  dependencies: DependencyReport[];
  summary: ComplianceSummary;
}
