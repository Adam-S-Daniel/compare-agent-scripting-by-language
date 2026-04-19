import { generateMatrix } from "./matrix-generator";
import * as fs from "fs";

interface MatrixConfig {
  os?: string[];
  nodeVersion?: string[];
  features?: string[];
  include?: Record<string, string>[];
  exclude?: Record<string, string>[];
  maxParallel?: number;
  failFast?: boolean;
  maxSize?: number;
}

async function main() {
  const configFile = process.argv[2];

  if (!configFile) {
    console.error("Usage: bun run index.ts <config.json>");
    process.exit(1);
  }

  try {
    // Read config file
    const configContent = fs.readFileSync(configFile, "utf-8");
    const config: MatrixConfig = JSON.parse(configContent);

    // Generate matrix
    const matrix = generateMatrix(config);

    // Output as JSON
    console.log(JSON.stringify(matrix, null, 2));
  } catch (error) {
    if (error instanceof SyntaxError) {
      console.error(`Failed to parse JSON config: ${error.message}`);
    } else if (error instanceof Error) {
      console.error(`Error: ${error.message}`);
    } else {
      console.error("Unknown error occurred");
    }
    process.exit(1);
  }
}

main();
