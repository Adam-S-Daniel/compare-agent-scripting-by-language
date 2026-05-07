#!/usr/bin/env bun
// CLI entrypoint for the semantic version bumper.
//
// Usage:
//   bun run src/cli.ts \
//       --version-file <package.json|VERSION> \
//       --commits-file <commits.txt> \
//       [--changelog CHANGELOG.md] \
//       [--date YYYY-MM-DD] \
//       [--dry-run]
//
// Always prints three machine-readable lines on stdout (suitable for grep in CI):
//   OLD_VERSION=<x.y.z>
//   NEW_VERSION=<x.y.z>
//   BUMP_TYPE=<major|minor|patch|none>

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import {
  parseCommitLog,
  determineBump,
  bumpVersion,
  generateChangelogEntry,
} from "./lib";

interface CliOptions {
  versionFile: string;
  commitsFile: string;
  changelog?: string;
  date: string;
  dryRun: boolean;
}

function parseArgs(argv: string[]): CliOptions {
  const opts: Partial<CliOptions> = { dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    switch (arg) {
      case "--version-file": opts.versionFile = argv[++i]; break;
      case "--commits-file": opts.commitsFile = argv[++i]; break;
      case "--changelog":    opts.changelog   = argv[++i]; break;
      case "--date":         opts.date        = argv[++i]; break;
      case "--dry-run":      opts.dryRun      = true; break;
      case "--help":
      case "-h":
        printUsage();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }
  if (!opts.versionFile) throw new Error("--version-file is required");
  if (!opts.commitsFile) throw new Error("--commits-file is required");
  if (!opts.date) opts.date = new Date().toISOString().slice(0, 10);
  return opts as CliOptions;
}

function printUsage(): void {
  process.stdout.write(
    "Usage: bun run src/cli.ts --version-file <path> --commits-file <path> " +
      "[--changelog <path>] [--date YYYY-MM-DD] [--dry-run]\n",
  );
}

// Reads the current version. If the file is JSON (e.g. package.json) we use
// the `version` field; otherwise we treat the whole file as the version string.
function readVersion(path: string): { version: string; isJson: boolean; raw: string } {
  if (!existsSync(path)) {
    throw new Error(`version file not found: ${path}`);
  }
  const raw = readFileSync(path, "utf8");
  if (path.endsWith(".json")) {
    const parsed = JSON.parse(raw) as { version?: unknown };
    if (typeof parsed.version !== "string") {
      throw new Error(`version file ${path} has no string "version" field`);
    }
    return { version: parsed.version, isJson: true, raw };
  }
  return { version: raw.trim(), isJson: false, raw };
}

function writeVersion(path: string, raw: string, isJson: boolean, newVersion: string): void {
  if (isJson) {
    // Preserve original formatting (indent, trailing newline) by string-substituting
    // only the version field rather than re-serializing the whole document.
    const replaced = raw.replace(
      /("version"\s*:\s*")[^"]+(")/,
      `$1${newVersion}$2`,
    );
    writeFileSync(path, replaced);
  } else {
    const trailingNewline = raw.endsWith("\n") ? "\n" : "";
    writeFileSync(path, newVersion + trailingNewline);
  }
}

// Prepends a new entry to the changelog so the latest release is at the top.
// Creates the file with a header if it doesn't exist yet.
function appendChangelog(path: string, entry: string): void {
  const header = "# Changelog\n\nAll notable changes to this project are documented here.\n\n";
  if (!existsSync(path)) {
    writeFileSync(path, header + entry);
    return;
  }
  const existing = readFileSync(path, "utf8");
  const trimmed = existing.startsWith(header) ? existing.slice(header.length) : existing;
  writeFileSync(path, header + entry + "\n" + trimmed);
}

async function main(): Promise<number> {
  const opts = parseArgs(process.argv.slice(2));
  const { version: oldVersion, isJson, raw } = readVersion(opts.versionFile);
  const commitsRaw = readFileSync(opts.commitsFile, "utf8");
  const commits = parseCommitLog(commitsRaw);
  const bump = determineBump(commits);

  const bumpType = bump ?? "none";
  const newVersion = bump ? bumpVersion(oldVersion, bump) : oldVersion;

  process.stdout.write(`OLD_VERSION=${oldVersion}\n`);
  process.stdout.write(`NEW_VERSION=${newVersion}\n`);
  process.stdout.write(`BUMP_TYPE=${bumpType}\n`);

  if (!bump) {
    process.stderr.write(
      `No release-worthy commits (only ${commits.map((c) => c.type).join(", ") || "<empty>"}); leaving version at ${oldVersion}.\n`,
    );
    return 0;
  }

  if (opts.dryRun) {
    process.stderr.write(`(dry-run) would have written ${newVersion} to ${opts.versionFile}\n`);
    return 0;
  }

  writeVersion(opts.versionFile, raw, isJson, newVersion);
  if (opts.changelog) {
    const entry = generateChangelogEntry(newVersion, commits, opts.date);
    appendChangelog(opts.changelog, entry);
  }
  return 0;
}

try {
  process.exit(await main());
} catch (err) {
  const msg = err instanceof Error ? err.message : String(err);
  process.stderr.write(`error: ${msg}\n`);
  process.exit(1);
}
