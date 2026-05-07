#!/usr/bin/env bun
// CLI interface for matrix generator
// Reads JSON config from file or stdin, outputs matrix to stdout

import { generateMatrix, MatrixConfig } from "./matrix-generator";
import { readFileSync } from "fs";
import { resolve } from "path";

async function main() {
  let configText = "";

  // Read from file argument or stdin
  const args = process.argv.slice(2);
  if (args.length > 0) {
    const filePath = resolve(args[0]);
    configText = readFileSync(filePath, "utf-8");
  } else {
    configText = await Bun.stdin.text();
  }

  try {
    const config: MatrixConfig = JSON.parse(configText);
    const result = generateMatrix(config);

    if (result.error) {
      console.error(`Error: ${result.error}`);
      process.exit(1);
    }

    // Output just the matrix (not wrapped in result object)
    console.log(JSON.stringify(result.matrix, null, 2));
  } catch (error) {
    console.error("Failed to parse config:", error);
    process.exit(1);
  }
}

await main();
