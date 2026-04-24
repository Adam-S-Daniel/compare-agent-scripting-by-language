import type { Secret, SecretStatus, SecretStatusResult, RotationReport, ValidatorConfig } from "./types";

const MS_PER_DAY = 86_400_000;

export function identifySecretStatus(
  secret: Secret,
  referenceDate: Date,
  warningWindowDays: number
): SecretStatusResult {
  const daysSinceRotation = Math.floor(
    (referenceDate.getTime() - secret.lastRotated.getTime()) / MS_PER_DAY
  );
  const daysUntilExpiry = secret.rotationPolicyDays - daysSinceRotation;

  let status: SecretStatus;
  if (daysUntilExpiry < 0) {
    status = "expired";
  } else if (daysUntilExpiry <= warningWindowDays) {
    status = "warning";
  } else {
    status = "ok";
  }

  return { secret, status, daysUntilExpiry, daysSinceRotation };
}

export function generateReport(
  secrets: Secret[],
  config: ValidatorConfig
): RotationReport {
  const referenceDate = config.referenceDate ?? new Date();
  const results = secrets.map((s) =>
    identifySecretStatus(s, referenceDate, config.warningWindowDays)
  );

  const expired = results.filter((r) => r.status === "expired");
  const warning = results.filter((r) => r.status === "warning");
  const ok = results.filter((r) => r.status === "ok");

  return {
    expired,
    warning,
    ok,
    generatedAt: referenceDate,
    summary: {
      expired: expired.length,
      warning: warning.length,
      ok: ok.length,
    },
  };
}
