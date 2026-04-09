/**
 * Semantic Version Bumper - Main Entry Point
 *
 * Usage:
 *   bun run src/index.ts [--version-file <path>] [--commits-file <path>] [--dry-run]
 *
 * Reads the current version from a version file (default: package.json or version.txt),
 * parses commit messages from stdin or a commits file,
 * determines the bump type, updates the version file, and generates a changelog entry.
 *
 * Outputs: the new version string to stdout.
 */

import { parseVersion, bumpVersion, determineVersionBump } from "./semver";
import { parseCommits, generateChangelog } from "./changelog";
import { readFileSync, writeFileSync, existsSync } from "fs";
import { join } from "path";

// ============================================================
// Argument Parsing
// ============================================================

interface CliArgs {
  versionFile: string;
  commitsFile: string | null;
  changelogFile: string;
  dryRun: boolean;
  date: string;
}

function parseArgs(args: string[]): CliArgs {
  const result: CliArgs = {
    versionFile: "package.json",
    commitsFile: null,
    changelogFile: "CHANGELOG.md",
    dryRun: false,
    date: new Date().toISOString().split("T")[0], // YYYY-MM-DD
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--version-file":
        result.versionFile = args[++i];
        break;
      case "--commits-file":
        result.commitsFile = args[++i];
        break;
      case "--changelog-file":
        result.changelogFile = args[++i];
        break;
      case "--dry-run":
        result.dryRun = true;
        break;
      case "--date":
        result.date = args[++i];
        break;
    }
  }

  return result;
}

// ============================================================
// Version File I/O
// ============================================================

function readCurrentVersion(versionFile: string): string {
  if (!existsSync(versionFile)) {
    throw new Error(`Version file not found: ${versionFile}`);
  }

  const content = readFileSync(versionFile, "utf-8");

  // Handle package.json
  if (versionFile.endsWith(".json")) {
    try {
      const pkg = JSON.parse(content);
      if (!pkg.version) {
        throw new Error(`No 'version' field in ${versionFile}`);
      }
      return pkg.version;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(`Failed to parse JSON version file: ${msg}`);
    }
  }

  // Handle plain text version file (version.txt, .version, etc.)
  const trimmed = content.trim();
  if (!trimmed) {
    throw new Error(`Version file is empty: ${versionFile}`);
  }
  return trimmed;
}

function writeNewVersion(versionFile: string, newVersion: string): void {
  const content = readFileSync(versionFile, "utf-8");

  if (versionFile.endsWith(".json")) {
    const pkg = JSON.parse(content);
    pkg.version = newVersion;
    writeFileSync(versionFile, JSON.stringify(pkg, null, 2) + "\n", "utf-8");
  } else {
    writeFileSync(versionFile, newVersion + "\n", "utf-8");
  }
}

// ============================================================
// Commits I/O
// ============================================================

function readCommitMessages(commitsFile: string | null): string[] {
  if (commitsFile) {
    if (!existsSync(commitsFile)) {
      throw new Error(`Commits file not found: ${commitsFile}`);
    }
    const content = readFileSync(commitsFile, "utf-8");
    // Each line is a commit message; blank lines are separators
    return content
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
  }

  // Fall back to reading from stdin (for piped git log output)
  // In Bun, process.stdin can be read synchronously
  try {
    const stdinContent = readFileSync("/dev/stdin", "utf-8");
    return stdinContent
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
  } catch {
    return [];
  }
}

// ============================================================
// Changelog I/O
// ============================================================

function prependChangelog(changelogFile: string, newEntry: string): void {
  let existing = "";
  if (existsSync(changelogFile)) {
    existing = readFileSync(changelogFile, "utf-8");
  }

  const separator = existing.startsWith("# Changelog") ? "\n" : "";
  const header = existing.startsWith("# Changelog") ? "" : "# Changelog\n\n";

  writeFileSync(
    changelogFile,
    header + newEntry + separator + existing,
    "utf-8"
  );
}

// ============================================================
// Main
// ============================================================

async function main(): Promise<void> {
  const args = parseArgs(Bun.argv.slice(2));

  // 1. Read current version
  const currentVersionStr = readCurrentVersion(args.versionFile);
  const currentVersion = parseVersion(currentVersionStr);

  // 2. Read and parse commit messages
  const rawMessages = readCommitMessages(args.commitsFile);

  if (rawMessages.length === 0) {
    console.error("Warning: No commit messages found. Defaulting to patch bump.");
  }

  const commits = parseCommits(rawMessages);

  // 3. Determine bump type
  const bumpType = determineVersionBump(commits);

  // 4. Calculate new version
  const newVersion = bumpVersion(currentVersion, bumpType);

  // 5. Generate changelog entry
  const changelogEntry = generateChangelog(newVersion, commits, args.date);

  if (args.dryRun) {
    console.log(`[DRY RUN] Current version: ${currentVersionStr}`);
    console.log(`[DRY RUN] Bump type: ${bumpType}`);
    console.log(`[DRY RUN] New version: ${newVersion}`);
    console.log("\n--- Changelog Entry ---");
    console.log(changelogEntry);
    return;
  }

  // 6. Update version file
  writeNewVersion(args.versionFile, newVersion);

  // 7. Prepend to changelog
  prependChangelog(args.changelogFile, changelogEntry);

  // 8. Output new version (this is the primary output for CI consumption)
  console.log(newVersion);
}

main().catch((err: unknown) => {
  const msg = err instanceof Error ? err.message : String(err);
  console.error(`Error: ${msg}`);
  process.exit(1);
});
