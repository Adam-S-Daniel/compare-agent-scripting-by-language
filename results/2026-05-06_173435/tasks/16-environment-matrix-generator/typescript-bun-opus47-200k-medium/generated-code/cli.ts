// CLI entry point: read config JSON file path from argv, write matrix JSON to stdout.
import { generateMatrix, type MatrixConfig } from "./matrix";

async function main(): Promise<void> {
  const path = process.argv[2];
  if (!path) {
    console.error("Usage: bun run cli.ts <config.json>");
    process.exit(2);
  }
  let config: MatrixConfig;
  try {
    const text = await Bun.file(path).text();
    config = JSON.parse(text) as MatrixConfig;
  } catch (e) {
    console.error(`Failed to read/parse config: ${(e as Error).message}`);
    process.exit(2);
  }
  try {
    const matrix = generateMatrix(config);
    console.log(JSON.stringify(matrix, null, 2));
  } catch (e) {
    console.error(`Error: ${(e as Error).message}`);
    process.exit(1);
  }
}

main();
