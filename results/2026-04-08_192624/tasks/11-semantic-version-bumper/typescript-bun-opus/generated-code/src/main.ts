/**
 * Main entry point for the semantic version bumper.
 * Reads the current version, analyzes git commits, bumps the version,
 * generates a changelog, and outputs the result.
 */

import { readFileSync, writeFileSync, existsSync } from "fs";
import { execSync } from "child_process";
import { parseVersion, formatVersion, bumpVersion } from "./version";
import { parseCommits, determineBumpType } from "./commits";
import { generateChangelog } from "./changelog";

/** Read the current version from a VERSION file or package.json */
function readCurrentVersion(): { version: string; source: string } {
  if (existsSync("VERSION")) {
    const version = readFileSync("VERSION", "utf-8").trim();
    return { version, source: "VERSION" };
  }

  if (existsSync("package.json")) {
    const pkg = JSON.parse(readFileSync("package.json", "utf-8"));
    if (pkg.version) {
      return { version: pkg.version, source: "package.json" };
    }
  }

  throw new Error("No VERSION file or package.json with version field found");
}

/** Get commit subject lines from git log */
function getCommitMessages(): string {
  try {
    return execSync('git log --format="%s" --no-merges', {
      encoding: "utf-8",
    });
  } catch (error) {
    throw new Error(`Failed to read git log: ${error}`);
  }
}

/** Write the new version back to the source file */
function updateVersion(newVersion: string, source: string): void {
  if (source === "VERSION") {
    writeFileSync("VERSION", newVersion + "\n");
  } else if (source === "package.json") {
    const pkg = JSON.parse(readFileSync("package.json", "utf-8"));
    pkg.version = newVersion;
    writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
  }
}

function main(): void {
  console.log("=== Semantic Version Bumper ===");

  // Step 1: Read current version
  const { version: currentVersionStr, source } = readCurrentVersion();
  const currentVersion = parseVersion(currentVersionStr);
  console.log(
    `Current version: ${formatVersion(currentVersion)} (from ${source})`,
  );

  // Step 2: Get and parse conventional commits
  const commitLog = getCommitMessages();
  const commits = parseCommits(commitLog);
  console.log(`Found ${commits.length} conventional commit(s)`);

  if (commits.length === 0) {
    console.log("No conventional commits found. Version unchanged.");
    console.log(`NEW_VERSION=${formatVersion(currentVersion)}`);
    return;
  }

  // Step 3: Determine bump type from commits
  const bump = determineBumpType(commits);
  console.log(`Bump type: ${bump}`);

  if (bump === "none") {
    console.log("No version-relevant commits. Version unchanged.");
    console.log(`NEW_VERSION=${formatVersion(currentVersion)}`);
    return;
  }

  // Step 4: Calculate new version
  const newVersion = bumpVersion(currentVersion, bump);
  const newVersionStr = formatVersion(newVersion);
  console.log(`New version: ${newVersionStr}`);

  // Step 5: Update the version file
  updateVersion(newVersionStr, source);
  console.log(`Updated ${source} with version ${newVersionStr}`);

  // Step 6: Generate and display changelog entry
  const changelog = generateChangelog(newVersionStr, commits);
  console.log("");
  console.log("=== Changelog Entry ===");
  console.log(changelog);

  // Step 7: Output machine-readable new version
  console.log(`NEW_VERSION=${newVersionStr}`);
}

main();
