// Core validation logic for the secret rotation validator.
// Determines urgency based on days since rotation vs policy/warning thresholds.

import type { SecretConfig, SecretStatus, RotationReport, Urgency } from "./types";

// Compute whole-day difference between two UTC dates (today - pastDate).
function daysBetween(past: Date, today: Date): number {
  const ms = today.getTime() - past.getTime();
  return Math.floor(ms / (1000 * 60 * 60 * 24));
}

// Parse a YYYY-MM-DD string as midnight UTC, throwing on bad input.
function parseDate(dateStr: string, fieldName: string): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
    throw new Error(`Invalid date format for ${fieldName}: "${dateStr}" (expected YYYY-MM-DD)`);
  }
  const d = new Date(`${dateStr}T00:00:00.000Z`);
  if (isNaN(d.getTime())) {
    throw new Error(`Invalid date value for ${fieldName}: "${dateStr}"`);
  }
  return d;
}

// Classify a single secret against today's date and the warning window.
// Urgency rules:
//   expired: daysUntilExpiry <= 0
//   warning: 0 < daysUntilExpiry <= warningWindowDays
//   ok:      daysUntilExpiry > warningWindowDays
export function validateSecret(
  secret: SecretConfig,
  today: Date,
  warningWindowDays: number
): SecretStatus {
  const lastRotatedDate = parseDate(secret.lastRotated, `secret "${secret.name}" lastRotated`);
  const daysSinceRotation = daysBetween(lastRotatedDate, today);
  const daysUntilExpiry = secret.rotationPolicyDays - daysSinceRotation;

  let urgency: Urgency;
  if (daysUntilExpiry <= 0) {
    urgency = "expired";
  } else if (daysUntilExpiry <= warningWindowDays) {
    urgency = "warning";
  } else {
    urgency = "ok";
  }

  return { secret, daysSinceRotation, daysUntilExpiry, urgency };
}

// Generate a full rotation report by evaluating all secrets.
export function generateReport(
  secrets: SecretConfig[],
  today: Date,
  warningWindowDays: number
): RotationReport {
  const statuses = secrets.map((s) => validateSecret(s, today, warningWindowDays));

  // Format the reference date as YYYY-MM-DD (UTC) for display
  const yyyy = today.getUTCFullYear();
  const mm = String(today.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(today.getUTCDate()).padStart(2, "0");
  const referenceDate = `${yyyy}-${mm}-${dd}`;

  return {
    generatedAt: new Date().toISOString(),
    referenceDate,
    warningWindowDays,
    expired: statuses.filter((s) => s.urgency === "expired"),
    warning: statuses.filter((s) => s.urgency === "warning"),
    ok: statuses.filter((s) => s.urgency === "ok"),
  };
}
