// CLI entry point.
//
// Usage:
//   bun run src/cli.ts \
//     --manifest <path> --config <path> [--licenses <path>] [--allow-unknown]
//
// Exit codes (chosen so a CI pipeline can distinguish failure modes):
//   0  all dependencies approved (or unknown allowed via --allow-unknown)
//   1  at least one denied license
//   2  at least one unknown license (default strict mode)
//   3  input error (missing/invalid file)

import { readFileSync } from "node:fs";
import { parseManifest } from "./parse.ts";
import { checkCompliance, type LicenseConfig, type LicenseLookup } from "./compliance.ts";
import { formatReport, summarize } from "./report.ts";

interface CliArgs {
  manifest: string;
  config: string;
  licenses: string | null;
  allowUnknown: boolean;
}

function parseArgs(argv: string[]): CliArgs {
  const args: Partial<CliArgs> = { allowUnknown: false, licenses: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case "--manifest": args.manifest = argv[++i]; break;
      case "--config": args.config = argv[++i]; break;
      case "--licenses": args.licenses = argv[++i]; break;
      case "--allow-unknown": args.allowUnknown = true; break;
      default:
        throw new Error(`Unknown argument: ${a}`);
    }
  }
  if (!args.manifest) throw new Error("--manifest is required");
  if (!args.config) throw new Error("--config is required");
  return args as CliArgs;
}

function readJson<T>(path: string, label: string): T {
  let raw: string;
  try {
    raw = readFileSync(path, "utf8");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new InputError(`Could not read ${label} at ${path}: ${msg}`);
  }
  try {
    return JSON.parse(raw) as T;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new InputError(`Could not parse ${label} at ${path}: ${msg}`);
  }
}

class InputError extends Error {}

// Build a lookup from a static JSON map (the "mock" the task asks for). Keeping
// the lookup function pluggable means production callers could swap in a
// registry-backed implementation without touching the engine.
function buildLookup(table: Record<string, string>): LicenseLookup {
  return async ({ name }) => (name in table ? table[name] : null);
}

async function main(argv: string[]): Promise<number> {
  let args: CliArgs;
  try {
    args = parseArgs(argv);
  } catch (err) {
    process.stderr.write(`error: ${(err as Error).message}\n`);
    return 3;
  }

  let manifestText: string;
  try {
    manifestText = readFileSync(args.manifest, "utf8");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    process.stderr.write(`error: Could not read manifest at ${args.manifest}: ${msg}\n`);
    return 3;
  }

  let config: LicenseConfig;
  let licenseTable: Record<string, string> = {};
  try {
    config = readJson<LicenseConfig>(args.config, "config");
    if (args.licenses) {
      licenseTable = readJson<Record<string, string>>(args.licenses, "licenses");
    }
  } catch (err) {
    if (err instanceof InputError) {
      process.stderr.write(`error: ${err.message}\n`);
      return 3;
    }
    throw err;
  }

  const deps = parseManifest(args.manifest, manifestText);
  const report = await checkCompliance(deps, buildLookup(licenseTable), config);
  const text = formatReport(report);
  process.stdout.write(text + "\n");

  const s = summarize(report);
  if (s.denied > 0) return 1;
  if (s.unknown > 0 && !args.allowUnknown) return 2;
  return 0;
}

const code = await main(process.argv.slice(2));
process.exit(code);
