// Core library for the semantic version bumper.
// Pure functions — no file I/O here so each piece is unit-testable.

export interface Version {
  major: number;
  minor: number;
  patch: number;
}

export interface Commit {
  type: string;       // conventional commit type: feat, fix, chore, etc.
  breaking: boolean;  // true when `!` appears or a BREAKING CHANGE footer is present
  subject: string;    // human-readable commit subject
}

export type BumpType = "major" | "minor" | "patch" | "none";

const VERSION_RE = /(\d+)\.(\d+)\.(\d+)/;

// Extract a semver from either a bare "x.y.z" file or a package.json string.
export function parseVersion(content: string): Version {
  const trimmed = content.trim();
  // Prefer a parsed `version` field if this is JSON — avoids matching other numbers.
  try {
    const json = JSON.parse(trimmed);
    if (json && typeof json.version === "string") {
      return parseVersion(json.version);
    }
  } catch {
    // not JSON — fall through to raw regex match
  }
  const m = trimmed.match(VERSION_RE);
  if (!m) throw new Error(`invalid version: ${content}`);
  return { major: Number(m[1]), minor: Number(m[2]), patch: Number(m[3]) };
}

// Parse a newline-separated log of commit messages (one per line, or separated
// by a blank-line delimiter for bodies). Conventional commits only — other
// lines are silently ignored so merge commits don't trigger bumps.
const HEADER_RE = /^(\w+)(?:\([^)]*\))?(!)?:\s*(.+)$/;

export function parseCommits(log: string): Commit[] {
  // Line-oriented parser: every line matching the conventional-commit header
  // regex starts a new commit. Subsequent non-header lines are treated as the
  // body of the most recent commit so a `BREAKING CHANGE:` footer can flip its
  // breaking flag. Non-matching lines before any commit (e.g. merge commits)
  // are dropped.
  const lines = log.split("\n");
  const out: Commit[] = [];
  for (const raw of lines) {
    const m = raw.match(HEADER_RE);
    if (m) {
      const [, type, bang, subject] = m;
      out.push({ type: type!, breaking: !!bang, subject: subject!.trim() });
    } else if (out.length > 0 && /^BREAKING CHANGE:/.test(raw.trim())) {
      out[out.length - 1]!.breaking = true;
    }
  }
  return out;
}

export function determineBump(commits: Commit[]): BumpType {
  if (commits.some((c) => c.breaking)) return "major";
  if (commits.some((c) => c.type === "feat")) return "minor";
  if (commits.some((c) => c.type === "fix")) return "patch";
  return "none";
}

export function bumpVersion(v: Version, bump: BumpType): string {
  switch (bump) {
    case "major": return `${v.major + 1}.0.0`;
    case "minor": return `${v.major}.${v.minor + 1}.0`;
    case "patch": return `${v.major}.${v.minor}.${v.patch + 1}`;
    case "none":  return `${v.major}.${v.minor}.${v.patch}`;
  }
}

export function generateChangelog(version: string, commits: Commit[]): string {
  const feats = commits.filter((c) => c.type === "feat" && !c.breaking);
  const fixes = commits.filter((c) => c.type === "fix" && !c.breaking);
  const breaks = commits.filter((c) => c.breaking);
  const others = commits.filter(
    (c) => !c.breaking && c.type !== "feat" && c.type !== "fix",
  );
  const lines: string[] = [`## ${version}`, ""];
  if (breaks.length) {
    lines.push("### BREAKING CHANGES", "");
    for (const c of breaks) lines.push(`- ${c.subject}`);
    lines.push("");
  }
  if (feats.length) {
    lines.push("### Features", "");
    for (const c of feats) lines.push(`- ${c.subject}`);
    lines.push("");
  }
  if (fixes.length) {
    lines.push("### Bug Fixes", "");
    for (const c of fixes) lines.push(`- ${c.subject}`);
    lines.push("");
  }
  if (others.length) {
    lines.push("### Other", "");
    for (const c of others) lines.push(`- ${c.type}: ${c.subject}`);
    lines.push("");
  }
  return lines.join("\n");
}

// Apply the new version back to either a bare version file or a package.json.
export function applyVersionToFile(content: string, newVersion: string): string {
  const trimmed = content.trim();
  try {
    const json = JSON.parse(trimmed);
    if (json && typeof json.version === "string") {
      json.version = newVersion;
      return JSON.stringify(json, null, 2) + "\n";
    }
  } catch {
    // not JSON
  }
  return newVersion + "\n";
}
