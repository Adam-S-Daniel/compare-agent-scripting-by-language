#!/usr/bin/env bun
// Main entry point: reads the current version, parses recent git commits,
// determines the appropriate version bump, updates the version file,
// generates a CHANGELOG entry, and prints the new version.

import { parseVersion, bumpVersion, formatVersion } from "./version";
import { parseCommit, determineBumpType } from "./commits";
import { generateChangelog } from "./changelog";
import { readFileSync, writeFileSync, existsSync } from "fs";

/** Locate the current version from VERSION file or package.json. */
function readCurrentVersion(): { version: string; source: string } {
  if (existsSync("VERSION")) {
    return { version: readFileSync("VERSION", "utf-8").trim(), source: "VERSION" };
  }
  if (existsSync("package.json")) {
    const pkg = JSON.parse(readFileSync("package.json", "utf-8"));
    if (pkg.version) {
      return { version: pkg.version, source: "package.json" };
    }
  }
  throw new Error(
    "No version source found. Create a VERSION file or add version to package.json.",
  );
}

/** Read commit subject lines from git log. */
function getCommitMessages(): string[] {
  // First try: commits since the last tag
  const tagResult = Bun.spawnSync(["git", "describe", "--tags", "--abbrev=0"], {
    stderr: "pipe",
  });
  let range = "";
  if (tagResult.exitCode === 0) {
    const tag = tagResult.stdout.toString().trim();
    range = `${tag}..HEAD`;
  }

  const args = ["git", "log", "--format=%s"];
  if (range) args.push(range);

  const result = Bun.spawnSync(args, { stderr: "pipe" });
  if (result.exitCode !== 0) {
    throw new Error("Failed to read git log: " + result.stderr.toString());
  }
  return result.stdout.toString().trim().split("\n").filter(Boolean);
}

/** Write the updated version back to its source file. */
function writeVersion(version: string, source: string): void {
  if (source === "VERSION") {
    writeFileSync("VERSION", version + "\n");
  } else if (source === "package.json") {
    const pkg = JSON.parse(readFileSync("package.json", "utf-8"));
    pkg.version = version;
    writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
  }
}

// --- Main execution ---
try {
  const { version: currentVersionStr, source } = readCurrentVersion();
  console.log(`Current version: ${currentVersionStr} (from ${source})`);

  const messages = getCommitMessages();
  console.log(`Found ${messages.length} commit(s)`);

  const commits = messages.map(parseCommit);
  const bumpType = determineBumpType(commits);

  if (!bumpType) {
    console.log("No version bump needed (no feat, fix, or breaking commits).");
    console.log(`VERSION=${currentVersionStr}`);
    process.exit(0);
  }

  const currentVersion = parseVersion(currentVersionStr);
  const newVersion = bumpVersion(currentVersion, bumpType);
  const newVersionStr = formatVersion(newVersion);

  console.log(`Bump type: ${bumpType}`);
  console.log(`New version: ${newVersionStr}`);

  // Update the version file
  writeVersion(newVersionStr, source);

  // Generate and prepend a changelog entry
  const changelog = generateChangelog(newVersionStr, commits);
  console.log("\nChangelog entry:");
  console.log(changelog);

  const changelogPath = "CHANGELOG.md";
  const existing = existsSync(changelogPath) ? readFileSync(changelogPath, "utf-8") : "";
  writeFileSync(changelogPath, changelog + "\n" + existing);

  // Machine-readable output for CI consumption
  console.log(`VERSION=${newVersionStr}`);
} catch (error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Error: ${message}`);
  process.exit(1);
}
