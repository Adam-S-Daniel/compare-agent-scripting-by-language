// Generate a markdown changelog section from parsed conventional commits.

import type { ConventionalCommit } from "./commits";

/** Map a commit type to a human-readable category label. */
function getCategoryLabel(type: string): string {
  switch (type) {
    case "feat":
      return "Features";
    case "fix":
      return "Bug Fixes";
    default:
      return "Other";
  }
}

/**
 * Build a markdown changelog entry for a given version and set of commits.
 * Groups commits by category (Features, Bug Fixes, Other) and highlights
 * breaking changes in a separate section.
 */
export function generateChangelog(
  version: string,
  commits: ConventionalCommit[],
  date: string = new Date().toISOString().split("T")[0],
): string {
  const sections: Record<string, string[]> = {};

  for (const commit of commits) {
    const category = getCategoryLabel(commit.type);
    if (!sections[category]) sections[category] = [];
    const scope = commit.scope ? `**${commit.scope}:** ` : "";
    sections[category].push(`- ${scope}${commit.description}`);

    if (commit.breaking) {
      if (!sections["Breaking Changes"]) sections["Breaking Changes"] = [];
      sections["Breaking Changes"].push(`- ${scope}${commit.description}`);
    }
  }

  let changelog = `## ${version} (${date})\n\n`;

  // Render sections in a stable order: breaking first, then features, fixes, other
  const order = ["Breaking Changes", "Features", "Bug Fixes", "Other"];
  for (const section of order) {
    const items = sections[section];
    if (items && items.length > 0) {
      changelog += `### ${section}\n\n`;
      const unique = [...new Set(items)];
      changelog += unique.join("\n") + "\n\n";
    }
  }

  return changelog.trimEnd() + "\n";
}
