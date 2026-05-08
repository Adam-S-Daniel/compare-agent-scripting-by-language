// CLI entry point. Reads a manifest, a policy file (allow/deny), and an
// optional mock-license database, then writes a compliance report to stdout
// and exits non-zero if any denied or unknown licenses are present.
//
// Flags:
//   --manifest <path>    Manifest file to scan (package.json | requirements.txt)
//   --policy <path>      JSON file with { allow: string[], deny: string[] }
//   --licenses <path>    Optional JSON file mapping name -> SPDX license id.
//                        When omitted the lookup returns null (everything unknown).
//   --format text|json   Output format. Default: text.
//   --report-file <path> Optional file to also write the rendered report to.
//   --fail-on <levels>   Comma list of statuses that should fail the run.
//                        Default: "denied,unknown".

import { readFileSync, existsSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { parseManifest } from "./parser.ts";
import { checkDependencies, type LicenseLookup, type Policy, type Status } from "./checker.ts";
import { renderReport, summarize, type Format } from "./report.ts";

interface Args {
  manifest: string;
  policy: string;
  licenses?: string;
  format: Format;
  reportFile?: string;
  failOn: Set<Status>;
}

function parseArgs(argv: string[]): Args {
  const args: Partial<Args> & { failOnRaw?: string } = { format: "text" };
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    const value = argv[i + 1];
    switch (flag) {
      case "--manifest":
        args.manifest = value;
        i++;
        break;
      case "--policy":
        args.policy = value;
        i++;
        break;
      case "--licenses":
        args.licenses = value;
        i++;
        break;
      case "--format":
        if (value !== "text" && value !== "json") {
          throw new Error(`--format must be 'text' or 'json' (got '${value}')`);
        }
        args.format = value;
        i++;
        break;
      case "--report-file":
        args.reportFile = value;
        i++;
        break;
      case "--fail-on":
        args.failOnRaw = value;
        i++;
        break;
      default:
        throw new Error(`Unknown flag: ${flag}`);
    }
  }
  if (!args.manifest) throw new Error("--manifest is required");
  if (!args.policy) throw new Error("--policy is required");
  const failOn = new Set<Status>(
    (args.failOnRaw ?? "denied,unknown")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean) as Status[],
  );
  return {
    manifest: args.manifest!,
    policy: args.policy!,
    licenses: args.licenses,
    format: args.format!,
    reportFile: args.reportFile,
    failOn,
  };
}

function readJson<T>(path: string, label: string): T {
  if (!existsSync(path)) {
    throw new Error(`${label} file '${path}' not found`);
  }
  const text = readFileSync(path, "utf8");
  try {
    return JSON.parse(text) as T;
  } catch (err) {
    throw new Error(`${label} file '${path}' is not valid JSON: ${(err as Error).message}`);
  }
}

// Build the license lookup. We read the mock database eagerly so missing/
// malformed files fail fast, instead of failing per-dep at lookup time.
function buildLookup(licensesPath: string | undefined): LicenseLookup {
  if (!licensesPath) {
    return async () => null;
  }
  const table = readJson<Record<string, string | null>>(licensesPath, "Licenses");
  return async (name: string) => {
    if (!(name in table)) return null;
    return table[name] ?? null;
  };
}

async function main(argv: string[]): Promise<number> {
  const args = parseArgs(argv);
  const manifestPath = resolve(args.manifest);
  if (!existsSync(manifestPath)) {
    throw new Error(`manifest '${args.manifest}' not found`);
  }
  const manifestText = readFileSync(manifestPath, "utf8");
  const policy = readJson<Policy>(args.policy, "Policy");
  if (!Array.isArray(policy.allow) || !Array.isArray(policy.deny)) {
    throw new Error(`Policy '${args.policy}' must have 'allow' and 'deny' arrays`);
  }
  const lookup = buildLookup(args.licenses);

  const deps = parseManifest(args.manifest, manifestText);
  const results = await checkDependencies(deps, policy, lookup);
  const report = renderReport(results, args.format);
  process.stdout.write(report + "\n");
  if (args.reportFile) {
    writeFileSync(args.reportFile, report + "\n");
  }
  const summary = summarize(results);
  for (const status of args.failOn) {
    if (summary[status] > 0) return 2;
  }
  return 0;
}

const argv = process.argv.slice(2);
main(argv)
  .then((code) => process.exit(code))
  .catch((err: Error) => {
    process.stderr.write(`error: ${err.message}\n`);
    process.exit(1);
  });
