// Secret rotation validator core logic.
//
// Inputs are mock JSON describing secrets. We compute days until each secret's
// next rotation deadline relative to a `now` timestamp, classify into
// expired / warning / ok buckets, and render reports as JSON or markdown.

export type Urgency = "expired" | "warning" | "ok";

export interface Secret {
  name: string;
  lastRotated: string; // ISO date (YYYY-MM-DD)
  rotationDays: number;
  services: string[];
}

export interface ClassifiedSecret {
  secret: Secret;
  dueDate: string; // ISO date
  daysUntilDue: number; // negative => overdue
  urgency: Urgency;
}

export interface Report {
  generatedAt: string;
  warningWindowDays: number;
  expired: ClassifiedSecret[];
  warning: ClassifiedSecret[];
  ok: ClassifiedSecret[];
  summary: { total: number; expired: number; warning: number; ok: number };
}

const MS_PER_DAY = 86_400_000;

function parseDate(iso: string, field: string, secretName: string): Date {
  const d = new Date(iso + "T00:00:00Z");
  if (Number.isNaN(d.getTime())) {
    throw new Error(
      `Secret "${secretName}" has invalid ${field}: "${iso}" (expected YYYY-MM-DD)`,
    );
  }
  return d;
}

function toIso(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function classifySecret(
  secret: Secret,
  now: Date,
  warningWindowDays: number,
): ClassifiedSecret {
  const last = parseDate(secret.lastRotated, "lastRotated", secret.name);
  const due = new Date(last.getTime() + secret.rotationDays * MS_PER_DAY);
  // Compare on whole UTC days so timezone of `now` doesn't matter.
  const nowDay = Math.floor(now.getTime() / MS_PER_DAY);
  const dueDay = Math.floor(due.getTime() / MS_PER_DAY);
  const daysUntilDue = dueDay - nowDay;

  let urgency: Urgency;
  if (daysUntilDue < 0) urgency = "expired";
  else if (daysUntilDue <= warningWindowDays) urgency = "warning";
  else urgency = "ok";

  return { secret, dueDate: toIso(due), daysUntilDue, urgency };
}

export function parseSecrets(jsonText: string): Secret[] {
  let data: unknown;
  try {
    data = JSON.parse(jsonText);
  } catch (err) {
    throw new Error(
      `Failed to parse config JSON: ${(err as Error).message}`,
    );
  }
  if (
    typeof data !== "object" || data === null ||
    !("secrets" in data) || !Array.isArray((data as { secrets: unknown }).secrets)
  ) {
    throw new Error(`Config must have shape { "secrets": [...] }`);
  }
  const out: Secret[] = [];
  for (const [i, raw] of (data as { secrets: unknown[] }).secrets.entries()) {
    if (typeof raw !== "object" || raw === null) {
      throw new Error(`secrets[${i}] must be an object`);
    }
    const r = raw as Record<string, unknown>;
    const name = r.name;
    const lastRotated = r.lastRotated;
    const rotationDays = r.rotationDays;
    const services = r.services;
    if (typeof name !== "string") {
      throw new Error(`secrets[${i}].name must be a string`);
    }
    if (typeof lastRotated !== "string") {
      throw new Error(`Secret "${name}" missing lastRotated (string YYYY-MM-DD)`);
    }
    if (typeof rotationDays !== "number" || rotationDays <= 0) {
      throw new Error(`Secret "${name}" missing rotationDays (positive number)`);
    }
    if (!Array.isArray(services) || !services.every((s) => typeof s === "string")) {
      throw new Error(`Secret "${name}" services must be an array of strings`);
    }
    out.push({ name, lastRotated, rotationDays, services: services as string[] });
  }
  return out;
}

export function generateReport(
  secrets: Secret[],
  now: Date,
  warningWindowDays: number,
): Report {
  const classified = secrets.map((s) => classifySecret(s, now, warningWindowDays));
  const expired = classified.filter((c) => c.urgency === "expired")
    .sort((a, b) => a.daysUntilDue - b.daysUntilDue);
  const warning = classified.filter((c) => c.urgency === "warning")
    .sort((a, b) => a.daysUntilDue - b.daysUntilDue);
  const ok = classified.filter((c) => c.urgency === "ok")
    .sort((a, b) => a.daysUntilDue - b.daysUntilDue);
  return {
    generatedAt: now.toISOString(),
    warningWindowDays,
    expired,
    warning,
    ok,
    summary: {
      total: secrets.length,
      expired: expired.length,
      warning: warning.length,
      ok: ok.length,
    },
  };
}

export function formatJson(report: Report): string {
  return JSON.stringify(report, null, 2);
}

function mdRow(cells: (string | number)[]): string {
  return `| ${cells.join(" | ")} |`;
}

export function formatMarkdown(report: Report): string {
  const lines: string[] = [];
  lines.push("# Secret Rotation Report");
  lines.push("");
  lines.push(`Generated: ${report.generatedAt}`);
  lines.push(`Warning window: ${report.warningWindowDays} day(s)`);
  lines.push("");
  lines.push(
    `Summary: total=${report.summary.total} expired=${report.summary.expired} ` +
      `warning=${report.summary.warning} ok=${report.summary.ok}`,
  );
  lines.push("");

  // Expired section: shows days overdue.
  lines.push("## Expired");
  if (report.expired.length === 0) {
    lines.push("_None_");
  } else {
    lines.push("| Secret | Last Rotated | Days Overdue | Services |");
    lines.push("| --- | --- | --- | --- |");
    for (const c of report.expired) {
      lines.push(
        mdRow([
          c.secret.name,
          c.secret.lastRotated,
          -c.daysUntilDue,
          c.secret.services.join(", "),
        ]),
      );
    }
  }
  lines.push("");

  // Warning section.
  lines.push("## Warning");
  if (report.warning.length === 0) {
    lines.push("_None_");
  } else {
    lines.push("| Secret | Last Rotated | Days Until Due | Services |");
    lines.push("| --- | --- | --- | --- |");
    for (const c of report.warning) {
      lines.push(
        mdRow([
          c.secret.name,
          c.secret.lastRotated,
          c.daysUntilDue,
          c.secret.services.join(", "),
        ]),
      );
    }
  }
  lines.push("");

  // OK section.
  lines.push("## OK");
  if (report.ok.length === 0) {
    lines.push("_None_");
  } else {
    lines.push("| Secret | Last Rotated | Days Until Due | Services |");
    lines.push("| --- | --- | --- | --- |");
    for (const c of report.ok) {
      lines.push(
        mdRow([
          c.secret.name,
          c.secret.lastRotated,
          c.daysUntilDue,
          c.secret.services.join(", "),
        ]),
      );
    }
  }
  lines.push("");

  return lines.join("\n");
}
