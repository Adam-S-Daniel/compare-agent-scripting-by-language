// CLI entrypoint. Reads a config JSON path as the first positional argument,
// validates and expands the matrix, prints the result as pretty JSON on stdout.
//
// Exit codes:
//   0  — matrix generated successfully
//   1  — unreadable / invalid JSON / missing file
//   2  — matrix violates a configured constraint (e.g. maxSize)
import { generateMatrix, MatrixConfig, MatrixConfigError } from "./matrix";

function fail(message: string, code: number): never {
  process.stderr.write(`error: ${message}\n`);
  process.exit(code);
}

function usage(): never {
  process.stderr.write("usage: bun run src/cli.ts <config.json>\n");
  process.exit(1);
}

const configPath = process.argv[2];
if (!configPath) usage();

let raw: string;
try {
  raw = await Bun.file(configPath).text();
} catch (err) {
  fail(`failed to read config file '${configPath}': ${(err as Error).message}`, 1);
}

let config: MatrixConfig;
try {
  config = JSON.parse(raw) as MatrixConfig;
} catch (err) {
  fail(`config file is not valid JSON: ${(err as Error).message}`, 1);
}

try {
  const out = generateMatrix(config);
  process.stdout.write(JSON.stringify(out, null, 2) + "\n");
  process.exit(0);
} catch (err) {
  if (err instanceof MatrixConfigError) {
    fail(err.message, 2);
  }
  fail((err as Error).message, 1);
}
