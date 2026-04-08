#!/usr/bin/env bun
// CLI entry point for the semantic version bumper.
//
// Usage:
//   bun run bump-version.ts <version-file> [--dry-run]
//
// Reads conventional commits from stdin (git log --oneline format),
// determines the appropriate version bump, updates the version file,
// prints a changelog entry, and outputs the new version.
//
// In a CI pipeline you'd typically pipe git log into this:
//   git log --oneline v1.2.3..HEAD | bun run bump-version.ts package.json

import {
  parseCommitLog,
  classifyCommits,
  determineBump,
  bumpVersion,
  readVersionFile,
  writeVersionFile,
  generateChangelog,
  formatVersion,
} from "./semver";

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");
  const versionFile = args.find((a) => !a.startsWith("--"));

  if (!versionFile) {
    console.error("Usage: bump-version.ts <version-file> [--dry-run]");
    console.error("  Reads conventional commits from stdin.");
    process.exit(1);
  }

  // Read commit log from stdin
  const stdin = await Bun.stdin.text();
  const commits = parseCommitLog(stdin);

  if (commits.length === 0) {
    console.error("No commits found on stdin.");
    process.exit(1);
  }

  const classified = classifyCommits(commits);
  const bump = determineBump(classified);

  if (!bump) {
    console.log("No version-bumping commits found (no feat/fix/breaking).");
    process.exit(0);
  }

  // Read current version, compute next
  const current = await readVersionFile(versionFile);
  const next = bumpVersion(current, bump);
  const nextStr = formatVersion(next);

  // Generate changelog
  const changelog = generateChangelog(nextStr, classified);

  if (dryRun) {
    console.log(`[dry-run] Would bump ${formatVersion(current)} → ${nextStr} (${bump})`);
    console.log("");
    console.log(changelog);
  } else {
    await writeVersionFile(versionFile, next);
    console.log(changelog);
    console.log(`---`);
    console.log(`Bumped ${formatVersion(current)} → ${nextStr} (${bump})`);
  }

  // Output just the version on the last line for easy capture in CI
  console.log(`NEW_VERSION=${nextStr}`);
}

main().catch((err) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
