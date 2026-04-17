#!/usr/bin/env bun
// CLI entry point for the environment matrix generator.
//
// Usage:
//   bun run src/cli.ts <config.json>          # read config from file
//   bun run src/cli.ts -                      # read config from stdin
//   bun run src/cli.ts <config.json> --output <path>   # write to file
//
// Output is the generated matrix as JSON on stdout. Errors go to stderr and
// cause a non-zero exit so CI steps can fail fast.

import { generateMatrix, MatrixConfig, MatrixError } from "./matrix.ts";

interface CliArgs {
  configPath: string;
  outputPath?: string;
}

function parseArgs(argv: string[]): CliArgs {
  // Positional: config path (or "-" for stdin). Flags: --output <path>.
  const positional: string[] = [];
  let outputPath: string | undefined;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a === "--output" || a === "-o") {
      const next = argv[i + 1];
      if (!next) throw new Error(`${a} requires a path argument`);
      outputPath = next;
      i++;
    } else if (a.startsWith("--output=")) {
      outputPath = a.slice("--output=".length);
    } else if (a === "--help" || a === "-h") {
      printUsageAndExit(0);
    } else {
      positional.push(a);
    }
  }
  if (positional.length !== 1) {
    throw new Error(
      `expected exactly one config path argument, got ${positional.length}`,
    );
  }
  return { configPath: positional[0]!, outputPath };
}

function printUsageAndExit(code: number): never {
  const usage = [
    "Usage: bun run src/cli.ts <config.json|-> [--output <path>]",
    "",
    "  <config.json>     Path to matrix config JSON. Use - to read from stdin.",
    "  --output <path>   Write output JSON to <path> instead of stdout.",
  ].join("\n");
  (code === 0 ? process.stdout : process.stderr).write(usage + "\n");
  process.exit(code);
}

async function readConfig(path: string): Promise<MatrixConfig> {
  const raw = path === "-" ? await readAllStdin() : await Bun.file(path).text();
  try {
    return JSON.parse(raw) as MatrixConfig;
  } catch (err) {
    // Re-throw with a clearer message — the raw SyntaxError doesn't mention
    // that we were trying to parse the config file.
    throw new Error(
      `failed to parse config as JSON: ${(err as Error).message}`,
    );
  }
}

async function readAllStdin(): Promise<string> {
  // Bun exposes stdin as a ReadableStream.
  let out = "";
  const decoder = new TextDecoder();
  // @ts-expect-error Bun.stdin is ReadableStream<Uint8Array> at runtime
  for await (const chunk of Bun.stdin.stream()) {
    out += decoder.decode(chunk as Uint8Array);
  }
  return out;
}

async function main(): Promise<void> {
  let args: CliArgs;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (err) {
    process.stderr.write(`error: ${(err as Error).message}\n`);
    printUsageAndExit(2);
  }

  const config = await readConfig(args.configPath);
  const result = generateMatrix(config);
  const json = JSON.stringify(result, null, 2);

  if (args.outputPath) {
    await Bun.write(args.outputPath, json + "\n");
  } else {
    process.stdout.write(json + "\n");
  }
}

main().catch((err: unknown) => {
  // MatrixError messages are already user-facing; other errors get a prefix
  // so the user can tell where the failure originated.
  if (err instanceof MatrixError) {
    process.stderr.write(`matrix error: ${err.message}\n`);
  } else if (err instanceof Error) {
    process.stderr.write(`error: ${err.message}\n`);
  } else {
    process.stderr.write(`error: ${String(err)}\n`);
  }
  process.exit(1);
});
