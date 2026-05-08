// Secret Rotation Validator — core types and logic
// GREEN: minimum implementation to pass all tests in validator.test.ts

export interface Secret {
  name: string;
  /** ISO date string: YYYY-MM-DD */
  lastRotated: string;
  rotationPolicyDays: number;
  requiredByServices: string[];
}

export type SecretUrgency = 'expired' | 'warning' | 'ok';

export interface SecretAnalysis {
  secret: Secret;
  urgency: SecretUrgency;
  /** Days until expiry. Negative means the secret is already past due. */
  daysUntilExpiry: number;
  /** YYYY-MM-DD string */
  expiryDate: string;
}

export interface RotationReport {
  generatedAt: string;
  warningWindowDays: number;
  summary: {
    total: number;
    expired: number;
    warning: number;
    ok: number;
  };
  expired: SecretAnalysis[];
  warning: SecretAnalysis[];
  ok: SecretAnalysis[];
}

export interface ValidatorConfig {
  secrets: Secret[];
  warningWindowDays: number;
  /** If omitted, defaults to today (new Date()). Useful for reproducible tests. */
  referenceDate?: string;
}

// ─── pure helpers ─────────────────────────────────────────────────────────────

/**
 * Days between the secret's expiry and referenceDate.
 * Negative → secret is already expired.
 * Uses UTC arithmetic so timezone differences don't shift the result by ±1 day.
 */
export function daysUntilExpiry(
  lastRotated: string,
  rotationPolicyDays: number,
  referenceDate: Date,
): number {
  const [y, m, d] = lastRotated.split('-').map(Number);
  // Date.UTC handles day overflow correctly (e.g. Dec day 91 → March 1)
  const expiryMs = Date.UTC(y, m - 1, d + rotationPolicyDays);
  const refMs = Date.UTC(
    referenceDate.getUTCFullYear(),
    referenceDate.getUTCMonth(),
    referenceDate.getUTCDate(),
  );
  return Math.floor((expiryMs - refMs) / (1000 * 60 * 60 * 24));
}

/** Returns the expiry date as a YYYY-MM-DD string. */
export function getExpiryDate(lastRotated: string, rotationPolicyDays: number): string {
  const [y, m, d] = lastRotated.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + rotationPolicyDays)).toISOString().split('T')[0];
}

// ─── analysis ─────────────────────────────────────────────────────────────────

export function analyzeSecret(
  secret: Secret,
  warningWindowDays: number,
  referenceDate: Date,
): SecretAnalysis {
  const days = daysUntilExpiry(secret.lastRotated, secret.rotationPolicyDays, referenceDate);
  const expiry = getExpiryDate(secret.lastRotated, secret.rotationPolicyDays);

  let urgency: SecretUrgency;
  if (days < 0) {
    urgency = 'expired';
  } else if (days <= warningWindowDays) {
    urgency = 'warning';
  } else {
    urgency = 'ok';
  }

  return { secret, urgency, daysUntilExpiry: days, expiryDate: expiry };
}

export function generateReport(config: ValidatorConfig): RotationReport {
  if (!config.secrets || !Array.isArray(config.secrets)) {
    throw new Error('Config must have a "secrets" array');
  }
  if (typeof config.warningWindowDays !== 'number' || config.warningWindowDays < 0) {
    throw new Error('"warningWindowDays" must be a non-negative number');
  }

  const referenceDate = config.referenceDate ? new Date(config.referenceDate) : new Date();

  const analyses = config.secrets.map(s =>
    analyzeSecret(s, config.warningWindowDays, referenceDate),
  );

  const expired = analyses.filter(a => a.urgency === 'expired');
  const warning = analyses.filter(a => a.urgency === 'warning');
  const ok = analyses.filter(a => a.urgency === 'ok');

  return {
    generatedAt: referenceDate.toISOString(),
    warningWindowDays: config.warningWindowDays,
    summary: { total: analyses.length, expired: expired.length, warning: warning.length, ok: ok.length },
    expired,
    warning,
    ok,
  };
}
