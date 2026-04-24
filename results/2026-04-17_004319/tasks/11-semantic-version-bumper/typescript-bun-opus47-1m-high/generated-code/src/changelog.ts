// Changelog generation. Produces a Markdown section for a single release.
// Breaking changes are called out first, then features, then fixes.
// chore/docs/style/refactor/test/ci/build commits are intentionally omitted
// because they aren't user-facing.
import type { Commit } from "./parser";

const SECTION_FEATURES = "### Features";
const SECTION_FIXES = "### Fixes";
const SECTION_BREAKING = "### Breaking Changes";

function formatLine(c: Commit): string {
  const scope = c.scope ? `**${c.scope}**: ` : "";
  return `- ${scope}${c.description}`;
}

export function generateChangelogEntry(
  newVersion: string,
  commits: readonly Commit[],
  date: string
): string {
  const lines: string[] = [`## ${newVersion} - ${date}`, ""];

  const breaking = commits.filter((c) => c.breaking);
  const features = commits.filter((c) => !c.breaking && c.type === "feat");
  const fixes = commits.filter((c) => !c.breaking && c.type === "fix");

  const hasAny = breaking.length + features.length + fixes.length > 0;
  if (!hasAny) {
    lines.push("No user-facing changes.");
    return lines.join("\n");
  }

  if (breaking.length) {
    lines.push(SECTION_BREAKING);
    for (const c of breaking) lines.push(formatLine(c));
    lines.push("");
  }
  if (features.length) {
    lines.push(SECTION_FEATURES);
    for (const c of features) lines.push(formatLine(c));
    lines.push("");
  }
  if (fixes.length) {
    lines.push(SECTION_FIXES);
    for (const c of fixes) lines.push(formatLine(c));
    lines.push("");
  }
  return lines.join("\n").trimEnd();
}
