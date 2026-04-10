/**
 * Core validation logic for the Secret Rotation Validator.
 * Determines whether secrets are expired, expiring soon (warning), or ok.
 * All date arithmetic uses UTC to avoid timezone-related drift.
 */
import type { SecretConfig, SecretStatus, RotationReport, Urgency } from "./types";

/**
 * Adds a number of days to a YYYY-MM-DD date string.
 * Uses UTC to avoid DST and timezone issues.
 */
function addDays(dateStr: string, days: number): string {
  const date = new Date(dateStr + "T00:00:00Z");
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

/**
 * Computes the number of days between two YYYY-MM-DD date strings.
 * Returns positive if 'to' is in the future, negative if in the past.
 * Uses Math.round to handle DST boundary days cleanly.
 */
function daysBetween(from: string, to: string): number {
  const fromDate = new Date(from + "T00:00:00Z");
  const toDate = new Date(to + "T00:00:00Z");
  const diffMs = toDate.getTime() - fromDate.getTime();
  return Math.round(diffMs / (1000 * 60 * 60 * 24));
}

/**
 * Classifies urgency based on days remaining until expiry:
 *   < 0              → expired (already past expiry date)
 *   0 to warningDays → warning (expiring today or within warning window)
 *   >= warningDays   → ok
 */
function classifyUrgency(daysUntilExpiry: number, warningWindowDays: number): Urgency {
  if (daysUntilExpiry < 0) return "expired";
  if (daysUntilExpiry < warningWindowDays) return "warning";
  return "ok";
}

/**
 * Processes a single secret and computes its rotation status.
 * @param secret - The secret configuration
 * @param today - Current date as YYYY-MM-DD (injectable for testing)
 * @param warningWindowDays - Secrets expiring within this window are flagged as warning
 */
export function processSecret(
  secret: SecretConfig,
  today: string,
  warningWindowDays: number
): SecretStatus {
  const expiryDate = addDays(secret.lastRotated, secret.rotationPolicyDays);
  const daysUntilExpiry = daysBetween(today, expiryDate);
  const urgency = classifyUrgency(daysUntilExpiry, warningWindowDays);

  return {
    name: secret.name,
    lastRotated: secret.lastRotated,
    rotationPolicyDays: secret.rotationPolicyDays,
    requiredBy: secret.requiredBy,
    expiryDate,
    daysUntilExpiry,
    urgency,
  };
}

/**
 * Generates a full rotation report for a list of secrets.
 * Groups secrets by urgency: expired, warning, ok.
 * @param secrets - Array of secret configurations
 * @param today - Current date as YYYY-MM-DD
 * @param warningWindowDays - Warning window in days (default: 14)
 */
export function generateReport(
  secrets: SecretConfig[],
  today: string,
  warningWindowDays: number = 14
): RotationReport {
  const statuses = secrets.map((s) => processSecret(s, today, warningWindowDays));

  const expired = statuses.filter((s) => s.urgency === "expired");
  const warning = statuses.filter((s) => s.urgency === "warning");
  const ok = statuses.filter((s) => s.urgency === "ok");

  return {
    generatedAt: today,
    warningWindowDays,
    summary: {
      expired: expired.length,
      warning: warning.length,
      ok: ok.length,
    },
    expired,
    warning,
    ok,
  };
}
