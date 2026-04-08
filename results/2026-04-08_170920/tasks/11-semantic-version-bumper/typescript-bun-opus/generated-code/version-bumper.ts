// Semantic version bumper — core logic.
// Parses conventional commits, determines version bump type,
// updates package.json, and generates changelog entries.

import { readFile, writeFile } from "fs/promises";

// ─── Types ───────────────────────────────────────────────────────────

export interface ParsedCommit {
  hash: string;
  type: string;
  scope: string | undefined;
  breaking: boolean;
  description: string;
}

export interface SemVer {
  major: number;
  minor: number;
  patch: number;
}

export type BumpType = "major" | "minor" | "patch" | "none";

// ─── Commit parsing ──────────────────────────────────────────────────

// Matches: <hash> <type>(<scope>)?!?: <description>
const COMMIT_RE = /^([a-z0-9]+)\s+(\w+)(?:\(([^)]+)\))?(!)?\s*:\s*(.+)/;

/**
 * Parse a single git log line into a structured commit object.
 * Returns null if the line is not a conventional commit.
 */
export function parseCommit(line: string): ParsedCommit | null {
  // Only match the first line for type/scope/description
  const firstLine = line.split("\n")[0];
  const match = firstLine.match(COMMIT_RE);
  if (!match) return null;

  const [, hash, type, scope, bang, description] = match;
  // Check for BREAKING CHANGE in the full message body/footer
  const hasBreakingFooter = line.includes("BREAKING CHANGE:");

  return {
    hash,
    type,
    scope: scope || undefined,
    breaking: bang === "!" || hasBreakingFooter,
    description: description.trim(),
  };
}

// ─── Version parsing ─────────────────────────────────────────────────

const SEMVER_RE = /^v?(\d+)\.(\d+)\.(\d+)$/;

/** Parse a semver string like "1.2.3" or "v1.2.3" into components. */
export function parseVersion(version: string): SemVer {
  const match = version.trim().match(SEMVER_RE);
  if (!match) {
    throw new Error(`Invalid semantic version: "${version}"`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

// ─── Bump type determination ─────────────────────────────────────────

/**
 * Given an array of raw commit log lines, determine the highest-priority
 * bump type: major > minor > patch > none.
 */
export function determineBumpType(commitLines: string[]): BumpType {
  let hasMinor = false;
  let hasPatch = false;

  for (const line of commitLines) {
    const parsed = parseCommit(line);
    if (!parsed) continue;

    if (parsed.breaking) return "major";
    if (parsed.type === "feat") hasMinor = true;
    if (parsed.type === "fix") hasPatch = true;
  }

  if (hasMinor) return "minor";
  if (hasPatch) return "patch";
  return "none";
}

// ─── Version bumping ─────────────────────────────────────────────────

/** Apply a bump type to a version string and return the new version. */
export function bumpVersion(version: string, bump: BumpType): string {
  const v = parseVersion(version);
  switch (bump) {
    case "major":
      return `${v.major + 1}.0.0`;
    case "minor":
      return `${v.major}.${v.minor + 1}.0`;
    case "patch":
      return `${v.major}.${v.minor}.${v.patch + 1}`;
    case "none":
      return `${v.major}.${v.minor}.${v.patch}`;
  }
}

// ─── Changelog generation ────────────────────────────────────────────

/** Generate a markdown changelog section for the given version and commits. */
export function generateChangelog(version: string, commitLines: string[]): string {
  const parsed = commitLines.map(parseCommit).filter((c): c is ParsedCommit => c !== null);

  const features = parsed.filter((c) => c.type === "feat");
  const fixes = parsed.filter((c) => c.type === "fix");
  const breaking = parsed.filter((c) => c.breaking);

  const lines: string[] = [];
  const date = new Date().toISOString().split("T")[0];
  lines.push(`## ${version} (${date})`);
  lines.push("");

  if (breaking.length > 0) {
    lines.push("### BREAKING CHANGES");
    lines.push("");
    for (const c of breaking) {
      const scope = c.scope ? `**${c.scope}:** ` : "";
      lines.push(`- ${scope}${c.description} (${c.hash})`);
    }
    lines.push("");
  }

  if (features.length > 0) {
    lines.push("### Features");
    lines.push("");
    for (const c of features) {
      const scope = c.scope ? `**${c.scope}:** ` : "";
      lines.push(`- ${scope}${c.description} (${c.hash})`);
    }
    lines.push("");
  }

  if (fixes.length > 0) {
    lines.push("### Bug Fixes");
    lines.push("");
    for (const c of fixes) {
      const scope = c.scope ? `**${c.scope}:** ` : "";
      lines.push(`- ${scope}${c.description} (${c.hash})`);
    }
    lines.push("");
  }

  return lines.join("\n");
}

// ─── Package.json read/write ─────────────────────────────────────────

/** Read the version field from a package.json file. */
export async function readVersionFromPackageJson(path: string): Promise<string> {
  const raw = await readFile(path, "utf-8");
  const pkg = JSON.parse(raw);
  if (!pkg.version) {
    throw new Error(`${path}: no version field found in package.json`);
  }
  return pkg.version;
}

/** Write a new version to a package.json file, preserving formatting. */
export async function writeVersionToPackageJson(path: string, version: string): Promise<void> {
  const raw = await readFile(path, "utf-8");
  const pkg = JSON.parse(raw);
  pkg.version = version;
  // Detect indent from existing file (default 2 spaces)
  const indent = raw.match(/^\s+/m)?.[0] || "  ";
  await writeFile(path, JSON.stringify(pkg, null, indent.length) + "\n");
}
