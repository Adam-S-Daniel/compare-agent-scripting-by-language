// Core classifier: given raw secret records and a warning window, return a
// report sorted by urgency. Pure (no I/O, no Date.now) so tests can pin "now".

export interface Secret {
  name: string;
  lastRotated: string; // ISO 8601 date (YYYY-MM-DD)
  rotationPolicyDays: number;
  requiredBy: string[];
}

export type Status = "expired" | "warning" | "ok";

export interface ClassifiedSecret extends Secret {
  status: Status;
  daysSinceRotation: number;
  daysUntilExpiry: number; // negative if expired
  expiresAt: string;
}

export interface Report {
  generatedAt: string;
  warningWindowDays: number;
  totals: { expired: number; warning: number; ok: number };
  expired: ClassifiedSecret[];
  warning: ClassifiedSecret[];
  ok: ClassifiedSecret[];
}

export interface ClassifyOptions {
  warningWindowDays: number;
  now: Date;
}

const MS_PER_DAY = 86_400_000;

function assertSecret(s: Secret, idx: number): void {
  if (typeof s?.name !== "string" || !s.name) {
    throw new Error(`secrets[${idx}].name must be a non-empty string`);
  }
  const rotated = new Date(s.lastRotated);
  if (Number.isNaN(rotated.getTime())) {
    throw new Error(`secrets[${idx}].lastRotated is not a valid ISO date: ${s.lastRotated}`);
  }
  if (!Number.isFinite(s.rotationPolicyDays) || s.rotationPolicyDays <= 0) {
    throw new Error(
      `secrets[${idx}].rotationPolicyDays must be a positive number, got ${s.rotationPolicyDays}`,
    );
  }
  if (!Array.isArray(s.requiredBy)) {
    throw new Error(`secrets[${idx}].requiredBy must be an array of service names`);
  }
}

function diffDays(later: Date, earlier: Date): number {
  // Round to nearest whole day to be tolerant of DST/offsets when the inputs
  // are date-only strings (parsed as UTC midnight).
  return Math.round((later.getTime() - earlier.getTime()) / MS_PER_DAY);
}

function classifyOne(s: Secret, opts: ClassifyOptions): ClassifiedSecret {
  const lastRotated = new Date(s.lastRotated);
  const expiresAt = new Date(lastRotated.getTime() + s.rotationPolicyDays * MS_PER_DAY);
  const daysSinceRotation = diffDays(opts.now, lastRotated);
  const daysUntilExpiry = diffDays(expiresAt, opts.now);

  let status: Status;
  if (daysUntilExpiry < 0) {
    status = "expired";
  } else if (daysUntilExpiry <= opts.warningWindowDays) {
    status = "warning";
  } else {
    status = "ok";
  }

  return {
    ...s,
    status,
    daysSinceRotation,
    daysUntilExpiry,
    expiresAt: expiresAt.toISOString().slice(0, 10),
  };
}

export function classifySecrets(secrets: Secret[], opts: ClassifyOptions): Report {
  if (!Array.isArray(secrets)) {
    throw new Error("secrets must be an array");
  }
  if (!Number.isFinite(opts.warningWindowDays) || opts.warningWindowDays < 0) {
    throw new Error(`warningWindowDays must be >= 0, got ${opts.warningWindowDays}`);
  }
  secrets.forEach(assertSecret);

  const classified = secrets.map((s) => classifyOne(s, opts));

  // Most overdue first within expired; soonest-expiring first within warning;
  // alphabetical by name within ok (deterministic output for snapshots).
  const expired = classified
    .filter((s) => s.status === "expired")
    .sort((a, b) => a.daysUntilExpiry - b.daysUntilExpiry);
  const warning = classified
    .filter((s) => s.status === "warning")
    .sort((a, b) => a.daysUntilExpiry - b.daysUntilExpiry);
  const ok = classified
    .filter((s) => s.status === "ok")
    .sort((a, b) => a.name.localeCompare(b.name));

  return {
    generatedAt: opts.now.toISOString(),
    warningWindowDays: opts.warningWindowDays,
    totals: { expired: expired.length, warning: warning.length, ok: ok.length },
    expired,
    warning,
    ok,
  };
}
