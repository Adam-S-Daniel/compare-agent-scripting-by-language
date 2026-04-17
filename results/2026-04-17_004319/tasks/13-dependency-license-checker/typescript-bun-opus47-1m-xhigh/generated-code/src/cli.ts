#!/usr/bin/env bun
// CLI entrypoint.
//
// Usage:
//   bun run src/cli.ts \
//     --manifest ./package.json \
//     --policy   ./policy.json \
//     --licenses ./licenses.json \
//     [--format text|json]   (default: json)
//
// Exit codes:
//   0 = no denied dependencies (approved + unknown are tolerated here;
//       a stricter policy could be added later)
//   2 = at least one denied dependency found
//   1 = usage or I/O error

import { runChecker } from "./runChecker.ts";
import { renderJson, renderText } from "./reporter.ts";
import type { LicensePolicy } from "./types.ts";

interface CliArgs {
  manifest: string;
  policy: string;
  licenses: string;
  format: "json" | "text";
}

function parseArgs(argv: string[]): CliArgs {
  const out: Partial<CliArgs> = { format: "json" };
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    const value = argv[i + 1];
    switch (flag) {
      case "--manifest": out.manifest = value; i++; break;
      case "--policy":   out.policy   = value; i++; break;
      case "--licenses": out.licenses = value; i++; break;
      case "--format":
        if (value !== "json" && value !== "text") {
          throw new Error(`--format must be json or text, got: ${value}`);
        }
        out.format = value; i++; break;
      default:
        throw new Error(`Unknown argument: ${flag}`);
    }
  }
  for (const key of ["manifest", "policy", "licenses"] as const) {
    if (!out[key]) throw new Error(`Missing required --${key} argument.`);
  }
  return out as CliArgs;
}

async function readJson<T>(path: string): Promise<T> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`File not found: ${path}`);
  }
  const text = await file.text();
  try {
    return JSON.parse(text) as T;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Invalid JSON in ${path}: ${msg}`);
  }
}

async function main(argv: string[]): Promise<number> {
  let args: CliArgs;
  try {
    args = parseArgs(argv);
  } catch (err) {
    console.error(`error: ${err instanceof Error ? err.message : err}`);
    return 1;
  }

  try {
    const manifestText = await Bun.file(args.manifest).text();
    const policy = await readJson<LicensePolicy>(args.policy);
    const licenseDb = await readJson<Record<string, string>>(args.licenses);
    const report = runChecker({ manifest: manifestText, policy, licenseDb });
    const output = args.format === "text" ? renderText(report) : renderJson(report);
    console.log(output);
    return report.summary.denied > 0 ? 2 : 0;
  } catch (err) {
    console.error(`error: ${err instanceof Error ? err.message : err}`);
    return 1;
  }
}

// Only run when invoked directly, not when imported by tests.
if (import.meta.main) {
  const code = await main(Bun.argv.slice(2));
  process.exit(code);
}
