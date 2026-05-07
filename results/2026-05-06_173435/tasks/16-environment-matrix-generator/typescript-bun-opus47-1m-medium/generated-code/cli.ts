#!/usr/bin/env bun
// CLI wrapper. Reads a JSON config from a path (or stdin when path is "-")
// and writes the generated matrix JSON to stdout. Exits non-zero with a
// readable error on validation failure.
import { generateMatrix, MatrixError, type MatrixConfig } from "./matrix";

async function readConfig(path: string): Promise<MatrixConfig> {
  const text =
    path === "-" ? await Bun.stdin.text() : await Bun.file(path).text();
  try {
    return JSON.parse(text) as MatrixConfig;
  } catch (err) {
    throw new MatrixError(
      `failed to parse JSON config from ${path}: ${(err as Error).message}`,
    );
  }
}

async function main() {
  const path = process.argv[2];
  if (!path) {
    console.error("usage: bun run cli.ts <config.json|->");
    process.exit(2);
  }
  try {
    const config = await readConfig(path);
    const result = generateMatrix(config);
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    if (err instanceof MatrixError) {
      console.error(`error: ${err.message}`);
      process.exit(1);
    }
    throw err;
  }
}

main();
