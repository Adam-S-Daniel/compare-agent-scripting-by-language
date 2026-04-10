// Core validation logic for secret rotation.
// Classifies each secret as expired, warning, or ok based on its last rotation
// date, policy, and a configurable warning window.

import type {
  SecretConfig,
  SecretStatus,
  Urgency,
  RotationConfig,
  RotationReport,
} from "./types";

/** Milliseconds in one day, used for date arithmetic. */
const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Calculate the number of whole days between two dates. */
function daysBetween(from: Date, to: Date): number {
  return Math.floor((to.getTime() - from.getTime()) / MS_PER_DAY);
}

/**
 * Validate a single secret against its rotation policy.
 * @param secret - The secret configuration to validate.
 * @param warningWindowDays - How many days before expiry to trigger a warning.
 * @param now - Reference date for the check (defaults to current date).
 * @returns A SecretStatus with urgency classification and computed fields.
 */
export function validateSecret(
  secret: SecretConfig,
  warningWindowDays: number,
  now: Date = new Date()
): SecretStatus {
  const lastRotatedDate = new Date(secret.lastRotated);
  const daysSinceRotation = daysBetween(lastRotatedDate, now);
  const daysUntilExpiry = secret.rotationPolicyDays - daysSinceRotation;

  let urgency: Urgency;
  if (daysUntilExpiry < 0) {
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
    rotationPolicyDays: secret.rotationPolicyDays,
    requiredBy: secret.requiredBy,
    lastRotated: secret.lastRotated,
  };
}

/**
 * Validate multiple secrets and return them sorted by urgency (expired first).
 */
export function validateSecrets(
  secrets: SecretConfig[],
  warningWindowDays: number,
  now: Date = new Date()
): SecretStatus[] {
  const urgencyOrder: Record<Urgency, number> = { expired: 0, warning: 1, ok: 2 };

  return secrets
    .map((s) => validateSecret(s, warningWindowDays, now))
    .sort((a, b) => urgencyOrder[a.urgency] - urgencyOrder[b.urgency]);
}

/**
 * Generate a full rotation report from configuration.
 */
export function generateReport(
  config: RotationConfig,
  now: Date = new Date()
): RotationReport {
  const secrets = validateSecrets(config.secrets, config.warningWindowDays, now);

  const summary = {
    total: secrets.length,
    expired: secrets.filter((s) => s.urgency === "expired").length,
    warning: secrets.filter((s) => s.urgency === "warning").length,
    ok: secrets.filter((s) => s.urgency === "ok").length,
  };

  return {
    generatedAt: now.toISOString(),
    warningWindowDays: config.warningWindowDays,
    secrets,
    summary,
  };
}
