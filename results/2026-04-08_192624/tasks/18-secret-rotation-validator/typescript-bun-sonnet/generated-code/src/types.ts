/**
 * Types for the Secret Rotation Validator.
 *
 * A "secret" is any credential/key that must be rotated on a schedule.
 * This module defines the shape of input configs, intermediate status objects,
 * the final rotation report, and supported output formats.
 */

/** Urgency levels, ordered from most to least critical. */
export type Urgency = "expired" | "warning" | "ok";

/** Supported output formats for the rotation report. */
export type OutputFormat = "markdown" | "json";

/**
 * Input configuration for a single secret.
 * All fields are required; callers must supply mock or real data.
 */
export interface SecretConfig {
  /** Unique identifier for the secret (e.g. "DB_PASSWORD"). */
  name: string;
  /** The date this secret was last rotated. */
  lastRotated: Date;
  /** How many days between required rotations. */
  rotationPolicyDays: number;
  /** Services that depend on this secret (for notification routing). */
  requiredBy: string[];
}

/**
 * The computed status of a secret at a given point in time.
 * Derived by classifySecret() from a SecretConfig.
 */
export interface SecretStatus {
  name: string;
  urgency: Urgency;
  /** Positive = days until expiry. Negative = days past expiry. */
  daysUntilExpiry: number;
  /** ISO string of when this secret expires (or expired). */
  expiresAt: string;
  requiredBy: string[];
  rotationPolicyDays: number;
  lastRotated: Date;
}

/** Summary counts for the overall report. */
export interface ReportSummary {
  totalSecrets: number;
  expiredCount: number;
  warningCount: number;
  okCount: number;
}

/**
 * The full rotation report, grouping statuses by urgency.
 * This is the primary output of generateReport().
 */
export interface RotationReport {
  generatedAt: Date;
  warningWindowDays: number;
  summary: ReportSummary;
  expired: SecretStatus[];
  warning: SecretStatus[];
  ok: SecretStatus[];
}
