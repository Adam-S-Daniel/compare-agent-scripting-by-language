// CLI entry point: reads a JSON secrets config, writes a grouped rotation
// report in markdown or JSON. Exit code is non-zero when any secret is
// expired, making this safe to run as a CI gate.
import { readFileSync } from "node:fs";
import { validateSecrets, type Secret } from "./validator.ts";
import { renderJson, renderMarkdown } from "./report.ts";

interface CliOptions {
  input: string;
  format: "markdown" | "json";
  warningDays: number;
  now: Date;
  failOnExpired: boolean;
}

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = {
    input: "",
    format: "markdown",
    warningDays: 14,
    now: new Date(),
    failOnExpired: true,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const take = () => {
      const v = argv[++i];
      if (v === undefined) throw new Error(`missing value for ${a}`);
      return v;
    };
    switch (a) {
      case "--input":
      case "-i":
        opts.input = take();
        break;
      case "--format":
      case "-f": {
        const v = take();
        if (v !== "markdown" && v !== "json") {
          throw new Error(`--format must be markdown or json (got "${v}")`);
        }
        opts.format = v;
        break;
      }
      case "--warning-days":
      case "-w": {
        const v = Number(take());
        if (!Number.isFinite(v) || v < 0) {
          throw new Error("--warning-days must be a non-negative number");
        }
        opts.warningDays = v;
        break;
      }
      case "--now": {
        // Mostly for deterministic testing.
        const d = new Date(take());
        if (Number.isNaN(d.getTime())) throw new Error("invalid --now date");
        opts.now = d;
        break;
      }
      case "--no-fail-on-expired":
        opts.failOnExpired = false;
        break;
      case "--help":
      case "-h":
        printHelp();
        process.exit(0);
      default:
        throw new Error(`unknown argument: ${a}`);
    }
  }
  if (!opts.input) throw new Error("--input <path> is required");
  return opts;
}

function printHelp(): void {
  process.stdout.write(
    `Usage: bun run src/cli.ts --input <path> [options]\n\n` +
      `Options:\n` +
      `  --input, -i <path>        JSON file with secrets array (required)\n` +
      `  --format, -f <fmt>        markdown | json (default: markdown)\n` +
      `  --warning-days, -w <n>    warning window in days (default: 14)\n` +
      `  --now <iso>               override "now" for deterministic output\n` +
      `  --no-fail-on-expired      exit 0 even when secrets are expired\n` +
      `  --help, -h                show this help\n`,
  );
}

function loadSecrets(path: string): Secret[] {
  let raw: string;
  try {
    raw = readFileSync(path, "utf8");
  } catch (err) {
    throw new Error(`could not read input file "${path}": ${(err as Error).message}`);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    throw new Error(`input is not valid JSON: ${(err as Error).message}`);
  }
  if (!Array.isArray(parsed)) {
    throw new Error("input JSON must be an array of secret objects");
  }
  return parsed.map((item, idx) => {
    if (
      !item ||
      typeof item !== "object" ||
      typeof (item as any).name !== "string" ||
      typeof (item as any).lastRotated !== "string" ||
      typeof (item as any).rotationPolicyDays !== "number" ||
      !Array.isArray((item as any).requiredBy)
    ) {
      throw new Error(`secret at index ${idx} is missing required fields`);
    }
    return item as Secret;
  });
}

async function main(): Promise<void> {
  let opts: CliOptions;
  try {
    opts = parseArgs(Bun.argv.slice(2));
  } catch (err) {
    process.stderr.write(`error: ${(err as Error).message}\n`);
    printHelp();
    process.exit(2);
  }

  try {
    const secrets = loadSecrets(opts.input);
    const report = validateSecrets(secrets, {
      now: opts.now,
      warningDays: opts.warningDays,
    });
    const out = opts.format === "json" ? renderJson(report) : renderMarkdown(report);
    process.stdout.write(out);
    if (!out.endsWith("\n")) process.stdout.write("\n");
    if (opts.failOnExpired && report.summary.expired > 0) {
      process.stderr.write(
        `\n${report.summary.expired} secret(s) are expired. Rotate them immediately.\n`,
      );
      process.exit(1);
    }
  } catch (err) {
    process.stderr.write(`error: ${(err as Error).message}\n`);
    process.exit(2);
  }
}

await main();
