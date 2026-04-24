// Core validator logic for the secret rotation checker.
//
// Design notes:
// - Pure functions. The "current time" is injected so tests are deterministic.
// - Dates are stored as calendar-day ISO strings (YYYY-MM-DD). Internally we
//   work in UTC milliseconds to avoid DST / local-timezone drift.
// - Classification rule: daysUntilExpiry < 0 -> expired, <= warningDays -> warning, else ok.

export type SecretStatus = "expired" | "warning" | "ok";
export type OutputFormat = "markdown" | "json";

export interface Secret {
  name: string;
  lastRotated: string;          // YYYY-MM-DD
  rotationPolicyDays: number;   // positive integer
  requiredBy: string[];
}

export interface EvaluatedSecret extends Secret {
  expiresOn: string;            // YYYY-MM-DD
  daysUntilExpiry: number;      // negative when overdue
  status: SecretStatus;
}

export interface ValidationReport {
  generatedAt: string;          // ISO timestamp
  warningDays: number;
  totals: { expired: number; warning: number; ok: number; total: number };
  expired: EvaluatedSecret[];
  warning: EvaluatedSecret[];
  ok: EvaluatedSecret[];
}

export interface EvalOptions {
  now: Date;
  warningDays: number;
}

const MS_PER_DAY = 86_400_000;

function parseIsoDay(value: string, field: string, name: string): number {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error(`invalid ${field} for "${name}": expected YYYY-MM-DD, got "${value}"`);
  }
  const ms = Date.parse(`${value}T00:00:00Z`);
  if (Number.isNaN(ms)) {
    throw new Error(`invalid ${field} for "${name}": "${value}" is not a real calendar date`);
  }
  return ms;
}

