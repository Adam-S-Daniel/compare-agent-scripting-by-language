// Main semantic version bumper — orchestrates all modules
// Usage: bun run bumper.ts [--dir <path>] [--version-file <path>] [--dry-run]

import { parseArgs } from "node:util";
import { join } from "node:path";
import { parseVersion, formatVersion, bumpVersion } from "./version";
import { parseCommitLog, determineBumpType } from "./commits";
import { generateChangelog, formatChangelog } from "./changelog";
import {
  readVersionFromPackageJson,
  writeVersionToPackageJson,
  readVersionFile,
  writeVersionFile,
} from "./file-ops";
import type { BumpType } from "./types";

export interface BumperOptions {
  dir: string;
  versionFile?: string; // If set, use a plain VERSION file instead of package.json
  dryRun: boolean;
  commitLog: string; // The git log output to analyze
}

export interface BumperResult {
  previousVersion: string;
  newVersion: string;
  bumpType: BumpType;
  changelog: string;
}

/** Core bumper logic, separated from CLI for testability */
export async function runBumper(options: BumperOptions): Promise<BumperResult> {
  // 1. Read current version
  let previousVersion: string;
  if (options.versionFile) {
    previousVersion = await readVersionFile(options.versionFile);
  } else {
    previousVersion = await readVersionFromPackageJson(options.dir);
  }

  // 2. Parse commits and determine bump type
  const commits = parseCommitLog(options.commitLog);
  const bumpType = determineBumpType(commits);

  if (!bumpType) {
    throw new Error("No version-bumping commits found (need feat, fix, or breaking change)");
  }

  // 3. Calculate new version
  const current = parseVersion(previousVersion);
  const next = bumpVersion(current, bumpType);
  const newVersion = formatVersion(next);

  // 4. Generate changelog
  const today = new Date().toISOString().split("T")[0];
  const entry = generateChangelog(commits, newVersion, today);
  const changelog = formatChangelog(entry);

  // 5. Write updated version (unless dry run)
  if (!options.dryRun) {
    if (options.versionFile) {
      await writeVersionFile(options.versionFile, newVersion);
    } else {
      await writeVersionToPackageJson(options.dir, newVersion);
    }

    // Append changelog to CHANGELOG.md
    const changelogPath = join(options.dir, "CHANGELOG.md");
    const file = Bun.file(changelogPath);
    const existing = (await file.exists()) ? await file.text() : "# Changelog\n\n";
    // Insert new entry after the header
    const headerEnd = existing.indexOf("\n\n");
    const updated =
      existing.slice(0, headerEnd + 2) + changelog + "\n" + existing.slice(headerEnd + 2);
    await Bun.write(changelogPath, updated);
  }

  return { previousVersion, newVersion, bumpType, changelog };
}

/** CLI entry point */
async function main(): Promise<void> {
  const { values } = parseArgs({
    options: {
      dir: { type: "string", default: "." },
      "version-file": { type: "string" },
      "dry-run": { type: "boolean", default: false },
      "commit-log": { type: "string" },
    },
  });

  const dir = values.dir!;
  const commitLog =
    values["commit-log"] ||
    // Default: read git log for conventional commits since last tag
    (await getGitLog(dir));

  try {
    const result = await runBumper({
      dir,
      versionFile: values["version-file"],
      dryRun: values["dry-run"]!,
      commitLog,
    });

    console.log(`Previous version: ${result.previousVersion}`);
    console.log(`New version: ${result.newVersion}`);
    console.log(`Bump type: ${result.bumpType}`);
    console.log("");
    console.log(result.changelog);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`Error: ${message}`);
    process.exit(1);
  }
}

/** Get git log of conventional commits since the last tag (or all commits) */
async function getGitLog(dir: string): Promise<string> {
  // Try to find the latest tag to use as the base
  let baseRef = "";
  try {
    const tagProc = Bun.spawnSync(["git", "describe", "--tags", "--abbrev=0"], { cwd: dir });
    if (tagProc.exitCode === 0) {
      baseRef = tagProc.stdout.toString().trim() + "..HEAD";
    }
  } catch {
    // No tags, use all commits
  }

  const args = ["git", "log", "--oneline"];
  if (baseRef) args.push(baseRef);

  const proc = Bun.spawnSync(args, { cwd: dir });
  if (proc.exitCode !== 0) {
    throw new Error(`Failed to get git log: ${proc.stderr.toString()}`);
  }
  return proc.stdout.toString().trim();
}

// Run CLI if this is the main script
if (import.meta.main) {
  main();
}
