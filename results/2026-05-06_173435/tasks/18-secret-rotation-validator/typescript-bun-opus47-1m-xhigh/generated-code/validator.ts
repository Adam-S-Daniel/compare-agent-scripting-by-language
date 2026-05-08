#!/usr/bin/env bun
// Secret Rotation Validator
//
// Reads a JSON file describing secrets (name, last-rotated date, rotation
// policy in days, required-by services), classifies each into one of three
// urgency buckets (expired, warning, ok), and emits a rotation report in
// either markdown or JSON.
//
// CLI:
//   bun run validator.ts \
//     --secrets <path>        (required)  path to a JSON array of secrets
//     --warning-days <N>      (optional)  warning window in days, default 14
//     --format <markdown|json>(optional)  output format, default 'markdown'
//     --now <ISO timestamp>   (optional)  override "now" for deterministic output
//
// Exit codes:
//   0  success
//   1  invalid arguments / unreadable input / malformed config

import { readFileSync, existsSync } from 'node:fs';

export interface Secret {
  name: string;
  lastRotated: string;
  rotationPolicyDays: number;
  requiredBy: string[];
}

export type Status = 'expired' | 'warning' | 'ok';

export interface ClassifiedSecret {
  name: string;
  lastRotated: string;
  rotationPolicyDays: number;
  requiredBy: string[];
  status: Status;
  expiresAt: string;
  daysUntilExpiry: number;
}

export interface Totals {
  expired: number;
  warning: number;
  ok: number;
}

export interface Report {
  generatedAt: string;
  warningWindowDays: number;
  totals: Totals;
  expired: ClassifiedSecret[];
  warning: ClassifiedSecret[];
  ok: ClassifiedSecret[];
}

const MS_PER_DAY = 86_400_000;

// Validate a single record from the secrets file. Throws on malformed input
// so the CLI surfaces a useful message rather than failing further downstream.
export function validateSecret(raw: unknown, idx: number): Secret {
  if (typeof raw !== 'object' || raw === null) {
    throw new Error(`Secret at index ${idx} must be an object`);
  }
  const r = raw as Record<string, unknown>;
  if (typeof r.name !== 'string' || r.name.length === 0) {
    throw new Error(`Secret at index ${idx} is missing a non-empty 'name' string`);
  }
  if (typeof r.lastRotated !== 'string') {
    throw new Error(`Secret '${r.name}' is missing a 'lastRotated' string (ISO date)`);
  }
  const parsed = new Date(r.lastRotated);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Secret '${r.name}' has invalid 'lastRotated' value: ${r.lastRotated}`);
  }
  if (typeof r.rotationPolicyDays !== 'number' || !Number.isFinite(r.rotationPolicyDays) || r.rotationPolicyDays <= 0) {
    throw new Error(`Secret '${r.name}' must have a positive numeric 'rotationPolicyDays'`);
  }
  if (!Array.isArray(r.requiredBy) || !r.requiredBy.every((s) => typeof s === 'string')) {
    throw new Error(`Secret '${r.name}' must have a 'requiredBy' array of service names`);
  }
  return {
    name: r.name,
    lastRotated: r.lastRotated,
    rotationPolicyDays: r.rotationPolicyDays,
    requiredBy: r.requiredBy as string[],
  };
}

// Compute expiration metadata for a single secret. Floor on the day diff so
// "any leftover hours" still count as 'today' until we tip over midnight.
export function classifySecret(
  secret: Secret,
  now: Date,
  warningDays: number,
): ClassifiedSecret {
  const lastRotatedMs = new Date(secret.lastRotated).getTime();
  const expiresAtMs = lastRotatedMs + secret.rotationPolicyDays * MS_PER_DAY;
  const daysUntilExpiry = Math.floor((expiresAtMs - now.getTime()) / MS_PER_DAY);

  let status: Status;
  if (daysUntilExpiry < 0) status = 'expired';
  else if (daysUntilExpiry <= warningDays) status = 'warning';
  else status = 'ok';

  return {
    name: secret.name,
    lastRotated: secret.lastRotated,
    rotationPolicyDays: secret.rotationPolicyDays,
    requiredBy: secret.requiredBy,
    status,
    expiresAt: new Date(expiresAtMs).toISOString(),
    daysUntilExpiry,
  };
}

// Sort by urgency (most-expired/soonest first), then by name for stable output.
function sortClassified(arr: ClassifiedSecret[]): ClassifiedSecret[] {
  return arr.slice().sort((a, b) => {
    if (a.daysUntilExpiry !== b.daysUntilExpiry) {
      return a.daysUntilExpiry - b.daysUntilExpiry;
    }
    return a.name.localeCompare(b.name);
  });
}

export function buildReport(secrets: Secret[], now: Date, warningDays: number): Report {
  const classified = secrets.map((s) => classifySecret(s, now, warningDays));
  const expired = sortClassified(classified.filter((s) => s.status === 'expired'));
  const warning = sortClassified(classified.filter((s) => s.status === 'warning'));
  const ok = sortClassified(classified.filter((s) => s.status === 'ok'));
  return {
    generatedAt: now.toISOString(),
    warningWindowDays: warningDays,
    totals: { expired: expired.length, warning: warning.length, ok: ok.length },
    expired,
    warning,
    ok,
  };
}

export function renderJson(report: Report): string {
  return JSON.stringify(report, null, 2);
}

export function renderMarkdown(report: Report): string {
  const lines: string[] = [];
  lines.push('# Secret Rotation Report');
  lines.push('');
  lines.push(`- Generated: ${report.generatedAt}`);
  lines.push(`- Warning window: ${report.warningWindowDays} days`);
  lines.push('');
  lines.push('## Summary');
  lines.push('');
  lines.push('| Status | Count |');
  lines.push('| --- | --- |');
  lines.push(`| Expired | ${report.totals.expired} |`);
  lines.push(`| Warning | ${report.totals.warning} |`);
  lines.push(`| OK | ${report.totals.ok} |`);
  lines.push('');

  // Expired table uses "Days Overdue" (positive) for human readability.
  lines.push(`## Expired (${report.totals.expired})`);
  lines.push('');
  if (report.expired.length === 0) {
    lines.push('_None_');
  } else {
    lines.push('| Secret | Last Rotated | Policy (days) | Days Overdue | Required By |');
    lines.push('| --- | --- | --- | --- | --- |');
    for (const s of report.expired) {
      lines.push(
        `| ${s.name} | ${s.lastRotated} | ${s.rotationPolicyDays} | ${-s.daysUntilExpiry} | ${s.requiredBy.join(', ')} |`,
      );
    }
  }
  lines.push('');

  lines.push(`## Warning (${report.totals.warning})`);
  lines.push('');
  if (report.warning.length === 0) {
    lines.push('_None_');
  } else {
    lines.push('| Secret | Last Rotated | Policy (days) | Days Until Expiry | Required By |');
    lines.push('| --- | --- | --- | --- | --- |');
    for (const s of report.warning) {
      lines.push(
        `| ${s.name} | ${s.lastRotated} | ${s.rotationPolicyDays} | ${s.daysUntilExpiry} | ${s.requiredBy.join(', ')} |`,
      );
    }
  }
  lines.push('');

  lines.push(`## OK (${report.totals.ok})`);
  lines.push('');
  if (report.ok.length === 0) {
    lines.push('_None_');
  } else {
    lines.push('| Secret | Last Rotated | Policy (days) | Days Until Expiry | Required By |');
    lines.push('| --- | --- | --- | --- | --- |');
    for (const s of report.ok) {
      lines.push(
        `| ${s.name} | ${s.lastRotated} | ${s.rotationPolicyDays} | ${s.daysUntilExpiry} | ${s.requiredBy.join(', ')} |`,
      );
    }
  }

  return lines.join('\n');
}

