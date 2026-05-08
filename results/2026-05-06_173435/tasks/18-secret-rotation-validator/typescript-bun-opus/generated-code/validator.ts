import type { SecretConfig, ValidationConfig, SecretStatus, RotationReport, Urgency } from "./types";

function daysBetween(a: Date, b: Date): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  const utcA = Date.UTC(a.getFullYear(), a.getMonth(), a.getDate());
  const utcB = Date.UTC(b.getFullYear(), b.getMonth(), b.getDate());
  return Math.floor((utcB - utcA) / msPerDay);
}

function addDays(date: Date, days: number): Date {
  const result = new Date(date.getTime());
  result.setUTCDate(result.getUTCDate() + days);
  return result;
}

function formatDate(date: Date): string {
  return date.toISOString().split("T")[0];
}

export function validateSecret(
  secret: SecretConfig,
  referenceDate: Date,
  warningWindowDays: number
): SecretStatus {
  if (!secret.name || secret.name.trim() === "") {
    throw new Error("Secret name cannot be empty");
  }
  if (secret.rotationPolicyDays <= 0) {
    throw new Error(
      `Invalid rotationPolicyDays for secret "${secret.name}": must be positive`
    );
  }

  const lastRotatedDate = new Date(secret.lastRotated + "T00:00:00Z");
  if (isNaN(lastRotatedDate.getTime())) {
    throw new Error(
      `Invalid lastRotated date for secret "${secret.name}": ${secret.lastRotated}`
    );
  }

  const expiryDate = addDays(lastRotatedDate, secret.rotationPolicyDays);
  const daysSinceRotation = daysBetween(lastRotatedDate, referenceDate);
  const daysUntilExpiry = daysBetween(referenceDate, expiryDate);

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
    expiryDate: formatDate(expiryDate),
    requiredBy: secret.requiredBy,
    rotationPolicyDays: secret.rotationPolicyDays,
    lastRotated: secret.lastRotated,
  };
}

export function generateReport(config: ValidationConfig): RotationReport {
  if (!config.secrets || !Array.isArray(config.secrets)) {
    throw new Error('Configuration must include a "secrets" array');
  }
  if (config.warningWindowDays < 0) {
    throw new Error("warningWindowDays must be non-negative");
  }

  const referenceDate = config.referenceDate
    ? new Date(config.referenceDate + "T00:00:00Z")
    : new Date();

  if (isNaN(referenceDate.getTime())) {
    throw new Error(`Invalid referenceDate: ${config.referenceDate}`);
  }

  const secrets = config.secrets.map((s) =>
    validateSecret(s, referenceDate, config.warningWindowDays)
  );

  const urgencyOrder: Record<Urgency, number> = { expired: 0, warning: 1, ok: 2 };
  secrets.sort(
    (a, b) =>
      urgencyOrder[a.urgency] - urgencyOrder[b.urgency] ||
      a.name.localeCompare(b.name)
  );

  const summary = {
    total: secrets.length,
    expired: secrets.filter((s) => s.urgency === "expired").length,
    warning: secrets.filter((s) => s.urgency === "warning").length,
    ok: secrets.filter((s) => s.urgency === "ok").length,
  };

  return {
    generatedAt: formatDate(referenceDate),
    warningWindowDays: config.warningWindowDays,
    secrets,
    summary,
  };
}
