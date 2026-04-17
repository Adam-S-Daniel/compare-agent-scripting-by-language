// End-to-end orchestration for bumping the version in a project.
//
// Steps:
//   1. Read the current version from the version file (package.json or VERSION).
//   2. Parse the provided commit log into conventional commits.
//   3. Decide the bump type (major/minor/patch/none).
//   4. If "none": print the current version, return.
//   5. Otherwise: compute the new version, write the version file, prepend a
//      changelog entry (creating the CHANGELOG.md if necessary), and return
//      the new version.

import { readFile, writeFile } from "node:fs/promises";
import { renderChangelogEntry } from "./changelog.ts";
import { parseCommitLog } from "./commits.ts";
import { decideBump } from "./decide.ts";
import { bumpVersion, formatVersion, parseVersion } from "./semver.ts";
import { readVersionFile, writeVersionFile } from "./versionFile.ts";
import type { Commit } from "./commits.ts";
import type { BumpType } from "./semver.ts";

export interface BumpRequest {
  versionPath: string;
  changelogPath: string;
  commitLog: string;
  /** ISO date string (yyyy-mm-dd). Explicit so tests are deterministic. */
  date: string;
  /** Optional commit-log delimiter. */
  delimiter?: string;
}

export interface BumpResult {
  oldVersion: string;
  newVersion: string;
  bump: BumpType;
  commits: Commit[];
}

export async function runBump(req: BumpRequest): Promise<BumpResult> {
  const oldVersion = await readVersionFile(req.versionPath);
  const parsedOld = parseVersion(oldVersion);
  const commits = parseCommitLog(req.commitLog, { delimiter: req.delimiter });
  const bump = decideBump(commits);

  if (bump === "none") {
    return {
      oldVersion,
      newVersion: oldVersion,
      bump,
      commits,
    };
  }

  const parsedNew = bumpVersion(parsedOld, bump);
  const newVersion = formatVersion(parsedNew);
  await writeVersionFile(req.versionPath, newVersion);

  const entry = renderChangelogEntry({
    version: newVersion,
    date: req.date,
    commits,
  });
  await prependChangelog(req.changelogPath, entry);

  return {
    oldVersion,
    newVersion,
    bump,
    commits,
  };
}

// Prepend a new entry to an existing CHANGELOG.md, preserving a top-level
// "# Changelog" heading and any preamble under it. Creates the file with a
// standard preamble when it does not yet exist.
async function prependChangelog(path: string, entry: string): Promise<void> {
  let existing = "";
  try {
    existing = await readFile(path, "utf8");
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code !== "ENOENT") throw err;
  }

  if (existing === "") {
    const preamble =
      "# Changelog\n\nAll notable changes to this project are documented in this file.\n\n";
    await writeFile(path, preamble + entry + "\n");
    return;
  }

  // Find the first release heading (## [...]) and insert before it. If there
  // is no such heading, append to the end of the file.
  const firstReleaseIdx = existing.search(/^## \[/m);
  if (firstReleaseIdx === -1) {
    const sep = existing.endsWith("\n") ? "" : "\n";
    await writeFile(path, existing + sep + entry + "\n");
    return;
  }
  const before = existing.slice(0, firstReleaseIdx);
  const after = existing.slice(firstReleaseIdx);
  await writeFile(path, before + entry + "\n" + after);
}
