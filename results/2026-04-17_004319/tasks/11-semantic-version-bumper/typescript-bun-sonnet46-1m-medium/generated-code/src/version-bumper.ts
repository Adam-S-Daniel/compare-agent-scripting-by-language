// Semantic version bumper — parses conventional commits and bumps semver accordingly

import { readFileSync, writeFileSync } from "fs";
import type { Commit, BumpResult, VersionFile } from "./types";

// Regex for a valid semver string
const SEMVER_RE = /^(\d+)\.(\d+)\.(\d+)(?:-[a-zA-Z0-9.]+)?(?:\+[a-zA-Z0-9.]+)?$/;

// Conventional commit prefix patterns
const COMMIT_TYPE_RE = /^([a-z]+)(\!)?(?:\([^)]*\))?(\!)?:\s+(.+)/;

export function parseVersion(content: string, format: "package.json" | "version.txt"): string {
  let version: string;

  if (format === "package.json") {
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(content);
    } catch {
      throw new Error("Invalid JSON in package.json");
    }
    if (typeof parsed.version !== "string" || !parsed.version) {
      throw new Error("No version field found in package.json");
    }
    version = parsed.version;
  } else {
    version = content.trim();
  }

  if (!SEMVER_RE.test(version)) {
    throw new Error(`Invalid semver string: "${version}"`);
  }

  return version;
}

export function parseCommits(gitLog: string): Commit[] {
  if (!gitLog.trim()) return [];

  return gitLog
    .split("\n")
    .filter((line) => line.trim())
    .map((line): Commit => {
      // git log --oneline format: "<hash> <message>"
      const spaceIdx = line.indexOf(" ");
      const hash = spaceIdx !== -1 ? line.slice(0, spaceIdx) : line;
      const message = spaceIdx !== -1 ? line.slice(spaceIdx + 1) : "";

      return parseCommitMessage(hash, message);
    });
}

function parseCommitMessage(hash: string, message: string): Commit {
  const firstLine = message.split("\n")[0];
  const match = firstLine.match(COMMIT_TYPE_RE);

  if (!match) {
    return { hash, message, type: "other", breaking: false };
  }

  const rawType = match[1];
  const bangAfterType = match[2] === "!";
  const bangAfterScope = match[3] === "!";
  const isBreakingBang = bangAfterType || bangAfterScope;

  // BREAKING CHANGE footer also marks a breaking commit
  const hasBreakingFooter = message.includes("BREAKING CHANGE:");
  const breaking = isBreakingBang || hasBreakingFooter;

  const type = normalizeType(rawType);

  return { hash, message, type, breaking };
}

function normalizeType(raw: string): Commit["type"] {
  switch (raw) {
    case "feat": return "feat";
    case "fix": return "fix";
    case "chore": return "chore";
    case "docs": return "docs";
    case "style": return "style";
    case "refactor": return "refactor";
    case "test": return "test";
    default: return "other";
  }
}

export function determineVersionBump(commits: Commit[]): "major" | "minor" | "patch" | "none" {
  if (commits.some((c) => c.breaking)) return "major";
  if (commits.some((c) => c.type === "feat")) return "minor";
  if (commits.some((c) => c.type === "fix")) return "patch";
  return "none";
}

export function bumpVersion(version: string, bump: "major" | "minor" | "patch" | "none"): string {
  const match = version.match(SEMVER_RE);
  if (!match) throw new Error(`Invalid semver: "${version}"`);

  let [, maj, min, pat] = match.map(Number);

  switch (bump) {
    case "major":
      return `${maj + 1}.0.0`;
    case "minor":
      return `${maj}.${min + 1}.0`;
    case "patch":
      return `${maj}.${min}.${pat + 1}`;
    case "none":
      return version;
  }
}

export function generateChangelog(
  prevVersion: string,
  newVersion: string,
  commits: Commit[]
): string {
  const date = new Date().toISOString().slice(0, 10);
  const lines: string[] = [`## [${newVersion}] - ${date}`, ""];

  const breaking = commits.filter((c) => c.breaking);
  const features = commits.filter((c) => c.type === "feat" && !c.breaking);
  const fixes = commits.filter((c) => c.type === "fix");

  if (breaking.length > 0) {
    lines.push("### Breaking Changes", "");
    breaking.forEach((c) => {
      const firstLine = c.message.split("\n")[0];
      lines.push(`- ${firstLine}`);
    });
    lines.push("");
  }

  if (features.length > 0) {
    lines.push("### Features", "");
    features.forEach((c) => {
      const firstLine = c.message.split("\n")[0];
      lines.push(`- ${firstLine}`);
    });
    lines.push("");
  }

  if (fixes.length > 0) {
    lines.push("### Bug Fixes", "");
    fixes.forEach((c) => {
      const firstLine = c.message.split("\n")[0];
      lines.push(`- ${firstLine}`);
    });
    lines.push("");
  }

  lines.push(`**Full Changelog**: ${prevVersion}...${newVersion}`);

  return lines.join("\n");
}

export function bumpVersionFile(
  filePath: string,
  format: "package.json" | "version.txt",
  commits: Commit[]
): BumpResult {
  const content = readFileSync(filePath, "utf8");
  const previousVersion = parseVersion(content, format);
  const bumpType = determineVersionBump(commits);
  const newVersion = bumpVersion(previousVersion, bumpType);
  const changelog = generateChangelog(previousVersion, newVersion, commits);

  if (bumpType !== "none") {
    if (format === "package.json") {
      const pkg = JSON.parse(content);
      pkg.version = newVersion;
      writeFileSync(filePath, JSON.stringify(pkg, null, 2) + "\n");
    } else {
      writeFileSync(filePath, newVersion + "\n");
    }
  }

  return { previousVersion, newVersion, bumpType, commits, changelog };
}
