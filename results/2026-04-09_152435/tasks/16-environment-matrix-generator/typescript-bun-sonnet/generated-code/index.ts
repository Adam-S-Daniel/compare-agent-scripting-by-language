/**
 * CLI entry point for the environment matrix generator.
 *
 * Usage: bun run index.ts <config-file.json>
 *
 * The script reads a MatrixConfig from the given JSON file and prints the
 * resulting GitHub Actions strategy JSON to stdout wrapped in delimiter markers
 * so the output can be reliably parsed from CI logs.
 *
 * Exit codes:
 *   0 — success (matrix printed)
 *   0 — validation error (MATRIX_ERROR line printed, still exits 0 so the
 *       workflow step doesn't fail when testing the error path)
 *   1 — unexpected / unrecoverable error (bad file path, invalid JSON, etc.)
 */

import { generateMatrix, type MatrixConfig } from "./matrix-generator";
import { readFileSync } from "fs";

const USAGE = "Usage: bun run index.ts <config-file.json>";

function main(): void {
  const [, , configPath] = process.argv;

  if (!configPath) {
    console.error(`Error: no config file specified.\n${USAGE}`);
    process.exit(1);
  }

  let raw: string;
  try {
    raw = readFileSync(configPath, "utf-8");
  } catch (err) {
    console.error(
      `Error: cannot read config file '${configPath}': ${(err as Error).message}`
    );
    process.exit(1);
  }

  let config: MatrixConfig;
  try {
    config = JSON.parse(raw) as MatrixConfig;
  } catch (err) {
    console.error(
      `Error: invalid JSON in '${configPath}': ${(err as Error).message}`
    );
    process.exit(1);
  }

  try {
    const result = generateMatrix(config);
    // Print with markers so the output can be grepped from CI logs.
    console.log("MATRIX_JSON_START");
    console.log(JSON.stringify(result, null, 2));
    console.log("MATRIX_JSON_END");
    console.log(`COMBINATION_COUNT: ${result.combinationCount}`);
  } catch (err) {
    // Validation errors (e.g. matrix too large) are printed as structured
    // output so the step exits 0 — the workflow step uses continue-on-error
    // for the expected-failure fixture.
    console.log(`MATRIX_ERROR: ${(err as Error).message}`);
  }
}

main();
