// CLI entrypoint: read a JSON config file, emit GitHub Actions strategy JSON.
//
// Usage: bun run src/cli.ts <config.json>
//
// Output shape (always-printed to stdout):
//   {
//     "strategy": {
//       "fail-fast": <bool>,
//       "max-parallel": <number>,   // optional, omitted if not configured
//       "matrix": { "include": [ { ... combo ... }, ... ] }
//     }
//   }
//
// Exit codes:
//   0 - success
//   1 - validation error (MatrixError)
//   2 - usage error (missing arg, unreadable file, malformed JSON)

import { readFileSync } from "node:fs";
import { generateMatrix, MatrixError, type MatrixConfig } from "./matrix";

function fail(code: number, message: string): never {
  process.stderr.write(`error: ${message}\n`);
  process.exit(code);
}

function main(argv: string[]): void {
  const configPath = argv[2];
  if (!configPath) {
    fail(2, "missing config file argument. Usage: bun run src/cli.ts <config.json>");
  }

  let raw: string;
  try {
    raw = readFileSync(configPath, "utf8");
  } catch (e) {
    fail(2, `cannot read config file '${configPath}': ${(e as Error).message}`);
  }

  let config: MatrixConfig;
  try {
    config = JSON.parse(raw) as MatrixConfig;
  } catch (e) {
    fail(2, `invalid JSON in '${configPath}': ${(e as Error).message}`);
  }

  let result;
  try {
    result = generateMatrix(config);
  } catch (e) {
    if (e instanceof MatrixError) fail(1, e.message);
    throw e;
  }

  // Build the strategy block with kebab-case keys to match Actions YAML.
  const strategy: Record<string, unknown> = {
    "fail-fast": result.failFast,
    matrix: result.matrix,
  };
  if (result.maxParallel !== undefined) {
    strategy["max-parallel"] = result.maxParallel;
  }

  process.stdout.write(JSON.stringify({ strategy }, null, 2) + "\n");
}

main(process.argv);
