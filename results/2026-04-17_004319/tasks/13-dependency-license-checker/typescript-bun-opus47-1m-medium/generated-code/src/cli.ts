// Minimal CLI wrapper around the checker. Usage:
//   bun run src/cli.ts <manifest> <policy.json> [licenses.json]
// Reads a manifest + policy, optionally a mock license table, writes a
// JSON compliance report to stdout. Exit codes:
//   0 - all deps approved
//   1 - one or more denied
//   2 - unknowns present but none denied
//   3 - bad arguments / IO errors
import {
  parseManifest,
  checkDependencies,
  formatReport,
  staticLookup,
  type PolicyConfig,
} from "./checker.ts";

async function readJson<T>(path: string): Promise<T> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`File not found: ${path}`);
  }
  return (await file.json()) as T;
}

async function main(argv: string[]): Promise<number> {
  const [manifestPath, policyPath, licensesPath] = argv;
  if (!manifestPath || !policyPath) {
    console.error(
      "Usage: bun run src/cli.ts <manifest> <policy.json> [licenses.json]",
    );
    return 3;
  }
  try {
    const manifestText = await Bun.file(manifestPath).text();
    const deps = parseManifest(manifestText);
    const policy = await readJson<PolicyConfig>(policyPath);
    const licenseTable = licensesPath
      ? await readJson<Record<string, string | null>>(licensesPath)
      : {};
    const lookup = staticLookup(licenseTable);
    const results = await checkDependencies(deps, policy, lookup);
    const report = formatReport(results);
    console.log(report);
    if (results.some((r) => r.status === "denied")) return 1;
    if (results.some((r) => r.status === "unknown")) return 2;
    return 0;
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    return 3;
  }
}

const code = await main(Bun.argv.slice(2));
process.exit(code);
