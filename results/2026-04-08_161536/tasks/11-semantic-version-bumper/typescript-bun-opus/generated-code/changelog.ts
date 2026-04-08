// Changelog generation from conventional commits

import type { ConventionalCommit, ChangelogEntry } from "./types";

/** Build a structured changelog entry from parsed commits */
export function generateChangelog(
  commits: ConventionalCommit[],
  version: string,
  date: string
): ChangelogEntry {
  const entry: ChangelogEntry = {
    version,
    date,
    features: [],
    fixes: [],
    breaking: [],
    other: [],
  };

  for (const commit of commits) {
    const desc = commit.scope
      ? `**${commit.scope}:** ${commit.description}`
      : commit.description;

    if (commit.breaking) {
      entry.breaking.push(desc);
    } else if (commit.type === "feat") {
      entry.features.push(desc);
    } else if (commit.type === "fix") {
      entry.fixes.push(desc);
    } else {
      entry.other.push(desc);
    }
  }

  return entry;
}

/** Format a changelog entry as a markdown string */
export function formatChangelog(entry: ChangelogEntry): string {
  const sections: string[] = [];
  sections.push(`## ${entry.version} (${entry.date})\n`);

  if (entry.breaking.length > 0) {
    sections.push("### Breaking Changes\n");
    for (const item of entry.breaking) sections.push(`- ${item}`);
    sections.push("");
  }

  if (entry.features.length > 0) {
    sections.push("### Features\n");
    for (const item of entry.features) sections.push(`- ${item}`);
    sections.push("");
  }

  if (entry.fixes.length > 0) {
    sections.push("### Bug Fixes\n");
    for (const item of entry.fixes) sections.push(`- ${item}`);
    sections.push("");
  }

  if (entry.other.length > 0) {
    sections.push("### Other Changes\n");
    for (const item of entry.other) sections.push(`- ${item}`);
    sections.push("");
  }

  return sections.join("\n");
}
