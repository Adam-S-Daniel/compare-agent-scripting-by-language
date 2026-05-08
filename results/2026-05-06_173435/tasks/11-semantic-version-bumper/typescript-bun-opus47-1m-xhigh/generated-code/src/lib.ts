// Pure library functions for the semantic version bumper.
//
// Conventional Commits subset we recognize:
//   <type>[optional scope][!]: <subject>
//     [optional body]
//     [optional BREAKING CHANGE: footer]
//
// Type -> bump:
//   ! suffix or "BREAKING CHANGE:" footer -> major
//   feat                                  -> minor
//   fix                                   -> patch
//   anything else                         -> no bump (chore/docs/refactor/etc.)
//
// All file I/O lives in cli.ts so this module stays trivially testable.

export interface Commit {
  type: string;
  scope?: string;
  subject: string;
  breaking: boolean;
  body?: string;
}

export type BumpType = "major" | "minor" | "patch";

const HEADER_RE = /^([a-zA-Z]+)(?:\(([^)]+)\))?(!)?:\s+(.+)$/;

export function parseCommit(message: string): Commit {
  if (!message || !message.trim()) {
    throw new Error("Cannot parse empty commit message");
  }
  const lines = message.split(/\r?\n/);
  const header = lines[0]!.trim();
  const body = lines.slice(1).join("\n").trim() || undefined;

  const m = HEADER_RE.exec(header);
  if (!m) {
    // Non-conventional commits are tagged "chore" so they're harmless to the bump.
    return { type: "chore", subject: header, breaking: false, body };
  }
  const [, type, scope, bang, subject] = m;
  const breaking = bang === "!" || /^BREAKING[ -]CHANGE:/m.test(body ?? "");
  return {
    type: type!.toLowerCase(),
    scope: scope || undefined,
    subject: subject!.trim(),
    breaking,
    body,
  };
}

// Commits in our log fixtures are separated by a line containing only "---".
// This mirrors what `git log --pretty=...---` would produce and avoids ambiguity
// around blank lines inside commit bodies.
export function parseCommitLog(log: string): Commit[] {
  return log
    .split(/^---\s*$/m)
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    .map(parseCommit);
}

export function determineBump(commits: Commit[]): BumpType | null {
  let level: BumpType | null = null;
  for (const c of commits) {
    if (c.breaking) return "major"; // major short-circuits — nothing outranks it.
    if (c.type === "feat" && level !== "minor") level = "minor";
    else if (c.type === "fix" && level === null) level = "patch";
  }
  return level;
}

export function bumpVersion(version: string, bump: BumpType): string {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(version);
  if (!m) {
    throw new Error(`Invalid semver string: "${version}"`);
  }
  let [maj, min, pat] = [Number(m[1]), Number(m[2]), Number(m[3])];
  switch (bump) {
    case "major":
      maj += 1;
      min = 0;
      pat = 0;
      break;
    case "minor":
      min += 1;
      pat = 0;
      break;
    case "patch":
      pat += 1;
      break;
  }
  return `${maj}.${min}.${pat}`;
}

interface Section {
  heading: string;
  commits: Commit[];
}

// Conventional Changelog convention: only feat/fix/perf/refactor and breaking
// changes show up in the changelog. chore/docs/test/style are noise.
export function generateChangelogEntry(
  version: string,
  commits: Commit[],
  isoDate: string,
): string {
  const sections: Section[] = [
    { heading: "BREAKING CHANGES", commits: commits.filter((c) => c.breaking) },
    {
      heading: "Features",
      commits: commits.filter((c) => c.type === "feat" && !c.breaking),
    },
    {
      heading: "Bug Fixes",
      commits: commits.filter((c) => c.type === "fix" && !c.breaking),
    },
    {
      heading: "Performance Improvements",
      commits: commits.filter((c) => c.type === "perf" && !c.breaking),
    },
  ];

  const lines: string[] = [`## [${version}] - ${isoDate}`, ""];
  for (const section of sections) {
    if (section.commits.length === 0) continue;
    lines.push(`### ${section.heading}`, "");
    for (const c of section.commits) {
      const scope = c.scope ? `**${c.scope}**: ` : "";
      lines.push(`- ${scope}${c.subject}`);
    }
    lines.push("");
  }
  return lines.join("\n").replace(/\n+$/, "\n");
}
