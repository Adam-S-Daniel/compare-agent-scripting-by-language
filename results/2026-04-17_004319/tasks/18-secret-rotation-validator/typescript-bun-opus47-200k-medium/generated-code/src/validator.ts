// Core domain logic for classifying secrets as expired / warning / ok
// based on their rotation policy and a configurable warning window.

export interface Secret {
  name: string;
  lastRotated: string; // ISO date (YYYY-MM-DD)
  rotationPolicyDays: number;
  requiredBy: string[];
}

export type Status = "expired" | "warning" | "ok";

export interface ClassifiedSecret extends Secret {
  status: Status;
  dueDate: string; // ISO date when rotation is due
  daysUntilDue: number; // negative when overdue
}

export interface ValidateOptions {
  now: Date;
  warningDays: number;
}

export interface Report {
  generatedAt: string;
  warningDays: number;
  summary: { total: number; expired: number; warning: number; ok: number };
  expired: ClassifiedSecret[];
  warning: ClassifiedSecret[];
  ok: ClassifiedSecret[];
}

const MS_PER_DAY = 86_400_000;

function parseIsoDate(s: string): Date {
  // Accept YYYY-MM-DD or full ISO; reject anything Date cannot parse.
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) {
    throw new Error(`invalid date: ${s}`);
  }
  return d;
}

function toIsoDay(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function classifySecret(
  s: Secret,
  now: Date,
  warningDays: number,
): ClassifiedSecret {
  if (!Number.isFinite(s.rotationPolicyDays) || s.rotationPolicyDays <= 0) {
    throw new Error(
      `rotationPolicyDays must be a positive number for secret "${s.name}"`,
    );
  }
  if (!Number.isFinite(warningDays) || warningDays < 0) {
    throw new Error("warningDays must be a non-negative number");
  }
  const last = parseIsoDate(s.lastRotated);
  const due = new Date(last.getTime() + s.rotationPolicyDays * MS_PER_DAY);
  // Use whole-day difference so two timestamps on the same day report 0.
  const diffMs = due.getTime() - now.getTime();
  const daysUntilDue = Math.floor(diffMs / MS_PER_DAY);

  let status: Status;
  if (daysUntilDue < 0) status = "expired";
  else if (daysUntilDue <= warningDays) status = "warning";
  else status = "ok";

  return {
    ...s,
    status,
    dueDate: toIsoDay(due),
    daysUntilDue,
  };
}

export function validateSecrets(
  secrets: Secret[],
  opts: ValidateOptions,
): Report {
  const classified = secrets.map((s) => classifySecret(s, opts.now, opts.warningDays));

  // Most-overdue first; soonest-due-next for warning; most-recently-rotated first for ok.
  const byDueAsc = (a: ClassifiedSecret, b: ClassifiedSecret) =>
    a.daysUntilDue - b.daysUntilDue;
  const byDueDesc = (a: ClassifiedSecret, b: ClassifiedSecret) =>
    b.daysUntilDue - a.daysUntilDue;

  const expired = classified.filter((c) => c.status === "expired").sort(byDueAsc);
  const warning = classified.filter((c) => c.status === "warning").sort(byDueAsc);
  const ok = classified.filter((c) => c.status === "ok").sort(byDueDesc);

  return {
    generatedAt: opts.now.toISOString(),
    warningDays: opts.warningDays,
    summary: {
      total: classified.length,
      expired: expired.length,
      warning: warning.length,
      ok: ok.length,
    },
    expired,
    warning,
    ok,
  };
}
