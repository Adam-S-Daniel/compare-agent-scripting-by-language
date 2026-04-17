// Render a changelog entry (Keep-a-Changelog style) for a set of commits.
//
// Sections:
//   - Breaking changes (commit.breaking === true)
//   - Features        (type === "feat" AND NOT breaking)
//   - Bug fixes       (type === "fix"  AND NOT breaking)
// Other conventional types (chore/docs/test/...) are hidden from the log.

import type { Commit } from "./commits.ts";

export interface ChangelogInput {
  version: string;
  date: string; // ISO yyyy-mm-dd
  commits: Commit[];
}

function bullet(commit: Commit): string {
  const scopePrefix = commit.scope ? `**${commit.scope}:** ` : "";
  return `- ${scopePrefix}${commit.subject}`;
}

export function renderChangelogEntry(input: ChangelogInput): string {
  const { version, date, commits } = input;
  const breaking = commits.filter((c) => c.breaking);
  const features = commits.filter((c) => !c.breaking && c.type === "feat");
  const fixes = commits.filter((c) => !c.breaking && c.type === "fix");

  const lines: string[] = [`## [${version}] - ${date}`, ""];

  let emittedAny = false;
  const addSection = (title: string, items: Commit[]): void => {
    if (items.length === 0) return;
    lines.push(`### ${title}`);
    for (const item of items) lines.push(bullet(item));
    lines.push("");
    emittedAny = true;
  };

  addSection("Breaking changes", breaking);
  addSection("Features", features);
  addSection("Bug fixes", fixes);

  if (!emittedAny) {
    lines.push("_No user-facing changes._");
    lines.push("");
  }

  return lines.join("\n");
}
