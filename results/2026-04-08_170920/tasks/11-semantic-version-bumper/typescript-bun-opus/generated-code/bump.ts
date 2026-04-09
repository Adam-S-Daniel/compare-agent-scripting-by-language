#!/usr/bin/env bun
// CLI entry point for semantic version bumper.
// Usage: bun run bump.ts [--package-json <path>] [--commit-file <path>] [--changelog <path>]
//
// If --commit-file is provided, reads commit lines from that file.
// Otherwise, reads commits from git log since the last tag.

import { readFile, writeFile, appendFile, access } from "fs/promises";
import { join, dirname } from "path";
import {
  determineBumpType,
  bumpVersion,
  generateChangelog,
  readVersionFromPackageJson,
  writeVersionToPackageJson,
  type BumpType,
} from "./version-bumper";

function parseArgs(args: string[]): Record<string, string> {
  const result: Record<string, string> = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith("--") && i + 1 < args.length) {
      result[args[i].slice(2)] = args[i + 1];
      i++;
    }
  }
  return result;
}

async function getCommitsFromGit(): Promise<string[]> {
  // Try to get commits since last tag; if no tags, get all commits
  const proc = Bun.spawn(["git", "log", "--oneline", "--no-decorate"], {
    stdout: "pipe",
    stderr: "pipe",
  });
  const output = await new Response(proc.stdout).text();
  await proc.exited;

  if (!output.trim()) {
    return [];
  }
  return output.trim().split("\n");
}

async function getCommitsFromFile(path: string): Promise<string[]> {
  const content = await readFile(path, "utf-8");
  return content.trim().split("\n").filter((l) => l.length > 0);
}

async function main(): Promise<void> {
  const opts = parseArgs(process.argv.slice(2));
  const pkgPath = opts["package-json"] || "package.json";
  const changelogPath = opts["changelog"] || "CHANGELOG.md";

  // Read current version
  let currentVersion: string;
  try {
    currentVersion = await readVersionFromPackageJson(pkgPath);
  } catch (err: any) {
    console.error(`Error reading version: ${err.message}`);
    process.exit(1);
  }

  // Get commits
  let commits: string[];
  if (opts["commit-file"]) {
    commits = await getCommitsFromFile(opts["commit-file"]);
  } else {
    commits = await getCommitsFromGit();
  }

  if (commits.length === 0) {
    console.log("No commits found. Version unchanged.");
    console.log(`current_version=${currentVersion}`);
    console.log(`new_version=${currentVersion}`);
    console.log(`bump_type=none`);
    process.exit(0);
  }

  // Determine bump type
  const bump: BumpType = determineBumpType(commits);

  if (bump === "none") {
    console.log("No conventional commits found. Version unchanged.");
    console.log(`current_version=${currentVersion}`);
    console.log(`new_version=${currentVersion}`);
    console.log(`bump_type=none`);
    process.exit(0);
  }

  // Bump version
  const newVersion = bumpVersion(currentVersion, bump);

  // Update package.json
  await writeVersionToPackageJson(pkgPath, newVersion);

  // Generate changelog entry
  const entry = generateChangelog(newVersion, commits);

  // Prepend to changelog (or create it)
  let existingChangelog = "";
  try {
    existingChangelog = await readFile(changelogPath, "utf-8");
  } catch {
    // File doesn't exist yet, that's fine
  }
  const header = "# Changelog\n\n";
  const body = existingChangelog.startsWith("# Changelog")
    ? existingChangelog.replace("# Changelog\n\n", "")
    : existingChangelog;
  await writeFile(changelogPath, header + entry + "\n" + body);

  // Output results — these lines are parsed by the CI workflow
  console.log(`current_version=${currentVersion}`);
  console.log(`new_version=${newVersion}`);
  console.log(`bump_type=${bump}`);
  console.log(`changelog_file=${changelogPath}`);
}

main();
