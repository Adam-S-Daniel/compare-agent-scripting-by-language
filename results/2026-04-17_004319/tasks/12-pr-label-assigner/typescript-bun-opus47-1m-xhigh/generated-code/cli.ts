#!/usr/bin/env bun
// CLI entry point for the PR label assigner.
//
// Usage:
//   bun run cli.ts --config <rules.json> --files <files.txt>   # read file list from newline-delimited file
//   bun run cli.ts --config <rules.json> --files-stdin         # read file list from stdin
//   bun run cli.ts --config <rules.json> <file1> <file2> ...   # files as positional args
//
// Output is JSON on stdout:
//   {"labels": ["api", "tests"]}
//
// Exit codes:
//   0 — success (labels printed, possibly empty array)
//   1 — user/config error (missing config, bad args, etc.)
//   2 — unexpected internal error

import { assignLabels, loadRules } from "./labeler";

interface Args {
  configPath: string;
  files: string[];
  filesFromStdin: boolean;
  filesFromFile?: string;
}

function parseArgs(argv: string[]): Args {
  const args: Args = {
    configPath: "",
    files: [],
    filesFromStdin: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--config") {
      args.configPath = argv[++i] ?? "";
    } else if (a === "--files") {
      args.filesFromFile = argv[++i] ?? "";
    } else if (a === "--files-stdin") {
      args.filesFromStdin = true;
    } else if (a === "--help" || a === "-h") {
      printUsage();
      process.exit(0);
    } else if (a && a.startsWith("--")) {
      throw new Error(`unknown flag: ${a}`);
    } else if (a) {
      args.files.push(a);
    }
  }
  if (!args.configPath) {
    throw new Error("missing required flag: --config <path>");
  }
  return args;
}

function printUsage(): void {
  console.error(
    "Usage: bun run cli.ts --config <rules.json> [--files <list.txt> | --files-stdin | <file>...]",
  );
}

async function readFileList(path: string): Promise<string[]> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`file list not found: ${path}`);
  }
  const text = await file.text();
  return splitLines(text);
}

async function readStdin(): Promise<string[]> {
  const chunks: Uint8Array[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk);
  }
  const text = new TextDecoder().decode(Buffer.concat(chunks));
  return splitLines(text);
}

function splitLines(text: string): string[] {
  return text
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

async function main(): Promise<void> {
  let args: Args;
  try {
    args = parseArgs(Bun.argv.slice(2));
  } catch (err) {
    console.error(`error: ${(err as Error).message}`);
    printUsage();
    process.exit(1);
  }

  let files: string[];
  try {
    if (args.filesFromStdin) {
      files = await readStdin();
    } else if (args.filesFromFile) {
      files = await readFileList(args.filesFromFile);
    } else {
      files = args.files;
    }
  } catch (err) {
    console.error(`error: ${(err as Error).message}`);
    process.exit(1);
  }

  let rules;
  try {
    rules = await loadRules(args.configPath);
  } catch (err) {
    console.error(`error: ${(err as Error).message}`);
    process.exit(1);
  }

  let labels: string[];
  try {
    labels = assignLabels(files, rules);
  } catch (err) {
    console.error(`error: ${(err as Error).message}`);
    process.exit(2);
  }

  // Emit a single JSON line so downstream steps can parse easily.
  console.log(JSON.stringify({ labels }));
}

void main();