export interface CliArgs {
  secretsPath: string;
  warningDays: number;
  format: 'markdown' | 'json';
  now: string | undefined;
}

export function parseArgs(argv: string[]): CliArgs {
  let secretsPath: string | undefined;
  let warningDays = 14;
  let format: 'markdown' | 'json' = 'markdown';
  let now: string | undefined;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const requireValue = (): string => {
      if (i + 1 >= argv.length) throw new Error(`Missing value for ${arg}`);
      return argv[++i]!;
    };
    switch (arg) {
      case '--secrets':
        secretsPath = requireValue();
        break;
      case '--warning-days': {
        const v = requireValue();
        const n = Number.parseInt(v, 10);
        if (Number.isNaN(n) || n < 0 || String(n) !== v) {
          throw new Error(`Invalid --warning-days value '${v}': must be a non-negative integer`);
        }
        warningDays = n;
        break;
      }
      case '--format': {
        const v = requireValue();
        if (v !== 'markdown' && v !== 'json') {
          throw new Error(`Invalid --format value '${v}': must be 'markdown' or 'json'`);
        }
        format = v;
        break;
      }
      case '--now':
        now = requireValue();
        break;
      case '--help':
      case '-h':
        printHelp();
        process.exit(0);
      // eslint-disable-next-line no-fallthrough
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!secretsPath) {
    throw new Error("Missing required argument --secrets <path>");
  }
  return { secretsPath, warningDays, format, now };
}

function printHelp(): void {
  console.log(`Usage: bun run validator.ts --secrets <path> [options]

Options:
  --secrets <path>          Path to a JSON array of secret records (required)
  --warning-days <N>        Warning window in days (default 14)
  --format <markdown|json>  Output format (default markdown)
  --now <ISO timestamp>     Override the current time, useful in tests
  --help                    Show this help`);
}

export function loadSecrets(secretsPath: string): Secret[] {
  if (!existsSync(secretsPath)) {
    throw new Error(`Secrets file not found: ${secretsPath}`);
  }
  let raw: string;
  try {
    raw = readFileSync(secretsPath, 'utf8');
  } catch (e) {
    throw new Error(`Failed to read secrets file ${secretsPath}: ${(e as Error).message}`);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    throw new Error(`Failed to parse JSON in ${secretsPath}: ${(e as Error).message}`);
  }
  if (!Array.isArray(parsed)) {
    throw new Error(`Secrets file ${secretsPath} must contain a JSON array, got ${typeof parsed}`);
  }
  return parsed.map((s, idx) => validateSecret(s, idx));
}

export function run(argv: string[]): { stdout: string; exitCode: number } {
  try {
    const args = parseArgs(argv);
    const secrets = loadSecrets(args.secretsPath);
    const now = args.now ? new Date(args.now) : new Date();
    if (Number.isNaN(now.getTime())) {
      throw new Error(`Invalid --now value: ${args.now}`);
    }
    const report = buildReport(secrets, now, args.warningDays);
    const output = args.format === 'json' ? renderJson(report) : renderMarkdown(report);
    return { stdout: output, exitCode: 0 };
  } catch (e) {
    const msg = (e as Error).message ?? String(e);
    return { stdout: `Error: ${msg}`, exitCode: 1 };
  }
}

// CLI entry point — only fires when this file is executed directly, not when
// it's imported (e.g. by tests in another file).
if (import.meta.main) {
  const { stdout, exitCode } = run(process.argv.slice(2));
  if (exitCode === 0) {
    console.log(stdout);
  } else {
    console.error(stdout);
  }
  process.exit(exitCode);
}
