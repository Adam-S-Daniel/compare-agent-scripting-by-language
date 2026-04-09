// Core validation logic: evaluates each secret against rotation policy and warning window

import type { SecretConfig, SecretStatus, RotationReport, Urgency } from "./types";

/**
 * Compute the number of whole days between two dates (date2 - date1).
 * Ignores time-of-day — works on calendar dates only.
 */
export function daysBetween(date1: Date, date2: Date): number {
  const MS_PER_DAY = 86_400_000;
  // Normalize to midnight UTC to avoid DST issues
  const utc1 = Date.UTC(date1.getFullYear(), date1.getMonth(), date1.getDate());
  const utc2 = Date.UTC(date2.getFullYear(), date2.getMonth(), date2.getDate());
  return Math.floor((utc2 - utc1) / MS_PER_DAY);
}

/**
 * Evaluate a single secret's rotation status relative to a reference date.
 */
export function evaluateSecret(
  secret: SecretConfig,
  referenceDate: Date,
  warningWindowDays: number
): SecretStatus {
  const lastRotated = new Date(secret.lastRotated);
  const daysSinceRotation = daysBetween(lastRotated, referenceDate);
  const daysUntilExpiry = secret.rotationPolicyDays - daysSinceRotation;

  // Compute the calendar expiry date
  const expiryDate = new Date(lastRotated);
  expiryDate.setUTCDate(expiryDate.getUTCDate() + secret.rotationPolicyDays);
  const expiryDateStr = expiryDate.toISOString().split("T")[0];

  let urgency: Urgency;
  if (daysUntilExpiry <= 0) {
    urgency = "expired";
  } else if (daysUntilExpiry <= warningWindowDays) {
    urgency = "warning";
  } else {
    urgency = "ok";
  }

  return {
    name: secret.name,
    urgency,
    daysSinceRotation,
    daysUntilExpiry,
    requiredBy: secret.requiredBy,
    expiryDate: expiryDateStr,
  };
}

/**
 * Build a full rotation report from a list of secrets.
 * Secrets are grouped by urgency for easy consumption.
 */
export function buildReport(
  secrets: SecretConfig[],
  warningWindowDays: number,
  referenceDate: Date = new Date()
): RotationReport {
  if (!Array.isArray(secrets) || secrets.length === 0) {
    throw new Error("No secrets provided. Supply at least one secret configuration.");
  }

  for (const s of secrets) {
    if (!s.name || typeof s.name !== "string") {
      throw new Error(`Invalid secret: missing or empty 'name' field.`);
    }
    if (!s.lastRotated || isNaN(new Date(s.lastRotated).getTime())) {
      throw new Error(`Invalid secret '${s.name}': 'lastRotated' must be a valid ISO date.`);
    }
    if (typeof s.rotationPolicyDays !== "number" || s.rotationPolicyDays <= 0) {
      throw new Error(`Invalid secret '${s.name}': 'rotationPolicyDays' must be a positive number.`);
    }
    if (!Array.isArray(s.requiredBy)) {
      throw new Error(`Invalid secret '${s.name}': 'requiredBy' must be an array of service names.`);
    }
  }

  if (typeof warningWindowDays !== "number" || warningWindowDays < 0) {
    throw new Error("warningWindowDays must be a non-negative number.");
  }

  const statuses = secrets.map((s) => evaluateSecret(s, referenceDate, warningWindowDays));

  return {
    generatedAt: referenceDate.toISOString().split("T")[0],
    warningWindowDays,
    secrets: statuses,
    expired: statuses.filter((s) => s.urgency === "expired"),
    warning: statuses.filter((s) => s.urgency === "warning"),
    ok: statuses.filter((s) => s.urgency === "ok"),
  };
}
