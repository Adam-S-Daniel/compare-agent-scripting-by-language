// CLI: reads package.json (or --version-file), reads commit log (--commits-file
// or git log), bumps the version, writes the file + CHANGELOG.md, prints the
// new version on stdout.
import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import {
  bumpVersion,
  determineBump,
  classifyCommit,
  generateChangelog,
  type Commit,
} from "./bumper.ts";

interface Args {
  versionFile: string;
  commitsFile?: string;
  changelogFile: string;
  date: string;
  dryRun: boolean;
}

function parseArgs(argv: string[]): Args {
  const args: Args = {
    versionFile: "package.json",
    changelogFile: "CHANGELOG.md",
    date: new Date().toISOString().slice(0, 10),
    dryRun: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    const next = () => argv[++i] ?? (() => { throw new Error(`Missing value for ${a}`); })();
    if (a === "--version-file") args.versionFile = next();
    else if (a === "--commits-file") args.commitsFile = next();
    else if (a === "--changelog-file") args.changelogFile = next();
    else if (a === "--date") args.date = next();
    else if (a === "--dry-run") args.dryRun = true;
    else if (a === "--help" || a === "-h") {
      console.log("Usage: bump [--version-file f] [--commits-file f] [--changelog-file f] [--date YYYY-MM-DD] [--dry-run]");
      process.exit(0);
    } else throw new Error(`Unknown argument: ${a}`);
  }
  return args;
}

// Commits fixture format: one commit per record, records separated by a line
// with only "---". Each record's first line is the subject; remaining lines
// are the body.
function parseCommitsFile(text: string): Commit[] {
  const out: Commit[] = [];
  const records = text.split(/^---\s*$/m).map(r => r.trim()).filter(Boolean);
  for (const record of records) {
    const lines = record.split("\n");
    const subject = lines[0]!.trim();
    const body = lines.slice(1).join("\n").trim();
    if (subject) out.push({ subject, body });
  }
  return out;
}

async function readCurrentVersion(path: string): Promise<{ version: string; isJson: boolean; json?: any }> {
  if (!existsSync(path)) throw new Error(`Version file not found: ${path}`);
  const raw = await readFile(path, "utf8");
  if (path.endsWith(".json")) {
    const json = JSON.parse(raw);
    if (typeof json.version !== "string") {
      throw new Error(`Key "version" missing or non-string in ${path}`);
    }
    return { version: json.version, isJson: true, json };
  }
  return { version: raw.trim(), isJson: false };
}

async function writeVersion(path: string, newVersion: string, isJson: boolean, json: any): Promise<void> {
  if (isJson) {
    json.version = newVersion;
    await writeFile(path, JSON.stringify(json, null, 2) + "\n");
  } else {
    await writeFile(path, newVersion + "\n");
  }
}

export async function main(argv: string[]): Promise<string> {
  const args = parseArgs(argv);

  const { version: current, isJson, json } = await readCurrentVersion(args.versionFile);

  let commits: Commit[];
  if (args.commitsFile) {
    commits = parseCommitsFile(await readFile(args.commitsFile, "utf8"));
  } else {
    // Fall back to `git log` when no fixture is provided.
    const proc = Bun.spawnSync(["git", "log", "--pretty=format:%s%n%b%n---"]);
    if (proc.exitCode !== 0) throw new Error("git log failed");
    commits = parseCommitsFile(proc.stdout.toString());
  }

  if (commits.length === 0) {
    throw new Error("No commits found to analyze");
  }

  const messages = commits.map(c => c.body ? `${c.subject}\n\n${c.body}` : c.subject);
  const level = determineBump(messages);
  const next = bumpVersion(current, level);

  console.log(`current=${current}`);
  console.log(`bump=${level}`);
  console.log(`next=${next}`);

  if (level === "none") {
    console.log("No releasable changes; version unchanged.");
    return next;
  }

  const entry = generateChangelog(next, commits, args.date);

  if (args.dryRun) {
    console.log("--- CHANGELOG ENTRY ---");
    console.log(entry);
    return next;
  }

  await writeVersion(args.versionFile, next, isJson, json);

  let prior = "";
  if (existsSync(args.changelogFile)) prior = await readFile(args.changelogFile, "utf8");
  const header = "# Changelog\n\n";
  const body = prior.startsWith("# Changelog") ? prior.slice(header.length) : prior;
  await writeFile(args.changelogFile, header + entry + (body ? "\n" + body : ""));

  console.log(`Wrote ${args.versionFile} and ${args.changelogFile}`);
  console.log(`VERSION=${next}`);
  return next;
}

// Note: classifyCommit is re-exported so consumers don't need to import it
// from bumper.ts separately. Currently unused externally but kept for clarity.
export { classifyCommit };

if (import.meta.main) {
  main(process.argv.slice(2)).catch(err => {
    console.error("Error:", err.message);
    process.exit(1);
  });
}
