// Command-line entry point.
//
// Usage:
//   bun run src/cli.ts --manifest <path> --config <path> [--fail-on-violation]
//
// The config JSON combines the licence policy and a mock licence database
// so the tool is fully hermetic — no network calls are made, which makes
// it practical to run in CI and deterministic in tests. In a real
// deployment the `licenses` field would be replaced with a resolver that
// hits the npm registry (or an internal SBOM store).

import { readFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { parseManifest } from "./parser";
import { createMockResolver } from "./resolver";
import { checkCompliance, type PolicyConfig } from "./compliance";
import { generateReport, summarise } from "./report";

interface Config extends PolicyConfig {
  licenses: Record<string, string>;
}

function parseConfig(text: string): Config {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    throw new Error(`Invalid config: not valid JSON (${reason})`);
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Invalid config: must be a JSON object");
  }
  const c = parsed as Record<string, unknown>;
  const allow = Array.isArray(c.allow) ? (c.allow as unknown[]).map(String) : [];
  const deny = Array.isArray(c.deny) ? (c.deny as unknown[]).map(String) : [];
  const licensesRaw = c.licenses;
  const licenses: Record<string, string> = {};
  if (licensesRaw && typeof licensesRaw === "object" && !Array.isArray(licensesRaw)) {
    for (const [k, v] of Object.entries(licensesRaw as Record<string, unknown>)) {
      licenses[k] = String(v);
    }
  }
  return { allow, deny, licenses };
}

function usage(): string {
  return [
    "Usage: bun run src/cli.ts --manifest <path> --config <path> [--fail-on-violation]",
    "",
    "  --manifest           Path to a package.json-style dependency manifest.",
    "  --config             Path to a JSON config with {allow, deny, licenses}.",
    "  --fail-on-violation  Exit 1 if any dependency is denied or unknown.",
  ].join("\n");
}

export async function main(argv: string[]): Promise<number> {
  let parsed: ReturnType<typeof parseArgs>;
  try {
    parsed = parseArgs({
      args: argv,
      options: {
        manifest: { type: "string" },
        config: { type: "string" },
        "fail-on-violation": { type: "boolean", default: false },
      },
      allowPositionals: false,
    });
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    process.stderr.write(`error: ${reason}\n${usage()}\n`);
    return 2;
  }

  const manifestPath = parsed.values.manifest;
  const configPath = parsed.values.config;
  const failOnViolation = parsed.values["fail-on-violation"] === true;

  if (!manifestPath || !configPath) {
    process.stderr.write(`error: --manifest and --config are required\n${usage()}\n`);
    return 2;
  }

  let manifestText: string;
  try {
    manifestText = readFileSync(manifestPath, "utf8");
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    process.stderr.write(`error: could not read manifest at ${manifestPath}: ${reason}\n`);
    return 2;
  }

  let configText: string;
  try {
    configText = readFileSync(configPath, "utf8");
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    process.stderr.write(`error: could not read config at ${configPath}: ${reason}\n`);
    return 2;
  }

  let config: Config;
  let deps: ReturnType<typeof parseManifest>;
  try {
    config = parseConfig(configText);
    deps = parseManifest(manifestText);
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    process.stderr.write(`error: ${reason}\n`);
    return 2;
  }

  const resolver = createMockResolver(config.licenses);
  const records = await checkCompliance(deps, { allow: config.allow, deny: config.deny }, resolver);
  process.stdout.write(generateReport(records));

  if (failOnViolation) {
    const s = summarise(records);
    if (s.denied > 0 || s.unknown > 0) return 1;
  }
  return 0;
}

if (import.meta.main) {
  main(process.argv.slice(2)).then((code) => {
    process.exit(code);
  });
}
