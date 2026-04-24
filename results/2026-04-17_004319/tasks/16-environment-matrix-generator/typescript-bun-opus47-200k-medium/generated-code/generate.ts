#!/usr/bin/env bun
// CLI: read a matrix config JSON from argv[2] (file path) or stdin,
// print the generated matrix JSON to stdout.

import { readFileSync } from "node:fs";
import { generateMatrix, type MatrixConfig } from "./matrix";

async function readInput(): Promise<string> {
  const arg = process.argv[2];
  if (arg && arg !== "-") return readFileSync(arg, "utf8");
  // Read from stdin
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
  return Buffer.concat(chunks).toString("utf8");
}

async function main(): Promise<void> {
  const raw = await readInput();
  let config: MatrixConfig;
  try {
    config = JSON.parse(raw);
  } catch (e) {
    console.error(`Invalid JSON: ${(e as Error).message}`);
    process.exit(2);
  }
  try {
    const result = generateMatrix(config);
    // Print single-line JSON so GitHub Actions matrix-from-output works.
    console.log(JSON.stringify(result));
  } catch (e) {
    console.error(`Matrix generation failed: ${(e as Error).message}`);
    process.exit(1);
  }
}

main();
