// Command-line entry point. Reads a manifest + license config, writes a report to stdout.
// Usage: bun run src/cli.ts --manifest <path> --config <path> [--licenses <path>]
// The optional --licenses file is a JSON map {depName: license} used as a mock lookup
// source (avoids network calls in CI). If omitted we treat all licenses as unknown.
import { readFileSync, existsSync } from "node:fs";
import { basename } from "node:path";
import {
  parseManifest,
  checkDependencies,
  generateReport,
  type LicenseConfig,
  type LicenseLookup,
  type Dependency,
} from "./checker.ts";

interface Args {
  manifest: string;
  config: string;
  licenses?: string;
}

function parseArgs(argv: string[]): Args {
  const out: Partial<Args> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--manifest") out.manifest = argv[++i];
    else if (a === "--config") out.config = argv[++i];
    else if (a === "--licenses") out.licenses = argv[++i];
  }
  if (!out.manifest || !out.config) {
    throw new Error(
      "Usage: cli.ts --manifest <file> --config <license-config.json> [--licenses <mock.json>]",
    );
  }
  return out as Args;
}

function loadJson<T>(path: string): T {
  if (!existsSync(path)) {
    throw new Error(`File not found: ${path}`);
  }
  try {
    return JSON.parse(readFileSync(path, "utf8")) as T;
  } catch (err) {
    throw new Error(`Failed to read JSON ${path}: ${(err as Error).message}`);
  }
}

async function main(): Promise<number> {
  const args = parseArgs(process.argv.slice(2));
  const manifestContent = readFileSync(args.manifest, "utf8");
  const deps = parseManifest(manifestContent, basename(args.manifest));
  const config = loadJson<LicenseConfig>(args.config);

  // Mock license lookup backed by a JSON map supplied by the caller (or empty).
  const table: Record<string, string> = args.licenses
    ? loadJson<Record<string, string>>(args.licenses)
    : {};
  const lookup: LicenseLookup = async (dep: Dependency) => table[dep.name];

  const entries = await checkDependencies(deps, config, lookup);
  const report = generateReport(entries);
  console.log(report);

  // Exit non-zero if any denied dependencies are found, so CI fails loudly.
  const hasDenied = entries.some((e) => e.status === "denied");
  return hasDenied ? 2 : 0;
}

main()
  .then((code) => process.exit(code))
  .catch((err: Error) => {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  });
