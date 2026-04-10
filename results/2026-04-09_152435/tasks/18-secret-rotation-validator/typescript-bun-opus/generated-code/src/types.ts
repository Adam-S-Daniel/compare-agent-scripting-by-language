// Types for the secret rotation validator.
// Defines the core data structures used throughout the application.

/** A single secret with its rotation metadata. */
export interface SecretConfig {
  name: string;
  lastRotated: string; // ISO 8601 date string (YYYY-MM-DD)
  rotationPolicyDays: number;
  requiredBy: string[];
}

/** Top-level configuration containing all secrets and the warning window. */
export interface RotationConfig {
  secrets: SecretConfig[];
  warningWindowDays: number;
}

/** Urgency classification for a secret. */
export type Urgency = "expired" | "warning" | "ok";

/** Result of validating a single secret. */
export interface SecretStatus {
  name: string;
  urgency: Urgency;
  daysSinceRotation: number;
  daysUntilExpiry: number; // negative means already expired
  rotationPolicyDays: number;
  requiredBy: string[];
  lastRotated: string;
}

/** The full rotation report. */
export interface RotationReport {
  generatedAt: string;
  warningWindowDays: number;
  secrets: SecretStatus[];
  summary: {
    total: number;
    expired: number;
    warning: number;
    ok: number;
  };
}

/** Supported output formats. */
export type OutputFormat = "json" | "markdown";
