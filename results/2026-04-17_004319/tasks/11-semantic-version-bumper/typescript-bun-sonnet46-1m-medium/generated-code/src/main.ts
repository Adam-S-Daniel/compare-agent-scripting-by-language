// CLI entry point for semantic version bumper
// Usage: bun run src/main.ts [version-file] [git-log-file]
// Reads commits from stdin or a file, bumps version in the version file, prints new version

import { readFileSync, writeFileSync, existsSync } from "fs";
import { parseCommits, bumpVersionFile, generateChangelog, determineVersionBump, bumpVersion, parseVersion } from "./version-bumper";

function detectFormat(filePath: string): "package.json" | "version.txt" {
  if (filePath.endsWith("package.json")) return "package.json";
  return "version.txt";
}

async function main() {
  const args = process.argv.slice(2);
  const versionFilePath = args[0];
  const gitLogFilePath = args[1];

  if (!versionFilePath) {
    console.error("Usage: bun run src/main.ts <version-file> [git-log-file]");
    console.error("  version-file: path to package.json or version.txt");
    console.error("  git-log-file: path to file with git log --oneline output (optional, reads stdin if omitted)");
    process.exit(1);
  }

  if (!existsSync(versionFilePath)) {
    console.error(`Error: version file not found: ${versionFilePath}`);
    process.exit(1);
  }

  let gitLog: string;
  if (gitLogFilePath) {
    if (!existsSync(gitLogFilePath)) {
      console.error(`Error: git log file not found: ${gitLogFilePath}`);
      process.exit(1);
    }
    gitLog = readFileSync(gitLogFilePath, "utf8");
  } else {
    // Read from stdin
    const chunks: Buffer[] = [];
    for await (const chunk of Bun.stdin.stream()) {
      chunks.push(Buffer.from(chunk));
    }
    gitLog = Buffer.concat(chunks).toString("utf8");
  }

  const format = detectFormat(versionFilePath);
  const commits = parseCommits(gitLog);

  if (commits.length === 0) {
    const content = readFileSync(versionFilePath, "utf8");
    const version = parseVersion(content, format);
    console.log(`No commits to process. Current version: ${version}`);
    process.exit(0);
  }

  try {
    const result = bumpVersionFile(versionFilePath, format, commits);

    console.log(`Previous version: ${result.previousVersion}`);
    console.log(`New version: ${result.newVersion}`);
    console.log(`Bump type: ${result.bumpType}`);
    console.log(`Commits processed: ${result.commits.length}`);
    console.log("");
    console.log("=== CHANGELOG ===");
    console.log(result.changelog);

    if (result.bumpType !== "none") {
      // Write changelog to CHANGELOG.md (prepend)
      const changelogPath = "CHANGELOG.md";
      let existing = "";
      if (existsSync(changelogPath)) {
        existing = readFileSync(changelogPath, "utf8");
      }
      writeFileSync(changelogPath, result.changelog + "\n\n" + existing);
      console.log(`\nUpdated ${versionFilePath} to ${result.newVersion}`);
      console.log(`Updated CHANGELOG.md`);
    } else {
      console.log("No version bump needed.");
    }
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(`Fatal error: ${err.message}`);
  process.exit(1);
});
