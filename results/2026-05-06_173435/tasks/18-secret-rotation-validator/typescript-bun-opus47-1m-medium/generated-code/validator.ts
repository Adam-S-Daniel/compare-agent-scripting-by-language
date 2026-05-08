// Secret rotation validator: pure logic + a CLI entrypoint.
// Pure functions are exported for unit testing; the CLI is invoked when
// this file is the entrypoint (Bun.main === import.meta.path).

export interface Secret {
  name: string;
  lastRotated: string; // ISO date (YYYY-MM-DD)
  rotationPolicyDays: number;
  requiredBy: string[];
}

export type Status = "expired" | "warning" | "ok";

export interface ClassifiedSecret extends Secret {
  status: Status;
  ageDays: number;
  daysUntilDue: number; // negative => overdue
}

export interface Report {
  generatedAt: string;
  warningDays: number;
  summary: { expired: number; warning: number; ok: number; total: number };
  expired: ClassifiedSecret[];
  warning: ClassifiedSecret[];
  ok: ClassifiedSecret[];
}

const MS_PER_DAY = 86_400_000;

function diffDays(later: Date, earlier: Date): number {
  // Floor to whole days (UTC-stable since we feed UTC dates).
  return Math.floor((later.getTime() - earlier.getTime()) / MS_PER_DAY);
}

export function classifySecret(secret: Secret, now: Date, warningDays: number): ClassifiedSecret {
  if (!Number.isFinite(secret.rotationPolicyDays) || secret.rotationPolicyDays <= 0) {
    throw new Error(
      `Secret '${secret.name}': rotationPolicyDays must be a positive number, got ${secret.rotationPolicyDays}`,
    );
  }
  const last = new Date(secret.lastRotated);
  if (Number.isNaN(last.getTime())) {
    throw new Error(`Secret '${secret.name}': invalid lastRotated date '${secret.lastRotated}'`);
  }
  const ageDays = diffDays(now, last);
  const daysUntilDue = secret.rotationPolicyDays - ageDays;

  let status: Status;
  if (daysUntilDue < 0) status = "expired";
  else if (daysUntilDue <= warningDays) status = "warning";
  else status = "ok";

  return { ...secret, status, ageDays, daysUntilDue };
}

export interface GenerateOptions {
  now?: Date;
  warningDays: number;
}

export function generateReport(secrets: Secret[], opts: GenerateOptions): Report {
  const now = opts.now ?? new Date();
  const classified = secrets.map((s) => classifySecret(s, now, opts.warningDays));
  // Most urgent first within each bucket.
  classified.sort((a, b) => a.daysUntilDue - b.daysUntilDue);

  const expired = classified.filter((s) => s.status === "expired");
  const warning = classified.filter((s) => s.status === "warning");
  const ok = classified.filter((s) => s.status === "ok");

  return {
    generatedAt: now.toISOString(),
    warningDays: opts.warningDays,
    summary: {
      expired: expired.length,
      warning: warning.length,
      ok: ok.length,
      total: classified.length,
    },
    expired,
    warning,
    ok,
  };
}

export function formatJson(report: Report): string {
  return JSON.stringify(report, null, 2);
}

function renderTable(rows: ClassifiedSecret[]): string {
  if (rows.length === 0) return "_none_";
  const header =
    "| Name | Last Rotated | Policy (days) | Days Until Due | Required By |\n" +
    "| --- | --- | --- | --- | --- |";
  const body = rows
    .map(
      (r) =>
        `| ${r.name} | ${r.lastRotated} | ${r.rotationPolicyDays} | ${r.daysUntilDue} | ${r.requiredBy.join(", ")} |`,
    )
    .join("\n");
  return `${header}\n${body}`;
}

export function formatMarkdown(report: Report): string {
  const { summary } = report;
  return [
    "# Secret Rotation Report",
    "",
    `Generated: ${report.generatedAt}  `,
    `Warning window: ${report.warningDays} days  `,
    `Total secrets: ${summary.total} (expired: ${summary.expired}, warning: ${summary.warning}, ok: ${summary.ok})`,
    "",
    `## Expired (${summary.expired})`,
    "",
    renderTable(report.expired),
    "",
    `## Warning (${summary.warning})`,
    "",
    renderTable(report.warning),
    "",
    `## OK (${summary.ok})`,
    "",
    renderTable(report.ok),
    "",
  ].join("\n");
}

