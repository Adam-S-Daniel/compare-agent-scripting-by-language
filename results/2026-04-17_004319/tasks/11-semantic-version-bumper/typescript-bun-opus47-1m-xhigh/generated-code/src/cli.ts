#!/usr/bin/env bun
// Command-line entry point.
//
// Usage:
//   bun run src/cli.ts --version-file <path> [--changelog <path>]
//                      [--commits <path>] [--date <yyyy-mm-dd>]
//                      [--delimiter <string>]
//
// If --commits is omitted, the tool reads the commit log from stdin.
// If --date is omitted, today's UTC date is used.
// Final output (to stdout) is the new version string — no newline prefix, so
// shells can easily capture it: `NEW=$(bun run src/cli.ts ...)`.

import { readFile } from "node:fs/promises";
import { runBump } from "./bump.ts";

interface Args {
  versionFile: string;
  changelog: string;
  commits: string | null;
  date: string;
  delimiter: string | undefined;
}

function parseArgs(argv: string[]): Args {
  // A tiny, dependency-free flag parser. We only accept the specific long
  // flags we know about — unknown flags are a hard error to prevent typos.
  const out: Args = {
    versionFile: "",
    changelog: "CHANGELOG.md",
    commits: null,
    date: new Date().toISOString().slice(0, 10),
    delimiter: undefined,
  };
  const get = (i: number): string => {
    if (i >= argv.length) throw new Error(`Missing value for ${argv[i - 1]}`);
    return argv[i];
  };
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    switch (flag) {
      case "--version-file":
        out.versionFile = get(++i);
        break;
      case "--changelog":
        out.changelog = get(++i);
        break;
      case "--commits":
        out.commits = get(++i);
        break;
      case "--date":
        out.date = get(++i);
        break;
      case "--delimiter":
        out.delimiter = get(++i);
        break;
      case "-h":
      case "--help":
        printHelp();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${flag}`);
    }
  }
  if (!out.versionFile) throw new Error("--version-file is required");
  return out;
}

function printHelp(): void {
  const text = `
semantic-version-bumper

  --version-file <path>     Path to package.json or plain VERSION file (required)
  --changelog <path>        Path to CHANGELOG.md (default: CHANGELOG.md)
  --commits <path>          Path to commit log fixture (default: stdin)
  --date <yyyy-mm-dd>       Date to record in the changelog (default: today UTC)
  --delimiter <string>      Commit separator in the log (default: blank line)
  -h, --help                Show this help

Output: the new version string on stdout.
`;
  process.stdout.write(text);
}

async function readCommitsFromStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function main(): Promise<void> {
  let args: Args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (err) {
    process.stderr.write(`error: ${(err as Error).message}\n`);
    process.exit(2);
  }

  try {
    const commitLog = args.commits
      ? await readFile(args.commits, "utf8")
      : await readCommitsFromStdin();

    const result = await runBump({
      versionPath: args.versionFile,
      changelogPath: args.changelog,
      commitLog,
      date: args.date,
      delimiter: args.delimiter,
    });

    // Diagnostic lines go to stderr so stdout stays clean for capture.
    process.stderr.write(
      `old=${result.oldVersion} new=${result.newVersion} bump=${result.bump} commits=${result.commits.length}\n`
    );
    process.stdout.write(result.newVersion + "\n");
  } catch (err) {
    process.stderr.write(`error: ${(err as Error).message}\n`);
    process.exit(1);
  }
}

main();
