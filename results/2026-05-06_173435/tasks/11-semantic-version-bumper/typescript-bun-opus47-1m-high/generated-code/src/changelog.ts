// Changelog entry generator. Produces a single Markdown section for one release,
// which the CLI then prepends to CHANGELOG.md. Layout follows conventional-changelog:
//   ## <version> (<date>)
//   ### BREAKING CHANGES   (only if any)
//   ### Features           (only if any feat:)
//   ### Bug Fixes          (only if any fix:)
//   ### Other Changes      (perf/refactor/etc., grouped)
// chore/docs/style/test/build/ci are intentionally suppressed from the user-facing
// changelog — they're noise for end users.

import type { ParsedCommit } from "./commits.ts";

export interface ChangelogInput {
  version: string;
  date: string;
  commits: ParsedCommit[];
}

const TYPE_LABELS: Record<string, string> = {
  feat: "Features",
  fix: "Bug Fixes",
  perf: "Performance",
  refactor: "Refactors",
  revert: "Reverts",
};

const SUPPRESSED = new Set(["chore", "docs", "style", "test", "build", "ci"]);

function formatBullet(c: ParsedCommit): string {
  return c.scope ? `- **${c.scope}**: ${c.description}` : `- ${c.description}`;
}

export function generateChangelogEntry(input: ChangelogInput): string {
  const { version, date, commits } = input;
  const lines: string[] = [`## ${version} (${date})`, ""];

  if (commits.length === 0) {
    lines.push("_No notable changes._", "");
    return lines.join("\n");
  }

  const breaking = commits.filter((c) => c.breaking);
  if (breaking.length > 0) {
    lines.push("### BREAKING CHANGES", "");
    for (const c of breaking) lines.push(formatBullet(c));
    lines.push("");
  }

  // Group remaining commits by labelled type, in a stable order.
  const ordered = ["feat", "fix", "perf", "refactor", "revert"];
  const grouped = new Map<string, ParsedCommit[]>();
  const other: ParsedCommit[] = [];

  for (const c of commits) {
    if (SUPPRESSED.has(c.type)) continue;
    if (TYPE_LABELS[c.type]) {
      const arr = grouped.get(c.type) ?? [];
      arr.push(c);
      grouped.set(c.type, arr);
    } else {
      other.push(c);
    }
  }

  for (const t of ordered) {
    const list = grouped.get(t);
    if (!list || list.length === 0) continue;
    lines.push(`### ${TYPE_LABELS[t]}`, "");
    for (const c of list) lines.push(formatBullet(c));
    lines.push("");
  }

  if (other.length > 0) {
    lines.push("### Other Changes", "");
    for (const c of other) lines.push(formatBullet(c));
    lines.push("");
  }

  // Trim trailing empty line for a tidy entry, then re-add one for separation.
  while (lines.length && lines[lines.length - 1] === "") lines.pop();
  lines.push("");
  return lines.join("\n");
}
