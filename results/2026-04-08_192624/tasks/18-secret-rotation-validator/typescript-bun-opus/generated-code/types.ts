// Domain types for the secret rotation validator

/** Urgency classification for a secret's rotation status */
export type Urgency = "expired" | "warning" | "ok";

/** Configuration for a single secret with rotation metadata */
export interface SecretConfig {
  name: string;
  lastRotated: string; // ISO date string (YYYY-MM-DD)
  rotationPolicyDays: number; // how often the secret must be rotated
  requiredBy: string[]; // services that depend on this secret
}

/** Result of evaluating one secret's rotation status */
export interface SecretStatus {
  name: string;
  urgency: Urgency;
  daysSinceRotation: number;
  daysUntilExpiry: number; // negative = overdue
  requiredBy: string[];
  expiryDate: string; // ISO date string
}

/** Full rotation report grouping secrets by urgency */
export interface RotationReport {
  generatedAt: string;
  warningWindowDays: number;
  secrets: SecretStatus[];
  expired: SecretStatus[];
  warning: SecretStatus[];
  ok: SecretStatus[];
}

/** Supported output formats */
export type OutputFormat = "json" | "markdown";
