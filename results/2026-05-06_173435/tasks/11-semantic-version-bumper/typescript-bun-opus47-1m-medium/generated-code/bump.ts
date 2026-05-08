// CLI entrypoint. Wires the pure bumper functions into a runnable script.
//
// Sources of commit data (in priority order):
//   1. --commit-log <path>     read pipe-delimited fixture file
//   2. $COMMIT_LOG_FILE         same, via env var (used by GH Actions)
//   3. git log <range>          falls back to real git history
//
// Usage:
//   bun run bump.ts --version-file package.json --commit-log fixtures/feat.log
//   bun run bump.ts --version-file VERSION --since-tag v1.0.0
//
// Outputs (also writes ${GITHUB_OUTPUT} when running in Actions):
//   previous_version=...
//   new_version=...
//   bump=major|minor|patch|none

import { runBump } from "./bumper.ts";
import { readFileSync, appendFileSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";

interface CliArgs {
  versionFile: string;
  commitLogPath?: string;
  changelogPath: string;
  sinceTag?: string;
  date: string;
}

function parseArgs(argv: string[]): CliArgs {
  const out: Partial<CliArgs> = {
    versionFile: "package.json",
    changelogPath: "CHANGELOG.md",
    date: new Date().toISOString().slice(0, 10),
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    switch (a) {
      case "--version-file":
        out.versionFile = next();
        break;
      case "--commit-log":
        out.commitLogPath = next();
        break;
      case "--changelog":
        out.changelogPath = next();
        break;
      case "--since-tag":
        out.sinceTag = next();
        break;
      case "--date":
        out.date = next();
        break;
      case "-h":
      case "--help":
        console.log(
          "Usage: bun run bump.ts [--version-file path] [--commit-log path] [--since-tag tag] [--changelog path] [--date YYYY-MM-DD]",
        );
        process.exit(0);
    }
  }
  return out as CliArgs;
}

function readCommitLog(args: CliArgs): string {
  const envPath = process.env.COMMIT_LOG_FILE;
  const path = args.commitLogPath ?? envPath;
  if (path) {
    if (!existsSync(path)) throw new Error(`commit log not found: ${path}`);
    return readFileSync(path, "utf8");
  }
  // fall back to git
  const range = args.sinceTag ? `${args.sinceTag}..HEAD` : "HEAD";
  const res = spawnSync("git", ["log", "--pretty=format:%h|%s", range], { encoding: "utf8" });
  if (res.status !== 0) {
    throw new Error(`git log failed: ${res.stderr}`);
  }
  return res.stdout;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const commitLog = readCommitLog(args);
  const result = runBump({
    versionFilePath: args.versionFile,
    commitLog,
    changelogPath: args.changelogPath,
    date: args.date,
  });

  // Human-readable
  console.log(`previous_version=${result.previousVersion}`);
  console.log(`new_version=${result.newVersion}`);
  console.log(`bump=${result.bump}`);
  console.log(`commits=${result.commits.length}`);

  // GH Actions step output
  const ghOut = process.env.GITHUB_OUTPUT;
  if (ghOut) {
    appendFileSync(
      ghOut,
      `previous_version=${result.previousVersion}\nnew_version=${result.newVersion}\nbump=${result.bump}\n`,
    );
  }
}

try {
  main();
} catch (e) {
  console.error(`error: ${(e as Error).message}`);
  process.exit(1);
}
