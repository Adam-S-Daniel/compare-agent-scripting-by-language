// Semantic version bumper — core logic
// Implements: parse, analyze commits, bump, and changelog generation

export interface SemVer {
  major: number;
  minor: number;
  patch: number;
}

export interface Commit {
  type: string;
  message: string;
  breaking: boolean;
}

export type BumpType = "major" | "minor" | "patch" | "none";

// Parse a "X.Y.Z" string into a SemVer object
export function parseVersion(version: string): SemVer {
  const match = version.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) throw new Error(`Invalid semantic version: "${version}"`);
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

// Parse a conventional commit message into a Commit
// Formats: "type: message", "type!: message", "type: message\n\nBREAKING CHANGE: ..."
export function parseConventionalCommit(raw: string): Commit {
  // Split message body from header
  const [header, ...bodyLines] = raw.split("\n");
  const body = bodyLines.join("\n");

  // Conventional commit header regex: type(scope)!: description
  const conventionalRegex = /^([a-zA-Z]+)(\([^)]+\))?(!)?\s*:\s*(.+)$/;
  const match = header.match(conventionalRegex);

  if (!match) {
    return { type: "unknown", message: raw.trim(), breaking: false };
  }

  const type = match[1];
  const bangBreaking = match[3] === "!";
  const message = match[4].trim();
  const footerBreaking = body.includes("BREAKING CHANGE:");

  return {
    type,
    message,
    breaking: bangBreaking || footerBreaking,
  };
}

// Determine the highest bump type from a list of commits
export function determineBumpType(commits: Commit[]): BumpType {
  if (commits.some((c) => c.breaking)) return "major";
  if (commits.some((c) => c.type === "feat")) return "minor";
  if (commits.some((c) => c.type === "fix")) return "patch";
  return "none";
}

// Apply a bump to a version string, returning the new version string
export function bumpVersion(version: string, bumpType: BumpType): string {
  const v = parseVersion(version);
  if (bumpType === "major") return `${v.major + 1}.0.0`;
  if (bumpType === "minor") return `${v.major}.${v.minor + 1}.0`;
  if (bumpType === "patch") return `${v.major}.${v.minor}.${v.patch + 1}`;
  return version;
}

const TYPE_LABELS: Record<string, string> = {
  feat: "Features",
  fix: "Bug Fixes",
  perf: "Performance",
  refactor: "Refactoring",
  docs: "Documentation",
  chore: "Chores",
};

// Generate a markdown changelog entry for a new version
export function generateChangelog(
  version: string,
  commits: Commit[],
  date: string
): string {
  const lines: string[] = [`## [${version}] - ${date}`, ""];

  // Group commits by type
  const groups: Record<string, Commit[]> = {};
  for (const commit of commits) {
    const key = commit.type;
    if (!groups[key]) groups[key] = [];
    groups[key].push(commit);
  }

  const orderedTypes = ["feat", "fix", "perf", "refactor", "docs", "chore"];
  const allTypes = [
    ...orderedTypes.filter((t) => groups[t]),
    ...Object.keys(groups).filter((t) => !orderedTypes.includes(t)),
  ];

  for (const type of allTypes) {
    const label = TYPE_LABELS[type] ?? type;
    lines.push(`### ${label}`, "");
    for (const commit of groups[type]) {
      const breaking = commit.breaking ? " **(BREAKING)**" : "";
      lines.push(`- ${commit.message}${breaking}`);
    }
    lines.push("");
  }

  return lines.join("\n");
}

// Read the "version" field from a package.json string
export function readVersionFromPackageJson(content: string): string {
  const pkg = JSON.parse(content); // throws on invalid JSON
  if (!pkg.version) throw new Error("No version field in package.json");
  return pkg.version as string;
}

// Write a new version back into a package.json string (preserves formatting)
export function writeVersionToPackageJson(content: string, newVersion: string): string {
  const pkg = JSON.parse(content);
  pkg.version = newVersion;
  return JSON.stringify(pkg, null, 2) + "\n";
}
