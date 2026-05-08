// Top-level orchestrator + thin CLI wrapper. Splitting `runBump` from the
// `main()` entrypoint keeps the orchestration testable without spawning subprocesses.

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { parseCommitLog, determineBump } from "./commits.ts";
import { generateChangelogEntry } from "./changelog.ts";
import { bumpVersion, formatVersion, parseVersion, type BumpKind } from "./semver.ts";
import { readVersionFile, writeVersionFile } from "./versionFile.ts";

export interface RunBumpOptions {
  versionFile: string;
  commitLog: string;
  changelogFile: string;
  date: string;
}

export interface RunBumpResult {
  previousVersion: string;
  newVersion: string;
  bump: BumpKind;
  changelogEntry: string;
}

export function runBump(opts: RunBumpOptions): RunBumpResult {
  const previousRaw = readVersionFile(opts.versionFile);
  const previous = parseVersion(previousRaw);

  const logText = readFileSync(opts.commitLog, "utf8");
  const commits = parseCommitLog(logText);
  const bump = determineBump(commits);

  const next = bumpVersion(previous, bump);
  const newVersion = formatVersion(next);

  // No-op: nothing to update or log.
  if (bump === "none") {
    return {
      previousVersion: formatVersion(previous),
      newVersion: formatVersion(previous),
      bump,
      changelogEntry: "",
    };
  }

  writeVersionFile(opts.versionFile, newVersion);

  const entry = generateChangelogEntry({
    version: newVersion,
    date: opts.date,
    commits,
  });

  // Prepend (preserving an existing top-level "# Changelog" header if present).
  let updated: string;
  if (existsSync(opts.changelogFile)) {
    const existing = readFileSync(opts.changelogFile, "utf8");
    const headerMatch = /^(#\s+Changelog\s*\n+)/.exec(existing);
    if (headerMatch) {
      const head = headerMatch[1];
      const rest = existing.slice(head.length);
      updated = `${head}${entry}\n${rest}`;
    } else {
      updated = `${entry}\n${existing}`;
    }
  } else {
    updated = `# Changelog\n\n${entry}`;
  }
  writeFileSync(opts.changelogFile, updated, "utf8");

  return {
    previousVersion: formatVersion(previous),
    newVersion,
    bump,
    changelogEntry: entry,
  };
}

// ---------- CLI entrypoint ----------
// Args (all optional, sensible defaults):
//   --version-file <path>     default: package.json
//   --commit-log <path>       default: commits.txt
//   --changelog <path>        default: CHANGELOG.md
//   --date <YYYY-MM-DD>       default: today (UTC)
//   --github-output <path>    if set, also write outputs (new_version, bump, previous_version)
//                             default: env GITHUB_OUTPUT
function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a && a.startsWith("--")) {
      const key = a.slice(2);
      const val = argv[i + 1];
      if (val === undefined || val.startsWith("--")) {
        out[key] = "true";
      } else {
        out[key] = val;
        i++;
      }
    }
  }
  return out;
}

function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

export async function main(argv: string[]): Promise<number> {
  try {
    const args = parseArgs(argv);
    const versionFile = resolve(args["version-file"] ?? "package.json");
    const commitLog = resolve(args["commit-log"] ?? "commits.txt");
    const changelogFile = resolve(args["changelog"] ?? "CHANGELOG.md");
    const date = args["date"] ?? todayIso();

    const result = runBump({ versionFile, commitLog, changelogFile, date });

    // Human-friendly stdout summary.
    console.log(`previous_version=${result.previousVersion}`);
    console.log(`bump=${result.bump}`);
    console.log(`new_version=${result.newVersion}`);

    // GitHub Actions outputs (key=value lines appended to $GITHUB_OUTPUT).
    const ghOutput = args["github-output"] ?? process.env.GITHUB_OUTPUT;
    if (ghOutput) {
      const lines = [
        `previous_version=${result.previousVersion}`,
        `new_version=${result.newVersion}`,
        `bump=${result.bump}`,
        "",
      ].join("\n");
      const fs = await import("node:fs");
      fs.appendFileSync(ghOutput, lines, "utf8");
    }
    return 0;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`error: ${msg}`);
    return 1;
  }
}

if (import.meta.main) {
  const code = await main(Bun.argv.slice(2));
  process.exit(code);
}
