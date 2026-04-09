/**
 * Changelog generation from conventional commits.
 * Groups commits by type and formats them as a Markdown changelog entry.
 */

import type { ConventionalCommit } from "./commits";

/** Generate a Markdown changelog entry from commits and version info */
export function generateChangelog(
  newVersion: string,
  commits: ConventionalCommit[],
  date: string = new Date().toISOString().split("T")[0],
): string {
  const lines: string[] = [];
  lines.push(`## [${newVersion}] - ${date}`);
  lines.push("");

  // Group commits by category
  const breaking = commits.filter((c) => c.breaking);
  const features = commits.filter((c) => c.type === "feat" && !c.breaking);
  const fixes = commits.filter((c) => c.type === "fix" && !c.breaking);
  const other = commits.filter(
    (c) => !["feat", "fix"].includes(c.type) && !c.breaking,
  );

  if (breaking.length > 0) {
    lines.push("### Breaking Changes");
    for (const c of breaking) lines.push(`- ${c.description}`);
    lines.push("");
  }

  if (features.length > 0) {
    lines.push("### Features");
    for (const c of features) lines.push(`- ${c.description}`);
    lines.push("");
  }

  if (fixes.length > 0) {
    lines.push("### Bug Fixes");
    for (const c of fixes) lines.push(`- ${c.description}`);
    lines.push("");
  }

  if (other.length > 0) {
    lines.push("### Other");
    for (const c of other) lines.push(`- ${c.description}`);
    lines.push("");
  }

  return lines.join("\n");
}
