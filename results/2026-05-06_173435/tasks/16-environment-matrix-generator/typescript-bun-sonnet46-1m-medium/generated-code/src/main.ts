// CLI entry point for the Environment Matrix Generator.
// Usage: bun run src/main.ts <config-file>

import { generateMatrix, type MatrixConfig } from "./matrix-generator";

const configPath = process.argv[2];
if (!configPath) {
  console.error("Usage: bun run src/main.ts <config-file>");
  process.exit(1);
}

let config: MatrixConfig;
try {
  const content = await Bun.file(configPath).text();
  config = JSON.parse(content) as MatrixConfig;
} catch (err) {
  console.error(`Error reading config file "${configPath}": ${err instanceof Error ? err.message : err}`);
  process.exit(1);
}

try {
  const result = generateMatrix(config);
  // Compact JSON on stdout for easy piping and single-line parsing
  console.log(JSON.stringify(result));
} catch (err) {
  console.error(`Matrix generation failed: ${err instanceof Error ? err.message : err}`);
  process.exit(1);
}
