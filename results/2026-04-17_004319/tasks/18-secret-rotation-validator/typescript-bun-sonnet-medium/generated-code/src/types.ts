export interface Secret {
  name: string;
  lastRotated: Date;
  rotationPolicyDays: number;
  requiredBy: string[];
}

export type SecretStatus = "expired" | "warning" | "ok";

export interface SecretStatusResult {
  secret: Secret;
  status: SecretStatus;
  daysUntilExpiry: number; // negative = overdue
  daysSinceRotation: number;
}

export interface RotationReport {
  expired: SecretStatusResult[];
  warning: SecretStatusResult[];
  ok: SecretStatusResult[];
  generatedAt: Date;
  summary: {
    expired: number;
    warning: number;
    ok: number;
  };
}

export interface ValidatorConfig {
  warningWindowDays: number;
  referenceDate?: Date;
}

// Shape of each secret in a fixture JSON file
export interface SecretInput {
  name: string;
  lastRotated: string; // ISO date string e.g. "2026-01-09"
  rotationPolicyDays: number;
  requiredBy: string[];
}

// Shape of the full fixture JSON file consumed by main.ts
export interface FixtureConfig {
  referenceDate?: string; // ISO date string; defaults to now
  warningWindowDays: number;
  secrets: SecretInput[];
}
