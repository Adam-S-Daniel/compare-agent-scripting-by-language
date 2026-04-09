// Parse conventional commit messages and determine the appropriate version bump.
// Conventional commit format: type(scope)!: description
//   - feat  -> minor bump
//   - fix   -> patch bump
//   - !     -> major bump (breaking change)

import type { BumpType } from "./version";

export interface ConventionalCommit {
  type: string;
  scope?: string;
  breaking: boolean;
  description: string;
}

/**
 * Parse a single commit subject line into a ConventionalCommit.
 * Non-conforming messages get type "other" and are ignored for bumping.
 */
export function parseCommit(subject: string): ConventionalCommit {
  const line = subject.trim();
  // Pattern: type(scope)!: description
  const match = line.match(/^(\w+)(?:\(([^)]*)\))?(!)?\s*:\s*(.+)$/);
  if (!match) {
    return { type: "other", breaking: false, description: line };
  }
  return {
    type: match[1],
    scope: match[2] || undefined,
    breaking: match[3] === "!",
    description: match[4].trim(),
  };
}

/**
 * Given a list of parsed commits, determine the highest-priority bump type.
 * Priority: major (breaking) > minor (feat) > patch (fix).
 * Returns null if no bump-worthy commits are found.
 */
export function determineBumpType(commits: ConventionalCommit[]): BumpType | null {
  let hasMinor = false;
  let hasPatch = false;

  for (const commit of commits) {
    if (commit.breaking) return "major";
    if (commit.type === "feat") hasMinor = true;
    if (commit.type === "fix") hasPatch = true;
  }

  if (hasMinor) return "minor";
  if (hasPatch) return "patch";
  return null;
}
