// Type definitions for the dependency license checker

export interface Dependency {
  name: string;
  version: string;
}

export interface LicenseConfig {
  allowList: string[];
  denyList: string[];
}

export interface LicenseInfo {
  name: string;
  version: string;
  license: string | null;
  status: "approved" | "denied" | "unknown";
}

export interface ComplianceReport {
  timestamp: string;
  totalDependencies: number;
  approved: number;
  denied: number;
  unknown: number;
  licenses: LicenseInfo[];
}

export interface DependencyManifest {
  type: "npm" | "python";
  dependencies: Dependency[];
}

export interface LicenseLookup {
  (name: string): Promise<string | null>;
}
