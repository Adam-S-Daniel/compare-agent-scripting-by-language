/**
 * TypeScript type definitions for the Secret Rotation Validator.
 * All types are explicit and fully annotated.
 */

/** A single secret entry from the configuration file */
export interface SecretConfig {
  name: string;
  lastRotated: string; // ISO date string YYYY-MM-DD
  rotationPolicyDays: number; // how often the secret must be rotated
  requiredBy: string[]; // services that depend on this secret
}

/** Urgency level for a secret's rotation status */
export type Urgency = "expired" | "warning" | "ok";

/** Computed rotation status for a single secret */
export interface SecretStatus {
  name: string;
  lastRotated: string;
  rotationPolicyDays: number;
  requiredBy: string[];
  expiryDate: string; // ISO date when secret expires (lastRotated + rotationPolicyDays)
  daysUntilExpiry: number; // negative = already expired, 0+ = days remaining
  urgency: Urgency;
}

/** Full rotation report with all secrets grouped by urgency */
export interface RotationReport {
  generatedAt: string; // ISO date of report generation
  warningWindowDays: number; // secrets expiring within this many days are flagged as warning
  summary: {
    expired: number;
    warning: number;
    ok: number;
  };
  expired: SecretStatus[];
  warning: SecretStatus[];
  ok: SecretStatus[];
}
