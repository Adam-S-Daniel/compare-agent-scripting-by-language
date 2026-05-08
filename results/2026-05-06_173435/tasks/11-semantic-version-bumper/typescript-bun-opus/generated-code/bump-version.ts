#!/usr/bin/env bun
// Main entry point — reads version from package.json or VERSION file,
// parses commit log, bumps version, writes changelog, outputs new version.

import { readFileSync, writeFileSync, existsSync } from "fs";
import {
  parseVersion,
  formatVersion,
  parseCommitLog,
  determineBumpType,
  bumpVersion,
  generateChangelog,
  readVersionFromPackageJson,
  updatePackageJsonVersion,
} from "./version-bumper";

function getCommitLog(): string {
  // If COMMIT_LOG_FILE env var is set, read from that file (for testing)
  const commitLogFile = process.env.COMMIT_LOG_FILE;
  if (commitLogFile && existsSync(commitLogFile)) {
    return readFileSync(commitLogFile, "utf-8");
  }

  // Otherwise read from git log
  const result = Bun.spawnSync(["git", "log", "--oneline", "--format=%s", "HEAD~10..HEAD"]);
  if (result.exitCode !== 0) {
    // Fallback: try getting all commits
    const fallback = Bun.spawnSync(["git", "log", "--oneline", "--format=%s"]);
    if (fallback.exitCode !== 0) {
      throw new Error("Failed to read git log");
    }
    return fallback.stdout.toString();
  }
  return result.stdout.toString();
}

function getVersionFile(): { path: string; content: string; type: "package" | "version" } {
  // Check for VERSION file first (env override)
  const versionFilePath = process.env.VERSION_FILE;
  if (versionFilePath && existsSync(versionFilePath)) {
    return {
      path: versionFilePath,
      content: readFileSync(versionFilePath, "utf-8"),
      type: "version",
    };
  }

  if (existsSync("package.json")) {
    return {
      path: "package.json",
      content: readFileSync("package.json", "utf-8"),
      type: "package",
    };
  }

  if (existsSync("VERSION")) {
    return {
      path: "VERSION",
      content: readFileSync("VERSION", "utf-8"),
      type: "version",
    };
  }

  throw new Error("No version file found (checked package.json and VERSION)");
}

function main(): void {
  try {
    const versionFile = getVersionFile();
    const currentVersionStr =
      versionFile.type === "package"
        ? readVersionFromPackageJson(versionFile.content)
        : versionFile.content.trim();

    const currentVersion = parseVersion(currentVersionStr);
    console.log(`Current version: ${formatVersion(currentVersion)}`);

    const commitLog = getCommitLog();
    const commits = parseCommitLog(commitLog);

    if (commits.length === 0) {
      console.log("No commits found. Version unchanged.");
      console.log(`::set-output name=version::${formatVersion(currentVersion)}`);
      console.log(`::set-output name=bumped::false`);
      return;
    }

    const bump = determineBumpType(commits);
    console.log(`Bump type: ${bump}`);

    if (bump === "none") {
      console.log("No version-relevant changes detected. Version unchanged.");
      console.log(`::set-output name=version::${formatVersion(currentVersion)}`);
      console.log(`::set-output name=bumped::false`);
      return;
    }

    const newVersion = bumpVersion(currentVersion, bump);
    const newVersionStr = formatVersion(newVersion);
    console.log(`New version: ${newVersionStr}`);

    // Update version file
    if (versionFile.type === "package") {
      const updated = updatePackageJsonVersion(versionFile.content, newVersionStr);
      writeFileSync(versionFile.path, updated);
    } else {
      writeFileSync(versionFile.path, newVersionStr + "\n");
    }

    // Generate changelog
    const today = process.env.CHANGELOG_DATE || new Date().toISOString().split("T")[0];
    const changelog = generateChangelog(newVersion, commits, today);
    console.log("\n--- CHANGELOG ---");
    console.log(changelog);

    // Append to CHANGELOG.md if it exists, otherwise create it
    const changelogPath = "CHANGELOG.md";
    if (existsSync(changelogPath)) {
      const existing = readFileSync(changelogPath, "utf-8");
      writeFileSync(changelogPath, changelog + existing);
    } else {
      writeFileSync(changelogPath, `# Changelog\n\n${changelog}`);
    }

    // Output for GitHub Actions
    console.log(`::set-output name=version::${newVersionStr}`);
    console.log(`::set-output name=bumped::true`);
    console.log(`::set-output name=bump_type::${bump}`);

    // Also write to GITHUB_OUTPUT if available
    const githubOutput = process.env.GITHUB_OUTPUT;
    if (githubOutput) {
      const outputLines = `version=${newVersionStr}\nbumped=true\nbump_type=${bump}\n`;
      writeFileSync(githubOutput, outputLines, { flag: "a" });
    }
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Error: ${message}`);
    process.exit(1);
  }
}

main();