// ---------------- CLI ----------------

interface CliArgs {
  input: string;
  format: "markdown" | "json";
  warningDays: number;
  failOn: "never" | "expired" | "warning";
  now?: Date;
}

function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = { input: "", format: "markdown", warningDays: 7, failOn: "expired" };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => {
      const v = argv[++i];
      if (v === undefined) throw new Error(`Missing value for ${a}`);
      return v;
    };
    switch (a) {
      case "--input": args.input = next(); break;
      case "--format": {
        const v = next();
        if (v !== "markdown" && v !== "json") throw new Error(`Unknown format: ${v}`);
        args.format = v;
        break;
      }
      case "--warning-days": args.warningDays = Number(next()); break;
      case "--fail-on": {
        const v = next();
        if (v !== "never" && v !== "expired" && v !== "warning") {
          throw new Error(`Unknown --fail-on value: ${v}`);
        }
        args.failOn = v;
        break;
      }
      case "--now": args.now = new Date(next()); break;
      case "-h":
      case "--help":
        printHelp();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${a}`);
    }
  }
  if (!args.input) throw new Error("--input <path> is required");
  if (!Number.isFinite(args.warningDays) || args.warningDays < 0) {
    throw new Error(`--warning-days must be a non-negative number`);
  }
  return args;
}

function printHelp(): void {
  console.log(
    [
      "Usage: bun run validator.ts --input <secrets.json> [options]",
      "",
      "Options:",
      "  --input <path>          Path to secrets JSON config (required)",
      "  --format <markdown|json>  Output format (default: markdown)",
      "  --warning-days <n>      Days ahead to flag as warning (default: 7)",
      "  --fail-on <never|warning|expired>  Exit non-zero policy (default: expired)",
      "  --now <iso-date>        Override 'now' (for deterministic runs/tests)",
    ].join("\n"),
  );
}

function loadSecrets(path: string): Secret[] {
  let raw: string;
  try {
    raw = require("node:fs").readFileSync(path, "utf8");
  } catch (e) {
    throw new Error(`Failed to read secrets file '${path}': ${(e as Error).message}`);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    throw new Error(`Failed to parse JSON in '${path}': ${(e as Error).message}`);
  }
  if (!Array.isArray(parsed)) {
    throw new Error(`Expected top-level JSON array of secrets in '${path}'`);
  }
  return parsed.map((s, idx) => {
    const o = s as Partial<Secret>;
    if (typeof o.name !== "string") throw new Error(`secret[${idx}]: 'name' must be a string`);
    if (typeof o.lastRotated !== "string")
      throw new Error(`secret[${idx}] '${o.name}': 'lastRotated' must be a string`);
    if (typeof o.rotationPolicyDays !== "number")
      throw new Error(`secret[${idx}] '${o.name}': 'rotationPolicyDays' must be a number`);
    if (!Array.isArray(o.requiredBy) || !o.requiredBy.every((x) => typeof x === "string"))
      throw new Error(`secret[${idx}] '${o.name}': 'requiredBy' must be string[]`);
    return o as Secret;
  });
}

async function main(): Promise<void> {
  let args: CliArgs;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (e) {
    console.error(`error: ${(e as Error).message}`);
    printHelp();
    process.exit(2);
  }

  let secrets: Secret[];
  try {
    secrets = loadSecrets(args.input);
  } catch (e) {
    console.error(`error: ${(e as Error).message}`);
    process.exit(2);
  }

  let report: Report;
  try {
    report = generateReport(secrets, { warningDays: args.warningDays, now: args.now });
  } catch (e) {
    console.error(`error: ${(e as Error).message}`);
    process.exit(2);
  }

  console.log(args.format === "json" ? formatJson(report) : formatMarkdown(report));

  // Policy gate for CI use.
  if (args.failOn === "expired" && report.summary.expired > 0) process.exit(1);
  if (args.failOn === "warning" && (report.summary.expired > 0 || report.summary.warning > 0))
    process.exit(1);
}

if (import.meta.main) {
  await main();
}