function toIsoDay(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

// Floor-divided whole-day diff between two UTC timestamps. We deliberately
// normalize `now` to midnight UTC so that "today" always counts as 0 days.
function wholeDaysBetween(fromMs: number, toMs: number): number {
  const fromDay = Math.floor(fromMs / MS_PER_DAY);
  const toDay = Math.floor(toMs / MS_PER_DAY);
  return toDay - fromDay;
}

export function classifySecret(secret: Secret, opts: EvalOptions): SecretStatus {
  return evaluate(secret, opts).status;
}

function evaluate(secret: Secret, opts: EvalOptions): EvaluatedSecret {
  if (!Number.isInteger(secret.rotationPolicyDays) || secret.rotationPolicyDays <= 0) {
    throw new Error(
      `rotationPolicyDays must be a positive integer for "${secret.name}" (got ${secret.rotationPolicyDays})`,
    );
  }
  if (opts.warningDays < 0 || !Number.isFinite(opts.warningDays)) {
    throw new Error(`warningDays must be a non-negative finite number (got ${opts.warningDays})`);
  }

  const rotatedMs = parseIsoDay(secret.lastRotated, "lastRotated", secret.name);
  const expiresMs = rotatedMs + secret.rotationPolicyDays * MS_PER_DAY;
  const nowMs = opts.now.getTime();
  const daysUntilExpiry = wholeDaysBetween(nowMs, expiresMs);

  let status: SecretStatus;
  if (daysUntilExpiry < 0) status = "expired";
  else if (daysUntilExpiry <= opts.warningDays) status = "warning";
  else status = "ok";

  return {
    ...secret,
    expiresOn: toIsoDay(expiresMs),
    daysUntilExpiry,
    status,
  };
}

export function validateSecrets(secrets: Secret[], opts: EvalOptions): ValidationReport {
  // Catch duplicate names up-front so ambiguous reports never reach the user.
  const seen = new Set<string>();
  for (const s of secrets) {
    if (seen.has(s.name)) throw new Error(`duplicate secret name: "${s.name}"`);
    seen.add(s.name);
  }

  const evaluated = secrets.map((s) => evaluate(s, opts));

  // Stable, deterministic sort: most-overdue first within each group; ties by name.
  const byUrgency = (a: EvaluatedSecret, b: EvaluatedSecret) =>
    a.daysUntilExpiry - b.daysUntilExpiry || a.name.localeCompare(b.name);

  const expired = evaluated.filter((s) => s.status === "expired").sort(byUrgency);
  const warning = evaluated.filter((s) => s.status === "warning").sort(byUrgency);
  const ok = evaluated.filter((s) => s.status === "ok").sort(byUrgency);

  return {
    generatedAt: opts.now.toISOString(),
    warningDays: opts.warningDays,
    totals: {
      expired: expired.length,
      warning: warning.length,
      ok: ok.length,
      total: evaluated.length,
    },
    expired,
    warning,
    ok,
  };
}

function renderGroup(title: string, rows: EvaluatedSecret[]): string {
  const lines: string[] = [];
  lines.push(`## ${title} (${rows.length})`);
  lines.push("");
  lines.push("| Name | Last Rotated | Policy (days) | Expires On | Days Left | Required By |");
  lines.push("| --- | --- | --- | --- | --- | --- |");
  if (rows.length === 0) {
    lines.push("| _(none)_ |  |  |  |  |  |");
  } else {
    for (const r of rows) {
      const required = r.requiredBy.length > 0 ? r.requiredBy.join(", ") : "-";
      lines.push(
        `| ${r.name} | ${r.lastRotated} | ${r.rotationPolicyDays} | ${r.expiresOn} | ${r.daysUntilExpiry} | ${required} |`,
      );
    }
  }
  lines.push("");
  return lines.join("\n");
}

export function renderReport(report: ValidationReport, format: OutputFormat): string {
  if (format === "json") return JSON.stringify(report, null, 2);
  if (format === "markdown") {
    const { totals } = report;
    const header = [
      "# Secret Rotation Report",
      "",
      `Generated: ${report.generatedAt}`,
      `Warning window: ${report.warningDays} days`,
      `Totals: ${totals.expired} expired, ${totals.warning} warning, ${totals.ok} ok (${totals.total} total)`,
      "",
    ].join("\n");
    return [
      header,
      renderGroup("Expired", report.expired),
      renderGroup("Warning", report.warning),
      renderGroup("OK", report.ok),
    ].join("\n");
  }
  throw new Error(`unknown format: ${format}`);
}

// ---- Config loading ------------------------------------------------------

function assertSecretShape(raw: unknown, index: number): Secret {
  if (typeof raw !== "object" || raw === null) {
    throw new Error(`config entry #${index} is not an object`);
  }
  const obj = raw as Record<string, unknown>;
  const required = ["name", "lastRotated", "rotationPolicyDays", "requiredBy"] as const;
  for (const key of required) {
    if (!(key in obj)) throw new Error(`config entry #${index}: missing required field "${key}"`);
  }
  if (typeof obj.name !== "string" || obj.name.length === 0) {
    throw new Error(`config entry #${index}: "name" must be a non-empty string`);
  }
  if (typeof obj.lastRotated !== "string") {
    throw new Error(`config entry #${index}: "lastRotated" must be a string`);
  }
  if (typeof obj.rotationPolicyDays !== "number") {
    throw new Error(`config entry #${index}: "rotationPolicyDays" must be a number`);
  }
  if (!Array.isArray(obj.requiredBy) || obj.requiredBy.some((x) => typeof x !== "string")) {
    throw new Error(`config entry #${index}: "requiredBy" must be a string[]`);
  }
  return {
    name: obj.name,
    lastRotated: obj.lastRotated,
    rotationPolicyDays: obj.rotationPolicyDays,
    requiredBy: obj.requiredBy as string[],
  };
}

export async function loadConfig(path: string): Promise<Secret[]> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`config file not found: ${path}`);
  }
  const text = await file.text();
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`failed to parse config ${path}: ${msg}`);
  }
  // Support either { secrets: [...] } or a bare array.
  const list: unknown = Array.isArray(parsed)
    ? parsed
    : (parsed as { secrets?: unknown })?.secrets;
  if (!Array.isArray(list)) {
    throw new Error(`failed to parse config ${path}: expected array or { secrets: [...] }`);
  }
  return list.map(assertSecretShape);
}
