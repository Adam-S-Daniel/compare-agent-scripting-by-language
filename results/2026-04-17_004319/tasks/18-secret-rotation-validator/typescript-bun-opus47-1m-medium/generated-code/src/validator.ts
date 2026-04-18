// Secret rotation validator — pure functions. The CLI wraps these.
// Classification uses whole-day math against a reference `now` so results
// are deterministic (and testable) regardless of wall-clock time.

export interface Secret {
  name: string;
  lastRotated: string; // YYYY-MM-DD
  rotationPolicyDays: number;
  requiredBy: string[];
}

export type Urgency = "expired" | "warning" | "ok";

export interface ReportEntry extends Secret {
  ageDays: number;
  daysUntilExpiry: number; // negative = past due
  status: Urgency;
}

export interface Report {
  generatedAt: string;
  warningWindowDays: number;
  expired: ReportEntry[];
  warning: ReportEntry[];
  ok: ReportEntry[];
}

const DAY_MS = 86_400_000;

function parseDate(iso: string): Date {
  // Accept YYYY-MM-DD; normalize to UTC midnight.
  const d = new Date(`${iso}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) throw new Error(`invalid date: ${iso}`);
  return d;
}

function diffDays(a: Date, b: Date): number {
  return Math.floor((a.getTime() - b.getTime()) / DAY_MS);
}

export function classify(secret: Secret, now: Date, warningDays: number): ReportEntry {
  const lastRotated = parseDate(secret.lastRotated);
  const ageDays = diffDays(now, lastRotated);
  const daysUntilExpiry = secret.rotationPolicyDays - ageDays;

  let status: Urgency;
  if (daysUntilExpiry <= 0) status = "expired";
  else if (daysUntilExpiry <= warningDays) status = "warning";
  else status = "ok";

  return { ...secret, ageDays, daysUntilExpiry, status };
}

export function generateReport(
  secrets: Secret[],
  now: Date,
  warningDays: number,
): Report {
  const classified = secrets.map((s) => classify(s, now, warningDays));
  const expired = classified
    .filter((e) => e.status === "expired")
    .sort((a, b) => a.daysUntilExpiry - b.daysUntilExpiry); // most overdue first
  const warning = classified
    .filter((e) => e.status === "warning")
    .sort((a, b) => a.daysUntilExpiry - b.daysUntilExpiry);
  const ok = classified
    .filter((e) => e.status === "ok")
    .sort((a, b) => a.daysUntilExpiry - b.daysUntilExpiry);

  return {
    generatedAt: now.toISOString(),
    warningWindowDays: warningDays,
    expired,
    warning,
    ok,
  };
}

export function formatJson(r: Report): string {
  return JSON.stringify(
    {
      generatedAt: r.generatedAt,
      warningWindowDays: r.warningWindowDays,
      counts: { expired: r.expired.length, warning: r.warning.length, ok: r.ok.length },
      expired: r.expired,
      warning: r.warning,
      ok: r.ok,
    },
    null,
    2,
  );
}

function mdTable(entries: ReportEntry[]): string {
  if (entries.length === 0) return "_None_\n";
  const rows = entries.map(
    (e) =>
      `| ${e.name} | ${e.lastRotated} | ${e.rotationPolicyDays} | ${e.ageDays} | ${e.daysUntilExpiry} | ${e.requiredBy.join(", ") || "-"} |`,
  );
  return [
    "| Name | Last Rotated | Policy (days) | Age (days) | Days Until Expiry | Required By |",
    "| --- | --- | --- | --- | --- | --- |",
    ...rows,
    "",
  ].join("\n");
}

export function formatMarkdown(r: Report): string {
  return [
    "# Secret Rotation Report",
    `Generated: ${r.generatedAt}  |  Warning window: ${r.warningWindowDays} days`,
    "",
    `## Expired (${r.expired.length})`,
    mdTable(r.expired),
    `## Warning (${r.warning.length})`,
    mdTable(r.warning),
    `## OK (${r.ok.length})`,
    mdTable(r.ok),
  ].join("\n");
}

// Validate raw JSON config. We only accept what we understand — fail loudly
// otherwise so misconfigured fixtures don't silently slip through CI.
export function loadConfig(raw: string): Secret[] {
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed)) throw new Error("config root must be an array of secrets");
  return parsed.map((entry, i) => {
    const prefix = `secret[${i}]`;
    if (typeof entry.name !== "string") throw new Error(`${prefix}: missing 'name'`);
    if (typeof entry.lastRotated !== "string")
      throw new Error(`${prefix}: missing 'lastRotated'`);
    if (typeof entry.rotationPolicyDays !== "number")
      throw new Error(`${prefix}: missing 'rotationPolicyDays'`);
    if (!Array.isArray(entry.requiredBy))
      throw new Error(`${prefix}: 'requiredBy' must be an array`);
    // Validate date parses.
    parseDate(entry.lastRotated);
    return {
      name: entry.name,
      lastRotated: entry.lastRotated,
      rotationPolicyDays: entry.rotationPolicyDays,
      requiredBy: entry.requiredBy,
    };
  });
}
