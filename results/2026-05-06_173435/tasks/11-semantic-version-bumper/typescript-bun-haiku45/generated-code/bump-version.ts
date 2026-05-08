#!/usr/bin/env bun

import { readFileSync, writeFileSync, existsSync } from "fs";
import { join } from "path";
import {
  parseVersion,
  bumpVersion,
  readVersionFile,
  writeVersionFile,
  formatVersion,
} from "./semantic-version";
import { analyzeCommits } from "./conventional-commits";
import { generateChangelogEntry } from "./changelog";

interface Options {
  versionFile: string;
  commitLog?: string;
  outputChangelog?: string;
}

// Parse command line arguments
function parseArgs(): Options {
  const args = Bun.argv.slice(2);

  if (args.length === 0) {
    printUsage();
    process.exit(1);
  }

  const options: Options = {
    versionFile: "",
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg === "--version-file" || arg === "-v") {
      options.versionFile = args[++i];
    } else if (arg === "--commit-log" || arg === "-c") {
      options.commitLog = args[++i];
    } else if (arg === "--output-changelog" || arg === "-o") {
      options.outputChangelog = args[++i];
    } else if (!options.versionFile) {
      options.versionFile = arg;
    }
  }

  if (!options.versionFile) {
    console.error("Error: version file is required");
    printUsage();
    process.exit(1);
  }

  return options;
}

function printUsage() {
  console.log(`
Usage: bump-version <version-file> [options]

Arguments:
  version-file              Path to package.json or VERSION file

Options:
  -c, --commit-log <log>    Conventional commits log (default: read from stdin)
  -o, --output-changelog    Path to write generated changelog entry

Examples:
  bump-version package.json
  bump-version VERSION -c "feat: add feature\\nfix: fix bug"
  bump-version package.json --output-changelog CHANGES.md
  `);
}

// Read commit log from stdin or option
async function readCommitLog(option?: string): Promise<string> {
  if (option) {
    return option;
  }

  // Read from stdin
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf-8");
}

async function main() {
  try {
    const options = parseArgs();

    // Verify version file exists
    if (!existsSync(options.versionFile)) {
      console.error(`Error: Version file not found: ${options.versionFile}`);
      process.exit(1);
    }

    // Read current version
    const currentVersionStr = readVersionFile(options.versionFile);
    const currentVersion = parseVersion(currentVersionStr);

    // Read and analyze commits
    const commitLog = await readCommitLog(options.commitLog);
    const analysis = analyzeCommits(commitLog);

    // Calculate new version
    const newVersion = bumpVersion(currentVersion, analysis.bumpType);
    const newVersionStr = formatVersion(newVersion);

    // Update version file
    writeVersionFile(options.versionFile, newVersionStr);

    // Generate changelog entry if requested
    if (options.outputChangelog) {
      const changelogEntry = generateChangelogEntry(newVersion, analysis.commits);
      writeFileSync(
        options.outputChangelog,
        changelogEntry,
        "utf-8"
      );
      console.log(`Changelog written to: ${options.outputChangelog}`);
    }

    // Output results
    console.log(`Version bumped: ${currentVersionStr} → ${newVersionStr}`);
    console.log(`Bump type: ${analysis.bumpType}`);
    console.log(`Commits analyzed: ${analysis.commits.length}`);

    // Exit with new version on stdout for scripting
    console.log(newVersionStr);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Error: ${message}`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("Unexpected error:", err);
  process.exit(1);
});
