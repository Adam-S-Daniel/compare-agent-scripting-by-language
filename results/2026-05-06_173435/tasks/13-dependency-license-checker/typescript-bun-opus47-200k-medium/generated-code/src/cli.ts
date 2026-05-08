#!/usr/bin/env bun
// CLI entry point. Wires file I/O around the pure pieces in parser/checker/report.
//
// Usage:
//   bun run src/cli.ts --manifest <path> --policy <path> [--mock-licenses <path>]
//
// `--mock-licenses` points at a JSON object mapping dependency names to license
// strings (or null). It exists so the script is testable without hitting a real
// registry; in production you would swap it for an HTTP-backed lookup.
//
// Exit codes:
//   0  every dependency is approved
//   1  at least one denied or unknown dependency (compliance failure)
//   2  invalid usage / I/O error

import { parseManifest } from "./parser.ts";
import { checkDependencies, type LicenseLookup, type PolicyConfig } from "./checker.ts";
import { formatReport, summarize } from "./report.ts";

interface Args {
  manifest?: string;
  policy?: string;
  mockLicenses?: string;
}

function parseArgs(argv: string[]): Args {
  const args: Args = {};
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    const next = argv[i + 1];
    if (flag === "--manifest") { args.manifest = next; i++; }
    else if (flag === "--policy") { args.policy = next; i++; }
    else if (flag === "--mock-licenses") { args.mockLicenses = next; i++; }
    else if (flag === "--help" || flag === "-h") { /* handled in main */ }
    else throw new Error(`Unknown argument: ${flag}`);
  }
  return args;
}

function makeMockLookup(path: string): LicenseLookup {
  const raw = Bun.file(path);
  // Read synchronously up-front so an invalid mock fails fast.
  const text = require("node:fs").readFileSync(path, "utf8");
  void raw;
  const map = JSON.parse(text) as Record<string, string | null>;
  return async (name) => (name in map ? map[name] : null);
}

async function main(): Promise<number> {
  let args: Args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (err) {
    process.stderr.write(`Error: ${(err as Error).message}\n`);
    return 2;
  }
  if (!args.manifest) {
    process.stderr.write("Error: --manifest <path> is required\n");
    return 2;
  }
  if (!args.policy) {
    process.stderr.write("Error: --policy <path> is required\n");
    return 2;
  }

  let manifestText: string;
  let policy: PolicyConfig;
  try {
    manifestText = await Bun.file(args.manifest).text();
    const policyText = await Bun.file(args.policy).text();
    policy = JSON.parse(policyText) as PolicyConfig;
  } catch (err) {
    process.stderr.write(`Error reading inputs: ${(err as Error).message}\n`);
    return 2;
  }

  const deps = parseManifest(args.manifest, manifestText);

  // Mock lookup is the only one we ship; production would inject a real one.
  const lookup: LicenseLookup = args.mockLicenses
    ? makeMockLookup(args.mockLicenses)
    : async () => null;

  const report = await checkDependencies(deps, policy, lookup);
  process.stdout.write(formatReport(report) + "\n");

  const s = summarize(report);
  return s.denied === 0 && s.unknown === 0 ? 0 : 1;
}

const code = await main();
process.exit(code);
