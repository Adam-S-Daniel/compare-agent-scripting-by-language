// bumper.ts
// Semantic version bumper: reads commits (conventional format), determines
// bump type (feat->minor, fix->patch, breaking->major), updates version file,
// and generates a CHANGELOG entry.

import { readFileSync, writeFileSync, existsSync } from "fs";
import { join } from "path";

// --- Types ---

export interface Commit {
  hash: string;
  type: string;
  scope?: string;
  message: string;
  breaking: boolean;
}

export type BumpType = "major" | "minor" | "patch" | "none";

export interface BumpResult {
  oldVersion: string;
  newVersion: string;
  bumpType: BumpType;
  commits: Commit[];
  changelog: string;
}

// --- Core parsing ---

// Parses a single conventional commit line:
// Format: <hash> <type>[(<scope>)][!]: <message>
export function parseCommit(line: string): Commit {
  const parts = line.match(/^([^\s]+)\s+(.+)$/);
  if (!parts) {
    return { hash: "", type: "unknown", message: line, breaking: false };
  }

  const hash = parts[1];
  const rest = parts[2];

  // BREAKING CHANGE in message body or ! after type/scope signals a major bump
  const hasBreakingMarker = /^[^:]+!:/.test(rest);
  const hasBreakingMessage = /breaking change/i.test(rest);
  const breaking = hasBreakingMarker || hasBreakingMessage;

  // type(scope)!: message  OR  type!: message  OR  type: message
  const typeMatch = rest.match(/^(\w+)(?:\(([^)]+)\))?!?:\s*(.+)$/);
  if (!typeMatch) {
    return { hash, type: "unknown", message: rest, breaking };
  }

  return {
    hash,
    type: typeMatch[1],
    scope: typeMatch[2] ?? undefined,
    message: typeMatch[3],
    breaking,
  };
}

// --- Bump type determination ---

// Precedence: major > minor > patch > none
export function determineBumpType(commits: Commit[]): BumpType {
  if (commits.length === 0) return "none";
  if (commits.some((c) => c.breaking)) return "major";
  if (commits.some((c) => c.type === "feat")) return "minor";
  if (commits.some((c) => c.type === "fix")) return "patch";
  return "none";
}

// --- Version manipulation ---

function parseVersion(version: string): [number, number, number] {
  const clean = version.replace(/^v/, "");
  const parts = clean.split(".").map(Number);
  if (parts.length !== 3 || parts.some((n) => isNaN(n))) {
    throw new Error(`Invalid semver string: "${version}"`);
  }
  return [parts[0], parts[1], parts[2]];
}

export function bumpVersion(version: string, bumpType: BumpType): string {
  if (bumpType === "none") return version;
  const [major, minor, patch] = parseVersion(version);
  switch (bumpType) {
    case "major": return `${major + 1}.0.0`;
    case "minor": return `${major}.${minor + 1}.0`;
    case "patch": return `${major}.${minor}.${patch + 1}`;
  }
}

// --- Changelog generation ---

export function generateChangelog(newVersion: string, commits: Commit[]): string {
  const date = new Date().toISOString().split("T")[0];
  const lines: string[] = [`## [${newVersion}] - ${date}`];

  const breaking = commits.filter((c) => c.breaking);
  const features = commits.filter((c) => !c.breaking && c.type === "feat");
  const fixes = commits.filter((c) => !c.breaking && c.type === "fix");
  const others = commits.filter((c) => !c.breaking && c.type !== "feat" && c.type !== "fix");

  function formatEntry(c: Commit): string {
    const prefix = c.scope ? `**${c.scope}**: ` : "";
    return `- ${prefix}${c.message} (${c.hash.slice(0, 7)})`;
  }

  if (breaking.length > 0) {
    lines.push("", "### Breaking Changes");
    breaking.forEach((c) => lines.push(formatEntry(c)));
  }
  if (features.length > 0) {
    lines.push("", "### Features");
    features.forEach((c) => lines.push(formatEntry(c)));
  }
  if (fixes.length > 0) {
    lines.push("", "### Bug Fixes");
    fixes.forEach((c) => lines.push(formatEntry(c)));
  }
  if (others.length > 0) {
    lines.push("", "### Other Changes");
    others.forEach((c) => lines.push(formatEntry(c)));
  }

  return lines.join("\n");
}

// --- File I/O ---

export function parseCommitsFile(commitsPath: string): Commit[] {
  if (!existsSync(commitsPath)) return [];
  const content = readFileSync(commitsPath, "utf-8").trim();
  if (!content) return [];
  return content.split("\n").filter((l) => l.trim()).map(parseCommit);
}

function readVersion(dir: string): { version: string; source: "package.json" | "version.txt" } {
  const pkgPath = join(dir, "package.json");
  const versionPath = join(dir, "version.txt");

  if (existsSync(pkgPath)) {
    const pkg = JSON.parse(readFileSync(pkgPath, "utf-8")) as { version: string };
    return { version: pkg.version, source: "package.json" };
  }
  if (existsSync(versionPath)) {
    return { version: readFileSync(versionPath, "utf-8").trim(), source: "version.txt" };
  }
  throw new Error("No version file found (package.json or version.txt)");
}

function writeVersion(
  dir: string,
  source: "package.json" | "version.txt",
  newVersion: string
): void {
  if (source === "package.json") {
    const pkgPath = join(dir, "package.json");
    const pkg = JSON.parse(readFileSync(pkgPath, "utf-8")) as Record<string, unknown>;
    pkg["version"] = newVersion;
    writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n");
  } else {
    writeFileSync(join(dir, "version.txt"), newVersion + "\n");
  }
}

// --- Main bump function ---

export function bump(dir: string, commitsPath: string): BumpResult {
  const { version: oldVersion, source } = readVersion(dir);
  const commits = parseCommitsFile(commitsPath);
  const bumpType = determineBumpType(commits);
  const newVersion = bumpVersion(oldVersion, bumpType);
  const changelog = generateChangelog(newVersion, commits);

  if (bumpType !== "none") {
    writeVersion(dir, source, newVersion);

    const changelogPath = join(dir, "CHANGELOG.md");
    const existing = existsSync(changelogPath) ? readFileSync(changelogPath, "utf-8") : "";
    writeFileSync(changelogPath, changelog + "\n\n" + existing);
  }

  return { oldVersion, newVersion, bumpType, commits, changelog };
}

// --- CLI entry point ---

if (import.meta.main) {
  const dir = process.argv[2] ?? ".";
  const commitsPath = process.argv[3] ?? join(dir, "commits.txt");

  try {
    const result = bump(dir, commitsPath);
    console.log(`OLD_VERSION=${result.oldVersion}`);
    console.log(`NEW_VERSION=${result.newVersion}`);
    console.log(`BUMP_TYPE=${result.bumpType}`);
    console.log("");
    console.log(result.changelog);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }
}
