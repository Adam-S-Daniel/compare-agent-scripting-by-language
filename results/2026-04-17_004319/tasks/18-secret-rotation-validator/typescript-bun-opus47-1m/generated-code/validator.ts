// Secret rotation validator — pure functions so the logic is trivially testable.
//
// A "secret" is some credential whose rotation policy is tracked here. For each
// secret we know when it was last rotated, how often it must be rotated, and
// which services depend on it. Given a reference date (usually today) and a
// warning window (days), we classify every secret into one of three buckets:
//
//   - expired: the last-rotated date + policy days is already in the past
//   - warning: the rotation deadline is within `warningDays` of the ref date
//   - ok:      the rotation deadline is further away than the warning window
//
// The CLI (cli.ts) is a thin wrapper that reads a JSON config, calls
// validateSecrets, renders the requested format, and sets an exit code.

export type SecretStatus = "expired" | "warning" | "ok";

export interface Secret {
  name: string;
  /** ISO-8601 date (YYYY-MM-DD) of last rotation. */
  lastRotated: string;
  /** How often this secret must be rotated, in whole days. */
  rotationDays: number;
  /** Services / components that depend on this secret. */
  requiredBy: string[];
}

export interface ClassifiedSecret {
  secret: Secret;
  status: SecretStatus;
  /** Negative when overdue, 0 when due today, positive when due in the future. */
  daysUntilRotation: number;
  /** ISO-8601 date on which this secret is considered due for rotation. */
  dueDate: string;
}

export interface ValidationReport {
  expired: ClassifiedSecret[];
  warning: ClassifiedSecret[];
  ok: ClassifiedSecret[];
  summary: { expired: number; warning: number; ok: number; total: number };
}

export interface ValidateOptions {
  referenceDate: Date;
  /** Secrets expiring within this many days (inclusive) are marked "warning". */
  warningDays: number;
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;

function parseIsoDate(iso: string, fieldLabel: string): Date {
  // We require the strict YYYY-MM-DD shape rather than whatever Date() accepts,
  // because "Dec 2" or "01/02/2026" are ambiguous and we want errors to be loud.
  if (!/^\d{4}-\d{2}-\d{2}$/.test(iso)) {
    throw new Error(
      `${fieldLabel} must be an ISO date (YYYY-MM-DD); got: ${JSON.stringify(iso)}`,
    );
  }
  const d = new Date(`${iso}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) {
    throw new Error(`${fieldLabel} is not a real date: ${JSON.stringify(iso)}`);
  }
  return d;
}

function toIsoDate(d: Date): string {
  // Keep everything in UTC so day arithmetic never drifts by TZ.
  return d.toISOString().slice(0, 10);
}

function daysBetween(from: Date, to: Date): number {
  // Both dates are anchored at UTC midnight, so integer-day diffs are exact.
  return Math.round((to.getTime() - from.getTime()) / MS_PER_DAY);
}

export function classifySecret(
  secret: Secret,
  referenceDate: Date,
  warningDays: number,
): ClassifiedSecret {
  const last = parseIsoDate(secret.lastRotated, `secret '${secret.name}'.lastRotated`);
  const due = new Date(last.getTime() + secret.rotationDays * MS_PER_DAY);
  const daysUntilRotation = daysBetween(referenceDate, due);

  let status: SecretStatus;
  if (daysUntilRotation < 0) {
    status = "expired";
  } else if (daysUntilRotation <= warningDays) {
    status = "warning";
  } else {
    status = "ok";
  }

  return {
    secret,
    status,
    daysUntilRotation,
    dueDate: toIsoDate(due),
  };
}

export function validateSecrets(
  secrets: Secret[],
  options: ValidateOptions,
): ValidationReport {
  const classified = secrets.map((s) =>
    classifySecret(s, options.referenceDate, options.warningDays),
  );

  const expired = classified
    .filter((c) => c.status === "expired")
    // Most overdue first (smallest — i.e. most negative — daysUntilRotation).
    .sort((a, b) => a.daysUntilRotation - b.daysUntilRotation);
  const warning = classified
    .filter((c) => c.status === "warning")
    // Soonest-due first.
    .sort((a, b) => a.daysUntilRotation - b.daysUntilRotation);
  const ok = classified
    .filter((c) => c.status === "ok")
    .sort((a, b) => a.daysUntilRotation - b.daysUntilRotation);

  return {
    expired,
    warning,
    ok,
    summary: {
      expired: expired.length,
      warning: warning.length,
      ok: ok.length,
      total: classified.length,
    },
  };
}

// -- Config parsing ---------------------------------------------------------

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

export function parseConfig(raw: unknown): Secret[] {
  if (!isPlainObject(raw)) {
    throw new Error("Config must be an object with a 'secrets' array");
  }
  const { secrets } = raw;
  if (!Array.isArray(secrets)) {
    throw new Error("Config.secrets must be an array");
  }

  return secrets.map((entry, i) => {
    if (!isPlainObject(entry)) {
      throw new Error(`secrets[${i}] must be an object`);
    }
    const name = entry["name"];
    if (typeof name !== "string" || name.length === 0) {
      throw new Error(`secrets[${i}].name must be a non-empty string`);
    }
    const lastRotated = entry["lastRotated"];
    if (typeof lastRotated !== "string") {
      throw new Error(`secrets[${i}] (${name}): lastRotated is required and must be a string`);
    }
    // Validate by parsing — surface the failure as a lastRotated error.
    parseIsoDate(lastRotated, `secrets[${i}] (${name}).lastRotated`);

    const rotationDays = entry["rotationDays"];
    if (
      typeof rotationDays !== "number" ||
      !Number.isInteger(rotationDays) ||
      rotationDays <= 0
    ) {
      throw new Error(
        `secrets[${i}] (${name}).rotationDays must be a positive integer`,
      );
    }

    const requiredBy = entry["requiredBy"];
    if (!Array.isArray(requiredBy) || !requiredBy.every((x) => typeof x === "string")) {
      throw new Error(`secrets[${i}] (${name}).requiredBy must be an array of strings`);
    }

    return {
      name,
      lastRotated,
      rotationDays,
      requiredBy: requiredBy.slice(),
    };
  });
}

// -- Output formatters ------------------------------------------------------

export function renderJson(report: ValidationReport): string {
  return JSON.stringify(report, null, 2);
}

function renderGroupTable(entries: ClassifiedSecret[]): string {
  if (entries.length === 0) {
    return "_(none)_";
  }
  const header =
    "| Name | Last Rotated | Due Date | Days | Required By |\n" +
    "|---|---|---|---|---|";
  const rows = entries.map((c) => {
    const deps = c.secret.requiredBy.length > 0 ? c.secret.requiredBy.join(", ") : "-";
    return `| ${c.secret.name} | ${c.secret.lastRotated} | ${c.dueDate} | ${c.daysUntilRotation} | ${deps} |`;
  });
  return [header, ...rows].join("\n");
}

export function renderMarkdown(report: ValidationReport): string {
  const { summary } = report;
  return [
    "# Secret Rotation Report",
    "",
    `- Expired: ${summary.expired}`,
    `- Warning: ${summary.warning}`,
    `- OK: ${summary.ok}`,
    `- Total: ${summary.total}`,
    "",
    "## Expired",
    "",
    renderGroupTable(report.expired),
    "",
    "## Warning",
    "",
    renderGroupTable(report.warning),
    "",
    "## OK",
    "",
    renderGroupTable(report.ok),
    "",
  ].join("\n");
}
