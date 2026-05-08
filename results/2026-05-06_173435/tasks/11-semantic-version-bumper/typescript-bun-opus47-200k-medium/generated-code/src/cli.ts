// CLI entry point: reads a version file and a commit log, writes the new version
// and changelog, prints the new version on stdout.
import { readFileSync, writeFileSync, existsSync, appendFileSync } from "node:fs";
import {
  bump,
  readVersionFromContent,
  writeVersionToContent,
} from "./bumper.ts";

interface CliArgs {
  versionFile: string;
  commitsFile: string;
  changelogFile: string;
  date?: string;
  dryRun: boolean;
}

function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = {
    versionFile: "package.json",
    commitsFile: "commits.txt",
    changelogFile: "CHANGELOG.md",
    dryRun: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--version-file") args.versionFile = argv[++i];
    else if (a === "--commits-file") args.commitsFile = argv[++i];
    else if (a === "--changelog-file") args.changelogFile = argv[++i];
    else if (a === "--date") args.date = argv[++i];
    else if (a === "--dry-run") args.dryRun = true;
    else throw new Error(`Unknown argument: ${a}`);
  }
  return args;
}

function main(): void {
  const args = parseArgs(process.argv.slice(2));
  if (!existsSync(args.versionFile))
    throw new Error(`Version file not found: ${args.versionFile}`);
  if (!existsSync(args.commitsFile))
    throw new Error(`Commits file not found: ${args.commitsFile}`);

  const versionContent = readFileSync(args.versionFile, "utf8");
  const currentVersion = readVersionFromContent(versionContent, args.versionFile);
  const commitLog = readFileSync(args.commitsFile, "utf8");

  const result = bump(currentVersion, commitLog, args.date);

  if (!args.dryRun) {
    const newContent = writeVersionToContent(
      versionContent,
      args.versionFile,
      result.newVersion,
    );
    writeFileSync(args.versionFile, newContent);
    const existing = existsSync(args.changelogFile)
      ? readFileSync(args.changelogFile, "utf8")
      : "# Changelog\n\n";
    writeFileSync(args.changelogFile, existing + result.changelog + "\n");
  }

  // Stable, parseable output for CI consumption.
  console.log(`OLD_VERSION=${result.oldVersion}`);
  console.log(`NEW_VERSION=${result.newVersion}`);
  console.log(`BUMP_TYPE=${result.bumpType}`);
  console.log("---CHANGELOG---");
  console.log(result.changelog);
  console.log("---END_CHANGELOG---");

  // Also append to GITHUB_OUTPUT if available (for use as Action output).
  const ghOut = process.env.GITHUB_OUTPUT;
  if (ghOut) {
    appendFileSync(
      ghOut,
      `old_version=${result.oldVersion}\nnew_version=${result.newVersion}\nbump_type=${result.bumpType}\n`,
    );
  }
}

try {
  main();
} catch (err) {
  const msg = err instanceof Error ? err.message : String(err);
  console.error(`ERROR: ${msg}`);
  process.exit(1);
}
