// Semantic-version bumper library.
//
// Pure-ish functions (parseVersion, classifyCommit, decideBump, ...) are easy
// to unit test. `runBump` is the only function that touches the filesystem.
// Git interaction lives in the CLI (bump.ts), which calls into this module
// with already-collected commit data — so tests don't need a real git repo.

import { readFileSync, writeFileSync, existsSync } from "node:fs";

export interface SemVer {
  major: number;
  minor: number;
  patch: number;
}

export type BumpType = "major" | "minor" | "patch" | "none";

export interface Commit {
  hash: string;
  message: string;
}

const SEMVER_RE = /^(\d+)\.(\d+)\.(\d+)$/;

export function parseVersion(s: string): SemVer {
  const m = s.trim().match(SEMVER_RE);
  if (!m) throw new Error(`Invalid semver: "${s}"`);
  return { major: Number(m[1]), minor: Number(m[2]), patch: Number(m[3]) };
}

export function formatVersion(v: SemVer): string {
  return `${v.major}.${v.minor}.${v.patch}`;
}

// Conventional Commits classification.
// Header form:  type(scope)?!?: description
//   - "!" before the colon  -> breaking (major)
//   - footer "BREAKING CHANGE:" / "BREAKING-CHANGE:" -> breaking (major)
//   - feat -> minor; fix -> patch; everything else -> none
const HEADER_RE = /^(\w+)(\([^)]*\))?(!)?:/;

export function classifyCommit(message: string): BumpType {
  const header = message.split(/\r?\n/, 1)[0] ?? "";
  const match = header.match(HEADER_RE);
  const body = message.slice(header.length);
  if (/(^|\n)BREAKING[ -]CHANGE:/i.test(body)) return "major";
  if (!match) return "none";
  const [, type, , bang] = match;
  if (bang === "!") return "major";
  if (type.toLowerCase() === "feat") return "minor";
  if (type.toLowerCase() === "fix") return "patch";
  return "none";
}

const PRECEDENCE: Record<BumpType, number> = { none: 0, patch: 1, minor: 2, major: 3 };

export function decideBump(messages: string[]): BumpType {
  let best: BumpType = "none";
  for (const m of messages) {
    const c = classifyCommit(m);
    if (PRECEDENCE[c] > PRECEDENCE[best]) best = c;
  }
  return best;
}

export function bumpVersion(current: string, bump: BumpType): string {
  const v = parseVersion(current);
  switch (bump) {
    case "major":
      return formatVersion({ major: v.major + 1, minor: 0, patch: 0 });
    case "minor":
      return formatVersion({ major: v.major, minor: v.minor + 1, patch: 0 });
    case "patch":
      return formatVersion({ major: v.major, minor: v.minor, patch: v.patch + 1 });
    case "none":
      return formatVersion(v);
  }
}

// Fixture/log format: one commit per line, "<hash>|<subject>".
// For multi-line messages, "\\n" in the line is interpreted as a real newline
// (so fixtures can encode BREAKING CHANGE footers on a single line).
export function parseCommitLog(text: string): Commit[] {
  const out: Commit[] = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    const idx = line.indexOf("|");
    if (idx === -1) continue;
    const hash = line.slice(0, idx);
    const message = line.slice(idx + 1).replace(/\\n/g, "\n");
    out.push({ hash, message });
  }
  return out;
}

export function generateChangelogEntry(
  newVersion: string,
  commits: Commit[],
  date: string,
): string {
  const breaking: Commit[] = [];
  const features: Commit[] = [];
  const fixes: Commit[] = [];
  const other: Commit[] = [];
  for (const c of commits) {
    const cls = classifyCommit(c.message);
    if (cls === "major") breaking.push(c);
    else if (cls === "minor") features.push(c);
    else if (cls === "patch") fixes.push(c);
    else other.push(c);
  }
  const lines: string[] = [`## ${newVersion} - ${date}`, ""];
  const section = (title: string, items: Commit[]) => {
    if (items.length === 0) return;
    lines.push(`### ${title}`, "");
    for (const c of items) {
      const subject = c.message.split(/\r?\n/, 1)[0];
      lines.push(`- ${subject} (${c.hash.slice(0, 7)})`);
    }
    lines.push("");
  };
  section("Breaking Changes", breaking);
  section("Features", features);
  section("Fixes", fixes);
  section("Other", other);
  return lines.join("\n");
}

export interface RunBumpOptions {
  versionFilePath: string;
  commitLog: string;
  changelogPath: string;
  date: string;
}

export interface RunBumpResult {
  previousVersion: string;
  newVersion: string;
  bump: BumpType;
  commits: Commit[];
}

// Reads the version file (package.json or plain-text VERSION), parses the
// commit log, decides the bump, and (if non-zero) writes the file back and
// prepends a changelog entry. Pure I/O happens here so the CLI is a thin shim.
export function runBump(opts: RunBumpOptions): RunBumpResult {
  if (!existsSync(opts.versionFilePath)) {
    throw new Error(`version file not found: ${opts.versionFilePath}`);
  }
  const raw = readFileSync(opts.versionFilePath, "utf8");
  const isJson = opts.versionFilePath.endsWith(".json");
  let previousVersion: string;
  let pkg: Record<string, unknown> | undefined;
  if (isJson) {
    try {
      pkg = JSON.parse(raw) as Record<string, unknown>;
    } catch (e) {
      throw new Error(`could not parse JSON version file: ${(e as Error).message}`);
    }
    if (typeof pkg.version !== "string") {
      throw new Error(`version file ${opts.versionFilePath} has no "version" string`);
    }
    previousVersion = pkg.version;
  } else {
    previousVersion = raw.trim();
  }
  parseVersion(previousVersion); // validate up front

  const commits = parseCommitLog(opts.commitLog);
  const bump = decideBump(commits.map((c) => c.message));
  const newVersion = bumpVersion(previousVersion, bump);

  if (bump !== "none") {
    if (isJson && pkg) {
      pkg.version = newVersion;
      writeFileSync(opts.versionFilePath, JSON.stringify(pkg, null, 2) + "\n");
    } else {
      writeFileSync(opts.versionFilePath, newVersion + "\n");
    }
    const entry = generateChangelogEntry(newVersion, commits, opts.date);
    const existing = existsSync(opts.changelogPath)
      ? readFileSync(opts.changelogPath, "utf8")
      : "# Changelog\n\n";
    writeFileSync(opts.changelogPath, existing + entry + "\n");
  }

  return { previousVersion, newVersion, bump, commits };
}
