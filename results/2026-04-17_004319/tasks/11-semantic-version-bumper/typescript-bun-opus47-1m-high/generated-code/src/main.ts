// CLI entry point + the pure `runBump` function used by tests and the
// GitHub Actions workflow.
//
// Inputs:
//   - package.json (any JSON file with a `version` field)
//   - a commit log text file whose entries are split by "---" lines.
//     In the workflow this comes from a fixture; in real use you'd pipe
//     `git log --format=%B%n---` into it.
//
// Outputs:
//   - rewrites package.json with the bumped version (if any).
//   - prepends a section to CHANGELOG.md.
//   - prints NEW_VERSION=x.y.z and BUMP_TYPE=t to stdout so the action can
//     pick them up as step outputs.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { parseCommitLog } from "./parser";
import { determineBumpType, bumpVersion } from "./bumper";
import { generateChangelogEntry } from "./changelog";

export interface RunOptions {
  packageFile: string;
  commitLog: string;
  changelogFile: string;
  date: string;
}

export interface RunResult {
  oldVersion: string;
  newVersion: string;
  bumpType: "major" | "minor" | "patch" | "none";
  changelogUpdated: boolean;
}

export function runBump(opts: RunOptions): RunResult {
  if (!existsSync(opts.packageFile)) {
    throw new Error(
      `package.json not found at '${opts.packageFile}'. Pass --package=<path> or cd into the project root.`
    );
  }

  let pkg: { version?: unknown; [k: string]: unknown };
  try {
    pkg = JSON.parse(readFileSync(opts.packageFile, "utf8"));
  } catch (e) {
    throw new Error(`Failed to parse package.json: ${(e as Error).message}`);
  }
  if (typeof pkg.version !== "string") {
    throw new Error(`package.json at '${opts.packageFile}' has no 'version' string field.`);
  }
  const oldVersion = pkg.version;

  if (!existsSync(opts.commitLog)) {
    throw new Error(`Commit log not found at '${opts.commitLog}'.`);
  }
  const log = readFileSync(opts.commitLog, "utf8");
  const commits = parseCommitLog(log);
  const bumpType = determineBumpType(commits);
  const newVersion = bumpVersion(oldVersion, bumpType);

  // Only rewrite files if we actually bumped.  This keeps no-op runs clean.
  let changelogUpdated = false;
  if (bumpType !== "none") {
    pkg.version = newVersion;
    // Preserve a trailing newline since most package.json conventions include one.
    writeFileSync(opts.packageFile, JSON.stringify(pkg, null, 2) + "\n");

    const entry = generateChangelogEntry(newVersion, commits, opts.date);
    let body = entry + "\n";
    if (existsSync(opts.changelogFile)) {
      const existing = readFileSync(opts.changelogFile, "utf8");
      // Preserve a top-level "# Changelog" header if present, otherwise prepend.
      if (/^#\s+Changelog/m.test(existing)) {
        body = existing.replace(
          /^(#\s+Changelog[^\n]*\n+)/,
          (m) => m + entry + "\n\n"
        );
      } else {
        body = entry + "\n\n" + existing;
      }
    } else {
      body = "# Changelog\n\n" + entry + "\n";
    }
    writeFileSync(opts.changelogFile, body);
    changelogUpdated = true;
  }

  return { oldVersion, newVersion, bumpType, changelogUpdated };
}

// ---- CLI --------------------------------------------------------------
// Flags are intentionally minimal; the workflow invokes us with explicit
// paths so we don't need any cleverness here.
interface CliFlags {
  packageFile: string;
  commitLog: string;
  changelogFile: string;
  date: string;
}

function parseFlags(argv: readonly string[]): CliFlags {
  const get = (name: string, fallback: string): string => {
    const prefix = `--${name}=`;
    const hit = argv.find((a) => a.startsWith(prefix));
    return hit ? hit.slice(prefix.length) : fallback;
  };
  const today = new Date().toISOString().slice(0, 10);
  return {
    packageFile: get("package", "package.json"),
    commitLog: get("commits", "commits.txt"),
    changelogFile: get("changelog", "CHANGELOG.md"),
    date: get("date", today),
  };
}

// Entry when executed via `bun run src/main.ts ...`.
// import.meta.main is true only when this file is the CLI entry.
if (import.meta.main) {
  try {
    const flags = parseFlags(process.argv.slice(2));
    const r = runBump(flags);
    console.log(`OLD_VERSION=${r.oldVersion}`);
    console.log(`NEW_VERSION=${r.newVersion}`);
    console.log(`BUMP_TYPE=${r.bumpType}`);
    console.log(`CHANGELOG_UPDATED=${r.changelogUpdated}`);
  } catch (e) {
    console.error(`error: ${(e as Error).message}`);
    process.exit(1);
  }
}
