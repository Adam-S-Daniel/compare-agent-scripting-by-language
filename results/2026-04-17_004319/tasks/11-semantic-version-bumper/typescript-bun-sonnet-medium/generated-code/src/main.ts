// CLI entry point for semantic version bumper
// Usage: bun run src/main.ts [--commits <file>] [--pkg <file>] [--dry-run]

import { readFileSync, writeFileSync, existsSync } from "fs";
import {
  parseConventionalCommit,
  determineBumpType,
  bumpVersion,
  generateChangelog,
  readVersionFromPackageJson,
  writeVersionToPackageJson,
  type Commit,
} from "./version-bumper";

interface CliOptions {
  commitsFile: string;
  pkgFile: string;
  dryRun: boolean;
  date: string;
}

function parseArgs(args: string[]): CliOptions {
  const opts: CliOptions = {
    commitsFile: "commits.json",
    pkgFile: "package.json",
    dryRun: false,
    date: new Date().toISOString().split("T")[0],
  };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--commits") opts.commitsFile = args[++i];
    else if (args[i] === "--pkg") opts.pkgFile = args[++i];
    else if (args[i] === "--dry-run") opts.dryRun = true;
    else if (args[i] === "--date") opts.date = args[++i];
  }
  return opts;
}

function loadCommits(file: string): Commit[] {
  if (!existsSync(file)) {
    console.error(`Commits file not found: ${file}`);
    process.exit(1);
  }
  const raw = readFileSync(file, "utf-8");
  const data = JSON.parse(raw) as string[];
  return data.map((msg) => parseConventionalCommit(msg));
}

function main() {
  const opts = parseArgs(process.argv.slice(2));

  // Read current version from package.json
  if (!existsSync(opts.pkgFile)) {
    console.error(`Package file not found: ${opts.pkgFile}`);
    process.exit(1);
  }
  const pkgContent = readFileSync(opts.pkgFile, "utf-8");
  const currentVersion = readVersionFromPackageJson(pkgContent);

  // Load and parse commits
  const commits = loadCommits(opts.commitsFile);
  const bumpType = determineBumpType(commits);
  const newVersion = bumpVersion(currentVersion, bumpType);
  const changelog = generateChangelog(newVersion, commits, opts.date);

  console.log(`Current version: ${currentVersion}`);
  console.log(`Bump type: ${bumpType}`);
  console.log(`New version: ${newVersion}`);
  console.log("");
  console.log("=== Changelog Entry ===");
  console.log(changelog);

  if (!opts.dryRun) {
    // Update package.json with new version
    const updatedPkg = writeVersionToPackageJson(pkgContent, newVersion);
    writeFileSync(opts.pkgFile, updatedPkg, "utf-8");

    // Append to CHANGELOG.md
    const changelogFile = "CHANGELOG.md";
    const existing = existsSync(changelogFile)
      ? readFileSync(changelogFile, "utf-8")
      : "# Changelog\n\n";
    const marker = "# Changelog\n\n";
    const newContent = existing.startsWith(marker)
      ? marker + changelog + "\n" + existing.slice(marker.length)
      : changelog + "\n" + existing;
    writeFileSync(changelogFile, newContent, "utf-8");

    console.log(`Updated ${opts.pkgFile} and CHANGELOG.md`);
  }
}

main();
