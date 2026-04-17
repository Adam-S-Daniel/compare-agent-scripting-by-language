// CLI: reads a config JSON file (path as first arg, or stdin) and prints the
// generated matrix to stdout as JSON.

import { generateMatrix, type MatrixConfig } from "./matrix";

async function readConfig(pathArg: string | undefined): Promise<MatrixConfig> {
  if (pathArg && pathArg !== "-") {
    const text = await Bun.file(pathArg).text();
    return JSON.parse(text) as MatrixConfig;
  }
  // stdin fallback
  const chunks: Uint8Array[] = [];
  const decoder = new TextDecoder();
  let text = "";
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk);
  }
  text = chunks.map((c) => decoder.decode(c)).join("");
  return JSON.parse(text) as MatrixConfig;
}

async function main() {
  const pathArg = Bun.argv[2];
  let config: MatrixConfig;
  try {
    config = await readConfig(pathArg);
  } catch (err) {
    console.error(`Failed to read config: ${(err as Error).message}`);
    process.exit(2);
  }

  try {
    const result = generateMatrix(config);
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    console.error(`Matrix error: ${(err as Error).message}`);
    process.exit(1);
  }
}

main();
