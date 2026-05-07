// Semantic version bumper — parses versions, determines bump type from
// conventional commits, updates version files, and generates changelogs.

export interface SemanticVersion {
  major: number;
  minor: number;
  patch: number;
}

export type BumpType = "major" | "minor" | "patch" | "none";

export interface CommitInfo {
  type: string;
  message: string;
  breaking: boolean;
}

export interface ChangelogEntry {
  version: string;
  date: string;
  sections: Record<string, string[]>;
}

export function parseVersion(versionString: string): SemanticVersion {
  const cleaned = versionString.trim().replace(/^v/, "");
  const match = cleaned.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Invalid semantic version: "${versionString}"`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

export function formatVersion(version: SemanticVersion): string {
  return `${version.major}.${version.minor}.${version.patch}`;
}

export function parseCommit(commitLine: string): CommitInfo {
  const trimmed = commitLine.trim();
  if (!trimmed) {
    return { type: "other", message: "", breaking: false };
  }

  // Check for BREAKING CHANGE line
  if (trimmed.startsWith("BREAKING CHANGE")) {
    return { type: "breaking", message: trimmed, breaking: true };
  }

  // Parse conventional commit format: type(scope)!: description
  const match = trimmed.match(/^(\w+)(?:\([^)]*\))?(!)?\s*:\s*(.+)$/);
  if (!match) {
    return { type: "other", message: trimmed, breaking: false };
  }

  const [, type, bang, message] = match;
  const breaking = bang === "!" || trimmed.includes("BREAKING CHANGE");

  return { type, message, breaking };
}

export function determineBumpType(commits: CommitInfo[]): BumpType {
  let hasMinor = false;
  let hasPatch = false;

  for (const commit of commits) {
    if (commit.breaking) return "major";
    if (commit.type === "feat") hasMinor = true;
    if (commit.type === "fix") hasPatch = true;
  }

  if (hasMinor) return "minor";
  if (hasPatch) return "patch";
  return "none";
}

export function bumpVersion(
  current: SemanticVersion,
  bump: BumpType
): SemanticVersion {
  switch (bump) {
    case "major":
      return { major: current.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: current.major, minor: current.minor + 1, patch: 0 };
    case "patch":
      return {
        major: current.major,
        minor: current.minor,
        patch: current.patch + 1,
      };
    case "none":
      return { ...current };
  }
}

export function generateChangelog(
  version: SemanticVersion,
  commits: CommitInfo[],
  date: string
): string {
  const sections: Record<string, string[]> = {};

  for (const commit of commits) {
    if (commit.type === "other" && !commit.message) continue;

    const sectionName = getSectionName(commit.type, commit.breaking);
    if (!sections[sectionName]) {
      sections[sectionName] = [];
    }
    sections[sectionName].push(commit.message);
  }

  let changelog = `## [${formatVersion(version)}] - ${date}\n\n`;

  for (const [section, messages] of Object.entries(sections)) {
    changelog += `### ${section}\n\n`;
    for (const msg of messages) {
      changelog += `- ${msg}\n`;
    }
    changelog += "\n";
  }

  return changelog;
}

function getSectionName(type: string, breaking: boolean): string {
  if (breaking) return "Breaking Changes";
  switch (type) {
    case "feat":
      return "Features";
    case "fix":
      return "Bug Fixes";
    case "docs":
      return "Documentation";
    case "chore":
      return "Chores";
    case "style":
      return "Styles";
    case "refactor":
      return "Refactoring";
    case "test":
      return "Tests";
    case "breaking":
      return "Breaking Changes";
    default:
      return "Other";
  }
}

export function parseCommitLog(logContent: string): CommitInfo[] {
  return logContent
    .split("\n")
    .filter((line) => line.trim().length > 0)
    .map(parseCommit);
}

export function readVersionFromPackageJson(content: string): string {
  const pkg = JSON.parse(content);
  if (!pkg.version) {
    throw new Error("No version field found in package.json");
  }
  return pkg.version;
}

export function updatePackageJsonVersion(
  content: string,
  newVersion: string
): string {
  const pkg = JSON.parse(content);
  pkg.version = newVersion;
  return JSON.stringify(pkg, null, 2) + "\n";
}
