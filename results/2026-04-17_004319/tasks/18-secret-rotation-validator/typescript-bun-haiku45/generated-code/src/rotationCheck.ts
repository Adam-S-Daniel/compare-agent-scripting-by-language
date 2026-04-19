import { Secret, RotationStatus, RotationReport } from "./types";

// Check rotation status of a single secret against a reference date
export function checkSecretRotation(
  secret: Secret,
  now: Date,
  warningDays: number = 14
): RotationStatus {
  const lastRotated = secret.lastRotated instanceof Date
    ? secret.lastRotated
    : new Date(secret.lastRotated);

  // Calculate expiration date
  const expirationDate = new Date(lastRotated);
  expirationDate.setDate(expirationDate.getDate() + secret.rotationPolicyDays);

  // Calculate days until expiration
  const msPerDay = 24 * 60 * 60 * 1000;
  const daysUntilExpiration = Math.floor(
    (expirationDate.getTime() - now.getTime()) / msPerDay
  );

  // Determine status
  let status: "expired" | "warning" | "ok";
  if (daysUntilExpiration < 0) {
    status = "expired";
  } else if (daysUntilExpiration <= warningDays) {
    status = "warning";
  } else {
    status = "ok";
  }

  return {
    secret,
    status,
    daysUntilExpiration,
    expirationDate,
  };
}

// Generate a rotation report for multiple secrets
export function generateRotationReport(
  secrets: Secret[],
  now: Date,
  warningDays: number = 14
): RotationReport {
  const statuses = secrets.map(secret => checkSecretRotation(secret, now, warningDays));

  const summary = {
    expired: statuses.filter(s => s.status === "expired").length,
    warning: statuses.filter(s => s.status === "warning").length,
    ok: statuses.filter(s => s.status === "ok").length,
  };

  return {
    generated: now,
    summary,
    secrets: statuses,
  };
}
