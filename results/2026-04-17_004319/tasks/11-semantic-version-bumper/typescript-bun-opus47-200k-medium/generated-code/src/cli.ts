#!/usr/bin/env bun
// CLI wrapper: read version + commits, bump, write back, emit changelog.
//
// Usage:
//   bun run src/cli.ts --version-file <path> --commits-file <path> \
//     [--changelog <path>] [--dry-run]
//
// Designed so that CI can consume either a bare VERSION file or a package.json.

import { readFileSync, writeFileSync, existsSync, appendFileSync } from "node:fs";
import {
  parseVersion,
  parseCommits,
  determineBump,
  bumpVersion,
  generateChangelog,
  applyVersionToFile,
} from "./bumper.ts";

interface Args {
  versionFile: string;
  commitsFile: string;
  changelog?: string;
  dryRun: boolean;
}

function parseArgs(argv: string[]): Args {
  const args: Partial<Args> = { dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--version-file") args.versionFile = argv[++i];
    else if (a === "--commits-file") args.commitsFile = argv[++i];
    else if (a === "--changelog") args.changelog = argv[++i];
    else if (a === "--dry-run") args.dryRun = true;
  }
  if (!args.versionFile) throw new Error("missing --version-file");
  if (!args.commitsFile) throw new Error("missing --commits-file");
  return args as Args;
}

function main(): void {
  let args: Args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (e) {
    console.error(`error: ${(e as Error).message}`);
    process.exit(2);
  }
  if (!existsSync(args.versionFile)) {
    console.error(`error: version file not found: ${args.versionFile}`);
    process.exit(1);
  }
  if (!existsSync(args.commitsFile)) {
    console.error(`error: commits file not found: ${args.commitsFile}`);
    process.exit(1);
  }
  const versionContent = readFileSync(args.versionFile, "utf8");
  const commitsContent = readFileSync(args.commitsFile, "utf8");

  const current = parseVersion(versionContent);
  const commits = parseCommits(commitsContent);
  const bump = determineBump(commits);
  const next = bumpVersion(current, bump);
  const changelog = generateChangelog(next, commits);

  // Emit structured output so the CI harness can assert on exact values.
  console.log(`current=${current.major}.${current.minor}.${current.patch}`);
  console.log(`bump=${bump}`);
  console.log(`next=${next}`);
  console.log("--- changelog ---");
  console.log(changelog);
  console.log("--- end changelog ---");

  if (args.dryRun) return;

  // Only rewrite the version file if an actual bump happened.
  if (bump !== "none") {
    writeFileSync(args.versionFile, applyVersionToFile(versionContent, next));
  }
  if (args.changelog) {
    // Prepend new entry above existing changelog content (common convention).
    const existing = existsSync(args.changelog)
      ? readFileSync(args.changelog, "utf8")
      : "# Changelog\n\n";
    writeFileSync(args.changelog, changelog + "\n" + existing);
  }
}

main();
