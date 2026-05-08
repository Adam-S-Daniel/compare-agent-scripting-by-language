import { SemVersion, formatVersion } from "./semantic-version";
import { ConventionalCommit } from "./conventional-commits";

// Generate a changelog entry for a single version
export function generateChangelogEntry(
  version: SemVersion,
  commits: ConventionalCommit[]
): string {
  const versionStr = formatVersion(version);
  const today = new Date().toISOString().split("T")[0];

  let entry = `## [${versionStr}] - ${today}\n`;

  if (commits.length === 0) {
    return entry;
  }

  // Group commits by type
  const groups: Record<string, ConventionalCommit[]> = {};

  for (const commit of commits) {
    let key = commit.type || "other";
    if (commit.breaking) {
      key = "breaking";
    }
    if (!groups[key]) {
      groups[key] = [];
    }
    groups[key].push(commit);
  }

  // Output sections in priority order
  const order = ["breaking", "feat", "fix", "refactor", "perf", "docs", "chore"];

  for (const type of order) {
    if (!groups[type]) continue;

    const heading = getHeadingForType(type);
    entry += `\n### ${heading}\n`;

    for (const commit of groups[type]) {
      const scope = commit.scope ? `**${commit.scope}:**` : "";
      entry += `- ${scope} ${commit.description}\n`;
    }
  }

  return entry;
}

// Map commit type to changelog heading
function getHeadingForType(type: string): string {
  const headings: Record<string, string> = {
    breaking: "Breaking Changes",
    feat: "Features",
    fix: "Bug Fixes",
    refactor: "Refactoring",
    perf: "Performance",
    docs: "Documentation",
    chore: "Maintenance",
  };
  return headings[type] || "Changes";
}

// Combine multiple changelog entries into a full changelog
export function generateFullChangelog(entries: string[]): string {
  let changelog = "# Changelog\n\nAll notable changes to this project are documented here.\n";
  changelog += "The format is based on [Keep a Changelog](https://keepachangelog.com/)\n";
  changelog += "and this project adheres to [Semantic Versioning](https://semver.org/).\n";

  if (entries.length > 0) {
    changelog += "\n";
    changelog += entries.join("\n");
  }

  return changelog;
}
